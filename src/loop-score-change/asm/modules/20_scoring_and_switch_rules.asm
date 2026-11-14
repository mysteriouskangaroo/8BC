; Scoring and switch rules
; Address range: $C919-$CDD7
; Pending-score helpers, CHAMP multiplier state, Rebound, and other normal-play switch handlers.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

        dc.b $F7,$10,$0E                                     ; $C919 unconfirmed: STAB $100e
        dc.b $F6,$10,$27                                     ; $C91C unconfirmed: LDAB SWITCH_EVENTS_STROBE1
        dc.b $C4,$07                                         ; $C91F unconfirmed: ANDB #$7
        dc.b $27,$1C                                         ; $C921 unconfirmed: BEQ $c93f
        dc.b $36                                             ; $C923 unconfirmed: PSHA
        dc.b $3C                                             ; $C924 unconfirmed: PSHX
        dc.b $86,$08                                         ; $C925 unconfirmed: LDAA #$8
        dc.b $CE,$C0,$29                                     ; $C927 unconfirmed: LDX #$c029
        dc.b $08                                             ; $C92A unconfirmed: INX
        dc.b $08                                             ; $C92B unconfirmed: INX
        dc.b $44                                             ; $C92C unconfirmed: LSRA
        dc.b $B5,$10,$27                                     ; $C92D unconfirmed: BITA SWITCH_EVENTS_STROBE1
        dc.b $27,$F8                                         ; $C930 unconfirmed: BEQ $c92a
        dc.b $43                                             ; $C932 unconfirmed: COMA
        dc.b $B4,$10,$27                                     ; $C933 unconfirmed: ANDA SWITCH_EVENTS_STROBE1
        dc.b $B7,$10,$27                                     ; $C936 unconfirmed: STAA SWITCH_EVENTS_STROBE1
        dc.b $EE,$00                                         ; $C939 unconfirmed: LDX $0,X
        dc.b $AD,$00                                         ; $C93B unconfirmed: JSR $0,X
        dc.b $38                                             ; $C93D unconfirmed: PULX
        dc.b $32                                             ; $C93E unconfirmed: PULA
        dc.b $F6,$10,$0E                                     ; $C93F unconfirmed: LDAB $100e
        dc.b $26,$D8                                         ; $C942 unconfirmed: BNE $c91c
        dc.b $39                                             ; $C944 unconfirmed: RTS
        dc.b $B6,$10,$27,$85,$20,$27,$08,$86,$1B,$BD,$C2,$7E,$7E,$F3,$4F,$48 ; $C945 data/unclassified
        dc.b $2A,$12,$B6,$10,$3A,$2A,$0D,$BD,$F5,$F7,$86,$63,$BD,$C2,$7E,$86 ; $C955 data/unclassified
        dc.b $17,$BD,$C2,$7E,$7E,$F4,$DF,$B6,$10,$C0,$84,$30,$27,$0B,$8D,$09 ; $C965 data/unclassified
        dc.b $B6,$10,$C0,$85,$10,$26,$02,$8D,$00,$7C,$00,$98,$7E,$FA,$1A,$C6 ; $C975 data/unclassified
        dc.b $09,$20,$1E,$C6,$08,$20,$1A,$C6,$07,$20,$16,$C6,$06,$20,$12,$C6 ; $C985 data/unclassified
        dc.b $05,$20,$0E,$C6,$04,$20,$0A,$C6,$03,$20,$06,$C6,$02,$20,$02,$C6 ; $C995 data/unclassified
        dc.b $01,$B6,$10,$C0,$84,$30,$27,$0B,$8D,$09,$B6,$10,$C0,$85,$10,$26 ; $C9A5 data/unclassified
        dc.b $02,$8D,$00,$37,$FB,$00,$97,$F7,$00,$97,$BD,$FA,$1A,$33,$39 ; $C9B5 data/unclassified
AWARD_500_POINTS_WITH_PLAYFIELD_MULTIPLIER:
        LDAB #$5                     ; $C9C4: $C6,$05
        BRA $c9ce                    ; $C9C6: $20,$06
        dc.b $C6,$03,$20,$02,$C6,$01                         ; $C9C8 data/unclassified
        LDAA CHAMP_COMPLETION_STATE  ; $C9CE: $B6,$10,$C0
        ANDA #$30                    ; $C9D1: $84,$30
        BEQ $c9e0                    ; $C9D3: $27,$0B
        BSR $c9e0                    ; $C9D5: $8D,$09
        LDAA CHAMP_COMPLETION_STATE  ; $C9D7: $B6,$10,$C0
        BITA #$10                    ; $C9DA: $85,$10
        BNE $c9e0                    ; $C9DC: $26,$02
        BSR $c9e0                    ; $C9DE: $8D,$00
        PSHB                         ; $C9E0: $37
        ADDB.w PENDING_SCORE_100S    ; $C9E1: $FB,$00,$95
        STAB.w PENDING_SCORE_100S    ; $C9E4: $F7,$00,$95
        JSR NORMALIZE_PENDING_SCORE_DIGITS ; $C9E7: $BD,$FA,$1A
        PULB                         ; $C9EA: $33
        RTS                          ; $C9EB: $39
        dc.b $BD,$C9,$A0                                     ; $C9EC data/unclassified
AWARD_5000_POINTS_WITH_PLAYFIELD_MULTIPLIER:
        LDAB #$5                     ; $C9EF: $C6,$05
        BRA AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER ; $C9F1: $20,$06
AWARD_3000_POINTS_WITH_PLAYFIELD_MULTIPLIER:
; Award the manual's 3,000-point CHAMP lane value through the common playfield multiplier. This runs before a just-completed CHAMP advances 10C0, so the completing lane uses the multiplier that was active before completion.
        LDAB #$3                     ; $C9F3: $C6,$03
        BRA AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER ; $C9F5: $20,$02
        dc.b $C6,$01                                         ; $C9F7 data/unclassified
AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER:
        LDAA CHAMP_COMPLETION_STATE  ; $C9F9: $B6,$10,$C0
; Multiplier award: mask the authoritative state to the double/triple bits.
        ANDA #$30                    ; $C9FC: $84,$30
        BEQ ADD_PENDING_SCORE_1000S  ; $C9FE: $27,$0B
        BSR ADD_PENDING_SCORE_1000S  ; $CA00: $8D,$09
; Multiplier award: any active multiplier adds a second copy of the base award.
        LDAA CHAMP_COMPLETION_STATE  ; $CA02: $B6,$10,$C0
        BITA #$10                    ; $CA05: $85,$10
; Multiplier award: if double bit 0x10 is set, stop at two copies; valid triple states have 0x20 set and 0x10 clear.
        BNE ADD_PENDING_SCORE_1000S  ; $CA07: $26,$02
        BSR ADD_PENDING_SCORE_1000S  ; $CA09: $8D,$00
; Multiplier award: triple adds the third copy of the base award.
ADD_PENDING_SCORE_1000S:
        PSHB                         ; $CA0B: $37
        ADDB.w PENDING_SCORE_1000S   ; $CA0C: $FB,$00,$96
        STAB.w PENDING_SCORE_1000S   ; $CA0F: $F7,$00,$96
        JSR NORMALIZE_PENDING_SCORE_DIGITS ; $CA12: $BD,$FA,$1A
        PULB                         ; $CA15: $33
        RTS                          ; $CA16: $39
        dc.b $C6,$03,$20,$02                                 ; $CA17 data/unclassified
AWARD_10_POINTS_WITH_PLAYFIELD_MULTIPLIER:
; Common 10-point award. Read CHAMP_COMPLETION_STATE at 10C0: 0x10 means playfield double and 0x20 means playfield triple. Valid game states keep those bits mutually exclusive; test 0x20 first, then 0x10, when adding new rules.
        LDAB #$1                     ; $CA1B: $C6,$01
        LDAA CHAMP_COMPLETION_STATE  ; $CA1D: $B6,$10,$C0
        ANDA #$30                    ; $CA20: $84,$30
        BEQ ADD_PENDING_SCORE_LOW_DIGIT ; $CA22: $27,$0B
        BSR ADD_PENDING_SCORE_LOW_DIGIT ; $CA24: $8D,$09
        LDAA CHAMP_COMPLETION_STATE  ; $CA26: $B6,$10,$C0
        BITA #$10                    ; $CA29: $85,$10
        BNE ADD_PENDING_SCORE_LOW_DIGIT ; $CA2B: $26,$02
        BSR ADD_PENDING_SCORE_LOW_DIGIT ; $CA2D: $8D,$00
ADD_PENDING_SCORE_LOW_DIGIT:
; Add B to the lowest pending-score digit at 0094, then normalize carries through FA1A. One unit here is 10 displayed points.
        PSHB                         ; $CA2F: $37
        ADDB.w PENDING_SCORE_10S     ; $CA30: $FB,$00,$94
        STAB.w PENDING_SCORE_10S     ; $CA33: $F7,$00,$94
        JSR NORMALIZE_PENDING_SCORE_DIGITS ; $CA36: $BD,$FA,$1A
        PULB                         ; $CA39: $33
        RTS                          ; $CA3A: $39
        dc.b $C6,$2E,$BD,$CA,$AA,$BD,$CA,$63,$B6,$10,$B1,$2A,$03,$7E,$C9,$EF ; $CA3B data/unclassified
        dc.b $7A,$10,$24,$48,$2A,$03,$7E,$C9,$F3,$7A,$10,$24,$48,$2A,$03,$7E ; $CA4B data/unclassified
        dc.b $C9,$F7,$7A,$10,$24,$7E,$C9,$CC,$B6,$10,$40,$B8,$10,$B1,$B7,$10 ; $CA5B data/unclassified
        dc.b $40,$86,$5A,$B7,$10,$B2,$39,$C6,$21,$8D,$34,$BD,$CA,$17,$B6,$10 ; $CA6B data/unclassified
        dc.b $C0,$84,$C0,$27,$14,$81,$C0,$27,$10,$B6,$10,$C0,$88,$C0,$B7,$10 ; $CA7B data/unclassified
        dc.b $C0,$B6,$10,$41,$8A,$C0,$B7,$10,$41,$39         ; $CA8B data/unclassified
HANDLE_SWITCH_07_REBOUND:
; Switch 07 Rebound handler. Queue sound command 0x22, pass the common score gate, then award the manual's 10-point value through CA1B.
        LDAB #$22                    ; $CA95: $C6,$22
        BSR QUEUE_SOUND_AND_CHECK_SCORE_GATE ; $CA97: $8D,$11
        JMP AWARD_10_POINTS_WITH_PLAYFIELD_MULTIPLIER ; $CA99: $7E,$CA,$1B
        dc.b $C6,$20,$8D,$0A,$7E,$C9,$F7,$C6,$31,$8D,$03,$7E,$C9,$C4 ; $CA9C data/unclassified
QUEUE_SOUND_AND_CHECK_SCORE_GATE:
; Common switch setup/gate. Store the caller-provided sound command in B at 1024, then continue to scoring only if lamp-shadow byte 103A has bits 7 and 6 both set. The exact physical lamp identities of those two gate bits remain untraced.
; Common switch setup/gate. Store the caller-provided sound command in B at 1024, then continue to scoring only if lamp-shadow byte 103A has bits 7 and 6 both set. The exact physical lamp identities of those two gate bits remain untraced.
        STAB PENDING_SOUND_COMMAND   ; $CAAA: $F7,$10,$24
        LDX #$103a                   ; $CAAD: $CE,$10,$3A
        JSR CHECK_SCORE_GATE_LAMP_BITS ; $CAB0: $BD,$F4,$DF
        BEQ $cab6                    ; $CAB3: $27,$01
        PULX                         ; $CAB5: $38
        RTS                          ; $CAB6: $39
        dc.b $BD,$F4,$DF,$26,$FA,$CE,$10,$3A,$A6,$06,$16,$CA,$1F,$E7,$06,$48 ; $CAB7 data/unclassified
        dc.b $85,$20,$27,$02,$8A,$01,$8A,$E0,$A4,$06,$A7,$06 ; $CAC7 data/unclassified
        RTS                          ; $CAD3: $39
HANDLE_CHAMP_LANE_SWITCH:
; Shared handler for switches 17-21 (C, H, A, M, P lanes). It scores the lane first, then records its bit in lamp/state byte 1040. Completing all five advances CHAMP_COMPLETION_STATE at 10C0: 00 -> 10 (double) -> 20 (triple) -> 60 -> E0.
        LDAB #$25                    ; $CAD4: $C6,$25
        BSR QUEUE_SOUND_AND_CHECK_SCORE_GATE ; $CAD6: $8D,$D2
        PSHA                         ; $CAD8: $36
        JSR AWARD_3000_POINTS_WITH_PLAYFIELD_MULTIPLIER ; $CAD9: $BD,$C9,$F3
; CHAMP timing: score this lane with the currently active multiplier before advancing the completion state.
        PULA                         ; $CADC: $32
        LDX #$1040                   ; $CADD: $CE,$10,$40
        BITA $0,X                    ; $CAE0: $A5,$00
        BNE $cad3                    ; $CAE2: $26,$EF
        INC PENDING_SOUND_COMMAND    ; $CAE4: $7C,$10,$24
        ORAA $0,X                    ; $CAE7: $AA,$00
        STAA $0,X                    ; $CAE9: $A7,$00
        ORAA #$e0                    ; $CAEB: $8A,$E0
        COMA                         ; $CAED: $43
        BNE $cad3                    ; $CAEE: $26,$E3
; CHAMP completion: continue only when all five lane bits in 1040 are now set.
        LDAA #$34                    ; $CAF0: $86,$34
        JSR $c27e                    ; $CAF2: $BD,$C2,$7E
        LDAA #$9                     ; $CAF5: $86,$09
        LDAB #$c                     ; $CAF7: $C6,$0C
        JSR $c919                    ; $CAF9: $BD,$C9,$19
        LDAB CHAMP_LANE_STATE        ; $CAFC: $F6,$10,$40
        EORB #$1f                    ; $CAFF: $C8,$1F
        STAB CHAMP_LANE_STATE        ; $CB01: $F7,$10,$40
        DECA                         ; $CB04: $4A
        BNE $caf7                    ; $CB05: $26,$F0
ADVANCE_CHAMP_COMPLETION_STATE:
        LDAA CHAMP_COMPLETION_STATE  ; $CB07: $B6,$10,$C0
; CHAMP state: inspect the current completion state before advancing it.
        BITA #$20                    ; $CB0A: $85,$20
        BNE RECORD_LATER_CHAMP_COMPLETION ; $CB0C: $26,$0A
        LDAB #$20                    ; $CB0E: $C6,$20
; CHAMP state: default next value to 0x20 (triple); this is used when the current value has 0x10 (double).
        BITA #$10                    ; $CB10: $85,$10
        BNE STORE_CHAMP_COMPLETION_STATE ; $CB12: $26,$0F
        LDAB #$10                    ; $CB14: $C6,$10
; CHAMP state: no multiplier was active, so the first completion selects 0x10 (double).
        BRA STORE_CHAMP_COMPLETION_STATE ; $CB16: $20,$0B
RECORD_LATER_CHAMP_COMPLETION:
        LDAB #$80                    ; $CB18: $C6,$80
; CHAMP state: triple is already active; select the third- or fourth-completion milestone bit.
        BITA #$40                    ; $CB1A: $85,$40
        BNE $cb20                    ; $CB1C: $26,$02
        LDAB #$40                    ; $CB1E: $C6,$40
        ORAB CHAMP_COMPLETION_STATE  ; $CB20: $FA,$10,$C0
; CHAMP state: preserve triple bit 0x20 while adding milestone bit 0x40 or 0x80.
STORE_CHAMP_COMPLETION_STATE:
        STAB CHAMP_COMPLETION_STATE  ; $CB23: $F7,$10,$C0
; CHAMP state: store 0x10 after completion 1 (double), 0x20 after completion 2 (triple), then add 0x40 and 0x80 on completions 3 and 4 while triple remains active.
        LDX #$103a                   ; $CB26: $CE,$10,$3A
        LDAB $7,X                    ; $CB29: $E6,$07
        ORAB #$f0                    ; $CB2B: $CA,$F0
        STAB $7,X                    ; $CB2D: $E7,$07
        LDAB $6,X                    ; $CB2F: $E6,$06
        ORAB #$e0                    ; $CB31: $CA,$E0
        STAB $6,X                    ; $CB33: $E7,$06
        LDAB #$80                    ; $CB35: $C6,$80
        LDAA $10b1                   ; $CB37: $B6,$10,$B1
        BMI $cb46                    ; $CB3A: $2B,$0A
        ASLA                         ; $CB3C: $48
        BMI $cb46                    ; $CB3D: $2B,$07
        LDAB #$40                    ; $CB3F: $C6,$40
        ASLA                         ; $CB41: $48
        BMI $cb46                    ; $CB42: $2B,$02
        LDAB #$20                    ; $CB44: $C6,$20
        STAB $10b1                   ; $CB46: $F7,$10,$B1
        COMB                         ; $CB49: $53
        ANDB $6,X                    ; $CB4A: $E4,$06
        STAB $6,X                    ; $CB4C: $E7,$06
        RTS                          ; $CB4E: $39
        dc.b $C6,$2A,$20,$02,$C6,$29,$BD,$CA,$AA,$17,$BD,$C2,$7E,$CE,$10,$3A ; $CB4F data/unclassified
        dc.b $A6,$0A,$B7,$10,$BA,$8A,$0F,$84,$FE,$A7,$0A,$C6,$0A,$BD,$C9,$19 ; $CB5F data/unclassified
        dc.b $88,$03,$B7,$10,$44,$C6,$0A,$BD,$C9,$19,$88,$06,$B7,$10,$44,$C6 ; $CB6F data/unclassified
        dc.b $0A,$BD,$C9,$19,$88,$0C,$B7,$10,$44,$C6,$0A,$BD,$C9,$19,$88,$08 ; $CB7F data/unclassified
        dc.b $B7,$10,$44,$CE,$10,$3A,$B6,$10,$BA,$A7,$0A,$8A,$F0,$CE,$CC,$25 ; $CB8F data/unclassified
        dc.b $5F,$5C,$08,$A1,$00,$26,$FA                     ; $CB9F rollover lamp-level lookup; result is 1-11 in B
AWARD_ROLLOVER_BUTTON_SCORE:
; Left/right rollover buttons share this call. The original indexed a table of
; 5,000, then 10,000 through 100,000. The variation routine at CC32 preserves
; the separate 5,000 fallback and maps the ten normal levels to 1,000-10,000.
        JSR ROLLOVER_SCORE_BY_LEVEL  ; $CBA6 variation: $BD,$CC,$32
        NOP                          ; $CBA9 fixed-address padding
        NOP                          ; $CBAA fixed-address padding
        NOP                          ; $CBAB fixed-address padding
        NOP                          ; $CBAC fixed-address padding
        NOP                          ; $CBAD fixed-address padding
        NOP                          ; $CBAE fixed-address padding
        NOP                          ; $CBAF fixed-address padding
        NOP                          ; $CBB0 fixed-address padding
        NOP                          ; $CBB1 fixed-address padding
        dc.b $B6,$10,$A0,$85,$20,$26,$18,$B6,$10,$C2,$85,$10,$27 ; $CBB2 data/unclassified
        dc.b $11,$CE,$16,$C6,$BD,$F6,$C9,$BD,$C1,$D6,$B6,$10,$A0,$8A,$20,$B7 ; $CBBF data/unclassified
        dc.b $10,$A0,$B6,$10,$C2,$84,$EF,$B7,$10,$C2,$B6,$10,$44,$8A,$10,$B7 ; $CBCF data/unclassified
        dc.b $10,$44,$F6,$10,$44,$CA,$F0,$CE,$CC,$25,$08,$E1,$00,$26,$FB,$E6 ; $CBDF data/unclassified
        dc.b $01,$CE,$10,$44,$A6,$00,$8A,$0F,$A7,$00,$E4,$00,$E7,$00,$B6,$16 ; $CBEF data/unclassified
        dc.b $A0,$44,$44,$44,$44,$4C,$CE,$CC,$31,$09,$4A,$26,$FC,$A6,$00,$F6 ; $CBFF data/unclassified
        dc.b $10,$44,$CA,$F0,$11,$26,$0F,$B6,$10,$A0,$85,$20,$26,$08,$B6,$10 ; $CC0F data/unclassified
        dc.b $C2,$8A,$10,$B7,$10,$C2,$39,$FF,$FE,$FD,$FB,$F7,$F6,$F5,$F3,$F2 ; $CC1F data/unclassified
        dc.b $F1,$F0,$F0                                     ; $CC2F final rollover lamp-state masks
ROLLOVER_SCORE_BY_LEVEL:
; B=1 is the original table's special 5,000 fallback. Normal rollover levels
; arrive as B=2..11; subtract one and award 1,000..10,000 through the existing
; playfield double/triple multiplier. Both JMP targets return to the caller.
        CMPB #$01                    ; $CC32
        BEQ ROLLOVER_SCORE_FALLBACK_5000 ; $CC34
        DECB                         ; $CC36: 2..11 becomes 1..10
        JMP AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER ; $CC37
ROLLOVER_SCORE_FALLBACK_5000:
        JMP AWARD_5000_POINTS_WITH_PLAYFIELD_MULTIPLIER ; $CC3A
        dc.b $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01 ; $CC3D fixed-address padding replacing old pointer table
        dc.b $86,$40,$20,$02,$86,$80,$C6                     ; $CC48 data/unclassified
        dc.b $2F,$BD,$CA,$AA,$36,$BD,$C9,$F7,$32,$B5,$10,$C0,$27,$C8,$F6,$10 ; $CC4F data/unclassified
        dc.b $C0,$C4,$3F,$F7,$10,$C0,$F6,$10,$41,$CA,$C0,$F7,$10,$41,$CE,$16 ; $CC5F data/unclassified
        dc.b $D4,$48,$25,$03,$CE,$16,$CD,$BD,$F6,$C9,$7E,$C1,$D6,$C6,$30,$BD ; $CC6F data/unclassified
        dc.b $CA,$AA,$BD,$CD,$AA,$36,$BD,$C9,$C4,$32,$CE,$10,$45,$36,$A5,$00 ; $CC7F data/unclassified
        dc.b $27,$0B,$43,$A4,$00,$A7,$00,$A6,$00,$84,$1F,$27,$03,$7E,$CD,$20 ; $CC8F data/unclassified
        dc.b $86,$35,$BD,$C2,$7E,$86,$08,$B7,$10,$B0,$CE,$D3,$19,$FF,$10,$AD ; $CC9F data/unclassified
        dc.b $4F,$B7,$10,$AF,$BD,$D1,$F8,$C6,$0A,$BD,$C9,$19,$FE,$10,$AD,$BD ; $CCAF data/unclassified
        dc.b $D2,$44,$86,$02,$B7,$10,$AF,$CE,$D3,$5D,$FF,$10,$AD,$BD,$D2,$4B ; $CCBF data/unclassified
        dc.b $C6,$0A,$BD,$C9,$19,$BD,$D2,$1F,$F6,$10,$45,$C8,$1F,$F7,$10,$45 ; $CCCF data/unclassified
        dc.b $CE,$10,$3A,$E6,$07,$CA,$F8,$58,$E7,$07,$F6,$10,$BE,$C5,$80,$27 ; $CCDF data/unclassified
        dc.b $33,$B6,$10,$3A,$85,$02,$27,$20,$C4,$7F,$F7,$10,$BE,$F6,$10,$3E ; $CCEF data/unclassified
        dc.b $CA,$80,$F7,$10,$3E,$CE,$16,$BF,$BD,$F6,$C9,$BD,$C1,$D6,$B6,$10 ; $CCFF data/unclassified
        dc.b $C1,$8A,$80,$B7,$10,$C1,$20,$09,$CE,$16,$BF,$BD,$F6,$C9,$BD,$C1 ; $CD0F data/unclassified
        dc.b $D6,$7E,$CD,$46,$F6,$10,$C1,$C5,$80,$27,$E3,$C4,$7F,$F7,$10,$C1 ; $CD1F data/unclassified
        dc.b $E6,$09,$CA,$80,$E7,$09,$CE,$16,$E2,$BD,$F6,$C9,$BD,$C1,$E9,$F6 ; $CD2F data/unclassified
        dc.b $10,$BE,$CA,$80,$F7,$10,$BE,$32,$C6,$28,$BD,$C9,$19,$CE,$CD,$CC ; $CD3F data/unclassified
        dc.b $08,$08,$44,$24,$FB,$EE,$00,$AD,$00,$CE,$00,$B4,$FF,$10,$B3 ; $CD4F data/unclassified
        dc.b $B6,$10,$C3                                     ; $CD5E unconfirmed: LDAA SUNK_POOL_BALLS_1_TO_7
        dc.b $43                                             ; $CD61 unconfirmed: COMA
        dc.b $5F                                             ; $CD62 unconfirmed: CLRB
        dc.b $85,$03                                         ; $CD63 unconfirmed: BITA #$3
        dc.b $26,$02                                         ; $CD65 unconfirmed: BNE $cd69
        dc.b $CA,$01                                         ; $CD67 unconfirmed: ORAB #$1
        dc.b $85,$04                                         ; $CD69 unconfirmed: BITA #$4
        dc.b $26,$02                                         ; $CD6B unconfirmed: BNE $cd6f
        dc.b $CA,$02                                         ; $CD6D unconfirmed: ORAB #$2
        dc.b $85,$18                                         ; $CD6F unconfirmed: BITA #$18
        dc.b $26,$02                                         ; $CD71 unconfirmed: BNE $cd75
        dc.b $CA,$04                                         ; $CD73 unconfirmed: ORAB #$4
        dc.b $85,$20                                         ; $CD75 unconfirmed: BITA #$20
        dc.b $26,$02                                         ; $CD77 unconfirmed: BNE $cd7b
        dc.b $CA,$08                                         ; $CD79 unconfirmed: ORAB #$8
        dc.b $85,$40                                         ; $CD7B unconfirmed: BITA #$40
        dc.b $26,$02                                         ; $CD7D unconfirmed: BNE $cd81
        dc.b $CA,$10                                         ; $CD7F unconfirmed: ORAB #$10
        dc.b $B6,$10,$C5                                     ; $CD81 unconfirmed: LDAA DROP_TARGET_SWITCH_CLOSURE_LATCHES
        dc.b $44                                             ; $CD84 unconfirmed: LSRA
        dc.b $24,$02                                         ; $CD85 unconfirmed: BCC $cd89
        dc.b $C4,$FE                                         ; $CD87 unconfirmed: ANDB #$fe
        dc.b $44                                             ; $CD89 unconfirmed: LSRA
        dc.b $44                                             ; $CD8A unconfirmed: LSRA
        dc.b $24,$02                                         ; $CD8B unconfirmed: BCC $cd8f
        dc.b $C4,$FD                                         ; $CD8D unconfirmed: ANDB #$fd
        dc.b $44                                             ; $CD8F unconfirmed: LSRA
        dc.b $24,$02                                         ; $CD90 unconfirmed: BCC $cd94
        dc.b $C4,$FB                                         ; $CD92 unconfirmed: ANDB #$fb
        dc.b $44                                             ; $CD94 unconfirmed: LSRA
        dc.b $44                                             ; $CD95 unconfirmed: LSRA
        dc.b $24,$02                                         ; $CD96 unconfirmed: BCC $cd9a
        dc.b $C4,$F7                                         ; $CD98 unconfirmed: ANDB #$f7
        dc.b $44                                             ; $CD9A unconfirmed: LSRA
        dc.b $24,$02                                         ; $CD9B unconfirmed: BCC $cd9f
        dc.b $C4,$EF                                         ; $CD9D unconfirmed: ANDB #$ef
        dc.b $C4,$1F                                         ; $CD9F unconfirmed: ANDB #$1f
        dc.b $86,$FF                                         ; $CDA1 unconfirmed: LDAA #$ff
        dc.b $B7,$10,$3F                                     ; $CDA3 unconfirmed: STAA DROP_TARGET_5000_LAMP_SHADOW
        dc.b $F7,$10,$BF                                     ; $CDA6 unconfirmed: STAB DROP_TARGET_5000_LAMP_FLASH_MASK
        dc.b $39                                             ; $CDA9 unconfirmed: RTS
        dc.b $B7,$10,$BA,$C6,$20,$44,$25,$11,$C6,$01,$44,$25,$0C,$C6,$04,$44 ; $CDAA data/unclassified
        dc.b $25,$07,$C6,$08,$44,$25,$02,$C6,$40,$B6,$10,$BA,$F5,$10,$C5,$26 ; $CDBA data/unclassified
        dc.b $02,$32,$32                                     ; $CDCA data/unclassified
        RTS                          ; $CDCD: $39
        dc.b $C6,$D8,$C6,$ED,$C6,$E6,$C6,$DF,$C6,$D1         ; $CDCE data/unclassified
