; Interrupts and periodic physical I/O
; Address range: $E000-$E387
; Timer/PIA interrupt flow, switch-matrix scan and debounce, lamp refresh, and momentary-solenoid pulse expiry.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

        dc.b $C0,$00,$E5,$0D,$E6,$B9,$E7,$2B,$E7,$FA,$E4,$B3,$E7,$2E,$E7,$32 ; $E000 data/unclassified
        dc.b $E7,$36,$E4,$B3,$E7,$3A,$E7,$3E,$E7,$42,$E4,$B3,$E7,$46,$E7,$4A ; $E010 data/unclassified
        dc.b $E7,$4E                                         ; $E020 data/unclassified
IRQ_TIMER_OUTPUT_COMPARE:
; Timer output-compare service. It enters the periodic I/O refresh at E28C.
        LDAA $0008                   ; $E022: $96,$08
        BITA #$40                    ; $E024: $85,$40
        BEQ IRQ_SCI_AND_TIMER_OVERFLOW ; $E026: $27,$33
        LDD $0009                    ; $E028: $DC,$09
        ADDD #$a1e                   ; $E02A: $C3,$0A,$1E
        STD $000b                    ; $E02D: $DD,$0B
        JMP PERIODIC_IO_REFRESH      ; $E02F: $7E,$E2,$8C
IRQ_EXTERNAL_PIA:
; External PIA interrupt service. It acknowledges PIA control/port activity at 0020-0023; the specific input source remains untraced.
        LDAA PIA0_CRB                ; $E032: $96,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        BPL $e043                    ; $E034: $2A,$0D
        LDAB #$34                    ; $E036: $C6,$34
        STAB PIA0_CRB                ; $E038: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        LDAA PIA0_PORTB_OR_DDRB      ; $E03A: $96,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        LDAA.w $009b                 ; $E03C: $B6,$00,$9B
        ORAA #$20                    ; $E03F: $8A,$20
        BRA $e06b                    ; $E041: $20,$28
        LDAA PIA0_CRA                ; $E043: $96,$21
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        BPL IRQ_SCI_AND_TIMER_OVERFLOW ; $E045: $2A,$14
        LDAA PIA0_PORTA_OR_DDRA      ; $E047: $96,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAA $1015                   ; $E049: $B6,$10,$15
        BNE IRQ_SCI_AND_TIMER_OVERFLOW ; $E04C: $26,$0D
        LDAA #$4b                    ; $E04E: $86,$4B
        STAA $1015                   ; $E050: $B7,$10,$15
        LDAA.w $009a                 ; $E053: $B6,$00,$9A
        ORAA #$4                     ; $E056: $8A,$04
        STAA.w $009a                 ; $E058: $B7,$00,$9A
IRQ_SCI_AND_TIMER_OVERFLOW:
        RTI                          ; $E05B: $3B
IRQ_TIMER_INPUT_CAPTURE:
        LDAA $0008                   ; $E05C: $96,$08
        BPL IRQ_SCI_AND_TIMER_OVERFLOW ; $E05E: $2A,$FB
        LDAB $000d                   ; $E060: $D6,$0D
        ANDA #$ef                    ; $E062: $84,$EF
        STAA $0008                   ; $E064: $97,$08
        LDAA.w $009b                 ; $E066: $B6,$00,$9B
        ANDA #$df                    ; $E069: $84,$DF
        STAA.w $009b                 ; $E06B: $B7,$00,$9B
        CLI                          ; $E06E: $0E
        DEC $100c                    ; $E06F: $7A,$10,$0C
        LDX $1011                    ; $E072: $FE,$10,$11
        BLE $e07b                    ; $E075: $2F,$04
        DEX                          ; $E077: $09
        STX $1011                    ; $E078: $FF,$10,$11
        LDAA $100e                   ; $E07B: $B6,$10,$0E
        BEQ $e084                    ; $E07E: $27,$04
        DECA                         ; $E080: $4A
        STAA $100e                   ; $E081: $B7,$10,$0E
        LDAA $100f                   ; $E084: $B6,$10,$0F
        BEQ $e08d                    ; $E087: $27,$04
        DECA                         ; $E089: $4A
        STAA $100f                   ; $E08A: $B7,$10,$0F
        LDAA $1013                   ; $E08D: $B6,$10,$13
        ADDA #$10                    ; $E090: $8B,$10
        DAA                          ; $E092: $19
        STAA $1013                   ; $E093: $B7,$10,$13
        LDAA $100d                   ; $E096: $B6,$10,$0D
        BEQ MOMENTARY_SOLENOID_PULSE_END ; $E099: $27,$06
        DECA                         ; $E09B: $4A
        STAA $100d                   ; $E09C: $B7,$10,$0D
        BNE $e0a7                    ; $E09F: $26,$06
MOMENTARY_SOLENOID_PULSE_END:
; Momentary-solenoid pulse end: when RAM 100D expires, force PIA1 port-B's low nibble to F (U14 M15, which the available material does not assign to a coil).
        LDAA #$f                     ; $E0A1: $86,$0F
        ORAA PIA1_PORTB_OR_DDRB      ; $E0A3: $9A,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
; PIA mode: PIA1 CRB bit 2 is set; this reads port-B peripheral data before selecting U14 M15.
        STAA PIA1_PORTB_OR_DDRB      ; $E0A5: $97,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
; PIA mode: PIA1 CRB bit 2 is set; this writes U14 selector F to end the momentary pulse.
        LDAA $1010                   ; $E0A7: $B6,$10,$10
        dc.b $27,$01                                         ; $E0AA unconfirmed: BEQ $e0ad
        dc.b $4A                                             ; $E0AC unconfirmed: DECA
        dc.b $B7,$10,$10                                     ; $E0AD unconfirmed: STAA $1010
        dc.b $B6,$10,$15                                     ; $E0B0 unconfirmed: LDAA $1015
        dc.b $27,$04                                         ; $E0B3 unconfirmed: BEQ $e0b9
        dc.b $4A                                             ; $E0B5 unconfirmed: DECA
        dc.b $B7,$10,$15                                     ; $E0B6 unconfirmed: STAA $1015
        dc.b $B6,$00,$9A                                     ; $E0B9 unconfirmed: LDAA.w $009a
        dc.b $85,$20                                         ; $E0BC unconfirmed: BITA #$20
        dc.b $27,$12                                         ; $E0BE unconfirmed: BEQ $e0d2
        dc.b $B6,$10,$02                                     ; $E0C0 unconfirmed: LDAA $1002
        dc.b $27,$04                                         ; $E0C3 unconfirmed: BEQ $e0c9
        dc.b $4A                                             ; $E0C5 unconfirmed: DECA
        dc.b $B7,$10,$02                                     ; $E0C6 unconfirmed: STAA $1002
        dc.b $B6,$10,$05                                     ; $E0C9 unconfirmed: LDAA $1005
        dc.b $27,$04                                         ; $E0CC unconfirmed: BEQ $e0d2
        dc.b $4A                                             ; $E0CE unconfirmed: DECA
        dc.b $B7,$10,$05                                     ; $E0CF unconfirmed: STAA $1005
        dc.b $B6,$00,$9A                                     ; $E0D2 unconfirmed: LDAA.w $009a
        dc.b $85,$80                                         ; $E0D5 unconfirmed: BITA #$80
        dc.b $27,$28                                         ; $E0D7 unconfirmed: BEQ $e101
        dc.b $FE,$10,$38                                     ; $E0D9 unconfirmed: LDX $1038
        dc.b $09                                             ; $E0DC unconfirmed: DEX
        dc.b $26,$1F                                         ; $E0DD unconfirmed: BNE $e0fe
        dc.b $CE,$16,$66                                     ; $E0DF unconfirmed: LDX #$1666
        dc.b $C6,$07                                         ; $E0E2 unconfirmed: LDAB #$7
        dc.b $A6,$00                                         ; $E0E4 unconfirmed: LDAA $0,X
        dc.b $8A,$0F                                         ; $E0E6 unconfirmed: ORAA #$f
        dc.b $81,$9F                                         ; $E0E8 unconfirmed: CMPA #$9f
        dc.b $23,$02                                         ; $E0EA unconfirmed: BLS $e0ee
        dc.b $86,$0F                                         ; $E0EC unconfirmed: LDAA #$f
        dc.b $84,$FA                                         ; $E0EE unconfirmed: ANDA #$fa
        dc.b $8B,$00                                         ; $E0F0 unconfirmed: ADDA #$0
        dc.b $19                                             ; $E0F2 unconfirmed: DAA
        dc.b $A7,$00                                         ; $E0F3 unconfirmed: STAA $0,X
        dc.b $08                                             ; $E0F5 unconfirmed: INX
        dc.b $5A                                             ; $E0F6 unconfirmed: DECB
        dc.b $27,$02                                         ; $E0F7 unconfirmed: BEQ $e0fb
        dc.b $25,$E9                                         ; $E0F9 unconfirmed: BCS $e0e4
        dc.b $CE,$1C,$20                                     ; $E0FB unconfirmed: LDX #$1c20
        dc.b $FF,$10,$38                                     ; $E0FE unconfirmed: STX $1038
        dc.b $B6,$10,$00                                     ; $E101 unconfirmed: LDAA WORK_RAM_U4_6116_START
        dc.b $4A                                             ; $E104 unconfirmed: DECA
        dc.b $26,$FD                                         ; $E105 unconfirmed: BNE $e104
        dc.b $CE,$10,$3A                                     ; $E107 unconfirmed: LDX #$103a
        dc.b $B6,$00,$9B                                     ; $E10A unconfirmed: LDAA.w $009b
        dc.b $85,$20                                         ; $E10D unconfirmed: BITA #$20
        dc.b $26,$03                                         ; $E10F unconfirmed: BNE $e114
        dc.b $CE,$10,$40                                     ; $E111 unconfirmed: LDX #$1040
        dc.b $C6,$F0                                         ; $E114 unconfirmed: LDAB #$f0
        dc.b $96,$23                                         ; $E116 unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E118 unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E11A unconfirmed: SEI
        dc.b $D7,$20                                         ; $E11B unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E11D unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E11F unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E121 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $A6,$00                                         ; $E123 unconfirmed: LDAA $0,X
        dc.b $36                                             ; $E125 unconfirmed: PSHA
        dc.b $48                                             ; $E126 unconfirmed: ASLA
        dc.b $48                                             ; $E127 unconfirmed: ASLA
        dc.b $48                                             ; $E128 unconfirmed: ASLA
        dc.b $48                                             ; $E129 unconfirmed: ASLA
        dc.b $48                                             ; $E12A unconfirmed: ASLA
        dc.b $97,$20                                         ; $E12B unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $5C                                             ; $E12D unconfirmed: INCB
        dc.b $32                                             ; $E12E unconfirmed: PULA
        dc.b $36                                             ; $E12F unconfirmed: PSHA
        dc.b $48                                             ; $E130 unconfirmed: ASLA
        dc.b $48                                             ; $E131 unconfirmed: ASLA
        dc.b $0E                                             ; $E132 unconfirmed: CLI
        dc.b $36                                             ; $E133 unconfirmed: PSHA
        dc.b $96,$23                                         ; $E134 unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E136 unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E138 unconfirmed: SEI
        dc.b $D7,$20                                         ; $E139 unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E13B unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E13D unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E13F unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $32                                             ; $E141 unconfirmed: PULA
        dc.b $97,$20                                         ; $E142 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $5C                                             ; $E144 unconfirmed: INCB
        dc.b $A6,$01                                         ; $E145 unconfirmed: LDAA $1,X
        dc.b $44                                             ; $E147 unconfirmed: LSRA
        dc.b $32                                             ; $E148 unconfirmed: PULA
        dc.b $46                                             ; $E149 unconfirmed: RORA
        dc.b $36                                             ; $E14A unconfirmed: PSHA
        dc.b $0E                                             ; $E14B unconfirmed: CLI
        dc.b $96,$23                                         ; $E14C unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E14E unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E150 unconfirmed: SEI
        dc.b $D7,$20                                         ; $E151 unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E153 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E155 unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E157 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $32                                             ; $E159 unconfirmed: PULA
        dc.b $97,$20                                         ; $E15A unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $5C                                             ; $E15C unconfirmed: INCB
        dc.b $08                                             ; $E15D unconfirmed: INX
        dc.b $A6,$00                                         ; $E15E unconfirmed: LDAA $0,X
        dc.b $36                                             ; $E160 unconfirmed: PSHA
        dc.b $0E                                             ; $E161 unconfirmed: CLI
        dc.b $48                                             ; $E162 unconfirmed: ASLA
        dc.b $48                                             ; $E163 unconfirmed: ASLA
        dc.b $48                                             ; $E164 unconfirmed: ASLA
        dc.b $48                                             ; $E165 unconfirmed: ASLA
        dc.b $36                                             ; $E166 unconfirmed: PSHA
        dc.b $96,$23                                         ; $E167 unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E169 unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E16B unconfirmed: SEI
        dc.b $D7,$20                                         ; $E16C unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E16E unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E170 unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E172 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $32                                             ; $E174 unconfirmed: PULA
        dc.b $97,$20                                         ; $E175 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $5C                                             ; $E177 unconfirmed: INCB
        dc.b $32                                             ; $E178 unconfirmed: PULA
        dc.b $36                                             ; $E179 unconfirmed: PSHA
        dc.b $48                                             ; $E17A unconfirmed: ASLA
        dc.b $36                                             ; $E17B unconfirmed: PSHA
        dc.b $0E                                             ; $E17C unconfirmed: CLI
        dc.b $96,$23                                         ; $E17D unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E17F unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E181 unconfirmed: SEI
        dc.b $D7,$20                                         ; $E182 unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E184 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E186 unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E188 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $32                                             ; $E18A unconfirmed: PULA
        dc.b $97,$20                                         ; $E18B unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $5C                                             ; $E18D unconfirmed: INCB
        dc.b $32                                             ; $E18E unconfirmed: PULA
        dc.b $37                                             ; $E18F unconfirmed: PSHB
        dc.b $E6,$01                                         ; $E190 unconfirmed: LDAB $1,X
        dc.b $54                                             ; $E192 unconfirmed: LSRB
        dc.b $46                                             ; $E193 unconfirmed: RORA
        dc.b $54                                             ; $E194 unconfirmed: LSRB
        dc.b $46                                             ; $E195 unconfirmed: RORA
        dc.b $33                                             ; $E196 unconfirmed: PULB
        dc.b $36                                             ; $E197 unconfirmed: PSHA
        dc.b $0E                                             ; $E198 unconfirmed: CLI
        dc.b $96,$23                                         ; $E199 unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E19B unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E19D unconfirmed: SEI
        dc.b $D7,$20                                         ; $E19E unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E1A0 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E1A2 unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E1A4 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $32                                             ; $E1A6 unconfirmed: PULA
        dc.b $97,$20                                         ; $E1A7 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $5C                                             ; $E1A9 unconfirmed: INCB
        dc.b $08                                             ; $E1AA unconfirmed: INX
        dc.b $A6,$00                                         ; $E1AB unconfirmed: LDAA $0,X
        dc.b $36                                             ; $E1AD unconfirmed: PSHA
        dc.b $48                                             ; $E1AE unconfirmed: ASLA
        dc.b $48                                             ; $E1AF unconfirmed: ASLA
        dc.b $48                                             ; $E1B0 unconfirmed: ASLA
        dc.b $36                                             ; $E1B1 unconfirmed: PSHA
        dc.b $0E                                             ; $E1B2 unconfirmed: CLI
        dc.b $96,$23                                         ; $E1B3 unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E1B5 unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E1B7 unconfirmed: SEI
        dc.b $D7,$20                                         ; $E1B8 unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E1BA unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E1BC unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E1BE unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $32                                             ; $E1C0 unconfirmed: PULA
        dc.b $97,$20                                         ; $E1C1 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $5C                                             ; $E1C3 unconfirmed: INCB
        dc.b $01                                             ; $E1C4 unconfirmed: NOP
        dc.b $01                                             ; $E1C5 unconfirmed: NOP
        dc.b $01                                             ; $E1C6 unconfirmed: NOP
        dc.b $01                                             ; $E1C7 unconfirmed: NOP
        dc.b $0E                                             ; $E1C8 unconfirmed: CLI
        dc.b $96,$23                                         ; $E1C9 unconfirmed: LDAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $8A,$3C                                         ; $E1CB unconfirmed: ORAA #$3c
        dc.b $0F                                             ; $E1CD unconfirmed: SEI
        dc.b $D7,$20                                         ; $E1CE unconfirmed: STAB PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $97,$23                                         ; $E1D0 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $84,$F7                                         ; $E1D2 unconfirmed: ANDA #$f7
        dc.b $97,$23                                         ; $E1D4 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $32                                             ; $E1D6 unconfirmed: PULA
        dc.b $97,$20                                         ; $E1D7 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $08                                             ; $E1D9 unconfirmed: INX
        dc.b $5C                                             ; $E1DA unconfirmed: INCB
        dc.b $27,$03                                         ; $E1DB unconfirmed: BEQ $e1e0
        dc.b $7E,$E1,$16                                     ; $E1DD unconfirmed: JMP $e116
        dc.b $5F                                             ; $E1E0 unconfirmed: CLRB
        dc.b $86,$30                                         ; $E1E1 unconfirmed: LDAA #$30
        dc.b $0F                                             ; $E1E3 unconfirmed: SEI
        dc.b $F7,$10,$0B                                     ; $E1E4 unconfirmed: STAB $100b
        dc.b $97,$23                                         ; $E1E7 unconfirmed: STAA PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        STAB PIA0_PORTB_OR_DDRB      ; $E1E9: $D7,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
; PIA mode: CRB was just written with 30 (bit 2 clear); this zero write programs PIA0 DDRB as all inputs for the switch returns.
        LDAB #$34                    ; $E1EB: $C6,$34
        STAB PIA0_CRB                ; $E1ED: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
; PIA mode: Writing 34 sets CRB bit 2, restoring PIA0 port-B peripheral-data access before the scan.
        CLI                          ; $E1EF: $0E
SWITCH_MATRIX_SCAN:
; Switch-matrix scan: drive the five one-hot strobes 10, 08, 04, 02, 01 through PIA0 port A (0020); after a short delay read the eight returns from PIA0 port B (0022) and debounce the samples in RAM. See HARDWARE_MAP.md for switch numbers.
        LDAA #$10                    ; $E1F0: $86,$10
        LDX #$102a                   ; $E1F2: $CE,$10,$2A
        CLI                          ; $E1F5: $0E
        STAA PIA0_PORTA_OR_DDRA      ; $E1F6: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
; PIA mode: PIA0 CRA bit 2 is set; this writes the next one-hot switch strobe to port A.
        BEQ $e25d                    ; $E1F8: $27,$63
        SEI                          ; $E1FA: $0F
        LSRA                         ; $E1FB: $44
        PSHA                         ; $E1FC: $36
        LDAA $6,X                    ; $E1FD: $A6,$06
        TAB                          ; $E1FF: $16
        EORA $c,X                    ; $E200: $A8,$0C
        ANDA $6,X                    ; $E202: $A4,$06
        STAB $c,X                    ; $E204: $E7,$0C
        LDAB #$1a                    ; $E206: $C6,$1A
        DECB                         ; $E208: $5A
        BNE $e208                    ; $E209: $26,$FD
        LDAB PIA0_PORTB_OR_DDRB      ; $E20B: $D6,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
; PIA mode: PIA0 CRB bit 2 is set; this reads the eight switch returns from port B.
        STAB $6,X                    ; $E20D: $E7,$06
        ANDA $6,X                    ; $E20F: $A4,$06
        ORAA $0,X                    ; $E211: $AA,$00
; Switch events: OR a debounced closure into the event byte at X; on strobe 0, X=1026 and mask 0x40 is switch 07 Rebound.
        STAA $0,X                    ; $E213: $A7,$00
; Switch events: latch the accumulated closure bits for the current strobe; 1026 mask 0x40 is switch 07 Rebound.
        PULA                         ; $E215: $32
        dc.b $09                                             ; $E216 unconfirmed: DEX
        dc.b $85,$01                                         ; $E217 unconfirmed: BITA #$1
        dc.b $27,$DA                                         ; $E219 unconfirmed: BEQ $e1f5
        dc.b $0E                                             ; $E21B unconfirmed: CLI
        dc.b $F6,$C0,$B7                                     ; $E21C unconfirmed: LDAB $c0b7
        dc.b $27,$D4                                         ; $E21F unconfirmed: BEQ $e1f5
        dc.b $F6,$10,$0C                                     ; $E221 unconfirmed: LDAB $100c
        dc.b $C5,$01                                         ; $E224 unconfirmed: BITB #$1
        dc.b $27,$CD                                         ; $E226 unconfirmed: BEQ $e1f5
        dc.b $4F                                             ; $E228 unconfirmed: CLRA
        dc.b $97,$20                                         ; $E229 unconfirmed: STAA PIA0_PORTA_OR_DDRA
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        dc.b $B6,$C0,$B7                                     ; $E22B unconfirmed: LDAA $c0b7
        dc.b $36                                             ; $E22E unconfirmed: PSHA
        dc.b $9A,$42                                         ; $E22F unconfirmed: ORAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $97,$42                                         ; $E231 unconfirmed: STAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $0F                                             ; $E233 unconfirmed: SEI
        dc.b $B6,$10,$31                                     ; $E234 unconfirmed: LDAA $1031
        dc.b $16                                             ; $E237 unconfirmed: TAB
        dc.b $B8,$10,$37                                     ; $E238 unconfirmed: EORA $1037
        dc.b $B4,$10,$31                                     ; $E23B unconfirmed: ANDA $1031
        dc.b $F7,$10,$37                                     ; $E23E unconfirmed: STAB $1037
        dc.b $C6,$1B                                         ; $E241 unconfirmed: LDAB #$1b
        dc.b $5A                                             ; $E243 unconfirmed: DECB
        dc.b $26,$FD                                         ; $E244 unconfirmed: BNE $e243
        dc.b $D6,$22                                         ; $E246 unconfirmed: LDAB PIA0_PORTB_OR_DDRB
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        dc.b $0E                                             ; $E248 unconfirmed: CLI
        dc.b $F7,$10,$31                                     ; $E249 unconfirmed: STAB $1031
        dc.b $B4,$10,$31                                     ; $E24C unconfirmed: ANDA $1031
        dc.b $BA,$10,$2B                                     ; $E24F unconfirmed: ORAA $102b
        dc.b $B7,$10,$2B                                     ; $E252 unconfirmed: STAA $102b
        dc.b $32                                             ; $E255 unconfirmed: PULA
        dc.b $88,$FF                                         ; $E256 unconfirmed: EORA #$ff
        dc.b $94,$42                                         ; $E258 unconfirmed: ANDA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $97,$42                                         ; $E25A unconfirmed: STAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $4F                                             ; $E25C unconfirmed: CLRA
        dc.b $43                                             ; $E25D unconfirmed: COMA
        dc.b $C6,$30                                         ; $E25E unconfirmed: LDAB #$30
        dc.b $0F                                             ; $E260 unconfirmed: SEI
        dc.b $D7,$23                                         ; $E261 unconfirmed: STAB PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $97,$22                                         ; $E263 unconfirmed: STAA PIA0_PORTB_OR_DDRB
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        dc.b $B7,$10,$0B                                     ; $E265 unconfirmed: STAA $100b
        dc.b $C6,$34                                         ; $E268 unconfirmed: LDAB #$34
        dc.b $D7,$23                                         ; $E26A unconfirmed: STAB PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $0E                                             ; $E26C unconfirmed: CLI
        dc.b $FE,$C0,$73                                     ; $E26D unconfirmed: LDX $c073
        dc.b $6E,$00                                         ; $E270 unconfirmed: JMP $0,X
        dc.b $0F                                             ; $E272 unconfirmed: SEI
        dc.b $F6,$00,$9B                                     ; $E273 unconfirmed: LDAB.w $009b
        dc.b $C5,$20                                         ; $E276 unconfirmed: BITB #$20
        dc.b $26,$08                                         ; $E278 unconfirmed: BNE $e282
        dc.b $C6,$35                                         ; $E27A unconfirmed: LDAB #$35
        dc.b $96,$22                                         ; $E27C unconfirmed: LDAA PIA0_PORTB_OR_DDRB
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        dc.b $D7,$23                                         ; $E27E unconfirmed: STAB PIA0_CRB
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        dc.b $20,$08                                         ; $E280 unconfirmed: BRA $e28a
        dc.b $96,$08                                         ; $E282 unconfirmed: LDAA $0008
        dc.b $D6,$0D                                         ; $E284 unconfirmed: LDAB $000d
        dc.b $8A,$10                                         ; $E286 unconfirmed: ORAA #$10
        dc.b $97,$08                                         ; $E288 unconfirmed: STAA $0008
        dc.b $0E                                             ; $E28A unconfirmed: CLI
        dc.b $3B                                             ; $E28B unconfirmed: RTI
PERIODIC_IO_REFRESH:
; Periodic I/O refresh. It multiplexes the lamp path at PIA0 and services other board I/O.
        LDAA PIA0_CRB                ; $E28C: $96,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        PSHA                         ; $E28E: $36
        LDAA PIA0_PORTA_OR_DDRA      ; $E28F: $96,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        PSHA                         ; $E291: $36
        LDAA $100b                   ; $E292: $B6,$10,$0B
        BNE $e2a4                    ; $E295: $26,$0D
        COMA                         ; $E297: $43
        LDAB #$30                    ; $E298: $C6,$30
        STAB PIA0_CRB                ; $E29A: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        STAA PIA0_PORTB_OR_DDRB      ; $E29C: $97,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
; PIA mode: CRB was just written with 30 (bit 2 clear), so this instruction writes PIA0 DDRB.
        LDAB #$34                    ; $E29E: $C6,$34
        STAB PIA0_CRB                ; $E2A0: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
; PIA mode: Writing 34 sets CRB bit 2, selecting PIA0 port-B peripheral data.
        STAA PIA0_PORTB_OR_DDRB      ; $E2A2: $97,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
; PIA mode: PIA0 CRB bit 2 is set, so this instruction writes port-B peripheral data.
        STAA PIA0_PORTA_OR_DDRA      ; $E2A4: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
; PIA mode: PIA0 CRA bit 2 is set, so this instruction writes port-A peripheral data for the multiplexed I/O path.
        LDAB #$3c                    ; $E2A6: $C6,$3C
        STAB PIA0_CRB                ; $E2A8: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        LDAB #$3d                    ; $E2AA: $C6,$3D
        STAB PIA1_CRA                ; $E2AC: $D7,$41
; I/O: PIA1 control register A. Bit 2 selects port-data versus data-direction access at 0040.
        LDAB #$34                    ; $E2AE: $C6,$34
        STAB PIA0_CRB                ; $E2B0: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        LDAB #$35                    ; $E2B2: $C6,$35
        STAB PIA1_CRA                ; $E2B4: $D7,$41
; I/O: PIA1 control register A. Bit 2 selects port-data versus data-direction access at 0040.
        LDX.w $0081                  ; $E2B6: $FE,$00,$81
        LDAA #$35                    ; $E2B9: $86,$35
        STAA PIA0_CRA                ; $E2BB: $97,$21
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        LDAA $0,X                    ; $E2BD: $A6,$00
        ORAA #$f                     ; $E2BF: $8A,$0F
        ANDA #$fe                    ; $E2C1: $84,$FE
        STAA PIA0_PORTA_OR_DDRA      ; $E2C3: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAB $7,X                    ; $E2C5: $E6,$07
        ORAA #$f                     ; $E2C7: $8A,$0F
        STAA PIA0_PORTA_OR_DDRA      ; $E2C9: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        ORAB #$f                     ; $E2CB: $CA,$0F
        ANDB #$fd                    ; $E2CD: $C4,$FD
        STAB PIA0_PORTA_OR_DDRA      ; $E2CF: $D7,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAA $e,X                    ; $E2D1: $A6,$0E
        ORAB #$f                     ; $E2D3: $CA,$0F
        STAB PIA0_PORTA_OR_DDRA      ; $E2D5: $D7,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        ORAA #$f                     ; $E2D7: $8A,$0F
        ANDA #$fb                    ; $E2D9: $84,$FB
        STAA PIA0_PORTA_OR_DDRA      ; $E2DB: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAB $15,X                   ; $E2DD: $E6,$15
        ORAA #$f                     ; $E2DF: $8A,$0F
        STAA PIA0_PORTA_OR_DDRA      ; $E2E1: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAA PIA1_PORTA_OR_DDRA      ; $E2E3: $96,$40
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
        ANDA #$1                     ; $E2E5: $84,$01
        ORAA.w $0080                 ; $E2E7: $BA,$00,$80
        STAA PIA1_PORTA_OR_DDRA      ; $E2EA: $97,$40
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
        ORAB #$f                     ; $E2EC: $CA,$0F
        ANDB #$f7                    ; $E2EE: $C4,$F7
        STAB PIA0_PORTA_OR_DDRA      ; $E2F0: $D7,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAA $23,X                   ; $E2F2: $A6,$23
        ORAB #$f                     ; $E2F4: $CA,$0F
        STAB PIA0_PORTA_OR_DDRA      ; $E2F6: $D7,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        ORAA #$f                     ; $E2F8: $8A,$0F
        STAA PIA0_PORTA_OR_DDRA      ; $E2FA: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAB PIA1_PORTA_OR_DDRA      ; $E2FC: $D6,$40
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
        ANDB #$fe                    ; $E2FE: $C4,$FE
        STAB PIA1_PORTA_OR_DDRA      ; $E300: $D7,$40
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
        ORAB #$1                     ; $E302: $CA,$01
        STAB PIA1_PORTA_OR_DDRA      ; $E304: $D7,$40
; I/O: PIA1 port A / DDRA. Its physical function is not yet traced.
        LDAB $c0b8                   ; $E306: $F6,$C0,$B8
        BEQ $e330                    ; $E309: $27,$25
        LDAA $1c,X                   ; $E30B: $A6,$1C
        ORAA #$f                     ; $E30D: $8A,$0F
        STAA PIA0_PORTA_OR_DDRA      ; $E30F: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        ORAB PIA1_PORTB_OR_DDRB      ; $E311: $DA,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        STAB PIA1_PORTB_OR_DDRB      ; $E313: $D7,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        NOP                          ; $E315: $01
        LDAB $c0b8                   ; $E316: $F6,$C0,$B8
        EORB PIA1_PORTB_OR_DDRB      ; $E319: $D8,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        STAB PIA1_PORTB_OR_DDRB      ; $E31B: $D7,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        LDAB $c0b8                   ; $E31D: $F6,$C0,$B8
        LDAA #$ff                    ; $E320: $86,$FF
        STAA PIA0_PORTA_OR_DDRA      ; $E322: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        ORAB PIA1_PORTB_OR_DDRB      ; $E324: $DA,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        STAB PIA1_PORTB_OR_DDRB      ; $E326: $D7,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        NOP                          ; $E328: $01
        LDAB $c0b8                   ; $E329: $F6,$C0,$B8
        EORB PIA1_PORTB_OR_DDRB      ; $E32C: $D8,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        STAB PIA1_PORTB_OR_DDRB      ; $E32E: $D7,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        LDAA.w $009a                 ; $E330: $B6,$00,$9A
        BITA #$a0                    ; $E333: $85,$A0
        BNE $e34e                    ; $E335: $26,$17
        LDAA.w $009b                 ; $E337: $B6,$00,$9B
        BITA #$40                    ; $E33A: $85,$40
        BNE $e34e                    ; $E33C: $26,$10
        LDAA $100c                   ; $E33E: $B6,$10,$0C
        BITA #$20                    ; $E341: $85,$20
        BNE $e34e                    ; $E343: $26,$09
        LDAB $1014                   ; $E345: $F6,$10,$14
        STAB PIA0_PORTA_OR_DDRA      ; $E348: $D7,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        ORAB #$ff                    ; $E34A: $CA,$FF
        STAB PIA0_PORTA_OR_DDRA      ; $E34C: $D7,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAA #$3d                    ; $E34E: $86,$3D
        STAA PIA0_CRA                ; $E350: $97,$21
; I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.
        ASL.w $0080                  ; $E352: $78,$00,$80
        LDX.w $0081                  ; $E355: $FE,$00,$81
        DEX                          ; $E358: $09
        CPX #$1045                   ; $E359: $8C,$10,$45
        BNE $e366                    ; $E35C: $26,$08
        LDAA #$2                     ; $E35E: $86,$02
        STAA.w $0080                 ; $E360: $B7,$00,$80
        LDX #$104c                   ; $E363: $CE,$10,$4C
        STX.w $0081                  ; $E366: $FF,$00,$81
        PULA                         ; $E369: $32
        STAA PIA0_PORTA_OR_DDRA      ; $E36A: $97,$20
; I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.
        LDAA $100b                   ; $E36C: $B6,$10,$0B
        BNE $e37c                    ; $E36F: $26,$0B
        LDAB #$30                    ; $E371: $C6,$30
        STAB PIA0_CRB                ; $E373: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        STAA PIA0_PORTB_OR_DDRB      ; $E375: $97,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        LDAB #$34                    ; $E377: $C6,$34
        STAB PIA0_CRB                ; $E379: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
        COMA                         ; $E37B: $43
        STAA PIA0_PORTB_OR_DDRB      ; $E37C: $97,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        PULA                         ; $E37E: $32
        TAB                          ; $E37F: $16
        LSRA                         ; $E380: $44
        BCS $e385                    ; $E381: $25,$02
        LDAA PIA0_PORTB_OR_DDRB      ; $E383: $96,$22
; I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.
        STAB PIA0_CRB                ; $E385: $D7,$23
; I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.
IRQ_NMI:
        RTI                          ; $E387: $3B
