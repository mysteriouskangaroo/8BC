; Game and ball state
; Address range: $C498-$C918
; New-game/per-ball state, player transitions, and the pool-ball drop-target reset/rearm sequence.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

START_GAME_AND_INITIALIZE_FIRST_BALL:
        LDX #$99                     ; $C498: $CE,$00,$99
        CLRA                         ; $C49B: $4F
        STAA $0,X                    ; $C49C: $A7,$00
        DEX                          ; $C49E: $09
        CPX #$82                     ; $C49F: $8C,$00,$82
        BNE $c49c                    ; $C4A2: $26,$F8
        JSR $eefb                    ; $C4A4: $BD,$EE,$FB
        CLRA                         ; $C4A7: $4F
        STAA $10a0                   ; $C4A8: $B7,$10,$A0
        STAA SUNK_POOL_BALLS_1_TO_7  ; $C4AB: $B7,$10,$C3
        STAA $10bd                   ; $C4AE: $B7,$10,$BD
        STAA $10be                   ; $C4B1: $B7,$10,$BE
        STAA DROP_TARGET_5000_LAMP_FLASH_MASK ; $C4B4: $B7,$10,$BF
        STAA CHAMP_COMPLETION_STATE  ; $C4B7: $B7,$10,$C0
        STAA $10c1                   ; $C4BA: $B7,$10,$C1
        STAA $10c2                   ; $C4BD: $B7,$10,$C2
        LDAA #$e0                    ; $C4C0: $86,$E0
        STAA CHAMP_LANE_STATE        ; $C4C2: $B7,$10,$40
        LDAA #$ff                    ; $C4C5: $86,$FF
        LDAB $168c                   ; $C4C7: $F6,$16,$8C
        BITB #$10                    ; $C4CA: $C5,$10
        BEQ $c4d0                    ; $C4CC: $27,$02
        LDAA #$7f                    ; $C4CE: $86,$7F
        STAA $1044                   ; $C4D0: $B7,$10,$44
        CLRB                         ; $C4D3: $5F
        LDAA $168b                   ; $C4D4: $B6,$16,$8B
        BITA #$40                    ; $C4D7: $85,$40
        BEQ $c4dd                    ; $C4D9: $27,$02
        LDAB #$80                    ; $C4DB: $C6,$80
        STAB $10c1                   ; $C4DD: $F7,$10,$C1
        LDAA $c072                   ; $C4E0: $B6,$C0,$72
        STAA.w $008f                 ; $C4E3: $B7,$00,$8F
        JSR $c58c                    ; $C4E6: $BD,$C5,$8C
        DEC.w $008f                  ; $C4E9: $7A,$00,$8F
        BNE $c4e6                    ; $C4EC: $26,$F8
        LDAA #$64                    ; $C4EE: $86,$64
        JSR $c27e                    ; $C4F0: $BD,$C2,$7E
        JSR $f4ba                    ; $C4F3: $BD,$F4,$BA
START_BALL_STATE:
; Per-ball initialization entry (also reached by the full new-game path at C498). It clears CHAMP_COMPLETION_STATE at C507, so playfield double/triple last only for the current ball, including later CHAMP completions on that ball.
        LDAA #$18                    ; $C4F6: $86,$18
        JSR $c27e                    ; $C4F8: $BD,$C2,$7E
        JSR $f4ee                    ; $C4FB: $BD,$F4,$EE
        BSR $c566                    ; $C4FE: $8D,$66
        JSR $c5d4                    ; $C500: $BD,$C5,$D4
        CLRA                         ; $C503: $4F
        STAA $10bd                   ; $C504: $B7,$10,$BD
        STAA CHAMP_COMPLETION_STATE  ; $C507: $B7,$10,$C0
; CHAMP state: clear playfield double/triple at the start of every ball.
        STAA $10c4                   ; $C50A: $B7,$10,$C4
        LDAA $10c6                   ; $C50D: $B6,$10,$C6
        ANDA #$fe                    ; $C510: $84,$FE
        STAA $10c6                   ; $C512: $B7,$10,$C6
        LDAA $168c                   ; $C515: $B6,$16,$8C
        BITA #$40                    ; $C518: $85,$40
        BNE $c521                    ; $C51A: $26,$05
        LDAB #$e0                    ; $C51C: $C6,$E0
        STAB CHAMP_LANE_STATE        ; $C51E: $F7,$10,$40
        CLR $10b1                    ; $C521: $7F,$10,$B1
        LDAA $168d                   ; $C524: $B6,$16,$8D
        BITA #$20                    ; $C527: $85,$20
        BEQ $c538                    ; $C529: $27,$0D
        LDAA CHAMP_LANE_STATE        ; $C52B: $B6,$10,$40
        ANDA #$df                    ; $C52E: $84,$DF
        STAA CHAMP_LANE_STATE        ; $C530: $B7,$10,$40
        LDAA #$20                    ; $C533: $86,$20
        STAA $10b1                   ; $C535: $B7,$10,$B1
        CLR DROP_TARGET_5000_LAMP_FLASH_MASK ; $C538: $7F,$10,$BF
        LDAA $10c1                   ; $C53B: $B6,$10,$C1
        ANDA #$80                    ; $C53E: $84,$80
        ORAA #$1                     ; $C540: $8A,$01
        STAA $10c1                   ; $C542: $B7,$10,$C1
        LDAA $168d                   ; $C545: $B6,$16,$8D
        BITA #$10                    ; $C548: $85,$10
        BNE $c558                    ; $C54A: $26,$0C
        CLRA                         ; $C54C: $4F
        STAA $10c2                   ; $C54D: $B7,$10,$C2
        LDAA $1044                   ; $C550: $B6,$10,$44
        ORAA #$1f                    ; $C553: $8A,$1F
        STAA $1044                   ; $C555: $B7,$10,$44
        LDAA #$11                    ; $C558: $86,$11
        LDAB $1682                   ; $C55A: $F6,$16,$82
        COMB                         ; $C55D: $53
        ANDB #$10                    ; $C55E: $C4,$10
        BNE $c565                    ; $C560: $26,$03
        JMP $c28d                    ; $C562: $7E,$C2,$8D
        RTS                          ; $C565: $39
        dc.b $C6,$02                                         ; $C566 unconfirmed: LDAB #$2
        dc.b $37                                             ; $C568 unconfirmed: PSHB
        dc.b $86,$FE                                         ; $C569 unconfirmed: LDAA #$fe
        dc.b $BD,$C9,$17                                     ; $C56B unconfirmed: JSR $c917
        dc.b $8D,$10                                         ; $C56E unconfirmed: BSR $c580
        dc.b $43                                             ; $C570 unconfirmed: COMA
        dc.b $48                                             ; $C571 unconfirmed: ASLA
        dc.b $43                                             ; $C572 unconfirmed: COMA
        dc.b $81,$FF                                         ; $C573 unconfirmed: CMPA #$ff
        dc.b $26,$F4                                         ; $C575 unconfirmed: BNE $c56b
        dc.b $33                                             ; $C577 unconfirmed: PULB
        dc.b $5A                                             ; $C578 unconfirmed: DECB
        dc.b $26,$ED                                         ; $C579 unconfirmed: BNE $c568
        dc.b $BD,$C9,$17                                     ; $C57B unconfirmed: JSR $c917
        dc.b $86,$FF                                         ; $C57E unconfirmed: LDAA #$ff
        dc.b $CE,$10,$3B                                     ; $C580 unconfirmed: LDX #$103b
        dc.b $A7,$00                                         ; $C583 unconfirmed: STAA $0,X
        dc.b $08                                             ; $C585 unconfirmed: INX
        dc.b $8C,$10,$46                                     ; $C586 unconfirmed: CPX #$1046
        dc.b $26,$F8                                         ; $C589 unconfirmed: BNE $c583
        dc.b $39                                             ; $C58B unconfirmed: RTS
        dc.b $8D,$35                                         ; $C58C unconfirmed: BSR $c5c3
        dc.b $B6,$10,$A0                                     ; $C58E unconfirmed: LDAA $10a0
        dc.b $A7,$00                                         ; $C591 unconfirmed: STAA $0,X
        dc.b $B6,$10,$C3                                     ; $C593 unconfirmed: LDAA SUNK_POOL_BALLS_1_TO_7
        dc.b $A7,$01                                         ; $C596 unconfirmed: STAA $1,X
        dc.b $B6,$10,$BE                                     ; $C598 unconfirmed: LDAA $10be
        dc.b $A7,$02                                         ; $C59B unconfirmed: STAA $2,X
        dc.b $B6,$10,$C1                                     ; $C59D unconfirmed: LDAA $10c1
        dc.b $A7,$03                                         ; $C5A0 unconfirmed: STAA $3,X
        dc.b $B6,$10,$C2                                     ; $C5A2 unconfirmed: LDAA $10c2
        dc.b $A7,$04                                         ; $C5A5 unconfirmed: STAA $4,X
        dc.b $B6,$10,$40                                     ; $C5A7 unconfirmed: LDAA CHAMP_LANE_STATE
        dc.b $8A,$E0                                         ; $C5AA unconfirmed: ORAA #$e0
        dc.b $A7,$05                                         ; $C5AC unconfirmed: STAA $5,X
        dc.b $B6,$10,$41                                     ; $C5AE unconfirmed: LDAA CHAMP_MULTIPLIER_LAMP_SHADOW
        dc.b $8A,$F0                                         ; $C5B1 unconfirmed: ORAA #$f0
        dc.b $A7,$06                                         ; $C5B3 unconfirmed: STAA $6,X
        dc.b $B6,$10,$44                                     ; $C5B5 unconfirmed: LDAA $1044
        dc.b $A7,$07                                         ; $C5B8 unconfirmed: STAA $7,X
        dc.b $B6,$10,$45                                     ; $C5BA unconfirmed: LDAA $1045
        dc.b $A7,$08                                         ; $C5BD unconfirmed: STAA $8,X
        dc.b $BD,$E7,$C5                                     ; $C5BF unconfirmed: JSR $e7c5
        dc.b $39                                             ; $C5C2 unconfirmed: RTS
        dc.b $CE,$10,$C7                                     ; $C5C3 unconfirmed: LDX #$10c7
        dc.b $B6,$00,$8F                                     ; $C5C6 unconfirmed: LDAA.w $008f
        dc.b $4A                                             ; $C5C9 unconfirmed: DECA
        dc.b $2F,$F6                                         ; $C5CA unconfirmed: BLE $c5c2
        dc.b $BD,$F8,$21                                     ; $C5CC unconfirmed: JSR $f821
        dc.b $BD,$F8,$22                                     ; $C5CF unconfirmed: JSR $f822
        dc.b $20,$F5                                         ; $C5D2 unconfirmed: BRA $c5c9
        dc.b $8D,$ED                                         ; $C5D4 unconfirmed: BSR $c5c3
        dc.b $A6,$00                                         ; $C5D6 unconfirmed: LDAA $0,X
        dc.b $B7,$10,$A0                                     ; $C5D8 unconfirmed: STAA $10a0
        dc.b $A6,$01                                         ; $C5DB unconfirmed: LDAA $1,X
        dc.b $B7,$10,$C3                                     ; $C5DD unconfirmed: STAA SUNK_POOL_BALLS_1_TO_7
        dc.b $A6,$02                                         ; $C5E0 unconfirmed: LDAA $2,X
        dc.b $B7,$10,$BE                                     ; $C5E2 unconfirmed: STAA $10be
        dc.b $A6,$03                                         ; $C5E5 unconfirmed: LDAA $3,X
        dc.b $B7,$10,$C1                                     ; $C5E7 unconfirmed: STAA $10c1
        dc.b $A6,$04                                         ; $C5EA unconfirmed: LDAA $4,X
        dc.b $B7,$10,$C2                                     ; $C5EC unconfirmed: STAA $10c2
        dc.b $A6,$05                                         ; $C5EF unconfirmed: LDAA $5,X
        dc.b $B7,$10,$40                                     ; $C5F1 unconfirmed: STAA CHAMP_LANE_STATE
        dc.b $A6,$06                                         ; $C5F4 unconfirmed: LDAA $6,X
        dc.b $B7,$10,$41                                     ; $C5F6 unconfirmed: STAA CHAMP_MULTIPLIER_LAMP_SHADOW
        dc.b $A6,$07                                         ; $C5F9 unconfirmed: LDAA $7,X
        dc.b $B7,$10,$44                                     ; $C5FB unconfirmed: STAA $1044
        dc.b $A6,$08                                         ; $C5FE unconfirmed: LDAA $8,X
        dc.b $B7,$10,$45                                     ; $C600 unconfirmed: STAA $1045
        dc.b $BD,$F1,$97                                     ; $C603 unconfirmed: JSR $f197
        dc.b $39                                             ; $C606 unconfirmed: RTS
        dc.b $B6,$10,$A0,$84,$7F,$B7,$10,$A0,$BD,$D0,$E3,$7E,$C5,$8C,$B6,$00 ; $C607 data/unclassified
        dc.b $9A,$85,$80,$27,$1E,$BD,$F4,$DF,$26,$19,$B6,$16,$8D,$85,$40,$27 ; $C617 data/unclassified
        dc.b $0A,$FE,$10,$B5,$26,$FB,$86,$65,$BD,$C2,$7E,$86,$2A,$BD,$C2,$7E ; $C627 data/unclassified
        dc.b $BD,$C7,$1D                                     ; $C637 data/unclassified
        dc.b $7E,$F7,$17                                     ; $C63A unconfirmed: JMP $f717
        dc.b $F6,$00,$9A                                     ; $C63D unconfirmed: LDAB.w $009a
        dc.b $C4,$04                                         ; $C640 unconfirmed: ANDB #$4
        dc.b $B6,$10,$3A                                     ; $C642 unconfirmed: LDAA LAMP_SHADOW_BANK_A_BYTE0
        dc.b $85,$02                                         ; $C645 unconfirmed: BITA #$2
        dc.b $26,$02                                         ; $C647 unconfirmed: BNE $c64b
        dc.b $CA,$40                                         ; $C649 unconfirmed: ORAB #$40
        dc.b $F7,$00,$9A                                     ; $C64B unconfirmed: STAB.w $009a
        dc.b $BD,$F6,$08                                     ; $C64E unconfirmed: JSR $f608
        dc.b $86,$0D                                         ; $C651 unconfirmed: LDAA #$d
        dc.b $C6,$04                                         ; $C653 unconfirmed: LDAB #$4
        dc.b $BD,$F5,$C2                                     ; $C655 unconfirmed: JSR PULSE_MOMENTARY_SOLENOID_BLOCKING
        dc.b $BD,$F5,$B7                                     ; $C658 unconfirmed: JSR $f5b7
        dc.b $F7,$10,$26                                     ; $C65B unconfirmed: STAB SWITCH_EVENTS_STROBE0
        dc.b $F6,$10,$27                                     ; $C65E unconfirmed: LDAB SWITCH_EVENTS_STROBE1
        dc.b $C4,$07                                         ; $C661 unconfirmed: ANDB #$7
        dc.b $F7,$10,$27                                     ; $C663 unconfirmed: STAB SWITCH_EVENTS_STROBE1
        dc.b $8D,$3F                                         ; $C666 unconfirmed: BSR $c6a7
        dc.b $B6,$10,$C3                                     ; $C668 unconfirmed: LDAA SUNK_POOL_BALLS_1_TO_7
        dc.b $8A,$80                                         ; $C66B unconfirmed: ORAA #$80
        dc.b $43                                             ; $C66D unconfirmed: COMA
        dc.b $26,$05                                         ; $C66E unconfirmed: BNE $c675
        dc.b $86,$80                                         ; $C670 unconfirmed: LDAA #$80
        dc.b $B7,$10,$BD                                     ; $C672 unconfirmed: STAA $10bd
        dc.b $BD,$C6,$B8                                     ; $C675 unconfirmed: JSR RESET_AND_REARM_POOL_BALL_DROP_TARGETS
        dc.b $B6,$10,$A0                                     ; $C678 unconfirmed: LDAA $10a0
        dc.b $8A,$80                                         ; $C67B unconfirmed: ORAA #$80
        dc.b $B7,$10,$A0                                     ; $C67D unconfirmed: STAA $10a0
        dc.b $BD,$C5,$58                                     ; $C680 unconfirmed: JSR $c558
        dc.b $B6,$10,$3A                                     ; $C683 unconfirmed: LDAA LAMP_SHADOW_BANK_A_BYTE0
        dc.b $85,$02                                         ; $C686 unconfirmed: BITA #$2
        dc.b $27,$15                                         ; $C688 unconfirmed: BEQ $c69f
        dc.b $B6,$00,$8E                                     ; $C68A unconfirmed: LDAA.w $008e
        dc.b $84,$F0                                         ; $C68D unconfirmed: ANDA #$f0
        dc.b $81,$20                                         ; $C68F unconfirmed: CMPA #$20
        dc.b $24,$0C                                         ; $C691 unconfirmed: BCC $c69f
        dc.b $86,$61                                         ; $C693 unconfirmed: LDAA #$61
        dc.b $F6,$00,$8F                                     ; $C695 unconfirmed: LDAB.w $008f
        dc.b $54                                             ; $C698 unconfirmed: LSRB
        dc.b $25,$01                                         ; $C699 unconfirmed: BCS $c69c
        dc.b $4C                                             ; $C69B unconfirmed: INCA
        dc.b $BD,$C2,$7E                                     ; $C69C unconfirmed: JSR $c27e
        dc.b $CE,$04,$B0                                     ; $C69F unconfirmed: LDX #$4b0
        dc.b $FF,$10,$B3                                     ; $C6A2 unconfirmed: STX $10b3
        dc.b $20,$93                                         ; $C6A5 unconfirmed: BRA $c63a
        dc.b $BD,$C8,$4B                                     ; $C6A7 unconfirmed: JSR $c84b
        dc.b $BD,$C8,$3F                                     ; $C6AA unconfirmed: JSR $c83f
        dc.b $FE,$10,$B7                                     ; $C6AD unconfirmed: LDX $10b7
        dc.b $B6,$10,$C3                                     ; $C6B0 unconfirmed: LDAA SUNK_POOL_BALLS_1_TO_7
        dc.b $8A,$80                                         ; $C6B3 unconfirmed: ORAA #$80
        dc.b $A7,$00                                         ; $C6B5 unconfirmed: STAA $0,X
        dc.b $39                                             ; $C6B7 unconfirmed: RTS
RESET_AND_REARM_POOL_BALL_DROP_TARGETS:
        dc.b $B6,$10,$C3                                     ; $C6B8 unconfirmed: LDAA SUNK_POOL_BALLS_1_TO_7
        dc.b $84,$7F                                         ; $C6BB unconfirmed: ANDA #$7f
        dc.b $26,$0A                                         ; $C6BD unconfirmed: BNE PULSE_ALL_POOL_BALL_DROP_TARGET_RESET_COILS
        dc.b $86,$60                                         ; $C6BF unconfirmed: LDAA #$60
        dc.b $BD,$C2,$7E                                     ; $C6C1 unconfirmed: JSR $c27e
        dc.b $C6,$5A                                         ; $C6C4 unconfirmed: LDAB #$5a
        dc.b $BD,$C9,$19                                     ; $C6C6 unconfirmed: JSR $c919
PULSE_ALL_POOL_BALL_DROP_TARGET_RESET_COILS:
; Reset and rearm all five pool-ball drop-target groups. Pulse U14 selectors M0-M4 in turn; after each reset, C6F7-C6FC clears only that group's physical closure latch in 10C5. The sunk-ball record at 10C3 is preserved, so the next hit can take the 5,000-point branch.
        dc.b $8D,$22                                         ; $C6C9 unconfirmed: BSR $c6ed
        dc.b $8D,$19                                         ; $C6CB unconfirmed: BSR $c6e6
        dc.b $8D,$10                                         ; $C6CD unconfirmed: BSR $c6df
        dc.b $8D,$07                                         ; $C6CF unconfirmed: BSR $c6d8
        dc.b $86,$BF                                         ; $C6D1 unconfirmed: LDAA #$bf
        dc.b $36                                             ; $C6D3 unconfirmed: PSHA
        dc.b $86,$04                                         ; $C6D4 unconfirmed: LDAA #$4
        dc.b $20,$1A                                         ; $C6D6 unconfirmed: BRA PULSE_ONE_DROP_TARGET_RESET_COIL
        dc.b $86,$DF                                         ; $C6D8 unconfirmed: LDAA #$df
        dc.b $36                                             ; $C6DA unconfirmed: PSHA
        dc.b $86,$03                                         ; $C6DB unconfirmed: LDAA #$3
        dc.b $20,$13                                         ; $C6DD unconfirmed: BRA PULSE_ONE_DROP_TARGET_RESET_COIL
        dc.b $86,$F7                                         ; $C6DF unconfirmed: LDAA #$f7
        dc.b $36                                             ; $C6E1 unconfirmed: PSHA
        dc.b $86,$02                                         ; $C6E2 unconfirmed: LDAA #$2
        dc.b $20,$0C                                         ; $C6E4 unconfirmed: BRA PULSE_ONE_DROP_TARGET_RESET_COIL
        dc.b $86,$FB                                         ; $C6E6 unconfirmed: LDAA #$fb
        dc.b $36                                             ; $C6E8 unconfirmed: PSHA
        dc.b $86,$01                                         ; $C6E9 unconfirmed: LDAA #$1
        dc.b $20,$05                                         ; $C6EB unconfirmed: BRA PULSE_ONE_DROP_TARGET_RESET_COIL
        dc.b $86,$FE                                         ; $C6ED unconfirmed: LDAA #$fe
        dc.b $36                                             ; $C6EF unconfirmed: PSHA
        dc.b $86,$00                                         ; $C6F0 unconfirmed: LDAA #$0
PULSE_ONE_DROP_TARGET_RESET_COIL:
        dc.b $C6,$05                                         ; $C6F2 unconfirmed: LDAB #$5
        dc.b $BD,$F5,$C2                                     ; $C6F4 unconfirmed: JSR PULSE_MOMENTARY_SOLENOID_BLOCKING
; Drop-target reset: pulse the selected M0-M4 reset coil through the blocking momentary-solenoid helper.
        dc.b $32                                             ; $C6F7 unconfirmed: PULA
        dc.b $16                                             ; $C6F8 unconfirmed: TAB
        dc.b $F4,$10,$C5                                     ; $C6F9 unconfirmed: ANDB DROP_TARGET_SWITCH_CLOSURE_LATCHES
        dc.b $F7,$10,$C5                                     ; $C6FC unconfirmed: STAB DROP_TARGET_SWITCH_CLOSURE_LATCHES
; Drop-target reset: clear only this group's closure latch in 10C5; preserve sunk-ball state 10C3.
        dc.b $C6,$0A                                         ; $C6FF unconfirmed: LDAB #$a
        dc.b $BD,$C9,$19                                     ; $C701 unconfirmed: JSR $c919
        dc.b $B4,$10,$29                                     ; $C704 unconfirmed: ANDA SWITCH_EVENTS_STROBE3
        dc.b $B7,$10,$29                                     ; $C707 unconfirmed: STAA SWITCH_EVENTS_STROBE3
        dc.b $B6,$10,$2A                                     ; $C70A unconfirmed: LDAA SWITCH_EVENTS_STROBE4
        dc.b $84,$E0                                         ; $C70D unconfirmed: ANDA #$e0
        dc.b $B7,$10,$2A                                     ; $C70F unconfirmed: STAA SWITCH_EVENTS_STROBE4
        dc.b $5F                                             ; $C712 unconfirmed: CLRB
        dc.b $F7,$10,$BF                                     ; $C713 unconfirmed: STAB DROP_TARGET_5000_LAMP_FLASH_MASK
        dc.b $53                                             ; $C716 unconfirmed: COMB
        dc.b $F7,$10,$3F                                     ; $C717 unconfirmed: STAB DROP_TARGET_5000_LAMP_SHADOW
        dc.b $7E,$CD,$5E                                     ; $C71A unconfirmed: JMP $cd5e
        dc.b $86,$02,$B7,$10,$AF,$CE,$D3,$13,$FF,$10,$AD,$86,$03,$B7,$10,$B0 ; $C71D data/unclassified
        dc.b $BD,$D1,$F8,$C6,$0A,$BD,$C9,$19,$FE,$10,$AD,$BD,$D2,$44,$FE,$10 ; $C72D data/unclassified
        dc.b $AD,$BD,$D2,$4B,$C6,$0A,$BD,$C9,$19,$BD,$D2,$1F,$B6,$10,$A0,$84 ; $C73D data/unclassified
        dc.b $7F,$B7,$10,$A0,$B6,$10,$43,$84,$70,$B7,$10,$B9,$BD,$C7,$65,$B6 ; $C74D data/unclassified
        dc.b $10,$B9,$B7,$10,$43,$7E,$C8,$59,$BD,$C8,$4B,$B6,$10,$44,$84,$60 ; $C75D data/unclassified
        dc.b $B7,$10,$BA,$B6,$10,$C3,$B7,$10,$BC,$B6,$10,$43,$85,$40,$26,$0D ; $C76D data/unclassified
        dc.b $86,$03,$8D,$25,$86,$05,$8D,$21,$86,$DF,$B7,$10,$43,$85,$20,$26 ; $C77D data/unclassified
        dc.b $09,$86,$07,$8D,$14,$86,$EF,$B7,$10,$43,$85,$10,$26,$04,$86,$09 ; $C78D data/unclassified
        dc.b $8D,$07,$86,$FF,$B7,$10,$43,$86,$0B,$B7,$10,$BB,$B6,$10,$BC,$B7 ; $C79D data/unclassified
        dc.b $10,$C3,$BD,$C8,$3F,$B6,$10,$BA,$B7,$10,$44,$C6,$05,$BD,$C9,$19 ; $C7AD data/unclassified
        dc.b $B6,$10,$C3,$27,$47,$86,$01,$B5,$10,$C3,$26,$05,$48,$26,$F8,$20 ; $C7BD data/unclassified
        dc.b $3B,$43,$B4,$10,$C3,$B7,$10,$C3,$8D,$68,$F6,$10,$3D,$B6,$10,$C3 ; $C7CD data/unclassified
        dc.b $2A,$07,$C4,$7F,$F7,$10,$3D,$20,$05,$CA,$80,$F7,$10,$3D,$BD,$C9 ; $C7DD data/unclassified
        dc.b $45,$26,$5A,$CE,$00,$01,$BD,$F4,$1C,$CE,$50,$00,$BD,$F4,$11,$86 ; $C7ED data/unclassified
        dc.b $37,$BD,$C2,$7E,$F6,$10,$BB,$BD,$C9,$19,$20,$B4,$B6,$10,$44,$85 ; $C7FD data/unclassified
        dc.b $20,$26,$25,$8A,$20,$B7,$10,$44,$86,$FF,$B7,$10,$C3,$8D,$23,$F6 ; $C80D data/unclassified
        dc.b $10,$3D,$B6,$10,$C3,$2A,$07,$C4,$7F,$F7,$10,$3D,$20,$05,$CA,$80 ; $C81D data/unclassified
        dc.b $F7,$10,$3D,$BD,$C9,$17,$20,$88,$85,$40,$26,$11,$8A,$40,$84,$DF ; $C82D data/unclassified
        dc.b $20,$D3                                         ; $C83D data/unclassified
        dc.b $FE,$10,$B7                                     ; $C83F unconfirmed: LDX $10b7
        dc.b $B6,$10,$C3                                     ; $C842 unconfirmed: LDAA SUNK_POOL_BALLS_1_TO_7
        dc.b $43                                             ; $C845 unconfirmed: COMA
        dc.b $8A,$80                                         ; $C846 unconfirmed: ORAA #$80
        dc.b $A7,$02                                         ; $C848 unconfirmed: STAA $2,X
        dc.b $39                                             ; $C84A unconfirmed: RTS
        dc.b $CE,$10,$3B                                     ; $C84B unconfirmed: LDX #$103b
        dc.b $B6,$00,$8F                                     ; $C84E unconfirmed: LDAA.w $008f
        dc.b $44                                             ; $C851 unconfirmed: LSRA
        dc.b $25,$01                                         ; $C852 unconfirmed: BCS $c855
        dc.b $08                                             ; $C854 unconfirmed: INX
        dc.b $FF,$10,$B7                                     ; $C855 unconfirmed: STX $10b7
        dc.b $39                                             ; $C858 unconfirmed: RTS
        dc.b $B6,$10,$45,$8A,$E0,$B7,$10,$BA,$B6,$10,$41,$8A,$F0,$B7,$10,$BC ; $C859 data/unclassified
        dc.b $B6,$10,$43,$85,$40,$26,$0B,$BD,$C8,$93,$BD,$C8,$93,$86,$DF,$B7 ; $C869 data/unclassified
        dc.b $10,$43,$85,$20,$26,$08,$BD,$C8,$93,$86,$EF,$B7,$10,$43,$85,$10 ; $C879 data/unclassified
        dc.b $26,$08,$BD,$C8,$93,$86,$FF,$B7,$10,$43,$B6,$10,$BA,$B7,$10,$45 ; $C889 data/unclassified
        dc.b $B6,$10,$BC,$B7,$10,$41,$C6,$14,$BD,$C9,$19,$8D,$17,$B6,$10,$41 ; $C899 data/unclassified
        dc.b $8A,$F0,$81,$FF,$27,$67,$0D,$46,$B7,$10,$41,$86,$E0,$B7,$10,$45 ; $C8A9 data/unclassified
        dc.b $C6,$0A,$20,$E4,$B6,$10,$45,$85,$01,$26,$07,$8A,$01,$B7,$10,$45 ; $C8B9 data/unclassified
        dc.b $8D,$36,$B6,$10,$45,$85,$02,$26,$07,$8A,$02,$B7,$10,$45,$8D,$28 ; $C8C9 data/unclassified
        dc.b $B6,$10,$45,$85,$04,$26,$07,$8A,$04,$B7,$10,$45,$8D,$1A,$B6,$10 ; $C8D9 data/unclassified
        dc.b $45,$85,$08,$26,$07,$8A,$08,$B7,$10,$45,$8D,$0C,$B6,$10,$45,$85 ; $C8E9 data/unclassified
        dc.b $10,$26,$1A,$8A,$10,$B7,$10,$45,$BD,$C9,$45,$26,$10,$CE,$00,$01 ; $C8F9 data/unclassified
        dc.b $BD,$F4,$1C,$86,$38,$BD,$C2,$7E,$C6,$0B,$BD,$C9,$19,$39 ; $C909 data/unclassified
        dc.b $C6,$0A                                         ; $C917 unconfirmed: LDAB #$a
