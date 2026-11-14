; Reset, initialization, and main control flow
; Address range: $E388-$ED3F
; Reset/SWI entry, PIA setup, main-loop dispatch, and service-mode control leading up to the automatic solenoid test.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

RESET:
RESET_AND_SWI_ENTRY:
; Reset and SWI vector target.  Startup initializes the 6803 and external I/O before normal game operation.
        dc.b $0F                                             ; $E388 unconfirmed: SEI
        dc.b $8E,$00,$FF                                     ; $E389 unconfirmed: LDS #$ff
        dc.b $86,$16                                         ; $E38C unconfirmed: LDAA #$16
        dc.b $97,$01                                         ; $E38E unconfirmed: STAA $0001
        dc.b $86,$10                                         ; $E390 unconfirmed: LDAA #$10
        dc.b $97,$03                                         ; $E392 unconfirmed: STAA $0003
        dc.b $C6,$38                                         ; $E394 unconfirmed: LDAB #$38
        dc.b $D7,$21                                         ; $E396 unconfirmed: STAB PIA0_CRA
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        dc.b $D7,$23                                         ; $E398 unconfirmed: STAB PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $D7,$41                                         ; $E39A unconfirmed: STAB PIA1_CRA
; I/O: PIA1 control register A. Bit 2 selects port-data versus data-direction access at 0040.
        dc.b $D7,$43                                         ; $E39C unconfirmed: STAB PIA1_CRB
; I/O: PIA1 control register B. Its CB2 output is CB12, the momentary-solenoid bank select.
        dc.b $86,$FF                                         ; $E39E unconfirmed: LDAA #$ff
        dc.b $97,$00                                         ; $E3A0 unconfirmed: STAA $0000
        dc.b $97,$20                                         ; $E3A2 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$22                                         ; $E3A4 unconfirmed: STAA PIA0_PORTB_OR_DDRB
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        dc.b $97,$40                                         ; $E3A6 unconfirmed: STAA PIA1_PORTA_OR_DDRA
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
        dc.b $97,$42                                         ; $E3A8 unconfirmed: STAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $C6,$34                                         ; $E3AA unconfirmed: LDAB #$34
        dc.b $D7,$23                                         ; $E3AC unconfirmed: STAB PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $D7,$41                                         ; $E3AE unconfirmed: STAB PIA1_CRA
; I/O: PIA1 control register A. Bit 2 selects port-data versus data-direction access at 0040.
        dc.b $C6,$3C                                         ; $E3B0 unconfirmed: LDAB #$3c
        dc.b $D7,$43                                         ; $E3B2 unconfirmed: STAB PIA1_CRB
; I/O: PIA1 control register B. Its CB2 output is CB12, the momentary-solenoid bank select.
        dc.b $D7,$21                                         ; $E3B4 unconfirmed: STAB PIA0_CRA
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        dc.b $4F                                             ; $E3B6 unconfirmed: CLRA
        dc.b $97,$20                                         ; $E3B7 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$22                                         ; $E3B9 unconfirmed: STAA PIA0_PORTB_OR_DDRB
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        dc.b $97,$40                                         ; $E3BB unconfirmed: STAA PIA1_PORTA_OR_DDRA
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
        dc.b $97,$02                                         ; $E3BD unconfirmed: STAA $0002
        dc.b $43                                             ; $E3BF unconfirmed: COMA
        dc.b $97,$42                                         ; $E3C0 unconfirmed: STAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $CE,$00,$81                                     ; $E3C2 unconfirmed: LDX #$81
        dc.b $86,$00                                         ; $E3C5 unconfirmed: LDAA #$0
        dc.b $A7,$00                                         ; $E3C7 unconfirmed: STAA $0,X
        dc.b $A1,$00                                         ; $E3C9 unconfirmed: CMPA $0,X
        dc.b $26,$FE                                         ; $E3CB unconfirmed: BNE $e3cb
        dc.b $4C                                             ; $E3CD unconfirmed: INCA
        dc.b $26,$F7                                         ; $E3CE unconfirmed: BNE $e3c7
        dc.b $A7,$00                                         ; $E3D0 unconfirmed: STAA $0,X
        dc.b $08                                             ; $E3D2 unconfirmed: INX
        dc.b $8C,$01,$00                                     ; $E3D3 unconfirmed: CPX #$100
        dc.b $26,$ED                                         ; $E3D6 unconfirmed: BNE $e3c5
        dc.b $BD,$E4,$9D                                     ; $E3D8 unconfirmed: JSR $e49d
VERIFY_ROM_ADDITIVE_CHECKSUM:
; Sum the 0x40 256-byte pages from C000-FFFF. The final 8-bit sum must be FF;
; otherwise carry returns set and reset enters the failure loop at E3E0.
        dc.b $CE,$C0,$00                                     ; $E3DB unconfirmed: LDX #$c000
        dc.b $8D,$0D                                         ; $E3DE unconfirmed: BSR $e3ed
ROM_CHECKSUM_FAILURE_LOOP:
        dc.b $25,$FE                                         ; $E3E0 unconfirmed: BCS $e3e0
        dc.b $3C                                             ; $E3E2 unconfirmed: PSHX
        dc.b $BD,$E4,$9D                                     ; $E3E3 unconfirmed: JSR $e49d
        dc.b $38                                             ; $E3E6 unconfirmed: PULX
        dc.b $EE,$0F                                         ; $E3E7 unconfirmed: LDX $f,X
        dc.b $26,$F3                                         ; $E3E9 unconfirmed: BNE $e3de
        dc.b $20,$21                                         ; $E3EB unconfirmed: BRA $e40e
        dc.b $3C                                             ; $E3ED unconfirmed: PSHX
        dc.b $E6,$0E                                         ; $E3EE unconfirmed: LDAB $e,X
        dc.b $27,$16                                         ; $E3F0 unconfirmed: BEQ $e408
        dc.b $C1,$FF                                         ; $E3F2 unconfirmed: CMPB #$ff
        dc.b $27,$15                                         ; $E3F4 unconfirmed: BEQ $e40b
        dc.b $4F                                             ; $E3F6 unconfirmed: CLRA
        dc.b $AB,$00                                         ; $E3F7 unconfirmed: ADDA $0,X
        dc.b $08                                             ; $E3F9 unconfirmed: INX
        dc.b $3C                                             ; $E3FA unconfirmed: PSHX
        dc.b $30                                             ; $E3FB unconfirmed: TSX
        dc.b $6D,$01                                         ; $E3FC unconfirmed: TST $1,X
        dc.b $38                                             ; $E3FE unconfirmed: PULX
        dc.b $26,$F6                                         ; $E3FF unconfirmed: BNE $e3f7
        dc.b $5A                                             ; $E401 unconfirmed: DECB
        dc.b $26,$F3                                         ; $E402 unconfirmed: BNE $e3f7
        dc.b $81,$FF                                         ; $E404 unconfirmed: CMPA #$ff
        dc.b $26,$03                                         ; $E406 unconfirmed: BNE $e40b
        dc.b $38                                             ; $E408 unconfirmed: PULX
        dc.b $0C                                             ; $E409 unconfirmed: CLC
        dc.b $39                                             ; $E40A unconfirmed: RTS
        dc.b $38                                             ; $E40B unconfirmed: PULX
        dc.b $0D                                             ; $E40C unconfirmed: SEC
        dc.b $39                                             ; $E40D unconfirmed: RTS
        dc.b $B6,$16,$00                                     ; $E40E unconfirmed: LDAA $1600
        dc.b $B4,$16,$01                                     ; $E411 unconfirmed: ANDA $1601
        dc.b $81,$FF                                         ; $E414 unconfirmed: CMPA #$ff
        dc.b $26,$02                                         ; $E416 unconfirmed: BNE $e41a
        dc.b $8D,$4F                                         ; $E418 unconfirmed: BSR $e469
        dc.b $8D,$69                                         ; $E41A unconfirmed: BSR $e485
        dc.b $CE,$10,$00                                     ; $E41C unconfirmed: LDX #$1000
        dc.b $8D,$39                                         ; $E41F unconfirmed: BSR $e45a
        dc.b $8C,$16,$00                                     ; $E421 unconfirmed: CPX #$1600
        dc.b $26,$F9                                         ; $E424 unconfirmed: BNE $e41f
        dc.b $CE,$14,$00                                     ; $E426 unconfirmed: LDX #$1400
        dc.b $FF,$00,$8B                                     ; $E429 unconfirmed: STX.w $008b
        dc.b $CE,$16,$00                                     ; $E42C unconfirmed: LDX #$1600
        dc.b $A6,$00                                         ; $E42F unconfirmed: LDAA $0,X
        dc.b $3C                                             ; $E431 unconfirmed: PSHX
        dc.b $FE,$00,$8B                                     ; $E432 unconfirmed: LDX.w $008b
        dc.b $A7,$00                                         ; $E435 unconfirmed: STAA $0,X
        dc.b $08                                             ; $E437 unconfirmed: INX
        dc.b $FF,$00,$8B                                     ; $E438 unconfirmed: STX.w $008b
        dc.b $38                                             ; $E43B unconfirmed: PULX
        dc.b $08                                             ; $E43C unconfirmed: INX
        dc.b $8C,$18,$00                                     ; $E43D unconfirmed: CPX #$1800
        dc.b $26,$ED                                         ; $E440 unconfirmed: BNE $e42f
        dc.b $86,$FF                                         ; $E442 unconfirmed: LDAA #$ff
        dc.b $B7,$16,$00                                     ; $E444 unconfirmed: STAA $1600
        dc.b $B7,$16,$01                                     ; $E447 unconfirmed: STAA $1601
        dc.b $CE,$16,$03                                     ; $E44A unconfirmed: LDX #$1603
        dc.b $8D,$0B                                         ; $E44D unconfirmed: BSR $e45a
        dc.b $8C,$18,$00                                     ; $E44F unconfirmed: CPX #$1800
        dc.b $26,$F9                                         ; $E452 unconfirmed: BNE $e44d
        dc.b $8D,$13                                         ; $E454 unconfirmed: BSR $e469
        dc.b $8D,$45                                         ; $E456 unconfirmed: BSR $e49d
        dc.b $20,$32                                         ; $E458 unconfirmed: BRA $e48c
        dc.b $86,$01                                         ; $E45A unconfirmed: LDAA #$1
        dc.b $A7,$00                                         ; $E45C unconfirmed: STAA $0,X
        dc.b $A1,$00                                         ; $E45E unconfirmed: CMPA $0,X
        dc.b $26,$FE                                         ; $E460 unconfirmed: BNE $e460
        dc.b $48                                             ; $E462 unconfirmed: ASLA
        dc.b $26,$F7                                         ; $E463 unconfirmed: BNE $e45c
        dc.b $A7,$00                                         ; $E465 unconfirmed: STAA $0,X
        dc.b $08                                             ; $E467 unconfirmed: INX
        dc.b $39                                             ; $E468 unconfirmed: RTS
        dc.b $CE,$16,$00                                     ; $E469 unconfirmed: LDX #$1600
        dc.b $FF,$00,$8B                                     ; $E46C unconfirmed: STX.w $008b
        dc.b $CE,$14,$00                                     ; $E46F unconfirmed: LDX #$1400
        dc.b $A6,$00                                         ; $E472 unconfirmed: LDAA $0,X
        dc.b $3C                                             ; $E474 unconfirmed: PSHX
        dc.b $FE,$00,$8B                                     ; $E475 unconfirmed: LDX.w $008b
        dc.b $A7,$00                                         ; $E478 unconfirmed: STAA $0,X
        dc.b $08                                             ; $E47A unconfirmed: INX
        dc.b $FF,$00,$8B                                     ; $E47B unconfirmed: STX.w $008b
        dc.b $38                                             ; $E47E unconfirmed: PULX
        dc.b $08                                             ; $E47F unconfirmed: INX
        dc.b $8C,$16,$00                                     ; $E480 unconfirmed: CPX #$1600
        dc.b $26,$ED                                         ; $E483 unconfirmed: BNE $e472
        dc.b $7F,$16,$00                                     ; $E485 unconfirmed: CLR $1600
        dc.b $7F,$16,$01                                     ; $E488 unconfirmed: CLR $1601
        dc.b $39                                             ; $E48B unconfirmed: RTS
        dc.b $CE,$00,$23                                     ; $E48C unconfirmed: LDX #$23
        dc.b $8D,$23                                         ; $E48F unconfirmed: BSR $e4b4
        dc.b $8D,$0A                                         ; $E491 unconfirmed: BSR $e49d
        dc.b $CE,$00,$43                                     ; $E493 unconfirmed: LDX #$43
        dc.b $8D,$1C                                         ; $E496 unconfirmed: BSR $e4b4
        dc.b $8D,$03                                         ; $E498 unconfirmed: BSR $e49d
        dc.b $7E,$E4,$E9                                     ; $E49A unconfirmed: JMP $e4e9
        dc.b $96,$03                                         ; $E49D unconfirmed: LDAA $0003
        dc.b $8A,$04                                         ; $E49F unconfirmed: ORAA #$4
        dc.b $97,$03                                         ; $E4A1 unconfirmed: STAA $0003
        dc.b $CE,$75,$30                                     ; $E4A3 unconfirmed: LDX #$7530
        dc.b $09                                             ; $E4A6 unconfirmed: DEX
        dc.b $26,$FD                                         ; $E4A7 unconfirmed: BNE $e4a6
        dc.b $84,$FB                                         ; $E4A9 unconfirmed: ANDA #$fb
        dc.b $97,$03                                         ; $E4AB unconfirmed: STAA $0003
        dc.b $CE,$9C,$40                                     ; $E4AD unconfirmed: LDX #$9c40
        dc.b $09                                             ; $E4B0 unconfirmed: DEX
        dc.b $26,$FD                                         ; $E4B1 unconfirmed: BNE $e4b0
        dc.b $39                                             ; $E4B3 unconfirmed: RTS
        dc.b $8D,$00                                         ; $E4B4 unconfirmed: BSR $e4b6
        dc.b $86,$31                                         ; $E4B6 unconfirmed: LDAA #$31
        dc.b $8D,$15                                         ; $E4B8 unconfirmed: BSR $e4cf
        dc.b $86,$39                                         ; $E4BA unconfirmed: LDAA #$39
        dc.b $8D,$11                                         ; $E4BC unconfirmed: BSR $e4cf
        dc.b $09                                             ; $E4BE unconfirmed: DEX
        dc.b $8D,$18                                         ; $E4BF unconfirmed: BSR $e4d9
        dc.b $08                                             ; $E4C1 unconfirmed: INX
        dc.b $86,$35                                         ; $E4C2 unconfirmed: LDAA #$35
        dc.b $8D,$09                                         ; $E4C4 unconfirmed: BSR $e4cf
        dc.b $86,$3D                                         ; $E4C6 unconfirmed: LDAA #$3d
        dc.b $8D,$05                                         ; $E4C8 unconfirmed: BSR $e4cf
        dc.b $09                                             ; $E4CA unconfirmed: DEX
        dc.b $8D,$0C                                         ; $E4CB unconfirmed: BSR $e4d9
        dc.b $09                                             ; $E4CD unconfirmed: DEX
        dc.b $39                                             ; $E4CE unconfirmed: RTS
        dc.b $A7,$00                                         ; $E4CF unconfirmed: STAA $0,X
        dc.b $E6,$00                                         ; $E4D1 unconfirmed: LDAB $0,X
        dc.b $C4,$3F                                         ; $E4D3 unconfirmed: ANDB #$3f
        dc.b $11                                             ; $E4D5 unconfirmed: CBA
        dc.b $26,$FE                                         ; $E4D6 unconfirmed: BNE $e4d6
        dc.b $39                                             ; $E4D8 unconfirmed: RTS
        dc.b $4F                                             ; $E4D9 unconfirmed: CLRA
        dc.b $A7,$00                                         ; $E4DA unconfirmed: STAA $0,X
        dc.b $C6,$03                                         ; $E4DC unconfirmed: LDAB #$3
        dc.b $5A                                             ; $E4DE unconfirmed: DECB
        dc.b $26,$FD                                         ; $E4DF unconfirmed: BNE $e4de
        dc.b $A1,$00                                         ; $E4E1 unconfirmed: CMPA $0,X
        dc.b $26,$FE                                         ; $E4E3 unconfirmed: BNE $e4e3
        dc.b $4C                                             ; $E4E5 unconfirmed: INCA
        dc.b $26,$F2                                         ; $E4E6 unconfirmed: BNE $e4da
        dc.b $39                                             ; $E4E8 unconfirmed: RTS
        dc.b $96,$08                                         ; $E4E9 unconfirmed: LDAA $0008
        dc.b $DC,$09                                         ; $E4EB unconfirmed: LDD $0009
        dc.b $C3,$0A,$1E                                     ; $E4ED unconfirmed: ADDD #$a1e
        dc.b $DD,$0B                                         ; $E4F0 unconfirmed: STD $000b
        dc.b $96,$08                                         ; $E4F2 unconfirmed: LDAA $0008
        dc.b $85,$40                                         ; $E4F4 unconfirmed: BITA #$40
        dc.b $27,$FA                                         ; $E4F6 unconfirmed: BEQ $e4f2
        dc.b $BD,$E4,$9D                                     ; $E4F8 unconfirmed: JSR $e49d
        dc.b $96,$22                                         ; $E4FB unconfirmed: LDAA PIA0_PORTB_OR_DDRB
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        dc.b $96,$23                                         ; $E4FD unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $2A,$FA                                         ; $E4FF unconfirmed: BPL $e4fb
        dc.b $BD,$E4,$9D                                     ; $E501 unconfirmed: JSR $e49d
        dc.b $96,$08                                         ; $E504 unconfirmed: LDAA $0008
        dc.b $96,$08                                         ; $E506 unconfirmed: LDAA $0008
        dc.b $2A,$FC                                         ; $E508 unconfirmed: BPL $e506
        dc.b $BD,$E4,$9D                                     ; $E50A unconfirmed: JSR $e49d
        dc.b $C6,$FF                                         ; $E50D unconfirmed: LDAB #$ff
PIA_INITIALIZATION:
; PIA setup sequence.  It configures both external 6821-compatible I/O address blocks.
        STAB $0000                   ; $E50F: $D7,$00
        STAB $1014                   ; $E511: $F7,$10,$14
        LDAA #$38                    ; $E514: $86,$38
        STAA PIA0_CRA                ; $E516: $97,$21
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        STAA PIA1_CRB                ; $E518: $97,$43
; I/O: PIA1 control register B. Its CB2 output is CB12, the momentary-solenoid bank select.
        LDAA #$30                    ; $E51A: $86,$30
        STAA PIA1_CRA                ; $E51C: $97,$41
; I/O: PIA1 control register A. Bit 2 selects port-data versus data-direction access at 0040.
        STAA PIA0_CRB                ; $E51E: $97,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        STAB PIA0_PORTA_OR_DDRA      ; $E520: $D7,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
; PIA mode: PIA0 CRA bit 2 is clear, so 0020 accesses DDRA.
        STAB PIA0_PORTB_OR_DDRB      ; $E522: $D7,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
; PIA mode: PIA0 CRB bit 2 is clear, so 0022 accesses DDRB.
        STAB PIA1_PORTA_OR_DDRA      ; $E524: $D7,$40
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
; PIA mode: PIA1 CRA bit 2 is clear, so 0040 accesses DDRA.
        STAB PIA1_PORTB_OR_DDRB      ; $E526: $D7,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
; PIA mode: PIA1 CRB bit 2 is clear, so 0042 accesses DDRB.
        LDAA #$3c                    ; $E528: $86,$3C
        STAA PIA0_CRB                ; $E52A: $97,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        STAA PIA1_CRB                ; $E52C: $97,$43
; I/O: PIA1 control register B. Its CB2 output is CB12, the momentary-solenoid bank select.
        LDAA #$34                    ; $E52E: $86,$34
        STAA PIA0_CRA                ; $E530: $97,$21
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        STAA PIA1_CRA                ; $E532: $97,$41
; I/O: PIA1 control register A. Bit 2 selects port-data versus data-direction access at 0040.
        CLRA                         ; $E534: $4F
        STAA $0002                   ; $E535: $97,$02
        STAA PIA0_PORTA_OR_DDRA      ; $E537: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
; PIA mode: PIA0 CRA bit 2 is set, so 0020 accesses port-A peripheral data.
        STAA PIA1_PORTA_OR_DDRA      ; $E539: $97,$40
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
; PIA mode: PIA1 CRA bit 2 is set, so 0040 accesses port-A peripheral data.
        STAA $1002                   ; $E53B: $B7,$10,$02
        STAA $1005                   ; $E53E: $B7,$10,$05
        LDAA #$10                    ; $E541: $86,$10
        STAA $0003                   ; $E543: $97,$03
        LDAA #$ff                    ; $E545: $86,$FF
        STAA PIA0_PORTB_OR_DDRB      ; $E547: $97,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
; PIA mode: PIA0 CRB bit 2 is set, so 0022 accesses port-B peripheral data.
        dc.b $CE,$00,$00                                     ; $E549 unconfirmed: LDX #$0
        dc.b $FF,$10,$03                                     ; $E54C unconfirmed: STX $1003
        dc.b $FF,$10,$06                                     ; $E54F unconfirmed: STX $1006
        dc.b $B6,$00,$9B                                     ; $E552 unconfirmed: LDAA.w $009b
        dc.b $85,$40                                         ; $E555 unconfirmed: BITA #$40
        dc.b $26,$05                                         ; $E557 unconfirmed: BNE $e55e
        dc.b $C6,$90                                         ; $E559 unconfirmed: LDAB #$90
        dc.b $F7,$10,$00                                     ; $E55B unconfirmed: STAB WORK_RAM_U4_6116_START
        dc.b $84,$BF                                         ; $E55E unconfirmed: ANDA #$bf
        dc.b $B7,$00,$9B                                     ; $E560 unconfirmed: STAA.w $009b
        dc.b $BD,$EE,$F2                                     ; $E563 unconfirmed: JSR $eef2
        dc.b $CE,$10,$4C                                     ; $E566 unconfirmed: LDX #$104c
        dc.b $FF,$00,$81                                     ; $E569 unconfirmed: STX.w $0081
        dc.b $86,$01                                         ; $E56C unconfirmed: LDAA #$1
        dc.b $B7,$00,$80                                     ; $E56E unconfirmed: STAA.w $0080
        dc.b $B6,$C0,$B7                                     ; $E571 unconfirmed: LDAA $c0b7
        dc.b $BB,$C0,$B8                                     ; $E574 unconfirmed: ADDA $c0b8
        dc.b $43                                             ; $E577 unconfirmed: COMA
        dc.b $97,$42                                         ; $E578 unconfirmed: STAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $CE,$FF,$FF                                     ; $E57A unconfirmed: LDX #$ffff
        dc.b $FF,$10,$2C                                     ; $E57D unconfirmed: STX SWITCH_SAMPLE_CURRENT_STROBE0
        dc.b $FF,$10,$2E                                     ; $E580 unconfirmed: STX SWITCH_SAMPLE_CURRENT_STROBE2
        dc.b $FF,$10,$30                                     ; $E583 unconfirmed: STX SWITCH_SAMPLE_CURRENT_STROBE4
        dc.b $FF,$10,$32                                     ; $E586 unconfirmed: STX SWITCH_SAMPLE_PREVIOUS_STROBE0
        dc.b $96,$03                                         ; $E589 unconfirmed: LDAA $0003
        dc.b $85,$08                                         ; $E58B unconfirmed: BITA #$8
        dc.b $27,$08                                         ; $E58D unconfirmed: BEQ $e597
        dc.b $86,$08                                         ; $E58F unconfirmed: LDAA #$8
        dc.b $97,$08                                         ; $E591 unconfirmed: STAA $0008
        dc.b $96,$08                                         ; $E593 unconfirmed: LDAA $0008
        dc.b $DC,$0D                                         ; $E595 unconfirmed: LDD $000d
        dc.b $86,$35                                         ; $E597 unconfirmed: LDAA #$35
        dc.b $D6,$22                                         ; $E599 unconfirmed: LDAB PIA0_PORTB_OR_DDRB
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        dc.b $97,$23                                         ; $E59B unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $D6,$20                                         ; $E59D unconfirmed: LDAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$21                                         ; $E59F unconfirmed: STAA PIA0_CRA
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        dc.b $DC,$09                                         ; $E5A1 unconfirmed: LDD $0009
        dc.b $C3,$0A,$1E                                     ; $E5A3 unconfirmed: ADDD #$a1e
        dc.b $DD,$0B                                         ; $E5A6 unconfirmed: STD $000b
        dc.b $7F,$10,$0A                                     ; $E5A8 unconfirmed: CLR $100a
        dc.b $7F,$10,$09                                     ; $E5AB unconfirmed: CLR $1009
        dc.b $0E                                             ; $E5AE unconfirmed: CLI
        dc.b $BD,$EE,$F2                                     ; $E5AF unconfirmed: JSR $eef2
        dc.b $BD,$EA,$7F                                     ; $E5B2 unconfirmed: JSR $ea7f
        dc.b $BD,$F9,$63                                     ; $E5B5 unconfirmed: JSR $f963
        dc.b $FE,$C0,$7F                                     ; $E5B8 unconfirmed: LDX $c07f
        dc.b $AD,$00                                         ; $E5BB unconfirmed: JSR $0,X
PROCESS_SWITCH_EVENTS:
; Normal-play switch dispatcher. It scans event bytes 1026-102A in strobe order and each byte from bit 7 down to bit 0, clears one event, and calls the corresponding pointer in the table at C011. Switch 07 (strobe 0, return 6) selects the C013 pointer to CA95.
        dc.b $5F                                             ; $E5BD unconfirmed: CLRB
        dc.b $CE,$10,$25                                     ; $E5BE unconfirmed: LDX #$1025
        dc.b $08                                             ; $E5C1 unconfirmed: INX
        dc.b $B6,$00,$9B                                     ; $E5C2 unconfirmed: LDAA.w $009b
        dc.b $85,$40                                         ; $E5C5 unconfirmed: BITA #$40
        dc.b $27,$07                                         ; $E5C7 unconfirmed: BEQ $e5d0
        dc.b $8C,$10,$2A                                     ; $E5C9 unconfirmed: CPX #$102a
        dc.b $27,$EF                                         ; $E5CC unconfirmed: BEQ PROCESS_SWITCH_EVENTS
        dc.b $20,$0A                                         ; $E5CE unconfirmed: BRA $e5da
        dc.b $B6,$C0,$B7                                     ; $E5D0 unconfirmed: LDAA $c0b7
        dc.b $27,$0F                                         ; $E5D3 unconfirmed: BEQ $e5e4
        dc.b $8C,$10,$2C                                     ; $E5D5 unconfirmed: CPX #$102c
        dc.b $27,$6C                                         ; $E5D8 unconfirmed: BEQ $e646
        dc.b $A6,$00                                         ; $E5DA unconfirmed: LDAA $0,X
        dc.b $84,$0F                                         ; $E5DC unconfirmed: ANDA #$f
        dc.b $26,$11                                         ; $E5DE unconfirmed: BNE $e5f1
        dc.b $CB,$08                                         ; $E5E0 unconfirmed: ADDB #$8
        dc.b $20,$DD                                         ; $E5E2 unconfirmed: BRA $e5c1
        dc.b $8C,$10,$2B                                     ; $E5E4 unconfirmed: CPX #$102b
        dc.b $27,$5D                                         ; $E5E7 unconfirmed: BEQ $e646
        dc.b $6D,$00                                         ; $E5E9 unconfirmed: TST $0,X
        dc.b $26,$19                                         ; $E5EB unconfirmed: BNE $e606
        dc.b $CB,$10                                         ; $E5ED unconfirmed: ADDB #$10
        dc.b $20,$D0                                         ; $E5EF unconfirmed: BRA $e5c1
        dc.b $86,$08                                         ; $E5F1 unconfirmed: LDAA #$8
        dc.b $B7,$10,$01                                     ; $E5F3 unconfirmed: STAA $1001
        dc.b $A6,$00                                         ; $E5F6 unconfirmed: LDAA $0,X
        dc.b $B5,$10,$01                                     ; $E5F8 unconfirmed: BITA $1001
        dc.b $26,$1E                                         ; $E5FB unconfirmed: BNE $e61b
        dc.b $5C                                             ; $E5FD unconfirmed: INCB
        dc.b $5C                                             ; $E5FE unconfirmed: INCB
        dc.b $74,$10,$01                                     ; $E5FF unconfirmed: LSR $1001
        dc.b $27,$B9                                         ; $E602 unconfirmed: BEQ PROCESS_SWITCH_EVENTS
        dc.b $20,$F2                                         ; $E604 unconfirmed: BRA $e5f8
        dc.b $86,$80                                         ; $E606 unconfirmed: LDAA #$80
        dc.b $B7,$10,$01                                     ; $E608 unconfirmed: STAA $1001
        dc.b $A6,$00                                         ; $E60B unconfirmed: LDAA $0,X
        dc.b $B5,$10,$01                                     ; $E60D unconfirmed: BITA $1001
        dc.b $26,$1F                                         ; $E610 unconfirmed: BNE $e631
        dc.b $5C                                             ; $E612 unconfirmed: INCB
        dc.b $5C                                             ; $E613 unconfirmed: INCB
        dc.b $74,$10,$01                                     ; $E614 unconfirmed: LSR $1001
        dc.b $27,$2D                                         ; $E617 unconfirmed: BEQ $e646
        dc.b $20,$F2                                         ; $E619 unconfirmed: BRA $e60d
        dc.b $73,$10,$01                                     ; $E61B unconfirmed: COM $1001
        dc.b $B4,$10,$01                                     ; $E61E unconfirmed: ANDA $1001
        dc.b $A7,$00                                         ; $E621 unconfirmed: STAA $0,X
        dc.b $CE,$E0,$02                                     ; $E623 unconfirmed: LDX #$e002
        dc.b $3A                                             ; $E626 unconfirmed: ABX
        dc.b $F6,$00,$9B                                     ; $E627 unconfirmed: LDAB.w $009b
        dc.b $EE,$00                                         ; $E62A unconfirmed: LDX $0,X
        dc.b $AD,$00                                         ; $E62C unconfirmed: JSR $0,X
        dc.b $7E,$E5,$BD                                     ; $E62E unconfirmed: JMP PROCESS_SWITCH_EVENTS
        dc.b $B6,$10,$01                                     ; $E631 unconfirmed: LDAA $1001
        dc.b $36                                             ; $E634 unconfirmed: PSHA
        dc.b $43                                             ; $E635 unconfirmed: COMA
        dc.b $A4,$00                                         ; $E636 unconfirmed: ANDA $0,X
        dc.b $A7,$00                                         ; $E638 unconfirmed: STAA $0,X
        dc.b $CE,$C0,$11                                     ; $E63A unconfirmed: LDX #PLAYFIELD_SWITCH_HANDLER_TABLE
        dc.b $3A                                             ; $E63D unconfirmed: ABX
        dc.b $32                                             ; $E63E unconfirmed: PULA
        dc.b $F6,$00,$9A                                     ; $E63F unconfirmed: LDAB.w $009a
        dc.b $EE,$00                                         ; $E642 unconfirmed: LDX $0,X
        dc.b $AD,$00                                         ; $E644 unconfirmed: JSR $0,X
        dc.b $B6,$10,$02                                     ; $E646 unconfirmed: LDAA $1002
        dc.b $26,$07                                         ; $E649 unconfirmed: BNE $e652
        dc.b $FE,$10,$03                                     ; $E64B unconfirmed: LDX $1003
        dc.b $27,$02                                         ; $E64E unconfirmed: BEQ $e652
        dc.b $AD,$00                                         ; $E650 unconfirmed: JSR $0,X
        dc.b $B6,$10,$05                                     ; $E652 unconfirmed: LDAA $1005
        dc.b $26,$0D                                         ; $E655 unconfirmed: BNE $e664
        dc.b $FE,$10,$06                                     ; $E657 unconfirmed: LDX $1006
        dc.b $27,$08                                         ; $E65A unconfirmed: BEQ $e664
        dc.b $7F,$10,$06                                     ; $E65C unconfirmed: CLR $1006
        dc.b $7F,$10,$07                                     ; $E65F unconfirmed: CLR $1007
        dc.b $AD,$00                                         ; $E662 unconfirmed: JSR $0,X
        dc.b $FE,$C0,$77                                     ; $E664 unconfirmed: LDX $c077
        dc.b $AD,$00                                         ; $E667 unconfirmed: JSR $0,X
        dc.b $BD,$F3,$8C                                     ; $E669 unconfirmed: JSR APPLY_PENDING_SCORE
        dc.b $FE,$C0,$81                                     ; $E66C unconfirmed: LDX $c081
        dc.b $AD,$00                                         ; $E66F unconfirmed: JSR $0,X
        dc.b $D6,$08                                         ; $E671 unconfirmed: LDAB $0008
        dc.b $C5,$08                                         ; $E673 unconfirmed: BITB #$8
        dc.b $26,$13                                         ; $E675 unconfirmed: BNE $e68a
        dc.b $96,$03                                         ; $E677 unconfirmed: LDAA $0003
        dc.b $85,$08                                         ; $E679 unconfirmed: BITA #$8
        dc.b $27,$17                                         ; $E67B unconfirmed: BEQ $e694
        dc.b $CA,$08                                         ; $E67D unconfirmed: ORAB #$8
        dc.b $D7,$08                                         ; $E67F unconfirmed: STAB $0008
        dc.b $DC,$09                                         ; $E681 unconfirmed: LDD $0009
        dc.b $C3,$0A,$1E                                     ; $E683 unconfirmed: ADDD #$a1e
        dc.b $DD,$0B                                         ; $E686 unconfirmed: STD $000b
        dc.b $20,$0A                                         ; $E688 unconfirmed: BRA $e694
        dc.b $96,$03                                         ; $E68A unconfirmed: LDAA $0003
        dc.b $85,$08                                         ; $E68C unconfirmed: BITA #$8
        dc.b $26,$04                                         ; $E68E unconfirmed: BNE $e694
        dc.b $C4,$F7                                         ; $E690 unconfirmed: ANDB #$f7
        dc.b $D7,$08                                         ; $E692 unconfirmed: STAB $0008
        dc.b $F6,$00,$9A                                     ; $E694 unconfirmed: LDAB.w $009a
        dc.b $C5,$04                                         ; $E697 unconfirmed: BITB #$4
        dc.b $26,$03                                         ; $E699 unconfirmed: BNE $e69e
        dc.b $7E,$E5,$BD                                     ; $E69B unconfirmed: JMP PROCESS_SWITCH_EVENTS
        dc.b $F6,$00,$9A                                     ; $E69E unconfirmed: LDAB.w $009a
        dc.b $C4,$7B                                         ; $E6A1 unconfirmed: ANDB #$7b
        dc.b $CA,$20                                         ; $E6A3 unconfirmed: ORAB #$20
        dc.b $F7,$00,$9A                                     ; $E6A5 unconfirmed: STAB.w $009a
        dc.b $4F                                             ; $E6A8 unconfirmed: CLRA
        dc.b $B7,$10,$16                                     ; $E6A9 unconfirmed: STAA $1016
        dc.b $43                                             ; $E6AC unconfirmed: COMA
        dc.b $B7,$10,$11                                     ; $E6AD unconfirmed: STAA $1011
        dc.b $F6,$00,$9B                                     ; $E6B0 unconfirmed: LDAB.w $009b
        dc.b $BD,$E6,$B9                                     ; $E6B3 unconfirmed: JSR $e6b9
        dc.b $7E,$E5,$BD                                     ; $E6B6 unconfirmed: JMP PROCESS_SWITCH_EVENTS
        dc.b $37                                             ; $E6B9 unconfirmed: PSHB
        dc.b $B6,$C0,$AC                                     ; $E6BA unconfirmed: LDAA $c0ac
        dc.b $BD,$C2,$8D                                     ; $E6BD unconfirmed: JSR $c28d
        dc.b $33                                             ; $E6C0 unconfirmed: PULB
        dc.b $C5,$40                                         ; $E6C1 unconfirmed: BITB #$40
        dc.b $26,$1A                                         ; $E6C3 unconfirmed: BNE $e6df
        dc.b $CE,$10,$2C                                     ; $E6C5 unconfirmed: LDX #$102c
        dc.b $A6,$00                                         ; $E6C8 unconfirmed: LDAA $0,X
        dc.b $84,$FB                                         ; $E6CA unconfirmed: ANDA #$fb
        dc.b $AA,$01                                         ; $E6CC unconfirmed: ORAA $1,X
        dc.b $AA,$02                                         ; $E6CE unconfirmed: ORAA $2,X
        dc.b $AA,$03                                         ; $E6D0 unconfirmed: ORAA $3,X
        dc.b $84,$0F                                         ; $E6D2 unconfirmed: ANDA #$f
        dc.b $27,$09                                         ; $E6D4 unconfirmed: BEQ $e6df
        dc.b $38                                             ; $E6D6 unconfirmed: PULX
        dc.b $86,$5E                                         ; $E6D7 unconfirmed: LDAA #$5e
        dc.b $B7,$00,$8D                                     ; $E6D9 unconfirmed: STAA.w $008d
        dc.b $7E,$EE,$A8                                     ; $E6DC unconfirmed: JMP $eea8
        dc.b $4F                                             ; $E6DF unconfirmed: CLRA
        dc.b $B7,$10,$26                                     ; $E6E0 unconfirmed: STAA SWITCH_EVENTS_STROBE0
        dc.b $B7,$10,$27                                     ; $E6E3 unconfirmed: STAA SWITCH_EVENTS_STROBE1
        dc.b $B7,$10,$28                                     ; $E6E6 unconfirmed: STAA SWITCH_EVENTS_STROBE2
        dc.b $B7,$10,$29                                     ; $E6E9 unconfirmed: STAA SWITCH_EVENTS_STROBE3
        dc.b $8D,$06                                         ; $E6EC unconfirmed: BSR $e6f4
        dc.b $FE,$C0,$AD                                     ; $E6EE unconfirmed: LDX $c0ad
        dc.b $7E,$C0,$8D                                     ; $E6F1 unconfirmed: JMP $c08d
        dc.b $0F                                             ; $E6F4 unconfirmed: SEI
        dc.b $B6,$00,$9B                                     ; $E6F5 unconfirmed: LDAA.w $009b
        dc.b $8A,$C0                                         ; $E6F8 unconfirmed: ORAA #$c0
        dc.b $B7,$00,$9B                                     ; $E6FA unconfirmed: STAA.w $009b
        dc.b $0E                                             ; $E6FD unconfirmed: CLI
        dc.b $BD,$EE,$F2                                     ; $E6FE unconfirmed: JSR $eef2
        dc.b $4F                                             ; $E701 unconfirmed: CLRA
        dc.b $B7,$10,$69                                     ; $E702 unconfirmed: STAA $1069
        dc.b $B7,$10,$6A                                     ; $E705 unconfirmed: STAA $106a
        dc.b $39                                             ; $E708 unconfirmed: RTS
        dc.b $CE,$EA,$D5,$8D,$09,$5D,$26,$05,$FE,$C0,$B1,$8D,$01,$39,$B6,$00 ; $E709 data/unclassified
        dc.b $8D,$E6,$00,$C1,$FF,$27,$09,$A1,$00,$27,$06,$C6,$05,$3A,$20,$F1 ; $E719 data/unclassified
        dc.b $5F,$39,$4F,$20,$22,$86,$01,$20,$1E,$86,$02,$20,$1A,$86,$03,$20 ; $E729 data/unclassified
        dc.b $16,$86,$04,$20,$12,$86,$05,$20,$0E,$86,$06,$20,$0A,$86,$07,$20 ; $E739 data/unclassified
        dc.b $06,$86,$08,$20,$02,$86,$09,$36,$FE,$C0,$AD,$BD,$C0,$8D,$32,$F6 ; $E749 data/unclassified
        dc.b $00,$9B,$C5,$80,$27,$17,$0F,$F6,$00,$9B,$C4,$7F,$F7,$00,$9B,$0E ; $E759 data/unclassified
        dc.b $CE,$10,$53,$C6,$FF,$E7,$00,$09,$8C,$10,$4C,$26,$F8,$BD,$E7,$E9 ; $E769 data/unclassified
        dc.b $26,$14,$CE,$10,$69,$E6,$00,$E7,$01,$BD,$E7,$C5,$A7,$00,$BD,$EA ; $E779 data/unclassified
        dc.b $67,$B7,$00,$8D,$20,$11,$36,$BD,$E7,$09,$32,$5D,$26,$18,$BD,$E6 ; $E789 data/unclassified
        dc.b $F4,$FE,$C0,$AF,$BD,$C0,$8D,$BD,$F5,$B3,$CE,$10,$26,$E7,$00,$E7 ; $E799 data/unclassified
        dc.b $01,$E7,$02,$E7,$03,$39,$E6,$03,$CE,$10,$4D,$C4,$7F,$27,$12,$C1 ; $E7A9 data/unclassified
        dc.b $07,$27,$14,$5A,$27,$0B,$5A,$27,$21,$7E,$E7,$97 ; $E7B9 data/unclassified
        dc.b $48                                             ; $E7C5 unconfirmed: ASLA
        dc.b $48                                             ; $E7C6 unconfirmed: ASLA
        dc.b $48                                             ; $E7C7 unconfirmed: ASLA
        dc.b $48                                             ; $E7C8 unconfirmed: ASLA
        dc.b $39                                             ; $E7C9 unconfirmed: RTS
        dc.b $8D,$F9,$A7,$00,$20,$D0,$CE,$10,$52,$E6,$00,$E7,$01,$09,$8C,$10 ; $E7CA data/unclassified
        dc.b $4C,$26,$F6,$8D,$E6,$A7,$01,$20,$BD,$E6,$00,$E7,$01,$20,$E1,$CE ; $E7DA data/unclassified
        dc.b $10,$46,$C6,$FF,$E1,$00,$26,$07,$08,$8C,$10,$4D,$26,$F6,$5F,$39 ; $E7EA data/unclassified
        dc.b $B6,$C0,$AC,$BD,$C2,$8D,$FE,$C0,$AD,$BD,$C0,$8D,$F6,$00,$9B,$C5 ; $E7FA data/unclassified
        dc.b $80,$27,$3B,$0F,$F6,$00,$9B,$C4,$7F,$F7,$00,$9B,$0E,$CE,$10,$61 ; $E80A data/unclassified
        dc.b $86,$FF,$BD,$EF,$00,$8D,$08,$B1,$C0,$71,$23,$22,$7E,$E6,$DF,$CE ; $E81A data/unclassified
        dc.b $10,$69,$BD,$F6,$38,$B6,$00,$86,$8B,$01,$19,$16,$CE,$10,$69,$A7 ; $E82A data/unclassified
        dc.b $01,$BD,$E7,$C5,$A7,$00,$17,$BD,$EA,$67,$B7,$00,$8D,$39,$0F,$F6 ; $E83A data/unclassified
        dc.b $00,$9B,$CA,$80,$F7,$00,$9B,$0E,$BD,$E7,$09,$5D,$27,$1A,$A6,$03 ; $E84A data/unclassified
        dc.b $E6,$04,$EE,$01,$3C,$36,$84,$7F,$27,$11,$81,$08,$27,$19,$81,$07 ; $E85A data/unclassified
        dc.b $27,$0C,$4A,$27,$0C,$4A,$27,$0C,$7E,$E7,$97,$7E,$E9,$D3,$7E,$E8 ; $E86A data/unclassified
        dc.b $A9,$7E,$E9,$34,$7E,$E9,$6E,$32,$38,$6E,$00,$38,$BD,$E6,$F4,$FE ; $E87A data/unclassified
        dc.b $C0,$AF,$BD,$C0,$8D,$7E,$E7,$A0,$5F,$4D,$27,$12,$5C,$8B,$FF,$36 ; $E88A data/unclassified
        dc.b $84,$0F,$81,$0F,$26,$05,$32,$84,$F9,$20,$EE,$32,$20,$EB,$39,$37 ; $E89A data/unclassified
        dc.b $BD,$E7,$E9,$26,$1C,$33,$32,$38,$3C,$8C,$16,$3C,$26,$03,$BD,$EF ; $E8AA data/unclassified
        dc.b $40,$38,$BD,$F6,$38,$CE,$10,$46,$BD,$F6,$98,$BD,$EA,$C0,$7E,$E7 ; $E8BA data/unclassified
        dc.b $A0,$CE,$10,$4D,$BD,$F6,$38,$33,$32,$4D,$2A,$05,$BD,$F9,$D2,$26 ; $E8CA data/unclassified
        dc.b $AA,$38,$3C,$5D,$27,$4E,$8C,$16,$27,$27,$1C,$B6,$00,$86,$11,$22 ; $E8DA data/unclassified
        dc.b $13,$8C,$16,$2E,$26,$3E,$4D,$27,$0B,$7F,$00,$83,$7F,$00,$84,$7F ; $E8EA data/unclassified
        dc.b $00,$85,$20,$30,$7E,$E8,$85,$37,$CE,$10,$4D,$BD,$F6,$38,$7F,$00 ; $E8FA data/unclassified
        dc.b $83,$7F,$00,$84,$7F,$00,$85,$33,$38,$3C,$B6,$00,$86,$27,$15,$11 ; $E90A data/unclassified
        dc.b $22,$E2,$BD,$F6,$98,$BD,$F6,$68,$CE,$16,$6D,$BD,$F6,$38,$BD,$F6 ; $E91A data/unclassified
        dc.b $14,$CE,$16,$6D,$BD,$F6,$98,$7E,$E8,$BB,$32,$37,$BD,$E7,$E9,$26 ; $E92A data/unclassified
        dc.b $14,$33,$38,$A6,$00,$84,$F0,$81,$90,$23,$01,$4F,$B7,$10,$46,$7F ; $E93A data/unclassified
        dc.b $10,$47,$7E,$E8,$C5,$CE,$10,$4D,$BD,$F6,$38,$B6,$00,$86,$84,$0F ; $E94A data/unclassified
        dc.b $33,$38,$11,$22,$71,$8C,$16,$1F,$26,$05,$4D,$26,$02,$20,$67,$BD ; $E95A data/unclassified
        dc.b $EA,$0A,$20,$CF,$32,$37,$BD,$E7,$E9,$26,$1F,$33,$38,$BD,$F1,$8E ; $E96A data/unclassified
        dc.b $4F,$5D,$27,$07,$5A,$0C,$8B,$01,$19,$20,$F6,$16,$84,$0F,$BD,$E7 ; $E97A data/unclassified
        dc.b $C5,$B7,$10,$46,$F7,$10,$47,$7E,$E8,$C5,$CE,$10,$4D,$BD,$F6,$38 ; $E98A data/unclassified
        dc.b $B6,$00,$86,$33,$38,$11,$22,$2E,$8C,$16,$76,$27,$0F,$8C,$16,$78 ; $E99A data/unclassified
        dc.b $27,$0A,$8C,$16,$7A,$27,$05,$8C,$16,$7C,$26,$06,$4D,$26,$03,$7E ; $E9AA data/unclassified
        dc.b $E8,$86,$BD,$E8,$92,$17,$36,$E6,$01,$C4,$0F,$84,$F0,$1B,$A7,$01 ; $E9BA data/unclassified
        dc.b $32,$BD,$EA,$0A,$20,$A7,$7E,$E8,$86,$32,$37,$BD,$E7,$E9,$26,$19 ; $E9CA data/unclassified
        dc.b $33,$C4,$F0,$38,$F7,$00,$8E,$A6,$00,$5F,$B4,$00,$8E,$27,$02,$C6 ; $E9DA data/unclassified
        dc.b $10,$F7,$10,$46,$5F,$F7,$10,$47,$39,$B6,$10,$4D,$33,$F7,$00,$8E ; $E9EA data/unclassified
        dc.b $38,$84,$10,$26,$07,$53,$E4,$00,$E7,$00,$20,$DB,$EA,$00,$20,$F8 ; $E9FA data/unclassified
        dc.b $BD,$E7,$C5,$E6,$00,$C4,$0F,$1B,$A7,$00,$39,$8D,$02,$8D,$00 ; $EA0A data/unclassified
        dc.b $C6,$41                                         ; $EA19 unconfirmed: LDAB #$41
        dc.b $7E,$F5,$B9                                     ; $EA1B unconfirmed: JMP $f5b9
        dc.b $8D,$F9                                         ; $EA1E unconfirmed: BSR $ea19
        dc.b $BD,$EE,$F2                                     ; $EA20 unconfirmed: JSR $eef2
        dc.b $B6,$00,$8D                                     ; $EA23 unconfirmed: LDAA.w $008d
        dc.b $81,$5E                                         ; $EA26 unconfirmed: CMPA #$5e
        dc.b $26,$0E                                         ; $EA28 unconfirmed: BNE $ea38
        dc.b $B6,$00,$9A                                     ; $EA2A unconfirmed: LDAA.w $009a
        dc.b $85,$04                                         ; $EA2D unconfirmed: BITA #$4
        dc.b $27,$E8                                         ; $EA2F unconfirmed: BEQ $ea19
        dc.b $84,$FB                                         ; $EA31 unconfirmed: ANDA #$fb
        dc.b $B7,$00,$9A                                     ; $EA33 unconfirmed: STAA.w $009a
        dc.b $20,$15                                         ; $EA36 unconfirmed: BRA $ea4d
        dc.b $B6,$10,$26                                     ; $EA38 unconfirmed: LDAA SWITCH_EVENTS_STROBE0
        dc.b $84,$0D                                         ; $EA3B unconfirmed: ANDA #$d
        dc.b $27,$DA                                         ; $EA3D unconfirmed: BEQ $ea19
        dc.b $7F,$10,$26                                     ; $EA3F unconfirmed: CLR SWITCH_EVENTS_STROBE0
        dc.b $44                                             ; $EA42 unconfirmed: LSRA
        dc.b $25,$08                                         ; $EA43 unconfirmed: BCS $ea4d
        dc.b $44                                             ; $EA45 unconfirmed: LSRA
        dc.b $44                                             ; $EA46 unconfirmed: LSRA
        dc.b $25,$17                                         ; $EA47 unconfirmed: BCS $ea60
        dc.b $38                                             ; $EA49 unconfirmed: PULX
        dc.b $7E,$E5,$0D                                     ; $EA4A unconfirmed: JMP $e50d
        dc.b $38                                             ; $EA4D unconfirmed: PULX
        dc.b $B6,$00,$8D                                     ; $EA4E unconfirmed: LDAA.w $008d
        dc.b $81,$5E                                         ; $EA51 unconfirmed: CMPA #$5e
        dc.b $23,$02                                         ; $EA53 unconfirmed: BLS $ea57
        dc.b $86,$59                                         ; $EA55 unconfirmed: LDAA #$59
        dc.b $4C                                             ; $EA57 unconfirmed: INCA
        dc.b $B7,$00,$8D                                     ; $EA58 unconfirmed: STAA.w $008d
        dc.b $FE,$10,$17                                     ; $EA5B unconfirmed: LDX $1017
        dc.b $6E,$00                                         ; $EA5E unconfirmed: JMP $0,X
        dc.b $38                                             ; $EA60 unconfirmed: PULX
        dc.b $BD,$E6,$B9                                     ; $EA61 unconfirmed: JSR $e6b9
        dc.b $7E,$E5,$BD                                     ; $EA64 unconfirmed: JMP PROCESS_SWITCH_EVENTS
        dc.b $4F,$36,$BD,$F6,$38,$B6,$00,$86,$27,$0B,$BD,$F6,$D9,$BD,$F6,$26 ; $EA67 data/unclassified
        dc.b $32,$4C,$36,$20,$F0,$32,$4D,$39                 ; $EA77 data/unclassified
        dc.b $CE,$16,$03                                     ; $EA7F unconfirmed: LDX #$1603
        dc.b $4F                                             ; $EA82 unconfirmed: CLRA
        dc.b $E6,$00                                         ; $EA83 unconfirmed: LDAB $0,X
        dc.b $54                                             ; $EA85 unconfirmed: LSRB
        dc.b $54                                             ; $EA86 unconfirmed: LSRB
        dc.b $54                                             ; $EA87 unconfirmed: LSRB
        dc.b $54                                             ; $EA88 unconfirmed: LSRB
        dc.b $1B                                             ; $EA89 unconfirmed: ABA
        dc.b $08                                             ; $EA8A unconfirmed: INX
        dc.b $8C,$16,$20                                     ; $EA8B unconfirmed: CPX #$1620
        dc.b $26,$F3                                         ; $EA8E unconfirmed: BNE $ea83
        dc.b $B1,$16,$02                                     ; $EA90 unconfirmed: CMPA $1602
        dc.b $26,$01                                         ; $EA93 unconfirmed: BNE $ea96
        dc.b $39                                             ; $EA95 unconfirmed: RTS
        dc.b $CE,$16,$03                                     ; $EA96 unconfirmed: LDX #$1603
        dc.b $3C                                             ; $EA99 unconfirmed: PSHX
        dc.b $CE,$C1,$2F                                     ; $EA9A unconfirmed: LDX #$c12f
        dc.b $A6,$00                                         ; $EA9D unconfirmed: LDAA $0,X
        dc.b $FF,$00,$8B                                     ; $EA9F unconfirmed: STX.w $008b
        dc.b $38                                             ; $EAA2 unconfirmed: PULX
        dc.b $BD,$E7,$C5                                     ; $EAA3 unconfirmed: JSR $e7c5
        dc.b $A7,$00                                         ; $EAA6 unconfirmed: STAA $0,X
        dc.b $08                                             ; $EAA8 unconfirmed: INX
        dc.b $3C                                             ; $EAA9 unconfirmed: PSHX
        dc.b $FE,$00,$8B                                     ; $EAAA unconfirmed: LDX.w $008b
        dc.b $08                                             ; $EAAD unconfirmed: INX
        dc.b $8C,$C1,$4B                                     ; $EAAE unconfirmed: CPX #$c14b
        dc.b $26,$EA                                         ; $EAB1 unconfirmed: BNE $ea9d
        dc.b $B6,$C1,$4B                                     ; $EAB3 unconfirmed: LDAA $c14b
        dc.b $B7,$16,$1F                                     ; $EAB6 unconfirmed: STAA $161f
        dc.b $FE,$C1,$4C                                     ; $EAB9 unconfirmed: LDX $c14c
        dc.b $FF,$16,$74                                     ; $EABC unconfirmed: STX $1674
        dc.b $38                                             ; $EABF unconfirmed: PULX
        dc.b $4F                                             ; $EAC0 unconfirmed: CLRA
        dc.b $CE,$16,$03                                     ; $EAC1 unconfirmed: LDX #$1603
        dc.b $E6,$00                                         ; $EAC4 unconfirmed: LDAB $0,X
        dc.b $54                                             ; $EAC6 unconfirmed: LSRB
        dc.b $54                                             ; $EAC7 unconfirmed: LSRB
        dc.b $54                                             ; $EAC8 unconfirmed: LSRB
        dc.b $54                                             ; $EAC9 unconfirmed: LSRB
        dc.b $1B                                             ; $EACA unconfirmed: ABA
        dc.b $08                                             ; $EACB unconfirmed: INX
        dc.b $8C,$16,$20                                     ; $EACC unconfirmed: CPX #$1620
        dc.b $26,$F3                                         ; $EACF unconfirmed: BNE $eac4
        dc.b $B7,$16,$02                                     ; $EAD1 unconfirmed: STAA $1602
        dc.b $39                                             ; $EAD4 unconfirmed: RTS
        dc.b $01,$16,$35,$87,$00,$02,$16,$20,$87,$00,$03,$16,$4A,$87,$00,$04 ; $EAD5 data/unclassified
        dc.b $16,$51,$87,$00,$05,$16,$58,$87,$00,$06,$16,$43,$87,$00,$07,$16 ; $EAE5 data/unclassified
        dc.b $3C,$87,$00,$08,$16,$66,$87,$00,$09,$16,$6D,$87,$00,$0A,$16,$27 ; $EAF5 data/unclassified
        dc.b $07,$05,$0B,$16,$5F,$87,$00,$0C,$16,$03,$07,$00,$0D,$16,$0A,$07 ; $EB05 data/unclassified
        dc.b $00,$0E,$16,$11,$07,$00,$0F,$16,$18,$07,$00,$10,$16,$2E,$07,$40 ; $EB15 data/unclassified
        dc.b $11,$16,$74,$02,$99,$12,$16,$76,$02,$50,$13,$16,$78,$02,$50,$14 ; $EB25 data/unclassified
        dc.b $16,$7A,$02,$50,$15,$16,$7C,$02,$50,$16,$16,$7E,$02,$50,$17,$16 ; $EB35 data/unclassified
        dc.b $1F,$01,$05,$18,$16,$81,$01,$03,$19,$16,$80,$01,$03,$1A,$16,$83 ; $EB45 data/unclassified
        dc.b $01,$03,$1B,$16,$82,$01,$03,$1C,$16,$84,$07,$00,$1D,$16,$8B,$00 ; $EB55 data/unclassified
        dc.b $10,$1E,$16,$8B,$00,$20,$1F,$16,$8B,$00,$80,$57,$EC,$13,$08,$00 ; $EB65 data/unclassified
        dc.b $58,$EC,$1D,$08,$00,$59,$EC,$CE,$08,$00,$5A,$EC,$F0,$08,$00,$5B ; $EB75 data/unclassified
        dc.b $ED,$1F,$08,$00,$5C,$ED,$40,$08,$00,$5D,$EF,$26,$08,$00,$5E,$EE ; $EB85 data/unclassified
        dc.b $A8,$08,$00,$5F,$ED,$D0,$08,$00,$60,$EB,$BB,$08,$00,$FF ; $EB95 data/unclassified
        dc.b $4F                                             ; $EBA3 unconfirmed: CLRA
        dc.b $F6,$00,$8D                                     ; $EBA4 unconfirmed: LDAB.w $008d
        dc.b $27,$07                                         ; $EBA7 unconfirmed: BEQ $ebb0
        dc.b $5A                                             ; $EBA9 unconfirmed: DECB
        dc.b $8B,$01                                         ; $EBAA unconfirmed: ADDA #$1
        dc.b $19                                             ; $EBAC unconfirmed: DAA
        dc.b $5D                                             ; $EBAD unconfirmed: TSTB
        dc.b $26,$F9                                         ; $EBAE unconfirmed: BNE $eba9
        dc.b $39                                             ; $EBB0 unconfirmed: RTS
        dc.b $B7,$10,$6A                                     ; $EBB1 unconfirmed: STAA $106a
        dc.b $BD,$E7,$C5                                     ; $EBB4 unconfirmed: JSR $e7c5
        dc.b $B7,$10,$69                                     ; $EBB7 unconfirmed: STAA $1069
        dc.b $39                                             ; $EBBA unconfirmed: RTS
        dc.b $CE,$EC,$F0,$FF,$10,$17,$FE,$E0,$00,$BD,$EB,$D2,$BD,$EB,$A3,$BD ; $EBBB data/unclassified
        dc.b $EB,$B1,$BD,$EA,$1E,$20,$E9,$A6,$02,$BD,$E7,$C5,$B7,$10,$4C,$A6 ; $EBCB data/unclassified
        dc.b $03,$BD,$E7,$C5,$B7,$10,$4B,$A6,$05,$BD,$E7,$C5,$B7,$10,$4A,$A6 ; $EBDB data/unclassified
        dc.b $06,$BD,$E7,$C5,$B7,$10,$49,$A6,$07,$BD,$E7,$C5,$B7,$10,$48,$A6 ; $EBEB data/unclassified
        dc.b $09,$BD,$E7,$C5,$B7,$10,$47,$A6,$0A,$BD,$E7,$C5,$B7,$10,$46,$A6 ; $EBFB data/unclassified
        dc.b $0D,$BD,$E7,$C5,$B7,$10,$4D,$39,$86,$FF,$B7,$10,$00,$86,$58,$B7 ; $EC0B data/unclassified
        dc.b $00,$8D,$7F,$00,$8B,$CE,$EC,$CE,$FF,$10,$17,$BD,$EE,$F2,$4F,$B7 ; $EC1B data/unclassified
        dc.b $00,$8E,$B6,$00,$8E,$BD,$F5,$6B,$37,$3C,$BD,$F6,$75,$F6,$00,$8E ; $EC2B data/unclassified
        dc.b $54,$54,$54,$54,$17,$F6,$00,$8E,$C4,$0F,$27,$06,$8B,$08,$19,$5A ; $EC3B data/unclassified
        dc.b $26,$FA,$8B,$01,$19,$B7,$00,$86,$BD,$F6,$86,$38,$33,$BD,$EB,$A3 ; $EC4B data/unclassified
        dc.b $BD,$EB,$B1,$BD,$EA,$1E,$B6,$10,$27,$7F,$10,$27,$85,$08,$26,$40 ; $EC5B data/unclassified
        dc.b $B6,$10,$28,$7F,$10,$28,$85,$08,$26,$2F,$B6,$10,$29,$7F,$10,$29 ; $EC6B data/unclassified
        dc.b $85,$08,$27,$03,$7F,$00,$8B,$B6,$00,$8B,$26,$A6,$B6,$00,$8E,$8B ; $EC7B data/unclassified
        dc.b $10,$B7,$00,$8E,$84,$F0,$81,$80,$26,$98,$B6,$00,$8E,$4C,$84,$0F ; $EC8B data/unclassified
        dc.b $81,$0C,$27,$81,$B7,$00,$8E,$20,$89,$86,$FF,$B7,$00,$8B,$20,$DC ; $EC9B data/unclassified
        dc.b $86,$FF,$B7,$00,$8B,$B6,$00,$8E,$26,$02,$86,$8B,$80,$10,$16,$84 ; $ECAB data/unclassified
        dc.b $F0,$81,$F0,$26,$09,$B6,$00,$8E,$84,$0F,$4A,$8A,$70,$16,$F7,$00 ; $ECBB data/unclassified
        dc.b $8E,$20,$D4,$CE,$EC,$F0,$FF,$10,$17,$CE,$10,$3A,$6F,$00,$FF,$00 ; $ECCB data/unclassified
        dc.b $8B,$BD,$EB,$A3,$BD,$EB,$B1,$BD,$EA,$1E,$FE,$00,$8B,$08,$8C,$10 ; $ECDB data/unclassified
        dc.b $46,$26,$E9,$20,$DE,$B6,$10,$2C,$B4,$10,$32,$85,$01,$26,$08,$B6 ; $ECEB data/unclassified
        dc.b $10,$26,$84,$FE,$B7,$10,$26,$CE,$ED,$1F,$FF,$10,$17,$86,$5A,$B7 ; $ECFB data/unclassified
        dc.b $00,$8D,$4F,$CE,$10,$45,$BD,$EF,$00,$BD,$EB,$A3,$BD,$EB,$B1,$BD ; $ED0B data/unclassified
        dc.b $EA,$1E,$20,$E3,$CE,$ED,$40,$FF,$10,$17,$B6,$00,$8E,$8B,$10,$19 ; $ED1B data/unclassified
        dc.b $84,$F0,$B7,$00,$8E,$CE,$10,$6F,$A7,$00,$09,$8C,$10,$45,$26,$F8 ; $ED2B data/unclassified
        dc.b $BD,$EA,$1E,$20,$DF                             ; $ED3B data/unclassified
