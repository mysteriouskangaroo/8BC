# Eight Ball Champ Deluxe Hardware and Memory Reference

This is the authoritative hardware and working-memory reference for the Eight
Ball Champ Deluxe variation. It carries forward the verified physical map of
the original ROM and adds the Deluxe RAM allocation. Original behavior remains
traceable to `../../originals/ghidra/HARDWARE_MAP.md`; variation-only state is
identified explicitly below.

## Evidence

- **Original reference ROM:** `../roms/u3_cpu.128` (16 KiB, mapped at `C000-FFFF`). Its SHA-1 is `25D310F169B92CE6B348330816DDC3B5710E57DA`.
- **Deluxe build:** `../build/u3_cpu.rebuilt.128`; the current hash and structural checks are recorded by `../asm/build.ps1` in `../build/verification.txt`.
- **Manual:** `../../../docs/Eight_Ball_Champ_OPS.pdf`, especially section 3: control-board layout/designations and cabinet/playfield schematics.
- **Ghidra program:** `u3_cpu.128`, analyzed as a Motorola 6801/6803-family processor.
- **Squawk & Talk command responses:** [PinWiki's Eight Ball Champ speech-command table](https://www.pinwiki.com/wiki/index.php/Eight_Ball_Champ), credited there to PinSider "Quench". The ROM confirms the command-byte transport described below; the audible response names remain community-sourced pending independent sound-ROM or hardware verification.

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

### U4 RAM: dedicated player-score display buffers

Each player has a dedicated seven-byte score buffer. Digits are stored
ones-first, with the displayed digit in the high nibble. These ranges are
separate from the saved rule-state slots described below.

| Player | Score-display buffer |
| ---: | --- |
| 1 | `1046-104C` |
| 2 | `104D-1053` |
| 3 | `1054-105A` |
| 4 | `105B-1061` |

### U4 RAM: canonical per-player record slots

The canonical record selector at `C5C3` assigns each player a **complete
13-byte slot**. For every player after Player 1, it calls the entry at `F821`
(seven consecutive `INX` instructions) and then the entry at `F822` (six
`INX` instructions), advancing X by 13 bytes. Within each slot, the first nine
bytes hold saved state and the final four bytes are reserved stride space.

| Player | Complete 13-byte slot | Nine stored bytes | Reserved stride bytes |
| ---: | --- | --- | --- |
| 1 | `10C7-10D3` | `10C7-10CF` | `10D0-10D3` |
| 2 | `10D4-10E0` | `10D4-10DC` | `10DD-10E0` |
| 3 | `10E1-10ED` | `10E1-10E9` | `10EA-10ED` |
| 4 | `10EE-10FA` | `10EE-10F6` | `10F7-10FA` |

The save routine at `C58C-C5BD` defines exactly what each stored byte contains.
An unresolved source byte is kept explicitly unnamed rather than assigned a
speculative game-rule meaning.

| Slot offset | Player 1 | Player 2 | Player 3 | Player 4 | Stored content |
| ---: | --- | --- | --- | --- | --- |
| `+0` | `10C7` | `10D4` | `10E1` | `10EE` | Copy of live byte `10A0`; exact feature meaning remains untraced |
| `+1` | `10C8` | `10D5` | `10E2` | `10EF` | Sunk pool balls 1-7 from `10C3` |
| `+2` | `10C9` | `10D6` | `10E3` | `10F0` | Copy of live byte `10BE`; exact feature meaning remains untraced |
| `+3` | `10CA` | `10D7` | `10E4` | `10F1` | Saucer/bonus progression from `10C1` |
| `+4` | `10CB` | `10D8` | `10E5` | `10F2` | Orbit-special state from `10C2` |
| `+5` | `10CC` | `10D9` | `10E6` | `10F3` | C-H-A-M-P state from `1040`; upper spinner-lamp bits are forced inactive when saved |
| `+6` | `10CD` | `10DA` | `10E7` | `10F4` | B-A-L-L state from `1041`; upper multiplier/special output bits are forced inactive when saved |
| `+7` | `10CE` | `10DB` | `10E8` | `10F5` | Shared orbit/rack-value state from `1044` |
| `+8` | `10CF` | `10DC` | `10E9` | `10F6` | E-I-G-H-T target state from `1045` |
| `+9` | `10D0` | `10DD` | `10EA` | `10F7` | Reserved; canonical record save/restore stores no field here |
| `+10` | `10D1` | `10DE` | `10EB` | `10F8` | Reserved; canonical record save/restore stores no field here |
| `+11` | `10D2` | `10DF` | `10EC` | `10F9` | Reserved; canonical record save/restore stores no field here |
| `+12` | `10D3` | `10E0` | `10ED` | `10FA` | Reserved; canonical record save/restore stores no field here |

### U4 RAM: Deluxe allocation

Deluxe begins at `10FB`, the first byte after all four canonical slots. Its
currently reserved envelope ends at `1148`. Persistent per-player values use
parallel arrays; active-player mirrors and temporary work remain shared.

| Address | Storage role | Meaning |
| --- | --- | --- |
| `10FB` | Live rule state | Collect location in bits 0-1; active flag in bit 2; post-5x waiting flag in bit 6; collect-deactivation authorization in bit 7 |
| `10FC` | Timer | Spinner inactivity countdown |
| `10FD` | Current ball | C-H-A-M-P completion count for the current ball |
| `10FE` | Live rule state | Spinner weighted binary value mask (`$20/$40/$80`) |
| `10FF` | Live rule state | Retained orbit-value low nibble while inactive orbit lamps are hidden |
| `1100` | Active-player mirror | Selected player's completed 8-ball racks; saturates at 255 |
| `1101` | Bonus working state | Completed-rack countdown, reloaded for each bonus-multiplier pass |
| `1102-1103` | Display backup | Saved credit-display ones and tens during end-of-ball bonus |
| `1104` | Active-player mirror | Selected player's completed B-A-L-L letters; saturates at 255 |
| `1105` | Bonus working state | B-A-L-L countdown, reloaded for each bonus-multiplier pass |
| `1106-1109` | Persistent per-player array | Completed-rack counters for Players 1-4 |
| `110A-110D` | Persistent per-player array | Completed B-A-L-L-letter counters for Players 1-4 |
| `110E` | Active-player mirror | Selected player's Called ball score in displayed 1,000-point units |
| `110F-1112` | Persistent per-player array | Called ball scores for Players 1-4 |
| `1113` | Lamp-overlay state | Called-ball lamp ID whose reversible flash overlay is applied |
| `1114` | Timer | Temporary spinner-value preview countdown |
| `1115` | Timer | Temporary orbit-value preview countdown after a right-orbit collect |
| `1116-1118` | Unassigned | No Deluxe symbol; do not claim without a fresh original-ROM trace |
| `1119-111E` | Lamp-output scratch | Six-byte Phase-B copy for player-specific rack/B-A-L-L "more" blinks |
| `111F-1125` | Display-overlay scratch | Seven-digit sunk-ball award in canonical ones-first display format |
| `1126` | Timer | Sunk-ball award display countdown |
| `1127` | Display-overlay state | Player number whose live score display is excluded from the overlay |
| `1128` | Display-overlay state | Active marker for the reversible score-display overlay |
| `1129-112A` | Formatting scratch | Binary work value for multiplied Called ball awards |
| `112B-1146` | Display backup | Backup of all four seven-digit player score buffers |
| `1147` | Lamp-output state | Blink phase for rack and B-A-L-L "more" indications |
| `1148` | Current ball | C/P anti-shatz rearm latch |

The active-player mirrors at `1100`, `1104`, and `110E` are loaded from the
selected player's array entries when the canonical restore path finishes and
are written back when their values advance. They are working copies, not a
second independent set of player progress.

#### Logical combined player state

The state is physically split to preserve the original 13-byte addressing
contract, but it can be read as one logical record per player. This table
combines every currently identified persistent player-owned field. Shared
timers, current-ball latches, lamp overlays, and display scratch are excluded
because they are not four independent player values.

| Logical field | Player 1 | Player 2 | Player 3 | Player 4 | Physical organization |
| --- | --- | --- | --- | --- | --- |
| Score-display digits | `1046-104C` | `104D-1053` | `1054-105A` | `105B-1061` | Four dedicated seven-byte buffers |
| Canonical `10A0` copy | `10C7` | `10D4` | `10E1` | `10EE` | Slot `+0` |
| Sunk pool balls 1-7 | `10C8` | `10D5` | `10E2` | `10EF` | Slot `+1` |
| Canonical `10BE` copy | `10C9` | `10D6` | `10E3` | `10F0` | Slot `+2` |
| Saucer/bonus progression | `10CA` | `10D7` | `10E4` | `10F1` | Slot `+3` |
| Orbit-special state | `10CB` | `10D8` | `10E5` | `10F2` | Slot `+4` |
| C-H-A-M-P state | `10CC` | `10D9` | `10E6` | `10F3` | Slot `+5` |
| B-A-L-L state | `10CD` | `10DA` | `10E7` | `10F4` | Slot `+6` |
| Orbit/rack-value state | `10CE` | `10DB` | `10E8` | `10F5` | Slot `+7` |
| E-I-G-H-T state | `10CF` | `10DC` | `10E9` | `10F6` | Slot `+8` |
| Deluxe completed racks | `1106` | `1107` | `1108` | `1109` | Four-byte parallel array |
| Deluxe completed B-A-L-L letters | `110A` | `110B` | `110C` | `110D` | Four-byte parallel array |
| Deluxe Called ball value | `110F` | `1110` | `1111` | `1112` | Four-byte parallel array |

The four reserved bytes in each canonical slot remain reserved. New
persistent Deluxe fields should use another four-byte parallel array rather
than changing the 13-byte stride or moving original state. This keeps the
original selector and save/restore routines stable while giving the source
and documentation a single logical player model.

`build.ps1` resolves the boundary symbols after assembly and fails unless
Deluxe begins at `10FB`, ends inside U4 RAM, and does not overlap the canonical
player slots. These tables describe verified allocations only; they do not
declare every other byte of `1000-17FF` unused.

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

### Numbered pool-ball drop-target lamps

The manual lamp chart, cross-checked against the
[PinWiki Eight Ball Champ lamp chart](https://www.pinwiki.com/wiki/index.php/Eight_Ball_Champ),
identifies the fourteen individually numbered Phase-A drop-target lamps below.
[PinMAME's Bally 6803 connector table](https://github.com/vpinball/pinmame/blob/master/src/wpc/by6803.c)
converts each connector pin to its controller lamp number. The ROM serializer
at `E107-E1EF` consumes the
six-byte Phase-A shadow at `103A-103F` as interleaved U15/U16/U17 triples;
following that order gives the exact shadow byte and bit in the last column.

| Driver | Connector | Lamp description | Wire code/color | PinMAME lamp | ROM shadow |
| --- | --- | --- | --- | ---: | --- |
| Q57 | J10-18 | Drop Target 1 | 58 Wht-Blk | 35 | `103B` bit 0 |
| Q26 | J10-4 | Drop Target 2 | 41 Grn-Red | 4 | `103B` bit 1 |
| Q43 | J10-11 | Drop Target 3 | 43 Grn-Yel | 20 | `103B` bit 2 |
| Q58 | J10-19 | Drop Target 4 | 10 Red | 36 | `103B` bit 3 |
| Q27 | J10-5 | Drop Target 5 | 60 Brn | 5 | `103B` bit 4 |
| Q44 | J10-12 | Drop Target 6 | 34 Yel-Grn | 21 | `103B` bit 5 |
| Q59 | J10-14 | Drop Target 7 | 36 Yel-Brn | 37 | `103B` bit 6 |
| Q45 | J10-10 | Drop Target 9 | 57 Wht-Orn | 22 | `103C` bit 0 |
| Q60 | J10-13 | Drop Target 10 | 51 Wht-Red | 38 | `103C` bit 1 |
| Q29 | J11-8 | Drop Target 11 | 67 Brn-Orn | 7 | `103C` bit 2 |
| Q46 | J11-16 | Drop Target 12 | 53 Wht-Yel | 23 | `103C` bit 3 |
| Q61 | J11-6/J12-10 | Drop Target 13 | 12 Red-Blu | 39 | `103C` bit 4 |
| Q30 | J11-12/J12-14 | Drop Target 14 | 45 Grn-Wht | 8 | `103C` bit 5 |
| Q47 | J11-11/J12-6 | Drop Target 15 | 13 Red-Yel | 24 | `103C` bit 6 |

These are distinct from the five shared **5,000 Drop Target** lamps on J13.
Those shared lamps occupy `103F` bits 0-4 and correspond to target groups 1/2,
3, 4/5, 6, and 7. Keeping the two sets separate is essential when implementing
an indication for one specifically called pool ball.

### B-A-L-L inserts and the paired AC lamp phases

The manual lamp chart and the actual-machine lamp behavior establish that the
four B-A-L-L inserts share drivers with drop targets 1-4 on the opposite AC
phase. The Phase-A serializer uses `103B` bits 0-3 for the four target lamps;
the corresponding Phase-B serializer byte is six bytes later at `1041`, so the
B-A-L-L inserts are `1041` bits 0-3. The upper nibble is not part of B-A-L-L.

| Driver | Connector | Phase-A lamp | Phase-B lamp | ROM Phase-B shadow |
| --- | --- | --- | --- | --- |
| Q57 | J10-18 | Drop Target 1 | B-A-L-L `B` | `1041` bit 0 |
| Q26 | J10-4 | Drop Target 2 | B-A-L-L `A` | `1041` bit 1 |
| Q43 | J10-11 | Drop Target 3 | B-A-L-L first `L` | `1041` bit 2 |
| Q58 | J10-19 | Drop Target 4 | B-A-L-L second `L` | `1041` bit 3 |

Consequently, an all-B-A-L-L output mask is `0F`. Mask `F0` instead reaches
unrelated Phase-B outputs, including playfield-multiplier/special indications,
and must not be used for a B-A-L-L animation.

### C-H-A-M-P lamp shadows

The stock orbit-value and Special inserts on the left and right sides are
parallel physical lamps on one driver per printed value; the ROM cannot select
one orbit bank independently. The C-H-A-M-P rows below are cross-checked
against the same manual/PinWiki chart and against the Phase-A partners already
located in the ROM serializer.

| Driver | Connector | Lamp description | Wire code/color | ROM shadow |
| --- | --- | --- | --- | --- |
| Q23 | J10-1 | C Return Lane | 91 Gry-Red | `1040` bit 0 |
| Q70 | J10-7 | H Top Lane | 56 Wht-Brn | `1040` bit 1 |
| Q55 | J10-16 | A Top Lane | 71 Orn-Red | `1040` bit 2 |
| Q24 | J10-2 | M Top Lane | 45 Grn-Wht | `1040` bit 3 |
| Q41 | J10-8 | P Return Lane | 62 Brn-Blu | `1040` bit 4 |

All five bits in `1040` are authoritative C-H-A-M-P progress as well as live
lamp shadows. The former directional H/A/M orbit animation has been removed;
current Deluxe code does not substitute an orbit-direction pattern over these
lamps. C/P anti-shatz logic changes only whether a new C or P is awarded and
does not change this physical lamp mapping.

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

The switch-to-rule execution traces, beginning with switch 07 Rebound and the
CHAMP playfield multiplier, are kept in [GAME_RULE_TRACES.md](GAME_RULE_TRACES.md).
This file stops at the verified electrical mapping; the trace document follows
those inputs through scoring, lamps, sounds, and game state.


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

### Solenoid self-test outputs and page 1-18 identification

The binary value on `PB10-PB13` selects U14 output `M0` through `M15`. These physical outputs are cross-checked by connector/pin in the schematic and the manual's *Solenoid Driver Locations* table:

| Driver output | Connector / pin | Physical coil | Page 1-18 solenoid self-test # | Description on page 1-18 |
| --- | --- | --- | ---: | --- |
| `M0` | J6-1 | Drop targets 1/2 | 01 | Drop Target 1,2,9,10 |
| `M1` | J6-2 | Drop target 3 | 02 | Drop Target 3,11 |
| `M2` | J6-3 | Drop targets 4/5 | 03 | Drop Target 4,5,12,13 |
| `M3` | J6-4 | Drop target 6 | 04 | Drop Target 6,14 |
| `M4` | J8-7 | Drop target 7 | 05 | Drop Target 7,15 |
| `M7` | J9-1 | Saucer | 06 | Saucer |
| `M8` | J9-2 | Right thumper bumper | 07 | Right Thumper Bumper |
| `M9` | J9-3 | Left thumper bumper | 08 | Left Thumper Bumper |
| `M10` | J9-4 | Right slingshot | 09 | Right Slingshot |
| `M11` | J9-6 | Left slingshot | 10 | Left Slingshot |
| `M13` | J9-8 | Outhole | 11 | Outhole |
| `M14` | J7-2 | Knocker | 12 | Knocker |
| Continuous output (`BF` in ROM test table) | On control board | K1 Relay (Flipper Enable) | 13 | K1 Relay (Flipper Enable) |

Note: Page 1-18's solenoid-test numbering conflicts with the numbered locator drawing on page 1-19 and with some replacement manual scans. Analysis of the ROM's automatic solenoid test confirms page 1-18, so its numbering is used in the table above. The instruction-level evidence is recorded in the canonical Ghidra comments.

Note: The schematic also shows `M5`, `M6`, and `M12`, but the Eight Ball Champ driver-location table does not give each one a physical-coil name. They remain unnamed here rather than guessed. They are also absent from the ROM's automatic-test selector sequence.

## Squawk & Talk command transport and response map

The CPU queues an eight-bit sound command at `1024`. The output routine at
`C26D` writes the command's low nibble to 6803 port 2 (`0002`), pulses bit 4
of port 3 (`0003`), then shifts the saved command right four places and
writes the high nibble to port 2. Thus the wire-level order is **low nibble
first, then high nibble**. The physical connector pins and sound-board net
names for these port signals remain untraced in the supplied schematic scan.

The response names below are the reported Squawk & Talk results from PinWiki.
Ranges compress commands whose response follows the command's low nibble;
for example, `41-4F` selects ball 1 through ball 15 respectively.

| Command | Reported Squawk & Talk response |
| --- | --- |
| `1D` | Sound effect used during register 93 sound-test mode |
| `41-4F` | One of four get/make/sink/shoot prompts for ball 1-15 |
| `50` | Pool-chalking quip telling the player to stop talking |
| `51-5F` | Announces ball 1 through ball 15 |
| `60` | Prompt to rack the balls |
| `61` | Assigns or announces solids |
| `62` | Assigns or announces stripes |
| `63` | Joke about applying too much English |
| `64` | Chalking prompt |
| `65` | Scratch callout |
| `66` | Shot compliment |
| `67-6B` | Announces the 8 ball followed by ball 1 through ball 5 |
| `6C` | One of four get/make/sink/shoot prompts for the 8 ball |
| `6D` + `6E` | Success callout; PinWiki presents the two bytes as one paired entry, but the exact invocation semantics are not independently verified |
| `6F` | Enthusiastic praise |
| `70-78` | Chalking prompt |
| `79` | Invitation to play another game |
| `7A` | Slow-play warning |
| `7B` | 2X multiplier announcement |
| `7C` | 3X multiplier announcement |
| `7D` | 5X multiplier announcement |
| `7E-80` | Chalking prompt |

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

Startup also verifies the CPU ROM at `E3DB-E40D`: it sums all `0x40` pages
from `C000-FFFF` and requires the eight-bit result to be `FF`. On failure it
spins at `E3E0` before normal initialization. Byte `C000` is a checksum
compensation byte; every build must generate it and verify the final sum.

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

The physical names and original-ROM evidence originate in the canonical
analysis under `../../originals/ghidra/`. Deluxe-specific RAM and rule behavior
must remain identified as variation work and agree with `../asm/`,
`GAME_RULE_TRACES.md`, and `../gamerules.md`.


## More information
https://www.pinwiki.com/wiki/index.php/Eight_Ball_Champ
