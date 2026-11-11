# Eight Ball Champ CPU / Hardware Reference

This note accompanies the canonical analysis project for the original,
read-only ROM.  It records the hardware model used when reading the 6803 ROM
and distinguishes confirmed facts from the remaining schematic-tracing work.

## Evidence

- **ROM:** `../roms/u3_cpu.128` (16 KiB, mapped at `C000-FFFF`).  Its SHA-1 is
  `25D310F169B92CE6B348330816DDC3B5710E57DA`.
- **Manual:** `../../../docs/Eight_Ball_Champ_OPS.pdf`, especially section 3:
  control-board layout/designations and cabinet/playfield schematics.
- **Ghidra program:** `u3_cpu.128`, analyzed as a Motorola 6801/6803-family
  processor.

## Definitions
 PIA: A Peripheral Interface Adapter is a 40-pin integrated circuit designed by Motorola in the 1970s to provide parallel input/output (I/O) interfacing for the Motorola 6800 family of microprocessors. For example, In an 8-bit parallel interface (like the 6821 PIA), there are 8 distinct physical wires dedicated to data. When the microprocessor sends a byte of data (e.g., 10110011), all 8 bits are sent across the 8 wires at the exact same instant, synchronized by a clock or control signal. The clock / control signal ensures that the sender and the receiver are perfectly synchronized and know exactly when to transmit or read data.

## Working memory map

| Address range | Purpose | Confidence |
| --- | --- | --- |
| `0000-001F` | 6803 internal registers (ports, timers, serial hardware) | Confirmed |
| `0020-0023` | One external 6821 PIA | Confirmed by board parts and ROM initialization |
| `0040-0043` | The other external 6821 PIA | Confirmed by board parts and ROM initialization |
| `0080-00FF` | 6803 on-chip RAM | Processor architecture; verify against the decoder sheet if needed |
| `1000-17FF` | 2 KiB working RAM, U4 (6116) | High confidence; the ROM actively uses this area |
| `C000-FFFF` | U3 CPU ROM | Confirmed |

The two PIAs are the ROM's bridge to the machine. A 6821's registers are organized as port A/DDRA, control A, port B/DDRB, control B at offsets `+0` through `+3`. The exact correspondence between the two address blocks and physical chips **U7/U8** remains to be verified from the CPU/PIA schematic sheets; do not assume a U7/U8 assignment yet.

## Executable starting points

The vector table at `FFF0-FFFF` identifies the first useful control-flow
anchors:

| Vector | Target | Meaning |
| --- | --- | --- |
| `FFF0` / `FFF2` | `E05B` | SCI / timer-overflow service |
| `FFF4` | `E022` | timer output-compare service |
| `FFF6` | `E05C` | timer input-capture service |
| `FFF8` | `E032` | external IRQ service (PIA activity) |
| `FFFA` | `E388` | SWI service |
| `FFFC` | `E387` | NMI service |
| `FFFE` | `E388` | reset entry |

The startup/PIA configuration sequence is concentrated around `E388` and
`E50F-E547`.  Hardware accesses to `0020-0023` and `0040-0043` are therefore
the best places to correlate firmware behavior with the wiring diagrams.

## Physical machine model

The manual identifies U1 as the 6803 CPU, U4 as the 6116 RAM, and U7/U8 as
6821 PIAs.  It also provides the switch, solenoid, lamp-driver, cabinet, and
playfield wiring tables.  In practical terms the paths are:

```text
switches / cabinet buttons  -> PIA inputs -> IRQ and rules code
rules code                  -> PIA outputs -> lamp and solenoid driver logic
lamp / solenoid driver logic -> playfield lamps, kickers, drop targets, etc.
```

The driver schematic shows a 74LS154 decoding momentary-solenoid data lines
and a 4514-based lamp-strobe circuit.  This supports interpreting repeated
PIA writes as physical-output activity, but individual bit-to-device names
must be traced sheet-by-sheet before adding final names to the disassembly.

## Annotation policy

Ghidra labels and comments use these rules:

- Vector, reset, interrupt, RAM, and PIA names are safe to use now.
- A port may be described as a **PIA** port without prematurely deciding
  which physical connector or U7/U8 package it is.
- Names for a particular switch, lamp, or coil are only final after their
  signal is followed through the schematic and cross-checked against ROM use.

The Ghidra annotations are deliberately kept in this original analysis
project.  Experimental rules changes belong in the separately named variation
directory, not here.
