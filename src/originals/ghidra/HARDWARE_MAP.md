# Eight Ball Champ CPU / Hardware Reference

This note accompanies the canonical analysis project for the original,
read-only ROM. It records the hardware model used when reading the 6803 ROM
and distinguishes confirmed facts from the remaining schematic-tracing work.

## Evidence

- **ROM:** `../roms/u3_cpu.128` (16 KiB, mapped at `C000-FFFF`). Its SHA-1 is `25D310F169B92CE6B348330816DDC3B5710E57DA`.
- **Manual:** `../../../docs/Eight_Ball_Champ_OPS.pdf`, especially section 3: control-board layout/designations and cabinet/playfield schematics.
- **Ghidra program:** `u3_cpu.128`, analyzed as a Motorola 6801/6803-family processor.

## Definitions

- **PIA:** A Peripheral Interface Adapter connects the CPU's data bus to external input and output pins. The CPU reads or writes its registers using ordinary memory-access instructions; the PIA then samples or changes several physical signals in parallel.
- **Working memory map:** The CPU's address book for RAM, ROM, internal hardware registers, and memory-mapped external devices. A RAM write stores a byte, while a write to an I/O address such as `0042` changes a PIA register and can ultimately change physical output signals.
- **Data-direction register (DDR):** One bit per PIA pin that selects whether that pin is an input or an output. A 6821 uses control-register bit 2 to select whether its port address accesses the DDR or the external-data register.

## Working memory map (16-bit address bus)

| Address range | Purpose | Confidence |
| --- | --- | --- |
| `0000-001F` | 6803 internal registers (ports, timers, serial hardware) | Confirmed |
| `0020-0023` | PIA0: multiplexed lamp-address and switch-matrix path | Confirmed by schematic net names and ROM use |
| `0024-003F` | No device identified | Untraced; no direct absolute ROM reference found |
| `0040-0043` | PIA1: momentary-solenoid path plus other I/O | Confirmed by schematic net names and ROM use |
| `0044-007F` | No device identified | Untraced; no direct absolute ROM reference found |
| `0080-00FF` | 6803 on-chip RAM | Processor architecture; verify against the decoder sheet if needed |
| `0100-0FFF` | No device identified | Untraced; no direct absolute ROM reference found |
| `1000-17FF` | 2 KiB working RAM, U4 (6116) | High confidence; the ROM actively uses this area |
| `1800-BFFF` | No device identified; likely unused address space | Untraced; no direct absolute ROM reference found |
| `C000-FFFF` | U3 CPU ROM (where the game code lives) | Confirmed |

Note: `No device identified` does **not** establish an electrically open bus,
a RAM mirror, or an expansion device; those possibilities require the missing
CPU/address-decoder schematic sheets or measurement. The current Ghidra
disassembly has no direct absolute ROM reference into any of those ranges.
That is useful negative evidence, but an address calculated at runtime and
accessed through the X index register might not appear as an absolute
reference.

### PIA address names and mode selection
The two PIAs are the ROM's bridge to the machine: each connects eight input or
output wires at a time, plus a few control wires. Each PIA occupies four CPU
addresses: port A (or its direction settings), control A, port B (or its
direction settings), and control B. **PIA0** and **PIA1** name the two
schematic signal groups, not specific chips: the available manual pages do not
yet prove which group is physical package **U7** or **U8**.

The canonical Ghidra project gives the PIA addresses neutral register names. The port addresses have two mode-selected meanings, so their labels do not embed one particular lamp, switch, or solenoid use:

| Address | Ghidra label | Register selected |
| --- | --- | --- |
| `0020` | `PIA0_PORTA_OR_DDRA` | PIA0 port-A data if `0021` CRA bit 2 is set; DDRA if clear |
| `0021` | `PIA0_CRA` | PIA0 control register A |
| `0022` | `PIA0_PORTB_OR_DDRB` | PIA0 port-B data if `0023` CRB bit 2 is set; DDRB if clear |
| `0023` | `PIA0_CRB` | PIA0 control register B |
| `0040` | `PIA1_PORTA_OR_DDRA` | PIA1 port-A data if `0041` CRA bit 2 is set; DDRA if clear |
| `0041` | `PIA1_CRA` | PIA1 control register A |
| `0042` | `PIA1_PORTB_OR_DDRB` | PIA1 port-B data if `0043` CRB bit 2 is set; DDRB if clear |
| `0043` | `PIA1_CRB` | PIA1 control register B |

For the address labels, only control-register **bit 2** changes what a port
address means:

| Control bit 2 | Access at port A or B address | Plain-language meaning |
| --- | --- | --- |
| `0` | DDRA or DDRB | Configure each of the eight pins: `0` is an input and `1` is an output. |
| `1` | Port-A or port-B data register | Read the input pins or write the output pins. |

Bits 0 and 1 are relevant, but not to this address choice: bit 0 enables or
disables interrupts from the `CA1`/`CB1` control input, and bit 1 selects which
edge triggers that input. Bits 3–5 configure the second control wire
(`CA2`/`CB2`) as an interrupt input or an output control signal; bits 6–7 are
read-only interrupt-status flags. The analysis calls out bit 2 most often
because it alone changes whether an instruction at a port address is a pin
configuration access or a live I/O access.

These are not confirmed address aliases. An address alias would mean that two
different CPU addresses select the same physical register, usually because
some address lines are not decoded. No such duplicate decoding has been
established here. Instead, each port address is an intentionally banked PIA
register selected by control bit 2.

The distinction is visible during initialization. Writes at `E520-E526`
occur after the relevant control bit has been cleared and therefore configure
the four DDRs. Writes at `E537`, `E539`, and `E547` occur after bit 2 has been
set and therefore access peripheral-data registers. The switch scan similarly
selects PIA0 DDRB at `E1E9`, restores port-B data access at `E1ED`, writes a
strobe through port A at `E1F6`, and reads the returns through port B at
`E20B`. Ghidra records these mode-specific meanings on the individual
instructions rather than overloading the address labels.

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

### Page 1-18 switch assembly identification

The following table accounts for every switch listed in the **Switch Assembly
Identification Table** on manual page 1-18 and places it in the ROM's 5-by-8
matrix. The switch identities are corrected to match the wiring/ROM evidence
and the actual-machine switch test.

| Switch self-test # | Established switch identity | Strobe | Return |
| ---: | --- | ---: | ---: |
| 01 | Right Thumper Bumper | 0 | 0 |
| 02 | Left Thumper Bumper | 0 | 1 |
| 03 | Right Slingshot | 0 | 2 |
| 04 | Left Slingshot | 0 | 3 |
| 05 | Saucer | 0 | 4 |
| 06 | Credit | 0 | 5 |
| 07 | Rebound | 0 | 6 |
| 08 | Outhole | 0 | 7 |
| 09 | Coin III (Right) | 1 | 0 |
| 10 | Coin I (Left) | 1 | 1 |
| 11 | Coin II (Middle) | 1 | 2 |
| 12 | Left Rollover Button | 1 | 3 |
| 13 | Right Rollover Button | 1 | 4 |
| 14 | Not Used | 1 | 5 |
| 15 | Tilt | 1 | 6 |
| 16 | Slam | 1 | 7 |
| 17 | "C" Return Lane | 2 | 0 |
| 18 | "H" Top Lane | 2 | 1 |
| 19 | "A" Top Lane | 2 | 2 |
| 20 | "M" Top Lane | 2 | 3 |
| 21 | "P" Return Lane | 2 | 4 |
| 22 | Not Used | 2 | 5 |
| 23 | Left Outlane | 2 | 6 |
| 24 | Right Outlane | 2 | 7 |
| 25 | Drop Target 1,2,9,10 | 3 | 0 |
| 26 | Lane Change (Cabinet) | 3 | 1 |
| 27 | Drop Target 3,11 | 3 | 2 |
| 28 | Drop Target 4,5,12,13 | 3 | 3 |
| 29 | Center Rollover Button | 3 | 4 |
| 30 | Drop Target 6,14 | 3 | 5 |
| 31 | Drop Target 7,15 | 3 | 6 |
| 32 | Spinner | 3 | 7 |
| 33 | Drop Target "E" | 4 | 0 |
| 34 | Drop Target "I" | 4 | 1 |
| 35 | Drop Target "G" | 4 | 2 |
| 36 | Drop Target "H" | 4 | 3 |
| 37 | Drop Target "T" | 4 | 4 |

Note: Manual page 1-18 prints the names for switches 26 and 32 in the opposite positions. The table above uses the corrected machine mapping: **26 = Lane Change (Cabinet)** and **32 = Spinner**. This was determined on an actual machine switch test.

Note: Page 1-18 lists switch self-test positions 01 through 37. Electrical matrix
positions 38 through 40 (strobe 4, returns 5 through 7) are not named on that
page, so they are intentionally not assigned a feature here.


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

### U14 decoder outputs and page 1-18 solenoid identification

The binary value on `PB10-PB13` selects U14 output `M0` through `M15`. These
physical outputs are cross-checked by connector/pin in the schematic and the
manual's *Solenoid Driver Locations* table:

| U14 output | Connector / pin | Physical coil | Page 1-18 solenoid self-test # | Description on page 1-18 |
| --- | --- | --- | ---: | --- |
| `M0` | J6-1 | Drop targets 1/2 | 04 | Drop Target 1,2,9,10 |
| `M1` | J6-2 | Drop target 3 | 05 | Drop Target 3,11 |
| `M2` | J6-3 | Drop targets 4/5 | 06 | Drop Target 4,5,12,13 |
| `M3` | J6-4 | Drop target 6 | 07 | Drop Target 6,14 |
| `M4` | J8-7 | Drop target 7 | 08 | Drop Target 7,15 |
| `M7` | J9-1 | Saucer | 01 | Saucer |
| `M8` | J9-2 | Right thumper bumper | 03 | Right Thumper Bumper |
| `M9` | J9-3 | Left thumper bumper | 02 | Left Thumper Bumper |
| `M10` | J9-4 | Right slingshot | 09 | Right Slingshot |
| `M11` | J9-6 | Left slingshot | 10 | Left Slingshot |
| `M13` | J9-8 | Outhole | 11 | Outhole |
| `M14` | J7-2 | Knocker | 12 | Knocker |
| Not yet traced | -- | K1 Relay (Flipper Enable) | 13 | K1 Relay (Flipper Enable) |

The schematic also shows `M5`, `M6`, and `M12`, but the Eight Ball Champ
driver-location table does not give each one a physical-coil name. They remain
unnamed here rather than guessed. The flipper-enable relay K1 is listed as
solenoid self-test 13 on page 1-18, but its U14 output still needs a complete
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
