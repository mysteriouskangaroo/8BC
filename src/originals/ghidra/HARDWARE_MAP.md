# Eight Ball Champ CPU / Hardware Reference

This note accompanies the canonical analysis project for the original,
read-only ROM. It records the hardware model used when reading the 6803 ROM
and distinguishes confirmed facts from the remaining schematic-tracing work.

## Evidence

- **ROM:** `../roms/u3_cpu.128` (16 KiB, mapped at `C000-FFFF`). Its SHA-1 is `25D310F169B92CE6B348330816DDC3B5710E57DA`.
- **Manual:** `../../../docs/Eight_Ball_Champ_OPS.pdf`, especially section 3: control-board layout/designations and cabinet/playfield schematics.
- **Ghidra program:** `u3_cpu.128`, analyzed as a Motorola 6801/6803-family processor.

## Definitions
 PIA: A Peripheral Interface Adapter is a 40-pin integrated circuit designed by Motorola in the 1970s to provide parallel input/output (I/O) interfacing for the Motorola 6800 family of microprocessors. For example, In an 8-bit parallel interface (like the 6821 PIA), there are 8 distinct physical wires dedicated to data. When the microprocessor sends a byte of data (e.g., 10110011), all 8 bits are sent across the 8 wires at the exact same instant, synchronized by a clock or control signal. The clock / control signal ensures that the sender and the receiver are perfectly synchronized and know exactly when to transmit or read data.

## Working memory map

| Address range | Purpose | Confidence |
| --- | --- | --- |
| `0000-001F` | 6803 internal registers (ports, timers, serial hardware) | Confirmed |
| `0020-0023` | PIA0: multiplexed lamp-address and switch-matrix path | Confirmed by schematic net names and ROM use |
| `0040-0043` | PIA1: momentary-solenoid path plus other I/O | Confirmed by schematic net names and ROM use |
| `0080-00FF` | 6803 on-chip RAM | Processor architecture; verify against the decoder sheet if needed |
| `1000-17FF` | 2 KiB working RAM, U4 (6116) | High confidence; the ROM actively uses this area |
| `C000-FFFF` | U3 CPU ROM | Confirmed |

The two PIAs are the ROM's bridge to the machine. A 6821's registers are organized as port A/DDRA, control A, port B/DDRB, control B at offsets `+0` through `+3`. **PIA0** and **PIA1** are schematic-net identities, not physical-chip designators: the exact correspondence to packages **U7/U8** remains unverified because sheets 1–4 are absent from this manual scan.

## Confirmed lamp path: PIA0 at `0020-0023`

When its control register selects peripheral data rather than a data-direction
register, `0020` is PIA0 port A. The schematic names its signals `PA00`
through `PA07`:

| PIA0 signal | Firmware address | Physical purpose |
| --- | --- | --- |
| `PA00-PA03` | bits 0–3 of `0020` | Four-bit address shared by lamp decoders U15, U16, and U17 |
| `PA05` | bit 5 of `0020` | Enable/inhibit control for one 16-lamp bank (U15) |
| `PA06` | bit 6 of `0020` | Enable/inhibit control for one 16-lamp bank (U16) |
| `PA07` | bit 7 of `0020` | Enable/inhibit control for one 16-lamp bank (U17) |
| `CB02` | PIA0 control-B output via `0023` | Common lamp-strobe signal |

The three 4514 decoders select a driver from `S0` through `S15`; the three
bank-enable lines make up to 48 individually addressable lamp-driver paths.
The timer output-compare service at `E022` jumps to the periodic I/O refresh
routine at `E28C`, which repeatedly updates `0020` and strobes the associated
control line. That behavior agrees with a multiplexed lamp matrix.

## Confirmed switch matrix: PIA0 at `0020` / `0022`

The same PIA0 port A is time-multiplexed for switch scanning. The ROM entry at
`E1F0` writes the five one-hot values `10`, `08`, `04`, `02`, and `01` to
`0020`, waits briefly, then reads `0022` at `E20B`. That is a five-strobe by
eight-return switch scan: 40 possible switch positions. Firmware keeps the
sampled state in RAM and combines successive samples for debounce/edge
handling before game rules consume an event.

The wiring table assigns a switch number as `(strobe × 8) + return + 1`.
The scan order in the ROM is therefore strobe 4 down to strobe 0. The exact
PIA-package identity (U7 versus U8) remains deliberately unnamed, but the
address-level relationship is confirmed: `0020` drives the matrix strobe and
`0022` reads its returns.

### Requested playfield switches

| Player-visible feature | Wiring-table name | Switch no. | Strobe | Return |
| --- | --- | ---: | ---: | ---: |
| Left inlane | `C` return lane | 17 | 2 | 0 |
| Green top rollover, left | `H` top lane | 18 | 2 | 1 |
| Green top rollover, middle | `A` top lane | 19 | 2 | 2 |
| Green top rollover, right | `M` top lane | 20 | 2 | 3 |
| Right inlane | `P` return lane | 21 | 2 | 4 |
| Left outlane | Left outlane | 23 | 2 | 6 |
| Right outlane | Right outlane | 24 | 2 | 7 |
| Left orange star rollover | Left rollover button | 12 | 1 | 3 |
| Right orange star rollover | Right rollover button | 13 | 1 | 4 |
| Middle orange star rollover | Center rollover button | 29 | 3 | 4 |
| Spinner | Spinner | 32 | 3 | 7 |

The `C` / `H` / `A` / `M` / `P` locations are the five playfield positions
used to spell **CHAMP**. The source matrix calls the two lower positions
“return lanes”; here they are also described as left/right inlanes so the
documentation matches the playfield terminology.

The printed switch-summary list in some copies of the manual transposes the
spinner and lane-change positions. The wiring matrix is internally consistent
with the ROM's five-by-eight scan and is used here: **spinner = 32** and the
cabinet lane-change input = **26**.

## Confirmed momentary-solenoid path: PIA1 at `0040-0043`

`0042` is PIA1 port B when CRB selects peripheral data. Its low nibble is
named directly on the board schematic:

| PIA1 signal | Firmware address | Physical purpose |
| --- | --- | --- |
| `PB10-PB13` | bits 0–3 of `0042` | Four-bit momentary-solenoid number into U14 (74LS154) |
| `CB12` | PIA1 control-B output via `0043` | Solenoid-bank select |

The helper at `F5DF` preserves the upper nibble of `0042`, writes the
requested low-nibble solenoid number, and changes the `CB12` state through
`0043` when the request's bit 7 is set. It also starts a four-tick timer in
`100D`. When that timer expires, the periodic service at `E0A1-E0A5` forces
the low nibble to `F`, selecting U14's `M15` decoder state. The available
schematic and driver table assign no physical coil to `M15`, ending the
momentary pulse. This is the firmware safety mechanism that prevents a
momentary coil from being held on indefinitely.

### U14 decoder outputs identified by both schematic and driver table

The binary value on `PB10-PB13` selects U14 output `M0` through `M15`. These
physical outputs are cross-checked by connector/pin in the schematic and the
manual's *Solenoid Driver Locations* table:

| U14 output | Connector / pin | Physical coil |
| --- | --- | --- |
| `M0` | J6-1 | Drop targets 1/2 |
| `M1` | J6-2 | Drop target 3 |
| `M2` | J6-3 | Drop targets 4/5 |
| `M3` | J6-4 | Drop target 6 |
| `M4` | J8-7 | Drop target 7 |
| `M7` | J9-1 | Saucer |
| `M8` | J9-2 | Right thumper bumper |
| `M9` | J9-3 | Left thumper bumper |
| `M10` | J9-4 | Right slingshot |
| `M11` | J9-6 | Left slingshot |
| `M13` | J9-8 | Outhole |
| `M14` | J7-2 | Knocker |

The schematic also shows `M5`, `M6`, and `M12`, but the Eight Ball Champ
driver-location table does not give each one a physical-coil name. They remain
unnamed here rather than guessed. The flipper-enable relay K1 is documented
as a controlled coil on the board, but its U14 output still needs a complete
trace through the unavailable sheet(s).

## Executable starting points

The vector table at `FFF0-FFFF` identifies the first useful control-flow
anchors:

| Vector | Target | Meaning |
| --- | --- | --- |
| `FFF0` / `FFF2` | `E05B` | SCI / timer-overflow service |
| `FFF4` | `E022` | timer output-compare service |
| `FFF6` | `E05C` | timer input-capture service |
| `FFF8` | `E032` | external IRQ service; acknowledges PIA control/port activity |
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
and three 4514-based lamp-strobe circuits. The ROM behavior above ties those
circuits to specific PIA registers. The switch matrix, display path, sound
control lines, the PIA0/PIA1-to-U7/U8 package relationship, and the remaining
solenoid outputs still require sheets 1–4 or an equivalent independent trace.

## Annotation policy

Ghidra labels and comments use these rules:

- Vector, reset, interrupt, RAM, and PIA names are safe to use now.
- The confirmed lamp and momentary-solenoid nets may use their schematic names
  (`PA00`, `PB10`, `CB02`, and so on) without prematurely deciding whether the
  physical package is U7 or U8.
- Names for a particular switch, lamp, or coil are only final after their
  signal is followed through the schematic and cross-checked against ROM use.

The Ghidra annotations are deliberately kept in this original analysis
project.  Experimental rules changes belong in the separately named variation
directory, not here.
