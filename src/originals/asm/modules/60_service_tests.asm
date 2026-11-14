; Service tests
; Address range: $ED40-$EFFF
; Automatic solenoid-test sequencing, displayed test-number handling, and adjacent diagnostics.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

RUN_AUTOMATIC_SOLENOID_SELF_TEST:
; Automatic solenoid self-test. C0AA points to the selector bytes at C0BA. The loop displays sequential BCD test numbers while firing M0, M1, M2, M3, M4, M7, M8, M9, M10, M11, M13, and M14 as tests 01-12. After two FF table terminators, the continuous-output table contains BF; EDBA writes it directly to PIA1 port B as test 13, the K1 flipper-enable relay. This ROM sequence independently confirms manual page 1-18.
        LDX #$ef26                   ; $ED40: $CE,$EF,$26
        STX $1017                    ; $ED43: $FF,$10,$17
        LDX SOLENOID_SELF_TEST_TABLE_POINTER ; $ED46: $FE,$C0,$AA
; Solenoid test: load the pointer at C0AA to the momentary-selector table at C0BA.
        DEX                          ; $ED49: $09
        CLR.w $008e                  ; $ED4A: $7F,$00,$8E
        INX                          ; $ED4D: $08
        STX.w $008b                  ; $ED4E: $FF,$00,$8B
        LDAA $0,X                    ; $ED51: $A6,$00
; Solenoid test: read the next selector; the table order is 00,01,02,03,04,07,08,09,0A,0B,0D,0E.
        CMPA #$ff                    ; $ED53: $81,$FF
        BEQ $ed78                    ; $ED55: $27,$21
        JSR MOMENTARY_SOLENOID_PULSE ; $ED57: $BD,$F5,$DF
; Solenoid test: fire this U14 selector through F5DF; EF1A advances the displayed number by one.
        LDAA #$e                     ; $ED5A: $86,$0E
        STAA $100d                   ; $ED5C: $B7,$10,$0D
        JSR INCREMENT_AND_DISPLAY_SELF_TEST_NUMBER ; $ED5F: $BD,$EF,$09
        JSR $eba3                    ; $ED62: $BD,$EB,$A3
        JSR $ebb1                    ; $ED65: $BD,$EB,$B1
        LDAB #$e                     ; $ED68: $C6,$0E
        JSR $f5b9                    ; $ED6A: $BD,$F5,$B9
        CLR SWITCH_EVENTS_STROBE0    ; $ED6D: $7F,$10,$26
        JSR $ea1e                    ; $ED70: $BD,$EA,$1E
        LDX.w $008b                  ; $ED73: $FE,$00,$8B
        BRA $ed4d                    ; $ED76: $20,$D5
        INX                          ; $ED78: $08
        STX.w $008b                  ; $ED79: $FF,$00,$8B
        LDAA $0,X                    ; $ED7C: $A6,$00
        CMPA #$ff                    ; $ED7E: $81,$FF
        BEQ $edb0                    ; $ED80: $27,$2E
        PSHA                         ; $ED82: $36
        JSR $c0b9                    ; $ED83: $BD,$C0,$B9
        LDAB #$12                    ; $ED86: $C6,$12
        JSR $f5b9                    ; $ED88: $BD,$F5,$B9
        PULA                         ; $ED8B: $32
        JSR MOMENTARY_SOLENOID_PULSE ; $ED8C: $BD,$F5,$DF
        LDAA #$e                     ; $ED8F: $86,$0E
        STAA $100d                   ; $ED91: $B7,$10,$0D
        JSR INCREMENT_AND_DISPLAY_SELF_TEST_NUMBER ; $ED94: $BD,$EF,$09
        JSR $eba3                    ; $ED97: $BD,$EB,$A3
        JSR $ebb1                    ; $ED9A: $BD,$EB,$B1
        LDAB #$e                     ; $ED9D: $C6,$0E
        JSR $f5b9                    ; $ED9F: $BD,$F5,$B9
        CLR SWITCH_EVENTS_STROBE0    ; $EDA2: $7F,$10,$26
        CLR SWITCH_SAMPLE_CURRENT_STROBE0 ; $EDA5: $7F,$10,$2C
        JSR $ea1e                    ; $EDA8: $BD,$EA,$1E
        LDX.w $008b                  ; $EDAB: $FE,$00,$8B
        BRA $ed78                    ; $EDAE: $20,$C8
        INX                          ; $EDB0: $08
        STX.w $008b                  ; $EDB1: $FF,$00,$8B
        LDAA $0,X                    ; $EDB4: $A6,$00
        CMPA #$ff                    ; $EDB6: $81,$FF
        BEQ RUN_AUTOMATIC_SOLENOID_SELF_TEST ; $EDB8: $27,$86
        STAA PIA1_PORTB_OR_DDRB      ; $EDBA: $97,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
; Solenoid test: write continuous pattern BF directly to PIA1 port B for displayed test 13 (K1 flipper-enable relay), not through U14.
        JSR INCREMENT_AND_DISPLAY_SELF_TEST_NUMBER ; $EDBC: $BD,$EF,$09
        JSR $eba3                    ; $EDBF: $BD,$EB,$A3
        JSR $ebb1                    ; $EDC2: $BD,$EB,$B1
        JSR $ea19                    ; $EDC5: $BD,$EA,$19
        JSR $ea1e                    ; $EDC8: $BD,$EA,$1E
        LDX.w $008b                  ; $EDCB: $FE,$00,$8B
        BRA $edb0                    ; $EDCE: $20,$E0
        dc.b $CE,$EC,$F0,$FF,$10,$17,$FE,$C0,$AA,$7F,$00,$8E,$FF,$00,$8B,$A6 ; $EDD0 data/unclassified
        dc.b $00,$81,$FF,$27,$37,$BD,$F5,$DF,$BD,$EF,$0B,$C6,$0E,$F7,$10,$0D ; $EDE0 data/unclassified
        dc.b $BD,$F5,$B9,$7F,$10,$26,$BD,$EB,$A3,$BD,$EB,$B1,$BD,$EA,$1E,$FE ; $EDF0 data/unclassified
        dc.b $00,$8B,$B6,$10,$27,$7F,$10,$27,$85,$08,$26,$D0,$B6,$10,$28,$7F ; $EE00 data/unclassified
        dc.b $10,$28,$85,$08,$27,$E0,$BD,$EF,$1A,$08,$20,$C0,$08,$FF,$00,$8B ; $EE10 data/unclassified
        dc.b $A6,$00,$81,$FF,$27,$41,$36,$BD,$C0,$B9,$C6,$12,$BD,$F5,$B9,$32 ; $EE20 data/unclassified
        dc.b $BD,$F5,$DF,$BD,$EF,$0B,$C6,$0E,$F7,$10,$0D,$BD,$F5,$B9,$7F,$10 ; $EE30 data/unclassified
        dc.b $26,$BD,$EB,$A3,$BD,$EB,$B1,$BD,$EA,$1E,$FE,$00,$8B,$B6,$10,$27 ; $EE40 data/unclassified
        dc.b $7F,$10,$27,$85,$08,$26,$C9,$B6,$10,$28,$7F,$10,$28,$85,$08,$27 ; $EE50 data/unclassified
        dc.b $E0,$BD,$EF,$1A,$08,$20,$B9,$08,$FF,$00,$8B,$A6,$00,$81,$FF,$26 ; $EE60 data/unclassified
        dc.b $03,$7E,$ED,$D0,$97,$42,$BD,$EF,$0B,$BD,$EB,$A3,$BD,$EB,$B1,$BD ; $EE70 data/unclassified
        dc.b $EA,$19,$BD,$EB,$A3,$BD,$EB,$B1,$BD,$EA,$1E,$FE,$00,$8B,$B6,$10 ; $EE80 data/unclassified
        dc.b $27,$7F,$10,$27,$85,$08,$26,$D3,$B6,$10,$28,$7F,$10,$28,$85,$08 ; $EE90 data/unclassified
        dc.b $27,$E0,$BD,$EF,$1A,$08,$20,$C3                 ; $EEA0 data/unclassified
        dc.b $CE,$EC,$F0                                     ; $EEA8 unconfirmed: LDX #$ecf0
        dc.b $FF,$10,$17                                     ; $EEAB unconfirmed: STX $1017
        dc.b $B6,$C0,$B7                                     ; $EEAE unconfirmed: LDAA $c0b7
        dc.b $26,$09                                         ; $EEB1 unconfirmed: BNE $eebc
        dc.b $B7,$10,$2B                                     ; $EEB3 unconfirmed: STAA $102b
        dc.b $B7,$10,$31                                     ; $EEB6 unconfirmed: STAA $1031
        dc.b $B7,$10,$37                                     ; $EEB9 unconfirmed: STAA $1037
        dc.b $7F,$00,$8E                                     ; $EEBC unconfirmed: CLR.w $008e
        dc.b $CE,$10,$26                                     ; $EEBF unconfirmed: LDX #$1026
        dc.b $C6,$08                                         ; $EEC2 unconfirmed: LDAB #$8
        dc.b $A6,$06                                         ; $EEC4 unconfirmed: LDAA $6,X
        dc.b $8D,$52                                         ; $EEC6 unconfirmed: BSR INCREMENT_BCD_SELF_TEST_NUMBER
        dc.b $44                                             ; $EEC8 unconfirmed: LSRA
        dc.b $25,$11                                         ; $EEC9 unconfirmed: BCS $eedc
        dc.b $5A                                             ; $EECB unconfirmed: DECB
        dc.b $26,$F8                                         ; $EECC unconfirmed: BNE $eec6
        dc.b $08                                             ; $EECE unconfirmed: INX
        dc.b $8C,$10,$2C                                     ; $EECF unconfirmed: CPX #$102c
        dc.b $26,$EE                                         ; $EED2 unconfirmed: BNE $eec2
        dc.b $7F,$00,$8E                                     ; $EED4 unconfirmed: CLR.w $008e
        dc.b $BD,$EF,$0B                                     ; $EED7 unconfirmed: JSR $ef0b
        dc.b $20,$0B                                         ; $EEDA unconfirmed: BRA $eee7
        dc.b $6F,$00                                         ; $EEDC unconfirmed: CLR $0,X
        dc.b $FE,$C0,$8B                                     ; $EEDE unconfirmed: LDX $c08b
        dc.b $BD,$C0,$8D                                     ; $EEE1 unconfirmed: JSR $c08d
        dc.b $BD,$EF,$0B                                     ; $EEE4 unconfirmed: JSR $ef0b
        dc.b $BD,$EB,$A3                                     ; $EEE7 unconfirmed: JSR $eba3
        dc.b $BD,$EB,$B1                                     ; $EEEA unconfirmed: JSR $ebb1
        dc.b $BD,$EA,$1E                                     ; $EEED unconfirmed: JSR $ea1e
        dc.b $20,$CA                                         ; $EEF0 unconfirmed: BRA $eebc
        dc.b $B6,$C0,$B7                                     ; $EEF2 unconfirmed: LDAA $c0b7
        dc.b $BB,$C0,$B8                                     ; $EEF5 unconfirmed: ADDA $c0b8
        dc.b $43                                             ; $EEF8 unconfirmed: COMA
        dc.b $97,$42                                         ; $EEF9 unconfirmed: STAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $86,$FF                                         ; $EEFB unconfirmed: LDAA #$ff
        dc.b $CE,$10,$6F                                     ; $EEFD unconfirmed: LDX #$106f
        dc.b $A7,$00                                         ; $EF00 unconfirmed: STAA $0,X
        dc.b $09                                             ; $EF02 unconfirmed: DEX
        dc.b $8C,$10,$39                                     ; $EF03 unconfirmed: CPX #$1039
        dc.b $26,$F8                                         ; $EF06 unconfirmed: BNE $ef00
        dc.b $39                                             ; $EF08 unconfirmed: RTS
INCREMENT_AND_DISPLAY_SELF_TEST_NUMBER:
        dc.b $8D,$0F                                         ; $EF09 unconfirmed: BSR INCREMENT_BCD_SELF_TEST_NUMBER
        dc.b $3C                                             ; $EF0B unconfirmed: PSHX
        dc.b $BD,$F6,$75                                     ; $EF0C unconfirmed: JSR $f675
        dc.b $B6,$00,$8E                                     ; $EF0F unconfirmed: LDAA.w $008e
        dc.b $B7,$00,$86                                     ; $EF12 unconfirmed: STAA.w $0086
        dc.b $BD,$F6,$86                                     ; $EF15 unconfirmed: JSR $f686
        dc.b $38                                             ; $EF18 unconfirmed: PULX
        dc.b $39                                             ; $EF19 unconfirmed: RTS
INCREMENT_BCD_SELF_TEST_NUMBER:
        PSHA                         ; $EF1A: $36
; Solenoid test: increment the BCD display counter, proving the first table selector is test 01 and each following byte is the next test number.
        LDAA.w $008e                 ; $EF1B: $B6,$00,$8E
        ADDA #$1                     ; $EF1E: $8B,$01
        DAA                          ; $EF20: $19
        STAA.w $008e                 ; $EF21: $B7,$00,$8E
        PULA                         ; $EF24: $32
        RTS                          ; $EF25: $39
        dc.b $CE,$EE,$A8,$FF,$10,$17,$FE,$C0,$83,$BD,$C0,$8D,$BD,$EB,$A3,$BD ; $EF26 data/unclassified
        dc.b $EB,$B1,$BD,$EA,$19,$BD,$EA,$1E,$20,$E6,$BD,$F0,$59,$CE,$16,$20 ; $EF36 data/unclassified
        dc.b $8D,$6A,$BD,$F6,$26,$25,$05,$CE,$16,$20,$8D,$60,$BD,$F0,$35,$CE ; $EF46 data/unclassified
        dc.b $10,$70,$8D,$55,$BD,$F0,$59,$CE,$16,$35,$8D,$50,$BD,$F6,$26,$25 ; $EF56 data/unclassified
        dc.b $05,$CE,$16,$35,$8D,$46,$BD,$F0,$35,$CE,$10,$7E,$8D,$3B,$8D,$3F ; $EF66 data/unclassified
        dc.b $C0,$02,$27,$2D,$2B,$2B,$37,$CE,$10,$85,$8D,$30,$B6,$00,$86,$84 ; $EF76 data/unclassified
        dc.b $0F,$81,$04,$23,$10,$BD,$F0,$48,$CE,$10,$85,$8D,$1C,$CE,$10,$85 ; $EF86 data/unclassified
        dc.b $BD,$F6,$C9,$20,$08,$BD,$F0,$48,$CE,$10,$85,$8D,$0C,$33,$5A,$26 ; $EF96 data/unclassified
        dc.b $D5,$CE,$10,$85,$8D,$06,$CE,$16,$3C,$7E,$F6,$98,$7E,$F6,$38,$5F ; $EFA6 data/unclassified
        dc.b $37,$BD,$F0,$64,$CE,$10,$70,$8D,$F3,$CE,$00,$86,$86,$99,$A0,$00 ; $EFB6 data/unclassified
        dc.b $A7,$00,$09,$8C,$00,$82,$26,$F4,$CE,$10,$70,$8D,$DC,$CE,$10,$7E ; $EFC6 data/unclassified
        dc.b $8D,$DA,$BD,$F9,$D2,$27,$56,$CE,$10,$70,$8D,$D0,$CE,$10,$77,$8D ; $EFD6 data/unclassified
        dc.b $C8,$BD,$F6,$68,$CE,$10,$7E,$8D,$C3,$BD,$F6,$14,$B6,$00,$83,$84 ; $EFE6 data/unclassified
        dc.b $F0,$26,$0D,$CE,$10,$70,$8D,$B1,$CE,$10         ; $EFF6 data/unclassified
