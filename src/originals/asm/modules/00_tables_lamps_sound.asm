; Low-ROM tables, lamp effects, and sound transport
; Address range: $C000-$C497
; Dispatch tables and early shared routines, including periodic lamp effects and controller-to-sound-board output.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

        dc.b $88,$42,$33,$38,$2D,$38,$30,$33,$2D,$30,$35,$20,$55,$33,$40,$00 ; $C000 data/unclassified
        dc.b $00                                             ; $C010 data/unclassified
PLAYFIELD_SWITCH_HANDLER_TABLE:
        dc.b $F8,$A8                                         ; $C011 data/unclassified
SWITCH_07_REBOUND_HANDLER_ENTRY:
        dc.b $CA,$95,$F8,$54,$D0,$4A,$CA,$72,$CA,$72,$CA,$9C,$CA,$9C,$C2,$7D ; $C013 data/unclassified
        dc.b $C9,$57,$C9,$4C,$CB,$4F,$CB,$53,$F0,$6D,$F0,$79,$F0,$85,$CC,$4C ; $C023 data/unclassified
        dc.b $CC,$48,$C2,$7D,$CA,$D4,$CA,$D4,$CA,$D4,$CA,$D4,$CA,$D4,$CA,$3B ; $C033 data/unclassified
SWITCH_31_DROP_TARGET_7_15_HANDLER_ENTRY:
        dc.b $D0,$05                                         ; $C043 data/unclassified
SWITCH_30_DROP_TARGET_6_14_HANDLER_ENTRY:
        dc.b $D0,$05,$CA,$A3                                 ; $C045 data/unclassified
SWITCH_28_DROP_TARGET_4_5_12_13_HANDLER_ENTRY:
        dc.b $CD,$D8                                         ; $C049 data/unclassified
SWITCH_27_DROP_TARGET_3_11_HANDLER_ENTRY:
        dc.b $D0,$05,$CA,$B7                                 ; $C04B data/unclassified
SWITCH_25_DROP_TARGET_1_2_9_10_HANDLER_ENTRY:
        dc.b $CD,$D8,$C2,$7D,$C2,$7D,$C2,$7D,$CC,$7C,$CC,$7C,$CC,$7C,$CC,$7C ; $C04F data/unclassified
        dc.b $CC,$7C,$C2,$7D,$C2,$7D,$C2,$7D,$C2,$7D,$C2,$7D,$C2,$7D,$C2,$7D ; $C05F data/unclassified
        dc.b $C2,$7D,$33,$04,$C1,$4E,$E3,$30,$E4,$B3,$F3,$8C,$F4,$76,$C1,$F9 ; $C06F data/unclassified
        dc.b $C3,$F0,$C2,$DD,$1D,$00,$D3,$A6,$1E,$00,$C2,$6D,$1F,$00 ; $C07F data/unclassified
        dc.b $7E,$C2,$65                                     ; $C08D unconfirmed: JMP $c265
        dc.b $F9,$8F,$1C,$00,$C4,$84,$C4,$98,$C6,$07,$C6,$15,$C4,$F6,$C6,$3D ; $C090 data/unclassified
        dc.b $D0,$C9,$F3,$27,$F3,$35,$F3,$41,$C2,$D5         ; $C0A0 data/unclassified
SOLENOID_SELF_TEST_TABLE_POINTER:
        dc.b $C0,$BA,$15,$0F,$00,$10,$00,$C0,$CA,$C0,$CA,$C0,$CA,$00,$00 ; $C0AA data/unclassified
        dc.b $39                                             ; $C0B9 unconfirmed: RTS
SOLENOID_SELF_TEST_MOMENTARY_BANK0:
        dc.b $00,$01,$02,$03,$04,$07,$08,$09,$0A,$0B,$0D,$0E ; $C0BA data/unclassified
SOLENOID_SELF_TEST_MOMENTARY_BANK0_END:
        dc.b $FF                                             ; $C0C6 data/unclassified
SOLENOID_SELF_TEST_MOMENTARY_BANK1_END:
        dc.b $FF                                             ; $C0C7 data/unclassified
SOLENOID_SELF_TEST_CONTINUOUS_OUTPUTS:
        dc.b $BF                                             ; $C0C8 data/unclassified
SOLENOID_SELF_TEST_CONTINUOUS_END:
        dc.b $FF,$20,$16,$A3,$87,$00,$21,$16,$AA,$87,$00,$22,$16,$B1,$87,$00 ; $C0C9 data/unclassified
        dc.b $23,$16,$B8,$87,$00,$24,$16,$BF,$87,$00,$25,$16,$C6,$87,$00,$26 ; $C0D9 data/unclassified
        dc.b $16,$CD,$87,$00,$27,$16,$D4,$87,$00,$28,$16,$DB,$87,$00,$29,$16 ; $C0E9 data/unclassified
        dc.b $E2,$87,$00,$2A,$16,$A1,$02,$99,$2B,$16,$8B,$00,$40,$2C,$16,$8C ; $C0F9 data/unclassified
        dc.b $00,$10,$2D,$16,$8C,$00,$20,$2E,$16,$8C,$00,$40,$2F,$16,$8C,$00 ; $C109 data/unclassified
        dc.b $80,$30,$16,$8D,$00,$10,$31,$16,$8D,$00,$20,$32,$16,$8D,$00,$40 ; $C119 data/unclassified
        dc.b $33,$16,$A0,$01,$07,$FF,$00,$00,$00,$00,$00,$08,$01,$00,$00,$00 ; $C129 data/unclassified
        dc.b $00,$00,$05,$03,$00,$00,$00,$00,$00,$00,$00,$05,$05,$05,$05,$05 ; $C139 data/unclassified
        dc.b $05,$05,$30,$10,$00                             ; $C149 data/unclassified
PERIODIC_GAMEPLAY_TIMERS_AND_EFFECTS:
; Periodic gameplay timers and effects. The CHAMP multiplier lamp flash occurs specifically at C1B3-C1B8; see that instruction-level comment.
        LDX $10b3                    ; $C14E: $FE,$10,$B3
        BEQ $c154                    ; $C151: $27,$01
        DEX                          ; $C153: $09
        STX $10b3                    ; $C154: $FF,$10,$B3
        LDX $10b5                    ; $C157: $FE,$10,$B5
        BEQ $c15d                    ; $C15A: $27,$01
        DEX                          ; $C15C: $09
        STX $10b5                    ; $C15D: $FF,$10,$B5
        LDAA $10b2                   ; $C160: $B6,$10,$B2
        BEQ $c166                    ; $C163: $27,$01
        DECA                         ; $C165: $4A
        STAA $10b2                   ; $C166: $B7,$10,$B2
        LDAA.w $009a                 ; $C169: $B6,$00,$9A
        ANDA #$32                    ; $C16C: $84,$32
        BNE $c1d3                    ; $C16E: $26,$63
        LDAA.w $009b                 ; $C170: $B6,$00,$9B
        BITA #$40                    ; $C173: $85,$40
        BNE $c1d3                    ; $C175: $26,$5C
        LDAB SWITCH_SAMPLE_PREVIOUS_STROBE0 ; $C177: $F6,$10,$32
        COMB                         ; $C17A: $53
        ANDB SWITCH_SAMPLE_CURRENT_STROBE0 ; $C17B: $F4,$10,$2C
        ANDB #$f                     ; $C17E: $C4,$0F
        BEQ $c18b                    ; $C180: $27,$09
        LDAA #$7                     ; $C182: $86,$07
        INCA                         ; $C184: $4C
        LSRB                         ; $C185: $54
        BCC $c184                    ; $C186: $24,$FC
        JSR MOMENTARY_SOLENOID_PULSE ; $C188: $BD,$F5,$DF
        LDAA $100c                   ; $C18B: $B6,$10,$0C
        ANDA #$f                     ; $C18E: $84,$0F
        CMPA #$f                     ; $C190: $81,$0F
        BNE $c1d3                    ; $C192: $26,$3F
        LDAA $10a0                   ; $C194: $B6,$10,$A0
        BITA #$80                    ; $C197: $85,$80
        BEQ $c1d3                    ; $C199: $27,$38
        LDX #$103a                   ; $C19B: $CE,$10,$3A
        LDAA $1,X                    ; $C19E: $A6,$01
        EORA $10bd                   ; $C1A0: $B8,$10,$BD
        STAA $1,X                    ; $C1A3: $A7,$01
        LDAA $4,X                    ; $C1A5: $A6,$04
        EORA $10be                   ; $C1A7: $B8,$10,$BE
        STAA $4,X                    ; $C1AA: $A7,$04
        LDAA $5,X                    ; $C1AC: $A6,$05
        EORA DROP_TARGET_5000_LAMP_FLASH_MASK ; $C1AE: $B8,$10,$BF
        STAA $5,X                    ; $C1B1: $A7,$05
FLASH_CHAMP_MULTIPLIER_LAMPS:
; CHAMP lamp animation only. XOR authoritative CHAMP_COMPLETION_STATE at 10C0 into CHAMP_MULTIPLIER_LAMP_SHADOW at 1041. Because the shadow blinks, gameplay rules must read 10C0 instead: test 0x20 for triple first, then 0x10 for double.
        LDAA $7,X                    ; $C1B3: $A6,$07
        EORA CHAMP_COMPLETION_STATE  ; $C1B5: $B8,$10,$C0
; CHAMP lamp flash: XOR stable state 10C0 into blinking lamp shadow 1041; never use 1041 as a gameplay condition.
        STAA $7,X                    ; $C1B8: $A7,$07
        LDAA $9,X                    ; $C1BA: $A6,$09
        EORA $10c1                   ; $C1BC: $B8,$10,$C1
        STAA $9,X                    ; $C1BF: $A7,$09
        LDAA $a,X                    ; $C1C1: $A6,$0A
        EORA $10c2                   ; $C1C3: $B8,$10,$C2
        STAA $a,X                    ; $C1C6: $A7,$0A
        LDAA $10bd                   ; $C1C8: $B6,$10,$BD
        BPL $c1d3                    ; $C1CB: $2A,$06
        LDAA $3,X                    ; $C1CD: $A6,$03
        EORA #$80                    ; $C1CF: $88,$80
        STAA $3,X                    ; $C1D1: $A7,$03
        JMP $e272                    ; $C1D3: $7E,$E2,$72
        dc.b $86,$6F,$BD,$C2,$7E,$CE,$16,$5F,$BD,$F6,$C9,$CE,$C2,$C5,$B6,$16 ; $C1D6 data/unclassified
        dc.b $80,$20,$2A,$CE,$C2,$CD,$B6,$16,$80,$84,$30,$27,$56,$84,$20,$26 ; $C1E6 data/unclassified
        dc.b $42,$20,$4E                                     ; $C1F6 data/unclassified
        dc.b $CE,$16,$A3                                     ; $C1F9 unconfirmed: LDX #$16a3
        dc.b $C5,$02                                         ; $C1FC unconfirmed: BITB #$2
        dc.b $26,$0A                                         ; $C1FE unconfirmed: BNE $c20a
        dc.b $CE,$16,$AA                                     ; $C200 unconfirmed: LDX #$16aa
        dc.b $C5,$04                                         ; $C203 unconfirmed: BITB #$4
        dc.b $26,$03                                         ; $C205 unconfirmed: BNE $c20a
        dc.b $CE,$16,$B1                                     ; $C207 unconfirmed: LDX #$16b1
        dc.b $BD,$F6,$C9                                     ; $C20A unconfirmed: JSR $f6c9
        dc.b $CE,$C2,$CD                                     ; $C20D unconfirmed: LDX #$c2cd
        dc.b $B6,$16,$81                                     ; $C210 unconfirmed: LDAA $1681
        dc.b $84,$30                                         ; $C213 unconfirmed: ANDA #$30
        dc.b $81,$30                                         ; $C215 unconfirmed: CMPA #$30
        dc.b $26,$1C                                         ; $C217 unconfirmed: BNE $c235
        dc.b $C6,$80                                         ; $C219 unconfirmed: LDAB #$80
        dc.b $F5,$16,$8B                                     ; $C21B unconfirmed: BITB $168b
        dc.b $26,$15                                         ; $C21E unconfirmed: BNE $c235
        dc.b $FF,$00,$8B                                     ; $C220 unconfirmed: STX.w $008b
        dc.b $FE,$10,$1D                                     ; $C223 unconfirmed: LDX $101d
        dc.b $E5,$00                                         ; $C226 unconfirmed: BITB $0,X
        dc.b $26,$06                                         ; $C228 unconfirmed: BNE $c230
        dc.b $EA,$00                                         ; $C22A unconfirmed: ORAB $0,X
        dc.b $E7,$00                                         ; $C22C unconfirmed: STAB $0,X
        dc.b $20,$02                                         ; $C22E unconfirmed: BRA $c232
        dc.b $86,$20                                         ; $C230 unconfirmed: LDAA #$20
        dc.b $FE,$00,$8B                                     ; $C232 unconfirmed: LDX.w $008b
        dc.b $81,$20                                         ; $C235 unconfirmed: CMPA #$20
        dc.b $26,$10                                         ; $C237 unconfirmed: BNE $c249
        dc.b $F6,$10,$3A                                     ; $C239 unconfirmed: LDAB LAMP_SHADOW_BANK_A_BYTE0
        dc.b $C5,$02                                         ; $C23C unconfirmed: BITB #$2
        dc.b $26,$09                                         ; $C23E unconfirmed: BNE $c249
        dc.b $F6,$00,$9A                                     ; $C240 unconfirmed: LDAB.w $009a
        dc.b $C5,$40                                         ; $C243 unconfirmed: BITB #$40
        dc.b $26,$02                                         ; $C245 unconfirmed: BNE $c249
        dc.b $86,$10                                         ; $C247 unconfirmed: LDAA #$10
        dc.b $16                                             ; $C249 unconfirmed: TAB
        dc.b $7E,$F3,$5C                                     ; $C24A unconfirmed: JMP $f35c
        dc.b $B6,$00,$9A,$84,$BF,$B7,$00,$9A,$B6,$10,$3A,$84,$FC,$B7,$10,$3A ; $C24D data/unclassified
        dc.b $86,$6E,$8D,$1D,$86,$1A,$20,$19                 ; $C25D data/unclassified
        dc.b $FF,$00,$8B                                     ; $C265 unconfirmed: STX.w $008b
        dc.b $B6,$00,$8B                                     ; $C268 unconfirmed: LDAA.w $008b
        dc.b $20,$11                                         ; $C26B unconfirmed: BRA $c27e
SEND_SOUND_COMMAND_TO_BOARD:
; Controller-to-sound-board command output. A queued byte from 1024 can be split across the 6803 ports and strobed to the sound board; the Rebound handler queues command 0x22.
        CMPA #$6                     ; $C26D: $81,$06
        BCC $c27e                    ; $C26F: $24,$0D
        LDAB $1682                   ; $C271: $F6,$16,$82
        BITB #$20                    ; $C274: $C5,$20
        BEQ $c28a                    ; $C276: $27,$12
        LDAA PENDING_SOUND_COMMAND   ; $C278: $B6,$10,$24
        BNE $c28a                    ; $C27B: $26,$0D
        RTS                          ; $C27D: $39
        dc.b $BD,$C2,$B7                                     ; $C27E unconfirmed: JSR $c2b7
        dc.b $F6,$16,$82                                     ; $C281 unconfirmed: LDAB $1682
        dc.b $C5,$20                                         ; $C284 unconfirmed: BITB #$20
        dc.b $26,$02                                         ; $C286 unconfirmed: BNE $c28a
        dc.b $84,$0F                                         ; $C288 unconfirmed: ANDA #$f
        dc.b $7F,$10,$24                                     ; $C28A unconfirmed: CLR PENDING_SOUND_COMMAND
        dc.b $0F                                             ; $C28D unconfirmed: SEI
        dc.b $36                                             ; $C28E unconfirmed: PSHA
        dc.b $97,$02                                         ; $C28F unconfirmed: STAA $0002
        dc.b $D6,$03                                         ; $C291 unconfirmed: LDAB $0003
        dc.b $C4,$EF                                         ; $C293 unconfirmed: ANDB #$ef
        dc.b $D7,$03                                         ; $C295 unconfirmed: STAB $0003
        dc.b $86,$06                                         ; $C297 unconfirmed: LDAA #$6
        dc.b $4A                                             ; $C299 unconfirmed: DECA
        dc.b $26,$FD                                         ; $C29A unconfirmed: BNE $c299
        dc.b $CA,$10                                         ; $C29C unconfirmed: ORAB #$10
        dc.b $D7,$03                                         ; $C29E unconfirmed: STAB $0003
        dc.b $C6,$1A                                         ; $C2A0 unconfirmed: LDAB #$1a
        dc.b $5A                                             ; $C2A2 unconfirmed: DECB
        dc.b $26,$FD                                         ; $C2A3 unconfirmed: BNE $c2a2
        dc.b $32                                             ; $C2A5 unconfirmed: PULA
        dc.b $44                                             ; $C2A6 unconfirmed: LSRA
        dc.b $44                                             ; $C2A7 unconfirmed: LSRA
        dc.b $44                                             ; $C2A8 unconfirmed: LSRA
        dc.b $44                                             ; $C2A9 unconfirmed: LSRA
        dc.b $97,$02                                         ; $C2AA unconfirmed: STAA $0002
        dc.b $C6,$1A                                         ; $C2AC unconfirmed: LDAB #$1a
        dc.b $5A                                             ; $C2AE unconfirmed: DECB
        dc.b $26,$FD                                         ; $C2AF unconfirmed: BNE $c2ae
        dc.b $0E                                             ; $C2B1 unconfirmed: CLI
        dc.b $C6,$01                                         ; $C2B2 unconfirmed: LDAB #$1
        dc.b $7E,$F5,$B9                                     ; $C2B4 unconfirmed: JMP $f5b9
        dc.b $81,$41                                         ; $C2B7 unconfirmed: CMPA #$41
        dc.b $25,$09                                         ; $C2B9 unconfirmed: BCS $c2c4
        dc.b $F6,$16,$8D                                     ; $C2BB unconfirmed: LDAB $168d
        dc.b $C5,$40                                         ; $C2BE unconfirmed: BITB #$40
        dc.b $26,$02                                         ; $C2C0 unconfirmed: BNE $c2c4
        dc.b $33                                             ; $C2C2 unconfirmed: PULB
        dc.b $33                                             ; $C2C3 unconfirmed: PULB
        dc.b $39                                             ; $C2C4 unconfirmed: RTS
        dc.b $E4,$B3,$C9,$94,$C2,$4D,$F6,$F8,$E4,$B3,$C9,$EC,$C2,$4D,$F6,$F8 ; $C2C5 data/unclassified
        dc.b $E4,$B3,$F9,$AA,$F9,$A8,$F9,$A6                 ; $C2D5 data/unclassified
        dc.b $B6,$00,$9A                                     ; $C2DD unconfirmed: LDAA.w $009a
        dc.b $85,$20                                         ; $C2E0 unconfirmed: BITA #$20
        dc.b $27,$67                                         ; $C2E2 unconfirmed: BEQ $c34b
        dc.b $B6,$00,$9B                                     ; $C2E4 unconfirmed: LDAA.w $009b
        dc.b $85,$04                                         ; $C2E7 unconfirmed: BITA #$4
        dc.b $26,$60                                         ; $C2E9 unconfirmed: BNE $c34b
        dc.b $FE,$10,$B3                                     ; $C2EB unconfirmed: LDX $10b3
        dc.b $26,$22                                         ; $C2EE unconfirmed: BNE $c312
        dc.b $B6,$10,$C6                                     ; $C2F0 unconfirmed: LDAA $10c6
        dc.b $85,$04                                         ; $C2F3 unconfirmed: BITA #$4
        dc.b $27,$09                                         ; $C2F5 unconfirmed: BEQ $c300
        dc.b $84,$FB                                         ; $C2F7 unconfirmed: ANDA #$fb
        dc.b $B7,$10,$C6                                     ; $C2F9 unconfirmed: STAA $10c6
        dc.b $86,$79                                         ; $C2FC unconfirmed: LDAA #$79
        dc.b $20,$09                                         ; $C2FE unconfirmed: BRA $c309
        dc.b $B6,$16,$8C                                     ; $C300 unconfirmed: LDAA $168c
        dc.b $85,$80                                         ; $C303 unconfirmed: BITA #$80
        dc.b $27,$0B                                         ; $C305 unconfirmed: BEQ $c312
        dc.b $86,$50                                         ; $C307 unconfirmed: LDAA #$50
        dc.b $BD,$C2,$7E                                     ; $C309 unconfirmed: JSR $c27e
        dc.b $CE,$A8,$C0                                     ; $C30C unconfirmed: LDX #$a8c0
        dc.b $FF,$10,$B3                                     ; $C30F unconfirmed: STX $10b3
        dc.b $FE,$10,$11                                     ; $C312 unconfirmed: LDX $1011
        dc.b $27,$15                                         ; $C315 unconfirmed: BEQ $c32c
        dc.b $B6,$10,$11                                     ; $C317 unconfirmed: LDAA $1011
        dc.b $26,$2B                                         ; $C31A unconfirmed: BNE $c347
        dc.b $B6,$10,$12                                     ; $C31C unconfirmed: LDAA $1012
        dc.b $81,$C8                                         ; $C31F unconfirmed: CMPA #$c8
        dc.b $24,$04                                         ; $C321 unconfirmed: BCC $c327
        dc.b $81,$32                                         ; $C323 unconfirmed: CMPA #$32
        dc.b $24,$15                                         ; $C325 unconfirmed: BCC $c33c
        dc.b $BD,$F3,$35                                     ; $C327 unconfirmed: JSR $f335
        dc.b $20,$09                                         ; $C32A unconfirmed: BRA $c335
        dc.b $CE,$01,$90                                     ; $C32C unconfirmed: LDX #$190
        dc.b $FF,$10,$11                                     ; $C32F unconfirmed: STX $1011
        dc.b $BD,$F3,$41                                     ; $C332 unconfirmed: JSR $f341
        dc.b $86,$50                                         ; $C335 unconfirmed: LDAA #$50
        dc.b $BD,$F5,$91                                     ; $C337 unconfirmed: JSR $f591
        dc.b $20,$0B                                         ; $C33A unconfirmed: BRA $c347
        dc.b $86,$50                                         ; $C33C unconfirmed: LDAA #$50
        dc.b $BD,$F5,$6B                                     ; $C33E unconfirmed: JSR $f56b
        dc.b $CE,$16,$18                                     ; $C341 unconfirmed: LDX #$1618
        dc.b $BD,$F6,$83                                     ; $C344 unconfirmed: JSR $f683
        dc.b $7E,$D0,$E8                                     ; $C347 unconfirmed: JMP $d0e8
        dc.b $39                                             ; $C34A unconfirmed: RTS
        dc.b $B6,$00,$9A                                     ; $C34B unconfirmed: LDAA.w $009a
        dc.b $43                                             ; $C34E unconfirmed: COMA
        dc.b $85,$C0                                         ; $C34F unconfirmed: BITA #$c0
        dc.b $26,$0E                                         ; $C351 unconfirmed: BNE $c361
        dc.b $43                                             ; $C353 unconfirmed: COMA
        dc.b $84,$BF                                         ; $C354 unconfirmed: ANDA #$bf
        dc.b $B7,$00,$9A                                     ; $C356 unconfirmed: STAA.w $009a
        dc.b $B6,$10,$3A                                     ; $C359 unconfirmed: LDAA LAMP_SHADOW_BANK_A_BYTE0
        dc.b $8A,$03                                         ; $C35C unconfirmed: ORAA #$3
        dc.b $B7,$10,$3A                                     ; $C35E unconfirmed: STAA LAMP_SHADOW_BANK_A_BYTE0
        dc.b $B6,$10,$B2                                     ; $C361 unconfirmed: LDAA $10b2
        dc.b $26,$12                                         ; $C364 unconfirmed: BNE $c378
        dc.b $B6,$10,$40                                     ; $C366 unconfirmed: LDAA CHAMP_LANE_STATE
        dc.b $8A,$E0                                         ; $C369 unconfirmed: ORAA #$e0
        dc.b $B7,$10,$BA                                     ; $C36B unconfirmed: STAA $10ba
        dc.b $B6,$10,$B1                                     ; $C36E unconfirmed: LDAA $10b1
        dc.b $43                                             ; $C371 unconfirmed: COMA
        dc.b $B4,$10,$BA                                     ; $C372 unconfirmed: ANDA $10ba
        dc.b $B7,$10,$40                                     ; $C375 unconfirmed: STAA CHAMP_LANE_STATE
        dc.b $B6,$00,$9A                                     ; $C378 unconfirmed: LDAA.w $009a
        dc.b $85,$02                                         ; $C37B unconfirmed: BITA #$2
        dc.b $26,$CB                                         ; $C37D unconfirmed: BNE $c34a
        dc.b $FE,$10,$B3                                     ; $C37F unconfirmed: LDX $10b3
        dc.b $26,$C6                                         ; $C382 unconfirmed: BNE $c34a
        dc.b $B6,$00,$9A                                     ; $C384 unconfirmed: LDAA.w $009a
        dc.b $85,$80                                         ; $C387 unconfirmed: BITA #$80
        dc.b $27,$56                                         ; $C389 unconfirmed: BEQ $c3e1
        dc.b $F6,$10,$C3                                     ; $C38B unconfirmed: LDAB SUNK_POOL_BALLS_1_TO_7
        dc.b $CA,$80                                         ; $C38E unconfirmed: ORAB #$80
        dc.b $53                                             ; $C390 unconfirmed: COMB
        dc.b $26,$12                                         ; $C391 unconfirmed: BNE $c3a5
        dc.b $86,$6C                                         ; $C393 unconfirmed: LDAA #$6c
        dc.b $F6,$10,$C6                                     ; $C395 unconfirmed: LDAB $10c6
        dc.b $C8,$01                                         ; $C398 unconfirmed: EORB #$1
        dc.b $F7,$10,$C6                                     ; $C39A unconfirmed: STAB $10c6
        dc.b $C5,$01                                         ; $C39D unconfirmed: BITB #$1
        dc.b $26,$02                                         ; $C39F unconfirmed: BNE $c3a3
        dc.b $86,$7A                                         ; $C3A1 unconfirmed: LDAA #$7a
        dc.b $20,$27                                         ; $C3A3 unconfirmed: BRA $c3cc
        dc.b $F6,$10,$C5                                     ; $C3A5 unconfirmed: LDAB DROP_TARGET_SWITCH_CLOSURE_LATCHES
        dc.b $C4,$6D                                         ; $C3A8 unconfirmed: ANDB #$6d
        dc.b $C5,$01                                         ; $C3AA unconfirmed: BITB #$1
        dc.b $27,$02                                         ; $C3AC unconfirmed: BEQ $c3b0
        dc.b $CA,$02                                         ; $C3AE unconfirmed: ORAB #$2
        dc.b $C5,$08                                         ; $C3B0 unconfirmed: BITB #$8
        dc.b $27,$02                                         ; $C3B2 unconfirmed: BEQ $c3b6
        dc.b $CA,$10                                         ; $C3B4 unconfirmed: ORAB #$10
        dc.b $FA,$10,$C3                                     ; $C3B6 unconfirmed: ORAB SUNK_POOL_BALLS_1_TO_7
        dc.b $CA,$80                                         ; $C3B9 unconfirmed: ORAB #$80
        dc.b $53                                             ; $C3BB unconfirmed: COMB
        dc.b $27,$8C                                         ; $C3BC unconfirmed: BEQ $c34a
        dc.b $86,$40                                         ; $C3BE unconfirmed: LDAA #$40
        dc.b $4C                                             ; $C3C0 unconfirmed: INCA
        dc.b $54                                             ; $C3C1 unconfirmed: LSRB
        dc.b $24,$FC                                         ; $C3C2 unconfirmed: BCC $c3c0
        dc.b $F6,$00,$8F                                     ; $C3C4 unconfirmed: LDAB.w $008f
        dc.b $54                                             ; $C3C7 unconfirmed: LSRB
        dc.b $25,$02                                         ; $C3C8 unconfirmed: BCS $c3cc
        dc.b $8B,$08                                         ; $C3CA unconfirmed: ADDA #$8
        dc.b $CE,$09,$60                                     ; $C3CC unconfirmed: LDX #$960
        dc.b $16                                             ; $C3CF unconfirmed: TAB
        dc.b $CB,$10                                         ; $C3D0 unconfirmed: ADDB #$10
        dc.b $F7,$10,$C4                                     ; $C3D2 unconfirmed: STAB $10c4
        dc.b $FF,$10,$B3                                     ; $C3D5 unconfirmed: STX $10b3
        dc.b $CE,$01,$2C                                     ; $C3D8 unconfirmed: LDX #$12c
        dc.b $FF,$10,$B5                                     ; $C3DB unconfirmed: STX $10b5
        dc.b $7E,$C2,$7E                                     ; $C3DE unconfirmed: JMP $c27e
        dc.b $CE,$09,$61                                     ; $C3E1 unconfirmed: LDX #$961
        dc.b $86,$50                                         ; $C3E4 unconfirmed: LDAA #$50
        dc.b $F6,$10,$0C                                     ; $C3E6 unconfirmed: LDAB $100c
        dc.b $54                                             ; $C3E9 unconfirmed: LSRB
        dc.b $25,$02                                         ; $C3EA unconfirmed: BCS $c3ee
        dc.b $86,$7A                                         ; $C3EC unconfirmed: LDAA #$7a
        dc.b $20,$E5                                         ; $C3EE unconfirmed: BRA $c3d5
        dc.b $CE,$1C,$20                                     ; $C3F0 unconfirmed: LDX #$1c20
        dc.b $FF,$10,$38                                     ; $C3F3 unconfirmed: STX $1038
        dc.b $BD,$F9,$63                                     ; $C3F6 unconfirmed: JSR $f963
        dc.b $BD,$F3,$27                                     ; $C3F9 unconfirmed: JSR $f327
        dc.b $86,$FF                                         ; $C3FC unconfirmed: LDAA #$ff
        dc.b $B7,$10,$C6                                     ; $C3FE unconfirmed: STAA $10c6
        dc.b $BD,$D0,$D5                                     ; $C401 unconfirmed: JSR $d0d5
        dc.b $4F                                             ; $C404 unconfirmed: CLRA
        dc.b $B7,$10,$A0                                     ; $C405 unconfirmed: STAA $10a0
        dc.b $B6,$10,$2C                                     ; $C408 unconfirmed: LDAA SWITCH_SAMPLE_CURRENT_STROBE0
        dc.b $84,$EF                                         ; $C40B unconfirmed: ANDA #$ef
        dc.b $B7,$10,$2C                                     ; $C40D unconfirmed: STAA SWITCH_SAMPLE_CURRENT_STROBE0
        dc.b $B6,$10,$2F                                     ; $C410 unconfirmed: LDAA SWITCH_SAMPLE_CURRENT_STROBE3
        dc.b $B4,$10,$35                                     ; $C413 unconfirmed: ANDA SWITCH_SAMPLE_PREVIOUS_STROBE3
        dc.b $B7,$10,$B9                                     ; $C416 unconfirmed: STAA $10b9
        dc.b $74,$10,$B9                                     ; $C419 unconfirmed: LSR $10b9
        dc.b $24,$07                                         ; $C41C unconfirmed: BCC $c425
        dc.b $86,$00                                         ; $C41E unconfirmed: LDAA #$0
        dc.b $C6,$05                                         ; $C420 unconfirmed: LDAB #$5
        dc.b $BD,$F5,$C2                                     ; $C422 unconfirmed: JSR PULSE_MOMENTARY_SOLENOID_BLOCKING
        dc.b $74,$10,$B9                                     ; $C425 unconfirmed: LSR $10b9
        dc.b $74,$10,$B9                                     ; $C428 unconfirmed: LSR $10b9
        dc.b $24,$07                                         ; $C42B unconfirmed: BCC $c434
        dc.b $86,$01                                         ; $C42D unconfirmed: LDAA #$1
        dc.b $C6,$05                                         ; $C42F unconfirmed: LDAB #$5
        dc.b $BD,$F5,$C2                                     ; $C431 unconfirmed: JSR PULSE_MOMENTARY_SOLENOID_BLOCKING
        dc.b $74,$10,$B9                                     ; $C434 unconfirmed: LSR $10b9
        dc.b $24,$07                                         ; $C437 unconfirmed: BCC $c440
        dc.b $86,$02                                         ; $C439 unconfirmed: LDAA #$2
        dc.b $C6,$05                                         ; $C43B unconfirmed: LDAB #$5
        dc.b $BD,$F5,$C2                                     ; $C43D unconfirmed: JSR PULSE_MOMENTARY_SOLENOID_BLOCKING
        dc.b $74,$10,$B9                                     ; $C440 unconfirmed: LSR $10b9
        dc.b $74,$10,$B9                                     ; $C443 unconfirmed: LSR $10b9
        dc.b $24,$07                                         ; $C446 unconfirmed: BCC $c44f
        dc.b $86,$03                                         ; $C448 unconfirmed: LDAA #$3
        dc.b $C6,$05                                         ; $C44A unconfirmed: LDAB #$5
        dc.b $BD,$F5,$C2                                     ; $C44C unconfirmed: JSR PULSE_MOMENTARY_SOLENOID_BLOCKING
        dc.b $74,$10,$B9                                     ; $C44F unconfirmed: LSR $10b9
        dc.b $24,$07                                         ; $C452 unconfirmed: BCC $c45b
        dc.b $86,$04                                         ; $C454 unconfirmed: LDAA #$4
        dc.b $C6,$05                                         ; $C456 unconfirmed: LDAB #$5
        dc.b $BD,$F5,$C2                                     ; $C458 unconfirmed: JSR PULSE_MOMENTARY_SOLENOID_BLOCKING
        dc.b $B6,$16,$8D                                     ; $C45B unconfirmed: LDAA $168d
        dc.b $85,$40                                         ; $C45E unconfirmed: BITA #$40
        dc.b $27,$21                                         ; $C460 unconfirmed: BEQ $c483
        dc.b $CE,$02,$58                                     ; $C462 unconfirmed: LDX #$258
        dc.b $FF,$10,$B3                                     ; $C465 unconfirmed: STX $10b3
        dc.b $FE,$10,$B3                                     ; $C468 unconfirmed: LDX $10b3
        dc.b $26,$FB                                         ; $C46B unconfirmed: BNE $c468
        dc.b $F6,$16,$1F                                     ; $C46D unconfirmed: LDAB $161f
        dc.b $54                                             ; $C470 unconfirmed: LSRB
        dc.b $54                                             ; $C471 unconfirmed: LSRB
        dc.b $54                                             ; $C472 unconfirmed: LSRB
        dc.b $54                                             ; $C473 unconfirmed: LSRB
        dc.b $86,$66                                         ; $C474 unconfirmed: LDAA #$66
        dc.b $4C                                             ; $C476 unconfirmed: INCA
        dc.b $5A                                             ; $C477 unconfirmed: DECB
        dc.b $26,$FC                                         ; $C478 unconfirmed: BNE $c476
        dc.b $BD,$C2,$7E                                     ; $C47A unconfirmed: JSR $c27e
        dc.b $CE,$03,$C0                                     ; $C47D unconfirmed: LDX #$3c0
        dc.b $FF,$10,$B3                                     ; $C480 unconfirmed: STX $10b3
        dc.b $39                                             ; $C483 unconfirmed: RTS
        dc.b $B6,$16,$A1                                     ; $C484 unconfirmed: LDAA $16a1
        dc.b $44                                             ; $C487 unconfirmed: LSRA
        dc.b $44                                             ; $C488 unconfirmed: LSRA
        dc.b $44                                             ; $C489 unconfirmed: LSRA
        dc.b $44                                             ; $C48A unconfirmed: LSRA
        dc.b $F6,$16,$A2                                     ; $C48B unconfirmed: LDAB $16a2
        dc.b $C4,$F0                                         ; $C48E unconfirmed: ANDB #$f0
        dc.b $1B                                             ; $C490 unconfirmed: ABA
        dc.b $81,$41                                         ; $C491 unconfirmed: CMPA #$41
        dc.b $26,$EE                                         ; $C493 unconfirmed: BNE $c483
        dc.b $7E,$F7,$11                                     ; $C495 unconfirmed: JMP $f711
