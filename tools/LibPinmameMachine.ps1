# Dot-source this file to get the lockstep Eight Ball Champ machine: one
# libpinmame boot per process, headless and unthrottled, that pauses the
# emulation thread after exactly the number of frames the caller asks for.
#
# The display callbacks are the frame clock. Each video update delivers every
# display in index order (core.c updateDisplay, then the generated alpha DMD as
# the last index), with null data when a display did not change. At the end of
# each update (the callback for the last display index) the machine reads the
# changed lamps and, if the frame counter equals the target, marks itself
# paused and blocks the emulation thread until the caller resumes it, so a
# pause always sits between whole updates. While paused, RAM, switches, lamps
# and displays can be read and written without racing the CPU. Stop() releases
# a paused emulation thread before PinmameStop joins it.
#
# libpinmame calls back on its own thread, which has no PowerShell runspace, so
# everything that runs during emulation is C#; every callback body catches
# everything, because an exception escaping a native callback kills the process.
# Requires PowerShell 7 (.NET NativeLibrary); the C# stays at C# 5 syntax.

if ($PSVersionTable.PSEdition -ne 'Core') {
    throw 'The libpinmame machine requires PowerShell 7 (pwsh).'
}

if (-not ('EightBallChampMachine' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class EightBallChampMachine {
    const string L = "libpinmame";
    // Hang guard for every wait, both threads; hitting it is a failure, never a pass.
    static volatile int hangGuardSeconds = 600;
    public static int HangGuardSeconds {
        get { return hangGuardSeconds; }
        set { if (value < 1) throw new ArgumentOutOfRangeException("value"); hangGuardSeconds = value; }
    }
    // Test hook (tests/kit/machine.tests.ps1 'Start survives a slow start-up'):
    // holds the game thread this long in the run-state callback, which
    // libpinmame raises before cpu_run has finished starting.
    static volatile int runStateDelayMs;
    public static int RunStateDelayMs {
        get { return runStateDelayMs; }
        set { if (value < 0) throw new ArgumentOutOfRangeException("value"); runStateDelayMs = value; }
    }
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void StateCb(int state, IntPtr u);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void DispAvailCb(int i, int n, IntPtr layout, IntPtr u);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void DispUpdCb(int i, IntPtr data, IntPtr layout, IntPtr u);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void SolCb(IntPtr state, IntPtr u);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int KeyCb(int key, IntPtr u);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void LogCb(int level, IntPtr fmt, IntPtr va, IntPtr u);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate void SndCb(int board, int cmd, IntPtr u);

    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern void PinmameSetConfig(IntPtr cfg);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern void PinmameSetHandleKeyboard(int v);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern void PinmameSetHandleMechanics(int v);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameRun([MarshalAs(UnmanagedType.LPStr)] string name);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameIsRunning();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern void PinmameStop();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern void PinmameSetSwitch(int sw, int state);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameGetSwitch(int sw);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameGetLamp(int lamp);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern void PinmameSetTimeFence(double t);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameGetMaxLamps();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameGetChangedLamps(IntPtr buf);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern IntPtr PinmameGetRawMemoryRegion(int region);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern UIntPtr PinmameGetRawMemoryRegionLength(int region);
    [DllImport("libc", EntryPoint = "vsnprintf", CallingConvention = CallingConvention.Cdecl)]
    static extern int UnixVsnprintf(StringBuilder buf, UIntPtr n, IntPtr fmt, IntPtr va);
    [DllImport("msvcrt", EntryPoint = "_vsnprintf", CallingConvention = CallingConvention.Cdecl)]
    static extern int WindowsVsnprintf(StringBuilder buf, UIntPtr n, IntPtr fmt, IntPtr va);

    // Kept in static fields so the GC cannot collect them while native code holds pointers.
    static StateCb sState = OnState; static DispAvailCb sAvail = OnAvail; static DispUpdCb sDisp = OnDisp;
    static SolCb sSol = OnSol; static KeyCb sKey = OnKey; static LogCb sLog = OnLog; static SndCb sSnd = OnSnd;

    static IntPtr libraryHandle = IntPtr.Zero;
    static bool booted;
    // Guards events, logs and display text, which both threads touch. After
    // Stop, 'closed' makes any late callback drop its event.
    static readonly object gate = new object();
    static bool closed;
    static readonly bool IsWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
    static volatile int state = -1;
    // Frame convention: Frame k is the pause point at the end of video update
    // k + 1 (Start returns at Frame 0, the end of the first update). An event is
    // stamped with the Frame of the first pause point at which it is visible, so
    // while paused at Frame k the event list holds exactly the events stamped
    // 0..k, and AdvanceUntilEvent returns the Frame it stopped at. Switch changes
    // made while paused at k are stamped k and take effect after k.
    // frame and target change only on the emulation thread while running, or on
    // the caller's thread while the emulation thread is blocked in Pause.
    static volatile int frame, target;
    static volatile int lastDisplay = -1;   // highest display index (from the display-available callback)
    static volatile bool stopping, stopped, faulted;
    static volatile string faultMessage;
    // 'paused' is set by the emulation thread when it blocks; 'resume' releases it.
    static readonly ManualResetEvent paused = new ManualResetEvent(false);
    static readonly AutoResetEvent resume = new AutoResetEvent(false);
    static List<string> events = new List<string>(), logs = new List<string>();
    static Dictionary<int, string> disp = new Dictionary<int, string>();
    static IntPtr lampBuf = IntPtr.Zero;
    static readonly Dictionary<int, char> Seg7 = new Dictionary<int, char> {
        {0x3f,'0'},{0x06,'1'},{0x5b,'2'},{0x4f,'3'},{0x66,'4'},{0x6d,'5'},{0x7d,'6'},{0x7c,'6'},
        {0x07,'7'},{0x7f,'8'},{0x6f,'9'},{0x67,'9'},{0x00,' '} };

    public static int Frame { get { return frame; } }
    public static int EventCount { get { lock (gate) return events.Count; } }
    public static string[] Logs { get { lock (gate) return logs.ToArray(); } }
    // True while libpinmame reports its game thread running (false after Stop returns).
    public static bool IsRunning { get { return libraryHandle != IntPtr.Zero && PinmameIsRunning() != 0; } }

    public static void LoadLibrary(string path) {
        if (libraryHandle != IntPtr.Zero) return;
        libraryHandle = NativeLibrary.Load(path);
        NativeLibrary.SetDllImportResolver(typeof(EightBallChampMachine).Assembly,
            delegate (string name, Assembly asm, DllImportSearchPath? sp) { return name == L ? libraryHandle : IntPtr.Zero; });
    }

    static string SegText(IntPtr data, int len) {
        var sb = new StringBuilder();
        for (int k = 0; k < len; k++) {
            int v = (ushort)Marshal.ReadInt16(data, 2 * k);
            char c; sb.Append(Seg7.TryGetValue(v & 0x7f, out c) ? c : '?');
            if ((v & 0x80) != 0) sb.Append(',');
        }
        return sb.ToString();
    }
    static void Ev(string s) { lock (gate) { if (!closed) events.Add(frame + " " + s); } }
    static void Log(string s) { lock (gate) { if (!closed) logs.Add(s); } }
    static void Fail(string where, Exception e) { try { Log("[callback-error " + where + "] " + e.GetType().Name + ": " + e.Message); } catch { } }

    // Emulation thread only: block until the caller resumes, or Stop() is called.
    // On a hang-guard expiry the machine is marked faulted and no longer paused,
    // so every later call throws instead of reading a free-running emulator.
    static void Pause() {
        if (stopping || faulted) return;
        paused.Set();
        int guard = hangGuardSeconds;
        if (!resume.WaitOne(TimeSpan.FromSeconds(guard))) {
            faultMessage = "hang guard: emulation thread paused " + guard + " s at frame " + frame + " without a resume; the machine is faulted";
            faulted = true;
            paused.Reset();
            throw new TimeoutException(faultMessage);
        }
    }

    static void OnState(int s, IntPtr u) { try { state = s; Log("state=" + s); if (s == 1 && runStateDelayMs > 0) Thread.Sleep(runStateDelayMs); } catch (Exception e) { Fail("state", e); } }
    static void OnAvail(int i, int n, IntPtr layout, IntPtr u) { try { if (i > lastDisplay) lastDisplay = i; } catch (Exception e) { Fail("avail", e); } }
    static void OnSol(IntPtr p, IntPtr u) { try { Ev("sol " + Marshal.ReadInt32(p, 0) + " " + Marshal.ReadInt32(p, 4)); } catch (Exception e) { Fail("sol", e); } }
    static int OnKey(int k, IntPtr u) { return 0; }
    static void OnSnd(int b, int c, IntPtr u) { try { Ev("snd " + b + " " + c); } catch (Exception e) { Fail("snd", e); } }
    static void OnLog(int level, IntPtr fmt, IntPtr va, IntPtr u) {
        try {
            var sb = new StringBuilder(1024);
            if (IsWindows) WindowsVsnprintf(sb, new UIntPtr(1023), fmt, va);
            else UnixVsnprintf(sb, new UIntPtr(1024), fmt, va);
            Log("[" + level + "] " + sb.ToString());
        }
        catch (Exception e) { Fail("log", e); }
    }
    static void OnDisp(int i, IntPtr data, IntPtr layout, IntPtr u) {
        try {
            if (data != IntPtr.Zero) {
                int len = Marshal.ReadInt32(layout, 12);   // PinmameDisplayLayout.length
                string t = SegText(data, len);
                bool changed;
                lock (gate) { string old; changed = !disp.TryGetValue(i, out old) || old != t; if (changed) disp[i] = t; }
                if (changed) Ev("disp " + i + " " + t);
            }
            if (i != lastDisplay || stopping) return;
            // End of a whole update: lamps, then the pause point for this Frame.
            if (lampBuf == IntPtr.Zero) lampBuf = Marshal.AllocHGlobal(8 * Math.Max(PinmameGetMaxLamps(), 1));
            int n = PinmameGetChangedLamps(lampBuf);
            for (int k = 0; k < n; k++) Ev("lamp " + Marshal.ReadInt32(lampBuf, 8 * k) + " " + Marshal.ReadInt32(lampBuf, 8 * k + 4));
            try { if (frame == target) Pause(); }
            finally { frame++; }
        }
        catch (Exception e) { Fail("disp", e); }
    }

    static void RequirePaused(string what) {
        if (faulted) throw new TimeoutException(what + ": " + faultMessage);
        if (!booted || stopped || stopping) throw new InvalidOperationException(what + ": the machine is not running.");
        if (!paused.WaitOne(0)) throw new InvalidOperationException(what + ": the emulation thread is not paused.");
    }

    public static void Start(string vpmPath) {
        if (libraryHandle == IntPtr.Zero) throw new InvalidOperationException("Call LoadLibrary first.");
        // libpinmame keeps process-wide state between runs (zip cache, sound-board
        // state), so only the first boot in a process is trustworthy.
        if (booted) throw new InvalidOperationException("libpinmame allows one boot per process; run each machine in a new pwsh process.");
        booted = true;
        if (!vpmPath.EndsWith("/") && !vpmPath.EndsWith("\\")) vpmPath += Path.DirectorySeparatorChar;
        foreach (string d in new[] { "nvram", "cfg", "hi" }) { string p = vpmPath + d; if (Directory.Exists(p)) Directory.Delete(p, true); }
        state = -1; frame = 0; target = 0; lastDisplay = -1; stopping = false; stopped = false; faulted = false;
        paused.Reset();
        lock (gate) { events = new List<string>(); logs = new List<string>(); disp = new Dictionary<int, string>(); closed = false; }

        // PinmameConfig: int audioFormat, int sampleRate, char vpmPath[512], 12 callback pointers.
        int size = 8 + 512 + 12 * IntPtr.Size;
        IntPtr cfg = Marshal.AllocHGlobal(size);
        try {
            for (int k = 0; k < size; k++) Marshal.WriteByte(cfg, k, 0);
            Marshal.WriteInt32(cfg, 4, 48000);
            byte[] pb = Encoding.UTF8.GetBytes(vpmPath);
            if (pb.Length > 511) throw new ArgumentException("VPM path longer than 511 bytes: " + vpmPath);
            Marshal.Copy(pb, 0, new IntPtr(cfg.ToInt64() + 8), pb.Length);
            Delegate[] cbs = { sState, sAvail, sDisp, null, null, null, null, sSol, null, sKey, sLog, sSnd };
            for (int k = 0; k < cbs.Length; k++)
                Marshal.WriteIntPtr(cfg, 520 + k * IntPtr.Size, cbs[k] == null ? IntPtr.Zero : Marshal.GetFunctionPointerForDelegate(cbs[k]));
            PinmameSetConfig(cfg);   // libpinmame copies the struct
        }
        finally { Marshal.FreeHGlobal(cfg); }
        PinmameSetHandleKeyboard(0); PinmameSetHandleMechanics(0);
        // A process exiting on an unhandled error still releases the emulation thread.
        AppDomain.CurrentDomain.ProcessExit += delegate { try { Stop(); } catch { } };

        int rc = PinmameRun("eballchp");
        if (rc != 0) throw new Exception("PinmameRun returned status " + rc);
        try {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            while (state != 1 && sw.Elapsed.TotalSeconds < 20) Thread.Sleep(5);
            if (state != 1) throw new TimeoutException("libpinmame did not reach the run state within 20 s (frame " + frame + ")");
            if (!paused.WaitOne(TimeSpan.FromSeconds(HangGuardSeconds)))
                throw new TimeoutException("machine did not pause at frame 0 within " + HangGuardSeconds + " s (frame " + frame + ")");
            // Turns off real-time throttling. Only once paused at frame 0: libpinmame
            // raises the run state before cpu_run resets the fence offset to
            // -fence, and fences set before that reset freeze emulated time at 0.
            PinmameSetTimeFence(1.0); PinmameSetTimeFence(1.0e7);
        }
        catch { try { Stop(); } catch { } throw; }
    }

    public static void Advance(int frames) {
        if (frames < 1) throw new ArgumentOutOfRangeException("frames", "Advance needs at least one frame.");
        RequirePaused("Advance");
        target = frame + frames;
        paused.Reset();
        resume.Set();
        if (!paused.WaitOne(TimeSpan.FromSeconds(hangGuardSeconds)))
            throw new TimeoutException("Advance(" + frames + ") did not reach frame " + target + " within " + hangGuardSeconds + " s; at frame " + frame);
        if (faulted) throw new TimeoutException("Advance: " + faultMessage);
        if (frame != target) throw new InvalidOperationException("Advance stopped at frame " + frame + ", expected " + target);
    }

    // Steps one frame at a time; returns the frame stamp of the first event added
    // after the call whose text (after the frame number) starts with prefix,
    // or -1 when maxFrames elapse without one.
    public static int AdvanceUntilEvent(string prefix, int maxFrames) {
        int seen = EventCount;
        for (int k = 0; k < maxFrames; k++) {
            Advance(1);
            lock (gate) {
                for (; seen < events.Count; seen++) {
                    string e = events[seen];
                    int sp = e.IndexOf(' ');
                    if (e.Substring(sp + 1).StartsWith(prefix, StringComparison.Ordinal)) return int.Parse(e.Substring(0, sp));
                }
            }
        }
        return -1;
    }

    public static void SetSwitch(int sw, bool closedSwitch) {
        RequirePaused("SetSwitch");
        PinmameSetSwitch(sw, closedSwitch ? 1 : 0);
        Ev("sw " + sw + " " + (closedSwitch ? 1 : 0));
    }
    public static bool GetSwitch(int sw) { RequirePaused("GetSwitch"); return PinmameGetSwitch(sw) != 0; }
    public static int Lamp(int n) { RequirePaused("Lamp"); return PinmameGetLamp(n); }
    public static string Display(int i) { lock (gate) { string t; return disp.TryGetValue(i, out t) ? t : null; } }

    static IntPtr RamAt(int addr, int n) {
        // PinmameReadMainCPUMemory returned zeros in the boot-test trial; the raw CPU1 region is live.
        IntPtr b = PinmameGetRawMemoryRegion(0x81);
        long len = (long)PinmameGetRawMemoryRegionLength(0x81).ToUInt64();
        if (b == IntPtr.Zero) throw new InvalidOperationException("CPU1 memory region is unavailable.");
        if (addr < 0 || n < 0 || addr + (long)n > len) throw new ArgumentOutOfRangeException("addr", "RAM range " + addr + "+" + n + " outside the " + len + "-byte CPU1 region.");
        return new IntPtr(b.ToInt64() + addr);
    }
    public static byte[] ReadRam(int addr, int n) {
        RequirePaused("ReadRam");
        var r = new byte[n]; Marshal.Copy(RamAt(addr, n), r, 0, n); return r;
    }
    public static void WriteRam(int addr, byte[] bytes) {
        RequirePaused("WriteRam");
        Marshal.Copy(bytes, 0, RamAt(addr, bytes.Length), bytes.Length);
    }

    public static string[] EventsSince(int index) {
        lock (gate) {
            if (index < 0) index = 0;
            if (index >= events.Count) return new string[0];
            return events.GetRange(index, events.Count - index).ToArray();
        }
    }

    public static void Stop() {
        if (!booted || stopped) return;
        stopping = true;
        resume.Set();   // release a paused emulation thread before PinmameStop joins it
        // PinmameStop joins the emulation thread with no timeout; bound it.
        var t = new Thread(delegate () { try { PinmameStop(); } catch { } });
        t.IsBackground = true;
        t.Start();
        bool joined = t.Join(TimeSpan.FromSeconds(60));
        lock (gate) { closed = true; }
        stopped = true;
        if (!joined) throw new TimeoutException("PinmameStop did not return within 60 s (frame " + frame + ")");
    }
}
'@
}

function Start-EbcMachine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LibraryPath,
        # Folder holding roms/eballchp.zip; its nvram/, cfg/ and hi/ are cleared first.
        [Parameter(Mandatory = $true)][string]$VpmPath
    )
    [EightBallChampMachine]::LoadLibrary((Resolve-Path -LiteralPath $LibraryPath).Path)
    [EightBallChampMachine]::Start((Resolve-Path -LiteralPath $VpmPath).Path)
}

function Stop-EbcMachine { [EightBallChampMachine]::Stop() }

# Runs a machine call; any exception stops the emulator before it propagates,
# so a failure on the caller's thread never leaves the emulation thread paused.
function Invoke-EbcGuarded([scriptblock]$Call) {
    try { & $Call }
    catch { try { [EightBallChampMachine]::Stop() } catch { }; throw }
}

function Step-EbcFrames {
    param([ValidateRange(1, [int]::MaxValue)][int]$Frames = 1)
    Invoke-EbcGuarded { [EightBallChampMachine]::Advance($Frames) }
}

function Wait-EbcEvent {
    param([Parameter(Mandatory = $true)][string]$Prefix, [Parameter(Mandatory = $true)][int]$MaxFrames)
    $start = [EightBallChampMachine]::Frame
    $f = Invoke-EbcGuarded { [EightBallChampMachine]::AdvanceUntilEvent($Prefix, $MaxFrames) }
    if ($f -lt 0) { throw "No event starting with '$Prefix' within $MaxFrames frames of frame $start (now frame $([EightBallChampMachine]::Frame))." }
    $f
}

function Set-EbcSwitch {
    param([Parameter(Mandatory = $true)][int]$Number, [Parameter(Mandatory = $true)][bool]$Closed)
    Invoke-EbcGuarded { [EightBallChampMachine]::SetSwitch($Number, $Closed) }
}

function Read-EbcRam {
    param([Parameter(Mandatory = $true)][int]$Address, [int]$Count = 1)
    try { , [EightBallChampMachine]::ReadRam($Address, $Count) }
    catch { try { [EightBallChampMachine]::Stop() } catch { }; throw }
}

function Write-EbcRam {
    param([Parameter(Mandatory = $true)][int]$Address, [Parameter(Mandatory = $true)][byte[]]$Bytes)
    Invoke-EbcGuarded { [EightBallChampMachine]::WriteRam($Address, $Bytes) }
}

function Get-EbcDisplay { param([Parameter(Mandatory = $true)][int]$Index) [EightBallChampMachine]::Display($Index) }

function Get-EbcLamp {
    param([Parameter(Mandatory = $true)][int]$Number)
    Invoke-EbcGuarded { [EightBallChampMachine]::Lamp($Number) }
}

function Get-EbcEvents { param([int]$Since = 0) [EightBallChampMachine]::EventsSince($Since) }
