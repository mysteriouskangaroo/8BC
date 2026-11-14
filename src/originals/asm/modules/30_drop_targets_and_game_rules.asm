; Drop targets and later game rules
; Address range: $CDD8-$DFFF
; Pool-ball first-sink/5,000 handlers and the remaining high-level rule code before the interrupt region.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

HANDLE_PAIRED_POOL_BALL_DROP_TARGET:
; Paired pool-ball drop-target handler for switches 25 (balls 1/2) and 28 (balls 4/5). Ignore a closure already latched in 10C5. Otherwise latch it, award 500 and record the first unsunk ball bit in 10C3; only after both bits in the pair are set does a later rearmed hit take the 5,000-point branch at D034.
        LDAB #$24                    ; $CDD8: $C6,$24
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE ; $CDDA: $BD,$CA,$AA
        BITA DROP_TARGET_SWITCH_CLOSURE_LATCHES ; $CDDD: $B5,$10,$C5
; Drop target: test whether this physical switch group is already latched closed in 10C5; the following branch rejects a repeat.
        BNE $cdcd                    ; $CDE0: $26,$EB
        PSHA                         ; $CDE2: $36
        ORAA DROP_TARGET_SWITCH_CLOSURE_LATCHES ; $CDE3: $BA,$10,$C5
        STAA DROP_TARGET_SWITCH_CLOSURE_LATCHES ; $CDE6: $B7,$10,$C5
; Drop target: store this group's new physical-closure latch in 10C5.
        PULA                         ; $CDE9: $32
        BITA SUNK_POOL_BALLS_1_TO_7  ; $CDEA: $B5,$10,$C3
        BEQ AWARD_FIRST_SINK_AND_RECORD_POOL_BALL ; $CDED: $27,$18
        ASLA                         ; $CDEF: $48
        BITA SUNK_POOL_BALLS_1_TO_7  ; $CDF0: $B5,$10,$C3
        BEQ AWARD_FIRST_SINK_AND_RECORD_POOL_BALL ; $CDF3: $27,$12
        LDAB #$1                     ; $CDF5: $C6,$01
        LSRA                         ; $CDF7: $44
        LSRA                         ; $CDF8: $44
        BCS $cdfd                    ; $CDF9: $25,$02
        LDAB #$4                     ; $CDFB: $C6,$04
        COMB                         ; $CDFD: $53
        ANDB DROP_TARGET_5000_LAMP_FLASH_MASK ; $CDFE: $F4,$10,$BF
        STAB DROP_TARGET_5000_LAMP_FLASH_MASK ; $CE01: $F7,$10,$BF
        JMP AWARD_LIT_DROP_TARGET_5000 ; $CE04: $7E,$D0,$34
AWARD_FIRST_SINK_AND_RECORD_POOL_BALL:
; First-sink path. C9C4 awards 500 points through the active playfield double/triple multiplier, then this code ORs the selected ball bit into SUNK_POOL_BALLS_1_TO_7 at 10C3 and starts its ball/lamp effects.
        PSHA                         ; $CE07: $36
        JSR AWARD_500_POINTS_WITH_PLAYFIELD_MULTIPLIER ; $CE08: $BD,$C9,$C4
; Drop target: award the first-sink base value of 500 points; the shared helper applies playfield double/triple.
        PULA                         ; $CE0B: $32
        PSHA                         ; $CE0C: $36
        ORAA SUNK_POOL_BALLS_1_TO_7  ; $CE0D: $BA,$10,$C3
; Drop target: preserve this ball as sunk in the seven-bit state at 10C3.
        STAA SUNK_POOL_BALLS_1_TO_7  ; $CE10: $B7,$10,$C3
        LDAA PENDING_SOUND_COMMAND   ; $CE13: $B6,$10,$24
        DECA                         ; $CE16: $4A
        PULB                         ; $CE17: $33
        PSHB                         ; $CE18: $37
        PSHA                         ; $CE19: $36
        LDAA #$50                    ; $CE1A: $86,$50
        INCA                         ; $CE1C: $4C
        LSRB                         ; $CE1D: $54
        BNE $ce1c                    ; $CE1E: $26,$FC
        LDAB.w $008f                 ; $CE20: $F6,$00,$8F
        LSRB                         ; $CE23: $54
        BCS $ce28                    ; $CE24: $25,$02
        ADDA #$8                     ; $CE26: $8B,$08
        CMPA $10c4                   ; $CE28: $B1,$10,$C4
        BNE $ce2f                    ; $CE2B: $26,$02
        LDAA #$66                    ; $CE2D: $86,$66
        JSR $c27e                    ; $CE2F: $BD,$C2,$7E
        LDX #$0                      ; $CE32: $CE,$00,$00
        STX $10b3                    ; $CE35: $FF,$10,$B3
        LDX #$12c                    ; $CE38: $CE,$01,$2C
        STX $10b5                    ; $CE3B: $FF,$10,$B5
        PULA                         ; $CE3E: $32
        JSR $c27e                    ; $CE3F: $BD,$C2,$7E
        PULA                         ; $CE42: $32
        STAA $10ba                   ; $CE43: $B7,$10,$BA
        JSR $c6a7                    ; $CE46: $BD,$C6,$A7
        LDAA SUNK_POOL_BALLS_1_TO_7  ; $CE49: $B6,$10,$C3
        ORAA #$80                    ; $CE4C: $8A,$80
        COMA                         ; $CE4E: $43
        BEQ $ce6c                    ; $CE4F: $27,$1B
        LDAA #$c                     ; $CE51: $86,$0C
        LDAB #$6                     ; $CE53: $C6,$06
        JSR $f5b9                    ; $CE55: $BD,$F5,$B9
        LDAB $10ba                   ; $CE58: $F6,$10,$BA
        EORB $0,X                    ; $CE5B: $E8,$00
        STAB $0,X                    ; $CE5D: $E7,$00
        LDAB $10ba                   ; $CE5F: $F6,$10,$BA
        EORB $2,X                    ; $CE62: $E8,$02
        STAB $2,X                    ; $CE64: $E7,$02
        DECA                         ; $CE66: $4A
        BNE $ce53                    ; $CE67: $26,$EA
        JMP $d03c                    ; $CE69: $7E,$D0,$3C
        LDX #$d363                   ; $CE6C: $CE,$D3,$63
        STX $10b9                    ; $CE6F: $FF,$10,$B9
        JSR $c84b                    ; $CE72: $BD,$C8,$4B
        CPX #$103b                   ; $CE75: $8C,$10,$3B
        BEQ $ce80                    ; $CE78: $27,$06
        LDX #$d383                   ; $CE7A: $CE,$D3,$83
        STX $10b9                    ; $CE7D: $FF,$10,$B9
        LDX $10b9                    ; $CE80: $FE,$10,$B9
        STX $10ad                    ; $CE83: $FF,$10,$AD
        CLRA                         ; $CE86: $4F
        STAA $10af                   ; $CE87: $B7,$10,$AF
        LDAA #$8                     ; $CE8A: $86,$08
        STAA $10b0                   ; $CE8C: $B7,$10,$B0
        JSR $d1f8                    ; $CE8F: $BD,$D1,$F8
        LDAB #$a                     ; $CE92: $C6,$0A
        JSR $c919                    ; $CE94: $BD,$C9,$19
        LDX $10ad                    ; $CE97: $FE,$10,$AD
        JSR $d244                    ; $CE9A: $BD,$D2,$44
        LDAB #$a                     ; $CE9D: $C6,$0A
        JSR $c919                    ; $CE9F: $BD,$C9,$19
        LDX #$d37d                   ; $CEA2: $CE,$D3,$7D
        STX $10b9                    ; $CEA5: $FF,$10,$B9
        JSR $c84b                    ; $CEA8: $BD,$C8,$4B
        CPX #$103b                   ; $CEAB: $8C,$10,$3B
        BEQ $ceb6                    ; $CEAE: $27,$06
        LDX #$d39d                   ; $CEB0: $CE,$D3,$9D
        STX $10b9                    ; $CEB3: $FF,$10,$B9
        LDX $10b9                    ; $CEB6: $FE,$10,$B9
        STX $10ad                    ; $CEB9: $FF,$10,$AD
        LDAA #$2                     ; $CEBC: $86,$02
        STAA $10af                   ; $CEBE: $B7,$10,$AF
        JSR $d24b                    ; $CEC1: $BD,$D2,$4B
        LDAB #$a                     ; $CEC4: $C6,$0A
        JSR $c919                    ; $CEC6: $BD,$C9,$19
        JSR $d21f                    ; $CEC9: $BD,$D2,$1F
        LDAA #$80                    ; $CECC: $86,$80
        STAA $10bd                   ; $CECE: $B7,$10,$BD
        LDAA $10c6                   ; $CED1: $B6,$10,$C6
        ANDA #$fe                    ; $CED4: $84,$FE
        STAA $10c6                   ; $CED6: $B7,$10,$C6
        JMP $d03c                    ; $CED9: $7E,$D0,$3C
        dc.b $86,$66,$BD,$C2,$7E,$86,$33,$BD,$C2,$7E,$86,$02,$B7,$10,$B0,$4F ; $CEDC data/unclassified
        dc.b $B7,$10,$AF,$CE,$D2,$A3,$FF,$10,$AD,$BD,$D1,$F8,$C6,$0A,$BD,$C9 ; $CEEC data/unclassified
        dc.b $19,$FE,$10,$AD,$BD,$D2,$44,$86,$33,$BD,$C2,$7E,$C6,$0A,$BD,$C9 ; $CEFC data/unclassified
        dc.b $19,$CE,$D3,$13,$FF,$10,$AD,$86,$02,$B7,$10,$AF,$BD,$D2,$4B,$86 ; $CF0C data/unclassified
        dc.b $33,$BD,$C2,$7E,$C6,$0A,$BD,$C9,$19,$86,$00,$B7,$10,$AF,$CE,$D2 ; $CF1C data/unclassified
        dc.b $A3,$FF,$10,$AD,$BD,$D2,$44,$86,$33,$BD,$C2,$7E,$C6,$0A,$BD,$C9 ; $CF2C data/unclassified
        dc.b $19,$86,$02,$B7,$10,$AF,$CE,$D3,$13,$FF,$10,$AD,$BD,$D2,$4B,$86 ; $CF3C data/unclassified
        dc.b $33,$BD,$C2,$7E,$C6,$0A,$BD,$C9,$19,$86,$00,$B7,$10,$AF,$CE,$D2 ; $CF4C data/unclassified
        dc.b $A3,$FF,$10,$AD,$BD,$D2,$44,$C6,$0A,$BD,$C9,$19,$BD,$D2,$1F,$5F ; $CF5C data/unclassified
        dc.b $F7,$10,$BF,$53,$F7,$10,$3F,$CE,$FF,$FF,$FF,$10,$3D,$C6,$0E,$37 ; $CF6C data/unclassified
        dc.b $86,$71,$BD,$F5,$6B,$86,$73,$BD,$F5,$91,$86,$33,$BD,$C2,$7E,$33 ; $CF7C data/unclassified
        dc.b $37,$58,$BD,$C9,$19,$86,$71,$BD,$F5,$91,$86,$73,$BD,$F5,$6B,$33 ; $CF8C data/unclassified
        dc.b $37,$58,$BD,$C9,$19,$33,$5A,$26,$D6,$86,$73,$BD,$F5,$91,$4F,$B7 ; $CF9C data/unclassified
        dc.b $10,$C3,$BD,$C6,$B8,$BD,$C6,$A7,$B6,$10,$44,$2B,$20,$F6,$16,$8C ; $CFAC data/unclassified
        dc.b $C5,$20,$26,$10,$B6,$10,$44,$8A,$80,$B7,$10,$44,$B6,$10,$A0,$8A ; $CFBC data/unclassified
        dc.b $10,$B7,$10,$A0,$CE,$16,$B8,$BD,$F6,$C9,$BD,$C1,$DB,$B6,$10,$44 ; $CFCC data/unclassified
        dc.b $85,$40,$26,$04,$84,$DF,$20,$0C,$85,$20,$26,$06,$8A,$20,$84,$BF ; $CFDC data/unclassified
        dc.b $20,$02,$84,$DF,$B7,$10,$44,$B6,$10,$44,$2A,$0C,$F6,$10,$A0,$C5 ; $CFEC data/unclassified
        dc.b $10,$26,$05,$84,$7F,$B7,$10,$44                 ; $CFFC data/unclassified
        RTS                          ; $D004: $39
HANDLE_SINGLE_POOL_BALL_DROP_TARGET:
; Single pool-ball drop-target handler for switches 27, 30, and 31 (balls 3, 6, and 7). Ignore a closure already latched in 10C5. Otherwise award 500 and set its 10C3 sunk bit on the first hit, or take the 5,000-point branch at D034 when already sunk.
        LDAB #$24                    ; $D005: $C6,$24
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE ; $D007: $BD,$CA,$AA
        BITA DROP_TARGET_SWITCH_CLOSURE_LATCHES ; $D00A: $B5,$10,$C5
; Drop target: test whether this physical switch group is already latched closed in 10C5; the following branch rejects a repeat.
        BNE $d004                    ; $D00D: $26,$F5
        PSHA                         ; $D00F: $36
; Drop target: preserve the target mask before setting its physical-closure latch in 10C5.
        ORAA DROP_TARGET_SWITCH_CLOSURE_LATCHES ; $D010: $BA,$10,$C5
        STAA DROP_TARGET_SWITCH_CLOSURE_LATCHES ; $D013: $B7,$10,$C5
        PULA                         ; $D016: $32
        BITA SUNK_POOL_BALLS_1_TO_7  ; $D017: $B5,$10,$C3
        BNE $d01f                    ; $D01A: $26,$03
        JMP AWARD_FIRST_SINK_AND_RECORD_POOL_BALL ; $D01C: $7E,$CE,$07
        LDAB #$2                     ; $D01F: $C6,$02
        BITA #$4                     ; $D021: $85,$04
        BNE $d02d                    ; $D023: $26,$08
        LDAB #$8                     ; $D025: $C6,$08
        BITA #$20                    ; $D027: $85,$20
        BNE $d02d                    ; $D029: $26,$02
        LDAB #$10                    ; $D02B: $C6,$10
        COMB                         ; $D02D: $53
        ANDB DROP_TARGET_5000_LAMP_FLASH_MASK ; $D02E: $F4,$10,$BF
        STAB DROP_TARGET_5000_LAMP_FLASH_MASK ; $D031: $F7,$10,$BF
AWARD_LIT_DROP_TARGET_5000:
; Already-sunk drop-target path. C9EF awards 5,000 points through the active playfield double/triple multiplier and updates the five drop-target 5,000 lamp effect.
        LDAB #$ff                    ; $D034: $C6,$FF
        STAB DROP_TARGET_5000_LAMP_SHADOW ; $D036: $F7,$10,$3F
; Drop target: set the shared 5,000 drop-target lamp shadow at 103F to FF.
        JSR AWARD_5000_POINTS_WITH_PLAYFIELD_MULTIPLIER ; $D039: $BD,$C9,$EF
; Drop target: award the already-sunk value of 5,000 points; the shared helper applies playfield double/triple.
        LDAB #$1e                    ; $D03C: $C6,$1E
        JSR $c919                    ; $D03E: $BD,$C9,$19
        LDAB SWITCH_EVENTS_STROBE4   ; $D041: $F6,$10,$2A
        ANDB #$e0                    ; $D044: $C4,$E0
        STAB SWITCH_EVENTS_STROBE4   ; $D046: $F7,$10,$2A
        RTS                          ; $D049: $39
        dc.b $BD,$F4,$DF,$26,$65,$86,$32,$BD,$C2,$7E,$B6,$10,$BD,$85,$80,$27 ; $D04A data/unclassified
        dc.b $0E,$7F,$10,$BD,$B6,$10,$3B,$8A,$80,$B7,$10,$3B,$BD,$CE,$DC,$B6 ; $D05A data/unclassified
        dc.b $10,$C1,$85,$08,$27,$0A,$BD,$C9,$6C,$86,$36,$BD,$C2,$7E,$20,$3A ; $D06A data/unclassified
        dc.b $36,$BD,$C9,$C4,$32,$16,$C4,$80,$F7,$10,$C1,$48,$BA,$10,$C1,$B7 ; $D07A data/unclassified
        dc.b $10,$C1,$C6,$FF,$F7,$10,$43,$48,$48,$48,$43,$B7,$10,$43,$F6,$10 ; $D08A data/unclassified
        dc.b $C1,$58,$58,$58,$58,$CE,$01,$68,$FF,$10,$B3,$86,$7E,$4A,$58,$24 ; $D09A data/unclassified
        dc.b $FC,$BD,$C2,$7E,$CE,$02,$58,$FF,$10,$B3,$C6,$3C,$BD,$C9,$19,$86 ; $D0AA data/unclassified
        dc.b $07,$C6,$06,$BD,$F5,$C2,$B6,$10,$26,$84,$EF,$B7,$10,$26 ; $D0BA data/unclassified
        dc.b $39                                             ; $D0C8 unconfirmed: RTS
        dc.b $7F,$10,$C6,$7F,$10,$AF,$CE,$03,$B6,$FF,$10,$B3 ; $D0C9 data/unclassified
        dc.b $BD,$F8,$29                                     ; $D0D5 unconfirmed: JSR $f829
        dc.b $73,$10,$C6                                     ; $D0D8 unconfirmed: COM $10c6
        dc.b $86,$0F                                         ; $D0DB unconfirmed: LDAA #$f
        dc.b $B7,$10,$B9                                     ; $D0DD unconfirmed: STAA $10b9
        dc.b $BD,$F7,$17                                     ; $D0E0 unconfirmed: JSR $f717
        dc.b $86,$15                                         ; $D0E3 unconfirmed: LDAA #$15
        dc.b $7E,$C2,$8D                                     ; $D0E5 unconfirmed: JMP $c28d
        dc.b $B6,$10,$0E                                     ; $D0E8 unconfirmed: LDAA $100e
        dc.b $26,$DB                                         ; $D0EB unconfirmed: BNE $d0c8
        dc.b $86,$19                                         ; $D0ED unconfirmed: LDAA #$19
        dc.b $B7,$10,$0E                                     ; $D0EF unconfirmed: STAA $100e
        dc.b $B6,$10,$B9                                     ; $D0F2 unconfirmed: LDAA $10b9
        dc.b $4C                                             ; $D0F5 unconfirmed: INCA
        dc.b $81,$11                                         ; $D0F6 unconfirmed: CMPA #$11
        dc.b $25,$3F                                         ; $D0F8 unconfirmed: BCS $d139
        dc.b $86,$02                                         ; $D0FA unconfirmed: LDAA #$2
        dc.b $B7,$10,$B0                                     ; $D0FC unconfirmed: STAA $10b0
        dc.b $B6,$10,$AF                                     ; $D0FF unconfirmed: LDAA $10af
        dc.b $88,$02                                         ; $D102 unconfirmed: EORA #$2
        dc.b $B7,$10,$AF                                     ; $D104 unconfirmed: STAA $10af
        dc.b $CE,$D2,$A3                                     ; $D107 unconfirmed: LDX #$d2a3
        dc.b $85,$02                                         ; $D10A unconfirmed: BITA #$2
        dc.b $27,$03                                         ; $D10C unconfirmed: BEQ $d111
        dc.b $CE,$D3,$13                                     ; $D10E unconfirmed: LDX #$d313
        dc.b $FF,$10,$AD                                     ; $D111 unconfirmed: STX $10ad
        dc.b $BD,$D1,$F8                                     ; $D114 unconfirmed: JSR $d1f8
        dc.b $C6,$0F                                         ; $D117 unconfirmed: LDAB #$f
        dc.b $BD,$C9,$19                                     ; $D119 unconfirmed: JSR $c919
        dc.b $FE,$10,$AD                                     ; $D11C unconfirmed: LDX $10ad
        dc.b $BD,$D2,$44                                     ; $D11F unconfirmed: JSR $d244
        dc.b $C6,$05                                         ; $D122 unconfirmed: LDAB #$5
        dc.b $BD,$C9,$19                                     ; $D124 unconfirmed: JSR $c919
        dc.b $FE,$10,$AD                                     ; $D127 unconfirmed: LDX $10ad
        dc.b $BD,$D2,$4B                                     ; $D12A unconfirmed: JSR $d24b
        dc.b $C6,$0F                                         ; $D12D unconfirmed: LDAB #$f
        dc.b $BD,$C9,$19                                     ; $D12F unconfirmed: JSR $c919
        dc.b $BD,$D2,$1F                                     ; $D132 unconfirmed: JSR $d21f
        dc.b $7F,$10,$B9                                     ; $D135 unconfirmed: CLR $10b9
        dc.b $39                                             ; $D138 unconfirmed: RTS
        dc.b $B7,$10,$B9                                     ; $D139 unconfirmed: STAA $10b9
        dc.b $CE,$D1,$70                                     ; $D13C unconfirmed: LDX #$d170
        dc.b $BD,$F8,$21                                     ; $D13F unconfirmed: JSR $f821
        dc.b $08                                             ; $D142 unconfirmed: INX
        dc.b $4A                                             ; $D143 unconfirmed: DECA
        dc.b $26,$F9                                         ; $D144 unconfirmed: BNE $d13f
        dc.b $A6,$00                                         ; $D146 unconfirmed: LDAA $0,X
        dc.b $B7,$10,$3D                                     ; $D148 unconfirmed: STAA $103d
        dc.b $43                                             ; $D14B unconfirmed: COMA
        dc.b $B7,$10,$3B                                     ; $D14C unconfirmed: STAA $103b
        dc.b $A6,$01                                         ; $D14F unconfirmed: LDAA $1,X
        dc.b $B7,$10,$3E                                     ; $D151 unconfirmed: STAA $103e
        dc.b $43                                             ; $D154 unconfirmed: COMA
        dc.b $B7,$10,$3C                                     ; $D155 unconfirmed: STAA $103c
        dc.b $A6,$02                                         ; $D158 unconfirmed: LDAA $2,X
        dc.b $B7,$10,$3F                                     ; $D15A unconfirmed: STAA DROP_TARGET_5000_LAMP_SHADOW
        dc.b $A6,$03                                         ; $D15D unconfirmed: LDAA $3,X
        dc.b $43                                             ; $D15F unconfirmed: COMA
        dc.b $B7,$10,$40                                     ; $D160 unconfirmed: STAA CHAMP_LANE_STATE
        dc.b $A6,$04                                         ; $D163 unconfirmed: LDAA $4,X
        dc.b $B7,$10,$41                                     ; $D165 unconfirmed: STAA CHAMP_MULTIPLIER_LAMP_SHADOW
        dc.b $A6,$05                                         ; $D168 unconfirmed: LDAA $5,X
        dc.b $B7,$10,$43                                     ; $D16A unconfirmed: STAA $1043
        dc.b $A6,$06                                         ; $D16D unconfirmed: LDAA $6,X
        dc.b $B7,$10,$44                                     ; $D16F unconfirmed: STAA $1044
        dc.b $A6,$07                                         ; $D172 unconfirmed: LDAA $7,X
        dc.b $B7,$10,$45                                     ; $D174 unconfirmed: STAA $1045
        dc.b $39                                             ; $D177 unconfirmed: RTS
        dc.b $FE,$FF,$00,$21,$00,$6E,$FE,$FF,$FC,$7F,$FF,$42,$FF,$DD,$FD,$00 ; $D178 data/unclassified
        dc.b $F8,$FF,$00,$84,$00,$3B,$FB,$FF,$F0,$7F,$FF,$48,$FF,$F7,$B7,$00 ; $D188 data/unclassified
        dc.b $E0,$FF,$00,$30,$00,$7B,$6F,$FF,$C0,$7F,$FF,$41,$FF,$FD,$DE,$00 ; $D198 data/unclassified
        dc.b $80,$FF,$00,$82,$00,$6E,$FD,$FF,$00,$7F,$FF,$44,$FF,$DD,$FB,$00 ; $D1A8 data/unclassified
        dc.b $00,$FE,$00,$28,$00,$3B,$F7,$FF,$00,$7C,$FF,$50,$FF,$F7,$AF,$00 ; $D1B8 data/unclassified
        dc.b $00,$F8,$00,$81,$00,$7B,$7E,$FF,$00,$70,$FF,$42,$FF,$FD,$DD,$00 ; $D1C8 data/unclassified
        dc.b $00,$E0,$00,$24,$00,$0E,$FB,$FF,$00,$40,$FF,$48,$FF,$8D,$F7,$00 ; $D1D8 data/unclassified
        dc.b $00,$80,$00,$90,$FF,$0B,$EF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D1E8 data/unclassified
        dc.b $B6,$10,$A0                                     ; $D1F8 unconfirmed: LDAA $10a0
        dc.b $84,$7F                                         ; $D1FB unconfirmed: ANDA #$7f
        dc.b $B7,$10,$A0                                     ; $D1FD unconfirmed: STAA $10a0
        dc.b $CE,$10,$A0                                     ; $D200 unconfirmed: LDX #$10a0
        dc.b $FF,$10,$B9                                     ; $D203 unconfirmed: STX $10b9
        dc.b $CE,$10,$3A                                     ; $D206 unconfirmed: LDX #$103a
        dc.b $3C                                             ; $D209 unconfirmed: PSHX
        dc.b $A6,$00                                         ; $D20A unconfirmed: LDAA $0,X
        dc.b $FE,$10,$B9                                     ; $D20C unconfirmed: LDX $10b9
        dc.b $08                                             ; $D20F unconfirmed: INX
        dc.b $FF,$10,$B9                                     ; $D210 unconfirmed: STX $10b9
        dc.b $A7,$00                                         ; $D213 unconfirmed: STAA $0,X
        dc.b $38                                             ; $D215 unconfirmed: PULX
        dc.b $08                                             ; $D216 unconfirmed: INX
        dc.b $8C,$10,$46                                     ; $D217 unconfirmed: CPX #$1046
        dc.b $26,$ED                                         ; $D21A unconfirmed: BNE $d209
        dc.b $7E,$C5,$7E                                     ; $D21C unconfirmed: JMP $c57e
        dc.b $CE,$10,$39                                     ; $D21F unconfirmed: LDX #$1039
        dc.b $FF,$10,$B9                                     ; $D222 unconfirmed: STX $10b9
        dc.b $CE,$10,$A1                                     ; $D225 unconfirmed: LDX #$10a1
        dc.b $3C                                             ; $D228 unconfirmed: PSHX
        dc.b $A6,$00                                         ; $D229 unconfirmed: LDAA $0,X
        dc.b $FE,$10,$B9                                     ; $D22B unconfirmed: LDX $10b9
        dc.b $08                                             ; $D22E unconfirmed: INX
        dc.b $FF,$10,$B9                                     ; $D22F unconfirmed: STX $10b9
        dc.b $A7,$00                                         ; $D232 unconfirmed: STAA $0,X
        dc.b $38                                             ; $D234 unconfirmed: PULX
        dc.b $08                                             ; $D235 unconfirmed: INX
        dc.b $8C,$10,$AD                                     ; $D236 unconfirmed: CPX #$10ad
        dc.b $26,$ED                                         ; $D239 unconfirmed: BNE $d228
        dc.b $B6,$10,$A0                                     ; $D23B unconfirmed: LDAA $10a0
        dc.b $8A,$80                                         ; $D23E unconfirmed: ORAA #$80
        dc.b $B7,$10,$A0                                     ; $D240 unconfirmed: STAA $10a0
        dc.b $39                                             ; $D243 unconfirmed: RTS
        dc.b $B6,$10,$AF                                     ; $D244 unconfirmed: LDAA $10af
        dc.b $84,$FE                                         ; $D247 unconfirmed: ANDA #$fe
        dc.b $20,$05                                         ; $D249 unconfirmed: BRA $d250
        dc.b $B6,$10,$AF                                     ; $D24B unconfirmed: LDAA $10af
        dc.b $8A,$01                                         ; $D24E unconfirmed: ORAA #$1
        dc.b $B7,$10,$AF                                     ; $D250 unconfirmed: STAA $10af
        dc.b $A6,$01                                         ; $D253 unconfirmed: LDAA $1,X
        dc.b $81,$0C                                         ; $D255 unconfirmed: CMPA #$c
        dc.b $24,$EA                                         ; $D257 unconfirmed: BCC $d243
        dc.b $EC,$00                                         ; $D259 unconfirmed: LDD $0,X
        dc.b $1B                                             ; $D25B unconfirmed: ABA
        dc.b $26,$15                                         ; $D25C unconfirmed: BNE $d273
        dc.b $F6,$10,$B0                                     ; $D25E unconfirmed: LDAB $10b0
        dc.b $BD,$C9,$19                                     ; $D261 unconfirmed: JSR $c919
        dc.b $B6,$10,$AF                                     ; $D264 unconfirmed: LDAA $10af
        dc.b $85,$02                                         ; $D267 unconfirmed: BITA #$2
        dc.b $27,$04                                         ; $D269 unconfirmed: BEQ $d26f
        dc.b $09                                             ; $D26B unconfirmed: DEX
        dc.b $09                                             ; $D26C unconfirmed: DEX
        dc.b $20,$E4                                         ; $D26D unconfirmed: BRA $d253
        dc.b $08                                             ; $D26F unconfirmed: INX
        dc.b $08                                             ; $D270 unconfirmed: INX
        dc.b $20,$E0                                         ; $D271 unconfirmed: BRA $d253
        dc.b $3C                                             ; $D273 unconfirmed: PSHX
        dc.b $EC,$00                                         ; $D274 unconfirmed: LDD $0,X
        dc.b $CE,$10,$3A                                     ; $D276 unconfirmed: LDX #$103a
        dc.b $3A                                             ; $D279 unconfirmed: ABX
        dc.b $F6,$10,$AF                                     ; $D27A unconfirmed: LDAB $10af
        dc.b $C5,$01                                         ; $D27D unconfirmed: BITB #$1
        dc.b $26,$05                                         ; $D27F unconfirmed: BNE $d286
        dc.b $43                                             ; $D281 unconfirmed: COMA
        dc.b $A4,$00                                         ; $D282 unconfirmed: ANDA $0,X
        dc.b $20,$02                                         ; $D284 unconfirmed: BRA $d288
        dc.b $AA,$00                                         ; $D286 unconfirmed: ORAA $0,X
        dc.b $A7,$00                                         ; $D288 unconfirmed: STAA $0,X
        dc.b $CE,$16,$27                                     ; $D28A unconfirmed: LDX #$1627
        dc.b $BD,$F6,$38                                     ; $D28D unconfirmed: JSR $f638
        dc.b $B6,$00,$86                                     ; $D290 unconfirmed: LDAA.w $0086
        dc.b $27,$09                                         ; $D293 unconfirmed: BEQ $d29e
        dc.b $B6,$10,$26                                     ; $D295 unconfirmed: LDAA SWITCH_EVENTS_STROBE0
        dc.b $85,$20                                         ; $D298 unconfirmed: BITA #$20
        dc.b $27,$02                                         ; $D29A unconfirmed: BEQ $d29e
        dc.b $38                                             ; $D29C unconfirmed: PULX
        dc.b $39                                             ; $D29D unconfirmed: RTS
        dc.b $38                                             ; $D29E unconfirmed: PULX
        dc.b $20,$C3                                         ; $D29F unconfirmed: BRA $d264
        dc.b $FF,$FF,$20,$09,$00,$00,$50,$09,$00,$00,$60,$0A,$00,$00,$80,$0A ; $D2A1 data/unclassified
        dc.b $00,$00,$30,$07,$00,$00,$80,$03,$11,$06,$C0,$07,$00,$00,$7F,$04 ; $D2B1 data/unclassified
        dc.b $00,$00,$7F,$03,$00,$00,$18,$05,$00,$00,$60,$01,$20,$02,$80,$04 ; $D2C1 data/unclassified
        dc.b $80,$09,$00,$00,$40,$02,$0F,$07,$00,$00,$FF,$0B,$00,$00,$11,$01 ; $D2D1 data/unclassified
        dc.b $09,$02,$00,$00,$0E,$01,$16,$02,$00,$00,$07,$05,$00,$00,$20,$06 ; $D2E1 data/unclassified
        dc.b $01,$0A,$00,$00,$40,$06,$00,$00,$02,$0A,$00,$00,$80,$06,$00,$00 ; $D2F1 data/unclassified
        dc.b $04,$0A,$00,$00,$08,$0A,$00,$00,$10,$0A,$00,$00,$0E,$06,$00,$00 ; $D301 data/unclassified
        dc.b $80,$01,$0F,$09,$FF,$FF,$FF,$FF,$2F,$09,$80,$01,$00,$00,$0E,$06 ; $D311 data/unclassified
        dc.b $50,$09,$00,$00,$F0,$0A,$00,$00,$08,$0A,$30,$07,$00,$00,$30,$07 ; $D321 data/unclassified
        dc.b $04,$0A,$00,$00,$80,$03,$11,$06,$C0,$07,$04,$0A,$00,$00,$7F,$04 ; $D331 data/unclassified
        dc.b $80,$06,$02,$0A,$00,$00,$7F,$03,$60,$06,$01,$0A,$00,$00,$0C,$01 ; $D341 data/unclassified
        dc.b $16,$02,$80,$04,$1F,$05,$80,$09,$00,$00,$73,$01,$69,$02,$FF,$FF ; $D351 data/unclassified
        dc.b $FF,$FF,$01,$03,$00,$00,$02,$03,$00,$00,$04,$03,$00,$00,$08,$03 ; $D361 data/unclassified
        dc.b $00,$00,$10,$03,$00,$00,$20,$03,$00,$00,$40,$03,$00,$00,$FF,$FF ; $D371 data/unclassified
        dc.b $FF,$FF,$01,$04,$00,$00,$02,$04,$00,$00,$04,$04,$00,$00,$08,$04 ; $D381 data/unclassified
        dc.b $00,$00,$10,$04,$00,$00,$20,$04,$00,$00,$40,$04,$00,$00,$FF,$FF ; $D391 data/unclassified
        dc.b $86,$19,$BD,$C2,$7E,$86,$0E,$C6,$0A,$BD,$F5,$C2,$C6,$0C,$7E,$C9 ; $D3A1 data/unclassified
        dc.b $19,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D3B1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D3C1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D3D1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D3E1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D3F1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D401 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D411 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D421 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D431 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D441 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D451 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D461 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D471 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D481 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D491 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D4A1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D4B1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D4C1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D4D1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D4E1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D4F1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D501 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D511 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D521 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D531 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D541 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D551 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D561 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D571 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D581 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D591 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D5A1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D5B1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D5C1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D5D1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D5E1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D5F1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D601 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D611 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D621 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D631 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D641 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D651 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D661 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D671 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D681 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D691 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D6A1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D6B1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D6C1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D6D1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D6E1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D6F1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D701 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D711 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D721 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D731 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D741 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D751 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D761 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D771 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D781 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D791 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D7A1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D7B1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D7C1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D7D1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D7E1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D7F1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D801 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D811 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D821 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D831 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D841 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D851 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D861 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D871 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D881 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D891 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D8A1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D8B1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D8C1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D8D1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D8E1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D8F1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D901 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D911 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D921 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D931 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D941 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D951 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D961 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D971 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D981 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D991 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D9A1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D9B1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D9C1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D9D1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D9E1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $D9F1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA01 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA11 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA21 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA31 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA41 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA51 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA61 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA71 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA81 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DA91 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DAA1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DAB1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DAC1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DAD1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DAE1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DAF1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB01 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB11 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB21 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB31 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB41 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB51 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB61 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB71 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB81 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DB91 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DBA1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DBB1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DBC1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DBD1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DBE1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DBF1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC01 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC11 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC21 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC31 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC41 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC51 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC61 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC71 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC81 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DC91 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DCA1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DCB1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DCC1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DCD1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DCE1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DCF1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD01 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD11 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD21 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD31 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD41 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD51 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD61 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD71 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD81 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DD91 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DDA1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DDB1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DDC1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DDD1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DDE1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DDF1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE01 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE11 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE21 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE31 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE41 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE51 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE61 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE71 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE81 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DE91 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DEA1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DEB1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DEC1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DED1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DEE1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DEF1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF01 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF11 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF21 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF31 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF41 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF51 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF61 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF71 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF81 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DF91 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DFA1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DFB1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DFC1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DFD1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DFE1 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $DFF1 data/unclassified
