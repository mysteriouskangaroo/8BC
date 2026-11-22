# Dot-source this file to get Invoke-EightBallChampBootTest, which boots an
# eballchp ROM set in libpinmame, headless and unthrottled, and reports whether
# the CPU got past the startup checksum and drove the displays.
#
# libpinmame calls back on its own emulation thread, which has no PowerShell
# runspace, so everything that runs during emulation is C#: the library
# resolver, every callback, and log formatting. An exception escaping a native
# callback would kill the process, so every callback body catches everything.
# Requires PowerShell 7 (.NET NativeLibrary); the C# stays at C# 5 syntax.

if ($PSVersionTable.PSEdition -ne 'Core') {
    throw 'The libpinmame boot test requires PowerShell 7 (pwsh); Windows PowerShell 5.1 can still run the builds.'
}

if (-not ('EightBallChampBoot' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

public class EightBallChampBootResult {
    public bool Pass; public string Reason; public int Frames; public double WallSeconds;
    public int DisplayEvents; public int LampEvents; public int SolenoidEvents; public int SoundEvents;
    public string Stack00FC; public int U4WrittenBytes; public string Digest;
    public string[] Events; public string[] Logs;
}

public static class EightBallChampBoot {
    const string L = "libpinmame";
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
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern void PinmameSetTimeFence(double t);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameGetMaxLamps();
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern int PinmameGetChangedLamps(IntPtr buf);
    [DllImport(L, CallingConvention = CallingConvention.Cdecl)] static extern IntPtr PinmameGetRawMemoryRegion(int region);
    [DllImport("libc", EntryPoint = "vsnprintf", CallingConvention = CallingConvention.Cdecl)]
    static extern int UnixVsnprintf(StringBuilder buf, UIntPtr n, IntPtr fmt, IntPtr va);
    [DllImport("msvcrt", EntryPoint = "_vsnprintf", CallingConvention = CallingConvention.Cdecl)]
    static extern int WindowsVsnprintf(StringBuilder buf, UIntPtr n, IntPtr fmt, IntPtr va);

    // Kept in static fields so the GC cannot collect them while native code holds pointers.
    static StateCb sState = OnState; static DispAvailCb sAvail = OnAvail; static DispUpdCb sDisp = OnDisp;
    static SolCb sSol = OnSol; static KeyCb sKey = OnKey; static LogCb sLog = OnLog; static SndCb sSnd = OnSnd;

    static IntPtr libraryHandle = IntPtr.Zero;
    static readonly bool IsWindows = RuntimeInformation.IsOSPlatform(OSPlatform.Windows);
    static volatile int state = -1;
    static int frame, totalFrames;
    static ManualResetEvent done;
    static List<string> events, logs;
    static Dictionary<int, string> disp;
    static IntPtr lampBuf = IntPtr.Zero;
    static readonly Dictionary<int, char> Seg7 = new Dictionary<int, char> {
        {0x3f,'0'},{0x06,'1'},{0x5b,'2'},{0x4f,'3'},{0x66,'4'},{0x6d,'5'},{0x7d,'6'},{0x7c,'6'},
        {0x07,'7'},{0x7f,'8'},{0x6f,'9'},{0x67,'9'},{0x00,' '} };

    public static void LoadLibrary(string path) {
        if (libraryHandle != IntPtr.Zero) return;
        libraryHandle = NativeLibrary.Load(path);
        NativeLibrary.SetDllImportResolver(typeof(EightBallChampBoot).Assembly,
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
    static byte[] Ram(int addr, int n) {
        // PinmameReadMainCPUMemory returned zeros in the trial; the raw CPU1 region is live.
        IntPtr b = PinmameGetRawMemoryRegion(0x81);
        var r = new byte[n]; Marshal.Copy(new IntPtr(b.ToInt64() + addr), r, 0, n); return r;
    }
    static string Hex(byte[] b) { return BitConverter.ToString(b).Replace("-", "").ToLowerInvariant(); }
    // Events after the frame cutoff are dropped so results do not depend on host timing.
    static void Ev(string s) { if (frame < totalFrames) events.Add(frame + " " + s); }
    static void Fail(string where, Exception e) { try { logs.Add("[callback-error " + where + "] " + e.GetType().Name); } catch { } }

    static void OnState(int s, IntPtr u) { try { state = s; logs.Add("state=" + s); } catch (Exception e) { Fail("state", e); } }
    static void OnAvail(int i, int n, IntPtr layout, IntPtr u) { }
    static void OnSol(IntPtr p, IntPtr u) { try { Ev("sol " + Marshal.ReadInt32(p, 0) + " " + Marshal.ReadInt32(p, 4)); } catch (Exception e) { Fail("sol", e); } }
    static int OnKey(int k, IntPtr u) { return 0; }
    static void OnSnd(int b, int c, IntPtr u) { try { Ev("snd " + b + " " + c); } catch (Exception e) { Fail("snd", e); } }
    static void OnLog(int level, IntPtr fmt, IntPtr va, IntPtr u) {
        try {
            var sb = new StringBuilder(1024);
            if (IsWindows) WindowsVsnprintf(sb, new UIntPtr(1023), fmt, va);
            else UnixVsnprintf(sb, new UIntPtr(1024), fmt, va);
            logs.Add("[" + level + "] " + sb.ToString());
        }
        catch (Exception e) { Fail("log", e); }
    }
    static void OnDisp(int i, IntPtr data, IntPtr layout, IntPtr u) {
        try {
            if (data != IntPtr.Zero) {
                int len = Marshal.ReadInt32(layout, 12);   // PinmameDisplayLayout.length
                string t = SegText(data, len);
                string old;
                if (!disp.TryGetValue(i, out old) || old != t) { disp[i] = t; Ev("disp " + i + " " + t); }
            }
            if (i != 0 || frame >= totalFrames) return;
            // Display 0 updates once per emulated frame: this is the frame clock.
            if (lampBuf == IntPtr.Zero) lampBuf = Marshal.AllocHGlobal(8 * Math.Max(PinmameGetMaxLamps(), 1));
            int n = PinmameGetChangedLamps(lampBuf);
            for (int k = 0; k < n; k++) Ev("lamp " + Marshal.ReadInt32(lampBuf, 8 * k) + " " + Marshal.ReadInt32(lampBuf, 8 * k + 4));
            if (frame == 0) { PinmameSetSwitch(8, 1); Ev("sw 8 1"); }   // ball resting in the outhole
            if (frame == 60 || frame == 300 || frame == totalFrames - 1) {
                byte[] u4 = Ram(0x1000, 0x800); int written = 0; foreach (byte x in u4) if (x != 0xFF) written++;
                Ev("ram stack=" + Hex(Ram(0x00FC, 4)) + " u4written=" + written);
            }
            frame++;
            if (frame >= totalFrames) done.Set();
        }
        catch (Exception e) { Fail("disp", e); }
    }

    public static EightBallChampBootResult Run(string vpmPath, int frames) {
        if (libraryHandle == IntPtr.Zero) throw new InvalidOperationException("Call LoadLibrary first.");
        if (!vpmPath.EndsWith("/") && !vpmPath.EndsWith("\\")) vpmPath += Path.DirectorySeparatorChar;
        foreach (string d in new[] { "nvram", "cfg", "hi" }) { string p = vpmPath + d; if (Directory.Exists(p)) Directory.Delete(p, true); }
        state = -1; frame = 0; totalFrames = frames; done = new ManualResetEvent(false);
        events = new List<string>(); logs = new List<string>(); disp = new Dictionary<int, string>();

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

        var sw = System.Diagnostics.Stopwatch.StartNew();
        int rc = PinmameRun("eballchp");
        if (rc != 0) throw new Exception("PinmameRun returned status " + rc);
        while (state != 1 && sw.Elapsed.TotalSeconds < 20) Thread.Sleep(5);
        PinmameSetTimeFence(1.0); PinmameSetTimeFence(1.0e7);   // turns off real-time throttling
        bool finished = done.WaitOne(TimeSpan.FromSeconds(600));
        PinmameStop();
        while (PinmameIsRunning() != 0 && sw.Elapsed.TotalSeconds < 630) Thread.Sleep(5);

        var r = new EightBallChampBootResult();
        r.Frames = frame; r.WallSeconds = Math.Round(sw.Elapsed.TotalSeconds, 2);
        r.Events = events.ToArray(); r.Logs = logs.ToArray();
        string last = null;
        foreach (string e in r.Events) {
            string k = e.Split(' ')[1];
            if (k == "disp") r.DisplayEvents++; else if (k == "lamp") r.LampEvents++;
            else if (k == "sol") r.SolenoidEvents++; else if (k == "snd") r.SoundEvents++;
            else if (k == "ram") last = e;
        }
        using (var h = SHA256.Create())
            r.Digest = Hex(h.ComputeHash(Encoding.UTF8.GetBytes(string.Join("\n", r.Events))));
        r.Stack00FC = last == null ? "" : last.Substring(last.IndexOf("stack=") + 6, 8);
        r.U4WrittenBytes = last == null ? -1 : int.Parse(last.Substring(last.IndexOf("u4written=") + 10));
        var why = new List<string>();
        if (!finished) why.Add("timed out before frame " + frames);
        if (r.DisplayEvents == 0) why.Add("no display events");
        if (r.Stack00FC == "c000e3e0") why.Add("stack 00FC-00FF = C000 E3E0 (checksum-failure loop)");
        if (r.U4WrittenBytes <= 0) why.Add("U4 RAM 1000-17FF never written (all FF)");
        r.Pass = why.Count == 0;
        r.Reason = r.Pass ? "ok" : string.Join("; ", why.ToArray());
        return r;
    }
}
'@
}

function Invoke-EightBallChampBootTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$LibraryPath,
        # Folder holding roms/eballchp.zip; its nvram/, cfg/ and hi/ are cleared first.
        [Parameter(Mandatory = $true)][string]$VpmPath,
        [ValidateRange(600, 36000)][int]$Frames = 1500
    )
    # libpinmame keeps process-wide state between runs: its zip cache reads a
    # later, different eballchp.zip through the first one's directory (corrupt
    # data or a hang), and sound-board state can leak into the next run's first
    # frame. Only the first boot in a process is trustworthy.
    if ($script:EightBallChampBootDone) {
        throw 'libpinmame allows one boot per process; run each boot test in a new pwsh process.'
    }
    $script:EightBallChampBootDone = $true
    [EightBallChampBoot]::LoadLibrary((Resolve-Path -LiteralPath $LibraryPath).Path)
    $result = [EightBallChampBoot]::Run((Resolve-Path -LiteralPath $VpmPath).Path, $Frames)
    [PSCustomObject]@{
        Pass           = $result.Pass
        Reason         = $result.Reason
        Frames         = $result.Frames
        WallSeconds    = $result.WallSeconds
        DisplayEvents  = $result.DisplayEvents
        LampEvents     = $result.LampEvents
        SolenoidEvents = $result.SolenoidEvents
        SoundEvents    = $result.SoundEvents
        Stack00FC      = $result.Stack00FC
        U4WrittenBytes = $result.U4WrittenBytes
        Digest         = $result.Digest
        Logs           = $result.Logs
    }
}
