; Shared helpers, displays, and output drivers
; Address range: $F000-$FFEF
; Display/score helpers and low-level sound, timing, and momentary-solenoid output routines.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

        dc.b $85,$BD,$F6,$C9,$20,$D7,$CE,$10,$77,$8D,$A7,$CE,$10,$70,$8D,$9F ; $F000 data/unclassified
        dc.b $CE,$10,$7E,$8D,$9D,$8D,$31,$CE,$10,$7E,$8D,$93,$BD,$F9,$D2,$27 ; $F010 data/unclassified
        dc.b $12,$33,$5C,$37,$CE,$10,$85,$8D,$89,$8D,$0C,$CE,$10,$85,$BD,$EF ; $F020 data/unclassified
        dc.b $AF,$20,$AA,$33,$39,$8D,$00,$86,$04,$CE,$00,$83,$68,$03,$69,$02 ; $F030 data/unclassified
        dc.b $69,$01,$69,$00,$4A,$26,$F5,$39,$86,$04,$CE,$00,$83,$64,$00,$66 ; $F040 data/unclassified
        dc.b $01,$66,$02,$66,$03,$4A,$26,$F5,$39,$CE,$00,$01,$FF,$00,$87,$09 ; $F050 data/unclassified
        dc.b $FF,$00,$89,$39,$BD,$F6,$75,$CE,$10,$85,$7E,$F6,$98 ; $F060 data/unclassified
        dc.b $36                                             ; $F06D unconfirmed: PSHA
        dc.b $CE,$16,$51                                     ; $F06E unconfirmed: LDX #$1651
        dc.b $BD,$F6,$C9                                     ; $F071 unconfirmed: JSR $f6c9
        dc.b $CE,$16,$78                                     ; $F074 unconfirmed: LDX #$1678
        dc.b $20,$16                                         ; $F077 unconfirmed: BRA $f08f
        dc.b $36,$CE,$16,$4A,$BD,$F6,$C9,$CE,$16,$76,$20,$0A,$36,$CE,$16,$58 ; $F079 data/unclassified
        dc.b $BD,$F6,$C9,$CE,$16,$7A                         ; $F089 data/unclassified
        dc.b $3C                                             ; $F08F unconfirmed: PSHX
        dc.b $CE,$16,$74                                     ; $F090 unconfirmed: LDX #$1674
        dc.b $BD,$F1,$8E                                     ; $F093 unconfirmed: JSR $f18e
        dc.b $26,$03                                         ; $F096 unconfirmed: BNE $f09b
        dc.b $7E,$F1,$1F                                     ; $F098 unconfirmed: JMP $f11f
        dc.b $CE,$F1,$9C                                     ; $F09B unconfirmed: LDX #$f19c
        dc.b $4A                                             ; $F09E unconfirmed: DECA
        dc.b $27,$23                                         ; $F09F unconfirmed: BEQ $f0c4
        dc.b $BD,$F8,$23                                     ; $F0A1 unconfirmed: JSR $f823
        dc.b $8C,$F3,$27                                     ; $F0A4 unconfirmed: CPX #$f327
        dc.b $26,$F5                                         ; $F0A7 unconfirmed: BNE $f09e
        dc.b $FE,$C0,$B3                                     ; $F0A9 unconfirmed: LDX $c0b3
        dc.b $BC,$C0,$B5                                     ; $F0AC unconfirmed: CPX $c0b5
        dc.b $27,$08                                         ; $F0AF unconfirmed: BEQ $f0b9
        dc.b $4A                                             ; $F0B1 unconfirmed: DECA
        dc.b $27,$10                                         ; $F0B2 unconfirmed: BEQ $f0c4
        dc.b $BD,$F8,$23                                     ; $F0B4 unconfirmed: JSR $f823
        dc.b $20,$F3                                         ; $F0B7 unconfirmed: BRA $f0ac
        dc.b $38                                             ; $F0B9 unconfirmed: PULX
        dc.b $86,$FF                                         ; $F0BA unconfirmed: LDAA #$ff
        dc.b $B7,$10,$24                                     ; $F0BC unconfirmed: STAA PENDING_SOUND_COMMAND
        dc.b $86,$06                                         ; $F0BF unconfirmed: LDAA #$6
        dc.b $7E,$F1,$82                                     ; $F0C1 unconfirmed: JMP $f182
        dc.b $FF,$10,$17                                     ; $F0C4 unconfirmed: STX $1017
        dc.b $38                                             ; $F0C7 unconfirmed: PULX
        dc.b $5F                                             ; $F0C8 unconfirmed: CLRB
        dc.b $8C,$16,$76                                     ; $F0C9 unconfirmed: CPX #$1676
        dc.b $27,$07                                         ; $F0CC unconfirmed: BEQ $f0d5
        dc.b $5C                                             ; $F0CE unconfirmed: INCB
        dc.b $8C,$16,$78                                     ; $F0CF unconfirmed: CPX #$1678
        dc.b $27,$01                                         ; $F0D2 unconfirmed: BEQ $f0d5
        dc.b $5C                                             ; $F0D4 unconfirmed: INCB
        dc.b $FE,$10,$17                                     ; $F0D5 unconfirmed: LDX $1017
        dc.b $3A                                             ; $F0D8 unconfirmed: ABX
        dc.b $A6,$00                                         ; $F0D9 unconfirmed: LDAA $0,X
        dc.b $36                                             ; $F0DB unconfirmed: PSHA
        dc.b $BB,$10,$0A                                     ; $F0DC unconfirmed: ADDA $100a
        dc.b $B7,$10,$0A                                     ; $F0DF unconfirmed: STAA $100a
        dc.b $32                                             ; $F0E2 unconfirmed: PULA
        dc.b $FE,$10,$17                                     ; $F0E3 unconfirmed: LDX $1017
        dc.b $E6,$03                                         ; $F0E6 unconfirmed: LDAB $3,X
        dc.b $26,$03                                         ; $F0E8 unconfirmed: BNE $f0ed
        dc.b $7E,$F1,$6F                                     ; $F0EA unconfirmed: JMP $f16f
        dc.b $11                                             ; $F0ED unconfirmed: CBA
        dc.b $25,$02                                         ; $F0EE unconfirmed: BCS $f0f2
        dc.b $8D,$59                                         ; $F0F0 unconfirmed: BSR $f14b
        dc.b $BB,$10,$09                                     ; $F0F2 unconfirmed: ADDA $1009
        dc.b $B7,$10,$09                                     ; $F0F5 unconfirmed: STAA $1009
        dc.b $FE,$10,$17                                     ; $F0F8 unconfirmed: LDX $1017
        dc.b $E6,$03                                         ; $F0FB unconfirmed: LDAB $3,X
        dc.b $11                                             ; $F0FD unconfirmed: CBA
        dc.b $25,$08                                         ; $F0FE unconfirmed: BCS $f108
        dc.b $7F,$10,$09                                     ; $F100 unconfirmed: CLR $1009
        dc.b $8D,$46                                         ; $F103 unconfirmed: BSR $f14b
        dc.b $B7,$10,$09                                     ; $F105 unconfirmed: STAA $1009
        dc.b $FE,$10,$17                                     ; $F108 unconfirmed: LDX $1017
        dc.b $E6,$04                                         ; $F10B unconfirmed: LDAB $4,X
        dc.b $27,$66                                         ; $F10D unconfirmed: BEQ $f175
        dc.b $B6,$10,$0A                                     ; $F10F unconfirmed: LDAA $100a
        dc.b $11                                             ; $F112 unconfirmed: CBA
        dc.b $25,$60                                         ; $F113 unconfirmed: BCS $f175
        dc.b $7F,$10,$0A                                     ; $F115 unconfirmed: CLR $100a
        dc.b $8D,$31                                         ; $F118 unconfirmed: BSR $f14b
        dc.b $B7,$10,$0A                                     ; $F11A unconfirmed: STAA $100a
        dc.b $20,$56                                         ; $F11D unconfirmed: BRA $f175
        dc.b $38                                             ; $F11F unconfirmed: PULX
        dc.b $8D,$6C                                         ; $F120 unconfirmed: BSR $f18e
        dc.b $27,$96                                         ; $F122 unconfirmed: BEQ $f0ba
        dc.b $36                                             ; $F124 unconfirmed: PSHA
        dc.b $BB,$10,$0A                                     ; $F125 unconfirmed: ADDA $100a
        dc.b $B7,$10,$0A                                     ; $F128 unconfirmed: STAA $100a
        dc.b $CE,$16,$7C                                     ; $F12B unconfirmed: LDX #$167c
        dc.b $8D,$5E                                         ; $F12E unconfirmed: BSR $f18e
        dc.b $32                                             ; $F130 unconfirmed: PULA
        dc.b $27,$3C                                         ; $F131 unconfirmed: BEQ $f16f
        dc.b $11                                             ; $F133 unconfirmed: CBA
        dc.b $25,$02                                         ; $F134 unconfirmed: BCS $f138
        dc.b $8D,$13                                         ; $F136 unconfirmed: BSR $f14b
        dc.b $BB,$10,$09                                     ; $F138 unconfirmed: ADDA $1009
        dc.b $B7,$10,$09                                     ; $F13B unconfirmed: STAA $1009
        dc.b $11                                             ; $F13E unconfirmed: CBA
        dc.b $25,$17                                         ; $F13F unconfirmed: BCS $f158
        dc.b $7F,$10,$09                                     ; $F141 unconfirmed: CLR $1009
        dc.b $8D,$05                                         ; $F144 unconfirmed: BSR $f14b
        dc.b $B7,$10,$09                                     ; $F146 unconfirmed: STAA $1009
        dc.b $20,$0D                                         ; $F149 unconfirmed: BRA $f158
        dc.b $37                                             ; $F14B unconfirmed: PSHB
        dc.b $7C,$10,$08                                     ; $F14C unconfirmed: INC $1008
        dc.b $50                                             ; $F14F unconfirmed: NEGB
        dc.b $1B                                             ; $F150 unconfirmed: ABA
        dc.b $33                                             ; $F151 unconfirmed: PULB
        dc.b $27,$03                                         ; $F152 unconfirmed: BEQ $f157
        dc.b $11                                             ; $F154 unconfirmed: CBA
        dc.b $22,$F4                                         ; $F155 unconfirmed: BHI $f14b
        dc.b $39                                             ; $F157 unconfirmed: RTS
        dc.b $CE,$16,$7E                                     ; $F158 unconfirmed: LDX #$167e
        dc.b $8D,$31                                         ; $F15B unconfirmed: BSR $f18e
        dc.b $27,$16                                         ; $F15D unconfirmed: BEQ $f175
        dc.b $B6,$10,$0A                                     ; $F15F unconfirmed: LDAA $100a
        dc.b $11                                             ; $F162 unconfirmed: CBA
        dc.b $25,$10                                         ; $F163 unconfirmed: BCS $f175
        dc.b $7F,$10,$0A                                     ; $F165 unconfirmed: CLR $100a
        dc.b $8D,$E1                                         ; $F168 unconfirmed: BSR $f14b
        dc.b $B7,$10,$0A                                     ; $F16A unconfirmed: STAA $100a
        dc.b $20,$06                                         ; $F16D unconfirmed: BRA $f175
        dc.b $BB,$10,$08                                     ; $F16F unconfirmed: ADDA $1008
        dc.b $B7,$10,$08                                     ; $F172 unconfirmed: STAA $1008
        dc.b $B6,$10,$08                                     ; $F175 unconfirmed: LDAA $1008
        dc.b $27,$A8                                         ; $F178 unconfirmed: BEQ $f122
        dc.b $BD,$F7,$0D                                     ; $F17A unconfirmed: JSR $f70d
        dc.b $7A,$10,$08                                     ; $F17D unconfirmed: DEC $1008
        dc.b $26,$F8                                         ; $F180 unconfirmed: BNE $f17a
        dc.b $BD,$F5,$B3                                     ; $F182 unconfirmed: JSR $f5b3
        dc.b $32                                             ; $F185 unconfirmed: PULA
        dc.b $43                                             ; $F186 unconfirmed: COMA
        dc.b $B4,$10,$27                                     ; $F187 unconfirmed: ANDA SWITCH_EVENTS_STROBE1
        dc.b $B7,$10,$27                                     ; $F18A unconfirmed: STAA SWITCH_EVENTS_STROBE1
        dc.b $39                                             ; $F18D unconfirmed: RTS
        dc.b $EC,$00                                         ; $F18E unconfirmed: LDD $0,X
        dc.b $8D,$05                                         ; $F190 unconfirmed: BSR $f197
        dc.b $C4,$F0                                         ; $F192 unconfirmed: ANDB #$f0
        dc.b $1B                                             ; $F194 unconfirmed: ABA
        dc.b $16                                             ; $F195 unconfirmed: TAB
        dc.b $39                                             ; $F196 unconfirmed: RTS
        dc.b $44                                             ; $F197 unconfirmed: LSRA
        dc.b $44                                             ; $F198 unconfirmed: LSRA
        dc.b $44                                             ; $F199 unconfirmed: LSRA
        dc.b $44                                             ; $F19A unconfirmed: LSRA
        dc.b $39                                             ; $F19B unconfirmed: RTS
        dc.b $01,$01,$01,$01,$00,$01,$01,$01,$01,$02,$01,$01,$01,$01,$03,$01 ; $F19C data/unclassified
        dc.b $01,$01,$01,$04,$01,$01,$01,$01,$05,$01,$02,$02,$01,$00,$01,$03 ; $F1AC data/unclassified
        dc.b $03,$01,$00,$01,$04,$04,$01,$00,$01,$05,$05,$01,$00,$02,$01,$01 ; $F1BC data/unclassified
        dc.b $02,$00,$03,$01,$01,$03,$00,$04,$01,$01,$04,$00,$05,$01,$01,$05 ; $F1CC data/unclassified
        dc.b $00,$02,$02,$02,$01,$00,$02,$02,$02,$01,$04,$02,$02,$02,$01,$06 ; $F1DC data/unclassified
        dc.b $02,$02,$02,$01,$08,$02,$02,$02,$01,$0A,$02,$01,$01,$01,$00,$02 ; $F1EC data/unclassified
        dc.b $03,$03,$01,$00,$02,$04,$04,$01,$00,$02,$05,$05,$01,$00,$04,$01 ; $F1FC data/unclassified
        dc.b $01,$02,$00,$06,$01,$01,$03,$00,$08,$01,$01,$04,$00,$0A,$01,$01 ; $F20C data/unclassified
        dc.b $05,$00,$03,$03,$03,$01,$00,$04,$04,$04,$01,$00,$05,$05,$05,$01 ; $F21C data/unclassified
        dc.b $00,$06,$06,$06,$01,$00,$07,$07,$07,$01,$00,$08,$08,$08,$01,$00 ; $F22C data/unclassified
        dc.b $09,$09,$09,$01,$00,$0C,$0C,$0C,$01,$00,$0E,$0E,$0E,$01,$00,$01 ; $F23C data/unclassified
        dc.b $01,$01,$02,$00,$01,$01,$01,$02,$04,$01,$01,$01,$02,$06,$01,$01 ; $F24C data/unclassified
        dc.b $01,$02,$08,$01,$01,$01,$02,$0A,$01,$02,$02,$02,$00,$01,$04,$04 ; $F25C data/unclassified
        dc.b $02,$00,$01,$06,$06,$02,$00,$01,$08,$08,$02,$00,$01,$0A,$0A,$02 ; $F26C data/unclassified
        dc.b $00,$03,$02,$02,$06,$00,$02,$01,$01,$04,$00,$05,$02,$02,$0A,$00 ; $F27C data/unclassified
        dc.b $03,$03,$03,$02,$0C,$03,$03,$03,$02,$12,$03,$03,$03,$02,$18,$03 ; $F28C data/unclassified
        dc.b $03,$03,$01,$06,$04,$04,$04,$01,$08,$05,$05,$05,$01,$0A,$01,$01 ; $F29C data/unclassified
        dc.b $01,$03,$00,$01,$01,$01,$03,$06,$01,$01,$01,$03,$09,$01,$01,$01 ; $F2AC data/unclassified
        dc.b $03,$0C,$01,$01,$01,$03,$0F,$02,$02,$02,$03,$00,$02,$02,$02,$03 ; $F2BC data/unclassified
        dc.b $0C,$02,$02,$02,$03,$12,$02,$02,$02,$03,$18,$02,$02,$02,$03,$1E ; $F2CC data/unclassified
        dc.b $05,$05,$05,$03,$00,$01,$01,$01,$04,$00,$03,$03,$03,$04,$00,$01 ; $F2DC data/unclassified
        dc.b $01,$01,$05,$00,$02,$02,$02,$05,$00,$03,$03,$03,$05,$00,$04,$04 ; $F2EC data/unclassified
        dc.b $04,$05,$00,$01,$00,$06,$01,$00,$00,$06,$03,$01,$00,$01,$06,$0E ; $F2FC data/unclassified
        dc.b $02,$00,$01,$02,$05,$01,$00,$01,$03,$0A,$01,$00,$04,$00,$01,$01 ; $F30C data/unclassified
        dc.b $00,$00,$01,$02,$02,$00,$02,$04,$0C,$01,$00     ; $F31C data/unclassified
        dc.b $CE,$10,$46                                     ; $F327 unconfirmed: LDX #$1046
        dc.b $A6,$00                                         ; $F32A unconfirmed: LDAA $0,X
        dc.b $A7,$2A                                         ; $F32C unconfirmed: STAA $2a,X
        dc.b $08                                             ; $F32E unconfirmed: INX
        dc.b $8C,$10,$62                                     ; $F32F unconfirmed: CPX #$1062
        dc.b $26,$F6                                         ; $F332 unconfirmed: BNE $f32a
        dc.b $39                                             ; $F334 unconfirmed: RTS
        dc.b $CE,$AA,$AA                                     ; $F335 unconfirmed: LDX #$aaaa
        dc.b $FF,$00,$83                                     ; $F338 unconfirmed: STX.w $0083
        dc.b $FF,$00,$85                                     ; $F33B unconfirmed: STX.w $0085
        dc.b $7E,$F6,$86                                     ; $F33E unconfirmed: JMP $f686
        dc.b $CE,$10,$46                                     ; $F341 unconfirmed: LDX #$1046
        dc.b $A6,$2A                                         ; $F344 unconfirmed: LDAA $2a,X
        dc.b $A7,$00                                         ; $F346 unconfirmed: STAA $0,X
        dc.b $08                                             ; $F348 unconfirmed: INX
        dc.b $8C,$10,$62                                     ; $F349 unconfirmed: CPX #$1062
        dc.b $26,$F6                                         ; $F34C unconfirmed: BNE $f344
        dc.b $39                                             ; $F34E unconfirmed: RTS
        dc.b $B6,$C0,$B7,$BB,$C0,$B8,$43,$97,$42,$3F,$54,$54,$54 ; $F34F data/unclassified
        dc.b $54                                             ; $F35C unconfirmed: LSRB
        dc.b $54                                             ; $F35D unconfirmed: LSRB
        dc.b $54                                             ; $F35E unconfirmed: LSRB
        dc.b $54                                             ; $F35F unconfirmed: LSRB
        dc.b $58                                             ; $F360 unconfirmed: ASLB
        dc.b $3A                                             ; $F361 unconfirmed: ABX
        dc.b $BD,$F4,$DF                                     ; $F362 unconfirmed: JSR CHECK_SCORE_GATE_LAMP_BITS
        dc.b $26,$1C                                         ; $F365 unconfirmed: BNE $f383
        dc.b $EE,$00                                         ; $F367 unconfirmed: LDX $0,X
        dc.b $6E,$00                                         ; $F369 unconfirmed: JMP $0,X
        dc.b $8D,$1F,$C6,$0E,$BD,$F5,$B9,$8D,$02,$26,$F5,$FE,$00,$94,$26,$08 ; $F36B data/unclassified
        dc.b $FE,$00,$96,$26,$03,$FE,$00,$98                 ; $F37B data/unclassified
        dc.b $39                                             ; $F383 unconfirmed: RTS
        dc.b $8D,$F0,$27,$FB,$8D,$07,$20,$F8                 ; $F384 data/unclassified
APPLY_PENDING_SCORE:
; Apply the pending score in 0094-0099 to the active player's displayed score over successive main-loop passes.
        LDAA $100f                   ; $F38C: $B6,$10,$0F
        BNE $f3a4                    ; $F38F: $26,$13
        LDAA.w $009a                 ; $F391: $B6,$00,$9A
        ANDA #$22                    ; $F394: $84,$22
        BEQ $f3a5                    ; $F396: $27,$0D
        LDX #$0                      ; $F398: $CE,$00,$00
        STX.w PENDING_SCORE_10S      ; $F39B: $FF,$00,$94
        STX.w PENDING_SCORE_1000S    ; $F39E: $FF,$00,$96
        STX.w PENDING_SCORE_100000S  ; $F3A1: $FF,$00,$98
        RTS                          ; $F3A4: $39
        LDAA.w PENDING_SCORE_10S     ; $F3A5: $B6,$00,$94
        BEQ $f3b7                    ; $F3A8: $27,$0D
        DEC.w PENDING_SCORE_10S      ; $F3AA: $7A,$00,$94
        LDAA #$0                     ; $F3AD: $86,$00
        JSR $f4b5                    ; $F3AF: $BD,$F4,$B5
        LDX #$10                     ; $F3B2: $CE,$00,$10
        BRA $f411                    ; $F3B5: $20,$5A
        LDAA.w PENDING_SCORE_100S    ; $F3B7: $B6,$00,$95
        BEQ $f3c9                    ; $F3BA: $27,$0D
        DEC.w PENDING_SCORE_100S     ; $F3BC: $7A,$00,$95
        LDAA #$1                     ; $F3BF: $86,$01
        JSR $f4b5                    ; $F3C1: $BD,$F4,$B5
        LDX #$100                    ; $F3C4: $CE,$01,$00
        BRA $f411                    ; $F3C7: $20,$48
        LDAA.w PENDING_SCORE_1000S   ; $F3C9: $B6,$00,$96
        BEQ $f3db                    ; $F3CC: $27,$0D
        DEC.w PENDING_SCORE_1000S    ; $F3CE: $7A,$00,$96
        LDAA #$2                     ; $F3D1: $86,$02
        JSR $f4b5                    ; $F3D3: $BD,$F4,$B5
        LDX #$1000                   ; $F3D6: $CE,$10,$00
        BRA $f411                    ; $F3D9: $20,$36
        LDAA.w PENDING_SCORE_10000S  ; $F3DB: $B6,$00,$97
        BEQ $f3ed                    ; $F3DE: $27,$0D
        DEC.w PENDING_SCORE_10000S   ; $F3E0: $7A,$00,$97
        LDAA #$3                     ; $F3E3: $86,$03
        JSR $f4b5                    ; $F3E5: $BD,$F4,$B5
        LDX #$1                      ; $F3E8: $CE,$00,$01
        BRA $f41c                    ; $F3EB: $20,$2F
        LDAA.w PENDING_SCORE_100000S ; $F3ED: $B6,$00,$98
        BEQ $f3ff                    ; $F3F0: $27,$0D
        DEC.w PENDING_SCORE_100000S  ; $F3F2: $7A,$00,$98
        LDAA #$4                     ; $F3F5: $86,$04
        JSR $f4b5                    ; $F3F7: $BD,$F4,$B5
        LDX #$10                     ; $F3FA: $CE,$00,$10
        BRA $f41c                    ; $F3FD: $20,$1D
        LDAA.w PENDING_SCORE_1000000S ; $F3FF: $B6,$00,$99
        BEQ $f3a4                    ; $F402: $27,$A0
        DEC.w PENDING_SCORE_1000000S ; $F404: $7A,$00,$99
        LDAA #$5                     ; $F407: $86,$05
        JSR $f4b5                    ; $F409: $BD,$F4,$B5
        LDX #$100                    ; $F40C: $CE,$01,$00
        BRA $f41c                    ; $F40F: $20,$0B
        CLR.w $0087                  ; $F411: $7F,$00,$87
        CLR.w $0088                  ; $F414: $7F,$00,$88
        STX.w $0089                  ; $F417: $FF,$00,$89
        BRA $f425                    ; $F41A: $20,$09
        CLR.w $0089                  ; $F41C: $7F,$00,$89
        CLR.w $008a                  ; $F41F: $7F,$00,$8A
        STX.w $0087                  ; $F422: $FF,$00,$87
        LDX $101b                    ; $F425: $FE,$10,$1B
        JSR $f638                    ; $F428: $BD,$F6,$38
        JSR $f614                    ; $F42B: $BD,$F6,$14
        LDX $101b                    ; $F42E: $FE,$10,$1B
        JSR $f698                    ; $F431: $BD,$F6,$98
        LDAA #$c                     ; $F434: $86,$0C
        STAA $100f                   ; $F436: $B7,$10,$0F
        LDAA.w $009a                 ; $F439: $B6,$00,$9A
        ORAA #$80                    ; $F43C: $8A,$80
        STAA.w $009a                 ; $F43E: $B7,$00,$9A
        CLR $100a                    ; $F441: $7F,$10,$0A
        CLR $1009                    ; $F444: $7F,$10,$09
        LDAB #$1                     ; $F447: $C6,$01
        LDAA.w $0083                 ; $F449: $B6,$00,$83
        ANDA #$f0                    ; $F44C: $84,$F0
        BEQ $f455                    ; $F44E: $27,$05
        LDX $c090                    ; $F450: $FE,$C0,$90
        JMP $0,X                     ; $F453: $6E,$00
        LDX #$1603                   ; $F455: $CE,$16,$03
        ASLB                         ; $F458: $58
        BSR $f46d                    ; $F459: $8D,$12
        BCS $f468                    ; $F45B: $25,$0B
        ASLB                         ; $F45D: $58
        BSR $f46d                    ; $F45E: $8D,$0D
        BCS $f468                    ; $F460: $25,$06
        ASLB                         ; $F462: $58
        BSR $f46d                    ; $F463: $8D,$08
        BCS $f468                    ; $F465: $25,$01
        RTS                          ; $F467: $39
        LDX $c07d                    ; $F468: $FE,$C0,$7D
        JMP $0,X                     ; $F46B: $6E,$00
        dc.b $37                                             ; $F46D unconfirmed: PSHB
        dc.b $FF,$00,$8B                                     ; $F46E unconfirmed: STX.w $008b
        dc.b $FE,$C0,$7B                                     ; $F471 unconfirmed: LDX $c07b
        dc.b $6E,$00                                         ; $F474 unconfirmed: JMP $0,X
        dc.b $FE,$10,$1B                                     ; $F476 unconfirmed: LDX $101b
        dc.b $BD,$F6,$38                                     ; $F479 unconfirmed: JSR $f638
        dc.b $BD,$F6,$68                                     ; $F47C unconfirmed: JSR $f668
        dc.b $FE,$00,$8B                                     ; $F47F unconfirmed: LDX.w $008b
        dc.b $BD,$F6,$38                                     ; $F482 unconfirmed: JSR $f638
        dc.b $33                                             ; $F485 unconfirmed: PULB
        dc.b $FF,$00,$8B                                     ; $F486 unconfirmed: STX.w $008b
        dc.b $BD,$F9,$D2                                     ; $F489 unconfirmed: JSR $f9d2
        dc.b $27,$13                                         ; $F48C unconfirmed: BEQ $f4a1
        dc.b $FE,$10,$1D                                     ; $F48E unconfirmed: LDX $101d
        dc.b $E5,$00                                         ; $F491 unconfirmed: BITB $0,X
        dc.b $26,$0C                                         ; $F493 unconfirmed: BNE $f4a1
        dc.b $37                                             ; $F495 unconfirmed: PSHB
        dc.b $BD,$F6,$26                                     ; $F496 unconfirmed: JSR $f626
        dc.b $24,$0B                                         ; $F499 unconfirmed: BCC $f4a6
        dc.b $BD,$F9,$D2                                     ; $F49B unconfirmed: JSR $f9d2
        dc.b $27,$06                                         ; $F49E unconfirmed: BEQ $f4a6
        dc.b $33                                             ; $F4A0 unconfirmed: PULB
        dc.b $FE,$00,$8B                                     ; $F4A1 unconfirmed: LDX.w $008b
        dc.b $0C                                             ; $F4A4 unconfirmed: CLC
        dc.b $39                                             ; $F4A5 unconfirmed: RTS
        dc.b $33                                             ; $F4A6 unconfirmed: PULB
        dc.b $17                                             ; $F4A7 unconfirmed: TBA
        dc.b $FE,$10,$1D                                     ; $F4A8 unconfirmed: LDX $101d
        dc.b $EA,$00                                         ; $F4AB unconfirmed: ORAB $0,X
        dc.b $E7,$00                                         ; $F4AD unconfirmed: STAB $0,X
        dc.b $16                                             ; $F4AF unconfirmed: TAB
        dc.b $FE,$00,$8B                                     ; $F4B0 unconfirmed: LDX.w $008b
        dc.b $0D                                             ; $F4B3 unconfirmed: SEC
        dc.b $39                                             ; $F4B4 unconfirmed: RTS
        dc.b $FE,$C0,$89                                     ; $F4B5 unconfirmed: LDX $c089
        dc.b $6E,$00                                         ; $F4B8 unconfirmed: JMP $0,X
        dc.b $CE,$10,$46                                     ; $F4BA unconfirmed: LDX #$1046
        dc.b $B6,$00,$8F                                     ; $F4BD unconfirmed: LDAA.w $008f
        dc.b $27,$08                                         ; $F4C0 unconfirmed: BEQ $f4ca
        dc.b $4A                                             ; $F4C2 unconfirmed: DECA
        dc.b $27,$05                                         ; $F4C3 unconfirmed: BEQ $f4ca
        dc.b $BD,$F8,$21                                     ; $F4C5 unconfirmed: JSR $f821
        dc.b $20,$F8                                         ; $F4C8 unconfirmed: BRA $f4c2
        dc.b $FF,$10,$1B                                     ; $F4CA unconfirmed: STX $101b
        dc.b $CE,$00,$90                                     ; $F4CD unconfirmed: LDX #$90
        dc.b $B6,$00,$8F                                     ; $F4D0 unconfirmed: LDAA.w $008f
        dc.b $27,$06                                         ; $F4D3 unconfirmed: BEQ $f4db
        dc.b $4A                                             ; $F4D5 unconfirmed: DECA
        dc.b $27,$03                                         ; $F4D6 unconfirmed: BEQ $f4db
        dc.b $08                                             ; $F4D8 unconfirmed: INX
        dc.b $20,$FA                                         ; $F4D9 unconfirmed: BRA $f4d5
        dc.b $FF,$10,$1D                                     ; $F4DB unconfirmed: STX $101d
        dc.b $39                                             ; $F4DE unconfirmed: RTS
CHECK_SCORE_GATE_LAMP_BITS:
; Common score-handler gate: return Z set only when bits 7 and 6 of lamp-shadow byte 103A are both set. This is used by the Rebound handler and another table dispatcher; do not infer physical lamp names without completing the schematic trace.
        LDAB LAMP_SHADOW_BANK_A_BYTE0 ; $F4DF: $F6,$10,$3A
        COMB                         ; $F4E2: $53
        ANDB #$c0                    ; $F4E3: $C4,$C0
        RTS                          ; $F4E5: $39
        dc.b $B6,$00,$8E,$8B,$10,$B7,$00,$8E                 ; $F4E6 data/unclassified
        dc.b $B6,$00,$8E                                     ; $F4EE unconfirmed: LDAA.w $008e
        dc.b $84,$F0                                         ; $F4F1 unconfirmed: ANDA #$f0
        dc.b $B7,$10,$69                                     ; $F4F3 unconfirmed: STAA $1069
        dc.b $86,$FF                                         ; $F4F6 unconfirmed: LDAA #$ff
        dc.b $B7,$10,$6A                                     ; $F4F8 unconfirmed: STAA $106a
        dc.b $86,$40                                         ; $F4FB unconfirmed: LDAA #$40
        dc.b $7E,$F5,$6B                                     ; $F4FD unconfirmed: JMP $f56b
        dc.b $3C,$33,$37,$C4,$7F,$11,$23,$05,$50,$1B,$0D,$20,$01,$0C,$38,$36 ; $F500 data/unclassified
        dc.b $3C,$32,$36,$84,$7F,$24,$01,$4A,$36,$38,$33,$3C,$32,$CE,$10,$3A ; $F510 data/unclassified
        dc.b $3A,$3C,$81,$08,$23,$09,$6F,$00,$63,$00,$08,$80,$08,$20,$F3,$5F ; $F520 data/unclassified
        dc.b $0D,$59,$4A,$26,$FB,$EA,$00,$E7,$00,$38,$33,$32,$4D,$27,$19,$5D ; $F530 data/unclassified
        dc.b $2B,$17,$81,$08,$23,$07,$63,$00,$08,$80,$08,$20,$F5,$C6,$FF,$0C ; $F540 data/unclassified
        dc.b $59,$4A,$26,$FB,$E4,$00,$E7,$00,$39,$81,$08,$23,$05,$80,$08,$08 ; $F550 data/unclassified
        dc.b $20,$F7,$C6,$FF,$0C,$59,$4A,$26,$FC,$20,$E9     ; $F560 data/unclassified
        dc.b $3C                                             ; $F56B unconfirmed: PSHX
        dc.b $37                                             ; $F56C unconfirmed: PSHB
        dc.b $CE,$10,$3A                                     ; $F56D unconfirmed: LDX #$103a
        dc.b $16                                             ; $F570 unconfirmed: TAB
        dc.b $84,$70                                         ; $F571 unconfirmed: ANDA #$70
        dc.b $C4,$0F                                         ; $F573 unconfirmed: ANDB #$f
        dc.b $C1,$0B                                         ; $F575 unconfirmed: CMPB #$b
        dc.b $23,$04                                         ; $F577 unconfirmed: BLS $f57d
        dc.b $C0,$0B                                         ; $F579 unconfirmed: SUBB #$b
        dc.b $20,$F8                                         ; $F57B unconfirmed: BRA $f575
        dc.b $3A                                             ; $F57D unconfirmed: ABX
        dc.b $44                                             ; $F57E unconfirmed: LSRA
        dc.b $44                                             ; $F57F unconfirmed: LSRA
        dc.b $44                                             ; $F580 unconfirmed: LSRA
        dc.b $44                                             ; $F581 unconfirmed: LSRA
        dc.b $4C                                             ; $F582 unconfirmed: INCA
        dc.b $C6,$FF                                         ; $F583 unconfirmed: LDAB #$ff
        dc.b $0C                                             ; $F585 unconfirmed: CLC
        dc.b $59                                             ; $F586 unconfirmed: ROLB
        dc.b $4A                                             ; $F587 unconfirmed: DECA
        dc.b $26,$FC                                         ; $F588 unconfirmed: BNE $f586
        dc.b $E4,$00                                         ; $F58A unconfirmed: ANDB $0,X
        dc.b $E7,$00                                         ; $F58C unconfirmed: STAB $0,X
        dc.b $33                                             ; $F58E unconfirmed: PULB
        dc.b $38                                             ; $F58F unconfirmed: PULX
        dc.b $39                                             ; $F590 unconfirmed: RTS
        dc.b $3C                                             ; $F591 unconfirmed: PSHX
        dc.b $37                                             ; $F592 unconfirmed: PSHB
        dc.b $CE,$10,$3A                                     ; $F593 unconfirmed: LDX #$103a
        dc.b $16                                             ; $F596 unconfirmed: TAB
        dc.b $84,$70                                         ; $F597 unconfirmed: ANDA #$70
        dc.b $C4,$0F                                         ; $F599 unconfirmed: ANDB #$f
        dc.b $C1,$0B                                         ; $F59B unconfirmed: CMPB #$b
        dc.b $23,$04                                         ; $F59D unconfirmed: BLS $f5a3
        dc.b $C0,$0B                                         ; $F59F unconfirmed: SUBB #$b
        dc.b $20,$F8                                         ; $F5A1 unconfirmed: BRA $f59b
        dc.b $3A                                             ; $F5A3 unconfirmed: ABX
        dc.b $44                                             ; $F5A4 unconfirmed: LSRA
        dc.b $44                                             ; $F5A5 unconfirmed: LSRA
        dc.b $44                                             ; $F5A6 unconfirmed: LSRA
        dc.b $44                                             ; $F5A7 unconfirmed: LSRA
        dc.b $4C                                             ; $F5A8 unconfirmed: INCA
        dc.b $5F                                             ; $F5A9 unconfirmed: CLRB
        dc.b $0D                                             ; $F5AA unconfirmed: SEC
        dc.b $59                                             ; $F5AB unconfirmed: ROLB
        dc.b $4A                                             ; $F5AC unconfirmed: DECA
        dc.b $26,$FC                                         ; $F5AD unconfirmed: BNE $f5ab
        dc.b $EA,$00                                         ; $F5AF unconfirmed: ORAB $0,X
        dc.b $20,$D9                                         ; $F5B1 unconfirmed: BRA $f58c
        dc.b $C6,$0C                                         ; $F5B3 unconfirmed: LDAB #$c
        dc.b $20,$02                                         ; $F5B5 unconfirmed: BRA $f5b9
        dc.b $C6,$03                                         ; $F5B7 unconfirmed: LDAB #$3
        dc.b $F7,$10,$0E                                     ; $F5B9 unconfirmed: STAB $100e
        dc.b $F6,$10,$0E                                     ; $F5BC unconfirmed: LDAB $100e
        dc.b $26,$FB                                         ; $F5BF unconfirmed: BNE $f5bc
        dc.b $39                                             ; $F5C1 unconfirmed: RTS
PULSE_MOMENTARY_SOLENOID_BLOCKING:
        PSHA                         ; $F5C2: $36
        LDAA.w $009a                 ; $F5C3: $B6,$00,$9A
        ORAA #$10                    ; $F5C6: $8A,$10
        STAA.w $009a                 ; $F5C8: $B7,$00,$9A
        PULA                         ; $F5CB: $32
        PSHB                         ; $F5CC: $37
        BSR MOMENTARY_SOLENOID_PULSE ; $F5CD: $8D,$10
        PULB                         ; $F5CF: $33
        STAB $100d                   ; $F5D0: $F7,$10,$0D
        INCB                         ; $F5D3: $5C
        BSR $f5b9                    ; $F5D4: $8D,$E3
        LDAA.w $009a                 ; $F5D6: $B6,$00,$9A
        ANDA #$ef                    ; $F5D9: $84,$EF
        STAA.w $009a                 ; $F5DB: $B7,$00,$9A
        RTS                          ; $F5DE: $39
MOMENTARY_SOLENOID_PULSE:
; Momentary-solenoid pulse helper: A bits 0-3 select U14 M0-M15 through PIA1 PB10-PB13; A bit 7 selects CB12's bank; starts the four-tick pulse timer at 100D.
        LDAB #$34                    ; $F5DF: $C6,$34
        TSTA                         ; $F5E1: $4D
        BPL $f5e6                    ; $F5E2: $2A,$02
        ORAB #$8                     ; $F5E4: $CA,$08
        STAB PIA1_CRB                ; $F5E6: $D7,$43
; I/O: PIA1 control register B. Its CB2 output is CB12, the momentary-solenoid bank select.
; PIA mode: Both 34 and 3C keep CRB bit 2 set, selecting PIA1 port-B peripheral data; bit 3 controls CB12.
        ANDA #$f                     ; $F5E8: $84,$0F
        LDAB PIA1_PORTB_OR_DDRB      ; $F5EA: $D6,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
; PIA mode: PIA1 CRB bit 2 is set; this reads port-B peripheral data so the upper nibble can be preserved.
        ANDB #$f0                    ; $F5EC: $C4,$F0
        ABA                          ; $F5EE: $1B
        LDAB #$4                     ; $F5EF: $C6,$04
        STAB $100d                   ; $F5F1: $F7,$10,$0D
        STAA PIA1_PORTB_OR_DDRB      ; $F5F4: $97,$42
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
; PIA mode: PIA1 CRB bit 2 is set; this writes the momentary-solenoid selector through port B.
        RTS                          ; $F5F6: $39
        dc.b $B6,$00,$9A,$8A,$82,$B7,$00,$9A,$86,$70         ; $F5F7 data/unclassified
        dc.b $BD,$F5,$6B                                     ; $F601 unconfirmed: JSR $f56b
        dc.b $86,$BF                                         ; $F604 unconfirmed: LDAA #$bf
        dc.b $20,$06                                         ; $F606 unconfirmed: BRA $f60e
        dc.b $86,$BF                                         ; $F608 unconfirmed: LDAA #$bf
        dc.b $94,$42                                         ; $F60A unconfirmed: ANDA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $20,$03                                         ; $F60C unconfirmed: BRA $f611
        dc.b $43                                             ; $F60E unconfirmed: COMA
        dc.b $9A,$42                                         ; $F60F unconfirmed: ORAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $97,$42                                         ; $F611 unconfirmed: STAA PIA1_PORTB_OR_DDRB
; I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.
        dc.b $39                                             ; $F613 unconfirmed: RTS
        dc.b $0C                                             ; $F614 unconfirmed: CLC
        dc.b $C6,$04                                         ; $F615 unconfirmed: LDAB #$4
        dc.b $CE,$00,$86                                     ; $F617 unconfirmed: LDX #$86
        dc.b $A6,$00                                         ; $F61A unconfirmed: LDAA $0,X
        dc.b $A9,$04                                         ; $F61C unconfirmed: ADCA $4,X
        dc.b $19                                             ; $F61E unconfirmed: DAA
        dc.b $A7,$00                                         ; $F61F unconfirmed: STAA $0,X
        dc.b $09                                             ; $F621 unconfirmed: DEX
        dc.b $5A                                             ; $F622 unconfirmed: DECB
        dc.b $26,$F5                                         ; $F623 unconfirmed: BNE $f61a
        dc.b $39                                             ; $F625 unconfirmed: RTS
        dc.b $CE,$00,$86                                     ; $F626 unconfirmed: LDX #$86
        dc.b $86,$99                                         ; $F629 unconfirmed: LDAA #$99
        dc.b $A0,$04                                         ; $F62B unconfirmed: SUBA $4,X
        dc.b $A7,$04                                         ; $F62D unconfirmed: STAA $4,X
        dc.b $09                                             ; $F62F unconfirmed: DEX
        dc.b $8C,$00,$82                                     ; $F630 unconfirmed: CPX #$82
        dc.b $26,$F4                                         ; $F633 unconfirmed: BNE $f629
        dc.b $0D                                             ; $F635 unconfirmed: SEC
        dc.b $20,$DD                                         ; $F636 unconfirmed: BRA $f615
        dc.b $8D,$16                                         ; $F638 unconfirmed: BSR $f650
        dc.b $B7,$00,$86                                     ; $F63A unconfirmed: STAA.w $0086
        dc.b $8D,$11                                         ; $F63D unconfirmed: BSR $f650
        dc.b $B7,$00,$85                                     ; $F63F unconfirmed: STAA.w $0085
        dc.b $8D,$0C                                         ; $F642 unconfirmed: BSR $f650
        dc.b $B7,$00,$84                                     ; $F644 unconfirmed: STAA.w $0084
        dc.b $8D,$07                                         ; $F647 unconfirmed: BSR $f650
        dc.b $84,$0F                                         ; $F649 unconfirmed: ANDA #$f
        dc.b $B7,$00,$83                                     ; $F64B unconfirmed: STAA.w $0083
        dc.b $09                                             ; $F64E unconfirmed: DEX
        dc.b $39                                             ; $F64F unconfirmed: RTS
        dc.b $A6,$00                                         ; $F650 unconfirmed: LDAA $0,X
        dc.b $44                                             ; $F652 unconfirmed: LSRA
        dc.b $44                                             ; $F653 unconfirmed: LSRA
        dc.b $44                                             ; $F654 unconfirmed: LSRA
        dc.b $44                                             ; $F655 unconfirmed: LSRA
        dc.b $81,$09                                         ; $F656 unconfirmed: CMPA #$9
        dc.b $23,$01                                         ; $F658 unconfirmed: BLS $f65b
        dc.b $4F                                             ; $F65A unconfirmed: CLRA
        dc.b $08                                             ; $F65B unconfirmed: INX
        dc.b $E6,$00                                         ; $F65C unconfirmed: LDAB $0,X
        dc.b $C4,$F0                                         ; $F65E unconfirmed: ANDB #$f0
        dc.b $C1,$90                                         ; $F660 unconfirmed: CMPB #$90
        dc.b $23,$01                                         ; $F662 unconfirmed: BLS $f665
        dc.b $5F                                             ; $F664 unconfirmed: CLRB
        dc.b $08                                             ; $F665 unconfirmed: INX
        dc.b $1B                                             ; $F666 unconfirmed: ABA
        dc.b $39                                             ; $F667 unconfirmed: RTS
        dc.b $FE,$00,$83                                     ; $F668 unconfirmed: LDX.w $0083
        dc.b $FF,$00,$87                                     ; $F66B unconfirmed: STX.w $0087
        dc.b $FE,$00,$85                                     ; $F66E unconfirmed: LDX.w $0085
        dc.b $FF,$00,$89                                     ; $F671 unconfirmed: STX.w $0089
        dc.b $39                                             ; $F674 unconfirmed: RTS
        dc.b $4F                                             ; $F675 unconfirmed: CLRA
        dc.b $B7,$00,$83                                     ; $F676 unconfirmed: STAA.w $0083
        dc.b $B7,$00,$84                                     ; $F679 unconfirmed: STAA.w $0084
        dc.b $B7,$00,$85                                     ; $F67C unconfirmed: STAA.w $0085
        dc.b $B7,$00,$86                                     ; $F67F unconfirmed: STAA.w $0086
        dc.b $39                                             ; $F682 unconfirmed: RTS
        dc.b $BD,$F6,$38                                     ; $F683 unconfirmed: JSR $f638
        dc.b $CE,$10,$5B                                     ; $F686 unconfirmed: LDX #$105b
        dc.b $8D,$04                                         ; $F689 unconfirmed: BSR $f68f
        dc.b $8D,$02                                         ; $F68B unconfirmed: BSR $f68f
        dc.b $8D,$00                                         ; $F68D unconfirmed: BSR $f68f
        dc.b $20,$07                                         ; $F68F unconfirmed: BRA $f698
        dc.b $8D,$E2,$8D,$F1,$FE,$10,$1B                     ; $F691 data/unclassified
        dc.b $5F                                             ; $F698 unconfirmed: CLRB
        dc.b $B6,$00,$83                                     ; $F699 unconfirmed: LDAA.w $0083
        dc.b $8D,$10                                         ; $F69C unconfirmed: BSR $f6ae
        dc.b $B6,$00,$84                                     ; $F69E unconfirmed: LDAA.w $0084
        dc.b $8D,$09                                         ; $F6A1 unconfirmed: BSR $f6ac
        dc.b $B6,$00,$85                                     ; $F6A3 unconfirmed: LDAA.w $0085
        dc.b $8D,$04                                         ; $F6A6 unconfirmed: BSR $f6ac
        dc.b $5C                                             ; $F6A8 unconfirmed: INCB
        dc.b $B6,$00,$86                                     ; $F6A9 unconfirmed: LDAA.w $0086
        dc.b $8D,$04                                         ; $F6AC unconfirmed: BSR $f6b2
        dc.b $48                                             ; $F6AE unconfirmed: ASLA
        dc.b $48                                             ; $F6AF unconfirmed: ASLA
        dc.b $48                                             ; $F6B0 unconfirmed: ASLA
        dc.b $48                                             ; $F6B1 unconfirmed: ASLA
        dc.b $5D                                             ; $F6B2 unconfirmed: TSTB
        dc.b $26,$09                                         ; $F6B3 unconfirmed: BNE $f6be
        dc.b $85,$F0                                         ; $F6B5 unconfirmed: BITA #$f0
        dc.b $27,$03                                         ; $F6B7 unconfirmed: BEQ $f6bc
        dc.b $5C                                             ; $F6B9 unconfirmed: INCB
        dc.b $20,$02                                         ; $F6BA unconfirmed: BRA $f6be
        dc.b $8A,$F0                                         ; $F6BC unconfirmed: ORAA #$f0
        dc.b $A7,$06                                         ; $F6BE unconfirmed: STAA $6,X
        dc.b $09                                             ; $F6C0 unconfirmed: DEX
        dc.b $39                                             ; $F6C1 unconfirmed: RTS
        dc.b $8D,$0F,$BD,$F6,$26,$20,$05                     ; $F6C2 data/unclassified
        dc.b $8D,$08                                         ; $F6C9 unconfirmed: BSR $f6d3
        dc.b $BD,$F6,$14                                     ; $F6CB unconfirmed: JSR $f614
        dc.b $FE,$00,$8B                                     ; $F6CE unconfirmed: LDX.w $008b
        dc.b $20,$C5                                         ; $F6D1 unconfirmed: BRA $f698
        dc.b $FF,$00,$8B                                     ; $F6D3 unconfirmed: STX.w $008b
        dc.b $BD,$F6,$38                                     ; $F6D6 unconfirmed: JSR $f638
        dc.b $CE,$00,$01                                     ; $F6D9 unconfirmed: LDX #$1
        dc.b $FF,$00,$89                                     ; $F6DC unconfirmed: STX.w $0089
        dc.b $7F,$00,$87                                     ; $F6DF unconfirmed: CLR.w $0087
        dc.b $7F,$00,$88                                     ; $F6E2 unconfirmed: CLR.w $0088
        dc.b $39                                             ; $F6E5 unconfirmed: RTS
        dc.b $CE,$16,$27,$BD,$F6,$C2,$CE,$16,$35,$BD,$F6,$C9,$86,$0A,$8D,$14 ; $F6E6 data/unclassified
        dc.b $20,$1F,$8D,$42,$24,$0D,$FE,$C0,$85,$AD,$00,$CE,$16,$20,$BD,$F6 ; $F6F6 data/unclassified
        dc.b $C9,$20,$08,$39                                 ; $F706 data/unclassified
        dc.b $7E,$C2,$8D                                     ; $F70A unconfirmed: JMP $c28d
        dc.b $86,$08                                         ; $F70D unconfirmed: LDAA #$8
        dc.b $8D,$F9                                         ; $F70F unconfirmed: BSR $f70a
        dc.b $CE,$16,$27                                     ; $F711 unconfirmed: LDX #$1627
        dc.b $BD,$F6,$C9                                     ; $F714 unconfirmed: JSR $f6c9
        dc.b $86,$30                                         ; $F717 unconfirmed: LDAA #$30
        dc.b $BD,$F5,$91                                     ; $F719 unconfirmed: JSR $f591
        dc.b $8D,$3C                                         ; $F71C unconfirmed: BSR $f75a
        dc.b $27,$09                                         ; $F71E unconfirmed: BEQ $f729
        dc.b $86,$30                                         ; $F720 unconfirmed: LDAA #$30
        dc.b $BD,$F5,$6B                                     ; $F722 unconfirmed: JSR $f56b
        dc.b $8D,$15                                         ; $F725 unconfirmed: BSR $f73c
        dc.b $24,$25                                         ; $F727 unconfirmed: BCC $f74e
        dc.b $B6,$16,$8B                                     ; $F729 unconfirmed: LDAA $168b
        dc.b $84,$20                                         ; $F72C unconfirmed: ANDA #$20
        dc.b $26,$05                                         ; $F72E unconfirmed: BNE $f735
        dc.b $CE,$FF,$FF                                     ; $F730 unconfirmed: LDX #$ffff
        dc.b $20,$03                                         ; $F733 unconfirmed: BRA $f738
        dc.b $FE,$16,$27                                     ; $F735 unconfirmed: LDX $1627
        dc.b $FF,$10,$6C                                     ; $F738 unconfirmed: STX $106c
        dc.b $39                                             ; $F73B unconfirmed: RTS
        dc.b $8D,$06                                         ; $F73C unconfirmed: BSR $f744
        dc.b $36                                             ; $F73E unconfirmed: PSHA
        dc.b $8D,$19                                         ; $F73F unconfirmed: BSR $f75a
        dc.b $33                                             ; $F741 unconfirmed: PULB
        dc.b $11                                             ; $F742 unconfirmed: CBA
        dc.b $39                                             ; $F743 unconfirmed: RTS
        dc.b $FC,$16,$2E                                     ; $F744 unconfirmed: LDD $162e
        dc.b $C4,$F0                                         ; $F747 unconfirmed: ANDB #$f0
        dc.b $BD,$F1,$97                                     ; $F749 unconfirmed: JSR $f197
        dc.b $1B                                             ; $F74C unconfirmed: ABA
        dc.b $39                                             ; $F74D unconfirmed: RTS
        dc.b $F7,$16,$28                                     ; $F74E unconfirmed: STAB $1628
        dc.b $58                                             ; $F751 unconfirmed: ASLB
        dc.b $58                                             ; $F752 unconfirmed: ASLB
        dc.b $58                                             ; $F753 unconfirmed: ASLB
        dc.b $58                                             ; $F754 unconfirmed: ASLB
        dc.b $F7,$16,$27                                     ; $F755 unconfirmed: STAB $1627
        dc.b $20,$CF                                         ; $F758 unconfirmed: BRA $f729
        dc.b $CE,$16,$27                                     ; $F75A unconfirmed: LDX #$1627
        dc.b $BD,$F6,$38                                     ; $F75D unconfirmed: JSR $f638
        dc.b $B6,$00,$86                                     ; $F760 unconfirmed: LDAA.w $0086
        dc.b $39                                             ; $F763 unconfirmed: RTS
        dc.b $CE,$FF,$FF,$FF,$10,$69,$B6,$10,$3A,$8A,$90,$B7,$10,$3A,$B6,$16 ; $F764 data/unclassified
        dc.b $8B,$84,$10,$27,$77,$86,$20,$BD,$F5,$91,$BD,$F3,$27,$BD,$F3,$35 ; $F774 data/unclassified
        dc.b $CE,$AA,$AA,$FF,$10,$6C,$C6,$0F,$BD,$F5,$B9,$B6,$10,$13,$B7,$10 ; $F784 data/unclassified
        dc.b $69,$86,$04,$B7,$10,$19,$85,$40,$26,$2C,$C6,$01,$BD,$F5,$B9,$4A ; $F794 data/unclassified
        dc.b $26,$F8,$FE,$C0,$92,$BD,$C0,$8D,$B6,$10,$13,$B7,$10,$6A,$B6,$10 ; $F7A4 data/unclassified
        dc.b $69,$84,$F0,$8B,$30,$19,$B7,$10,$69,$B6,$10,$19,$44,$44,$BB,$10 ; $F7B4 data/unclassified
        dc.b $19,$B7,$10,$19,$20,$D0,$7F,$10,$69,$86,$20,$BD,$F5,$6B,$BD,$F3 ; $F7C4 data/unclassified
        dc.b $41,$BD,$F7,$17,$B6,$00,$8E,$84,$0F,$B7,$00,$8E,$7F,$00,$8F,$7C ; $F7D4 data/unclassified
        dc.b $00,$8F,$BD,$F4,$BA,$8D,$0D,$7A,$00,$8E,$26,$F3,$8D,$37,$FE,$C0 ; $F7E4 data/unclassified
        dc.b $87,$7E,$C0,$8D,$FE,$10,$1B,$A6,$01,$84,$F0,$F6,$10,$6A,$C4,$F0 ; $F7F4 data/unclassified
        dc.b $11,$26,$1A,$B6,$16,$8B,$84,$80,$26,$0D,$FE,$10,$1D,$A6,$00,$85 ; $F804 data/unclassified
        dc.b $10,$26,$07,$8A,$10,$A7,$00,$BD,$F6,$F8,$FE,$10,$1B ; $F814 data/unclassified
        dc.b $08                                             ; $F821 unconfirmed: INX
        dc.b $08                                             ; $F822 unconfirmed: INX
        dc.b $08                                             ; $F823 unconfirmed: INX
        dc.b $08                                             ; $F824 unconfirmed: INX
        dc.b $08                                             ; $F825 unconfirmed: INX
        dc.b $08                                             ; $F826 unconfirmed: INX
        dc.b $08                                             ; $F827 unconfirmed: INX
        dc.b $39                                             ; $F828 unconfirmed: RTS
        dc.b $86,$03                                         ; $F829 unconfirmed: LDAA #$3
        dc.b $B7,$10,$11                                     ; $F82B unconfirmed: STAA $1011
        dc.b $B6,$00,$9A                                     ; $F82E unconfirmed: LDAA.w $009a
        dc.b $8A,$20                                         ; $F831 unconfirmed: ORAA #$20
        dc.b $84,$7F                                         ; $F833 unconfirmed: ANDA #$7f
        dc.b $B7,$00,$9A                                     ; $F835 unconfirmed: STAA.w $009a
        dc.b $86,$60                                         ; $F838 unconfirmed: LDAA #$60
        dc.b $7E,$F6,$01                                     ; $F83A unconfirmed: JMP $f601
        dc.b $7C,$00,$8E,$CE,$10,$3F,$B6,$00,$8E,$84,$0F,$27,$09,$8D,$D5,$4A ; $F83D data/unclassified
        dc.b $26,$FB,$6F,$00,$6F,$01,$39,$FE,$C0,$94,$AD,$00,$BD,$F7,$5A,$27 ; $F84D data/unclassified
        dc.b $F5,$B6,$00,$9A,$85,$20,$27,$26,$B6,$00,$9A,$84,$DF,$B7,$00,$9A ; $F85D data/unclassified
        dc.b $FE,$C0,$96,$AD,$00,$8D,$2A,$BD,$EA,$7F,$CE,$00,$00,$FF,$10,$03 ; $F86D data/unclassified
        dc.b $86,$FF,$B7,$10,$14,$BD,$F4,$E6,$7C,$00,$8F,$7E,$F9,$00,$B6,$00 ; $F87D data/unclassified
        dc.b $8E,$84,$F0,$81,$10,$22,$D1,$B6,$00,$8E,$84,$0F,$B1,$C0,$72,$24 ; $F88D data/unclassified
        dc.b $B5,$8D,$9D,$C6,$08,$BD,$F7,$0A,$7E,$F6,$E6,$B6,$10,$3A,$48,$2A ; $F89D data/unclassified
        dc.b $A5,$C6,$2D,$BD,$F5,$B9,$FE,$C0,$98,$AD,$00,$B6,$00,$9A,$84,$80 ; $F8AD data/unclassified
        dc.b $26,$02,$20,$32,$BD,$F3,$84,$FE,$C0,$9A,$AD,$00,$B6,$10,$3A,$84 ; $F8BD data/unclassified
        dc.b $02,$27,$23,$F6,$00,$8E,$17,$C4,$0F,$F1,$00,$8F,$26,$15,$84,$F0 ; $F8CD data/unclassified
        dc.b $BD,$F1,$97,$F6,$16,$1F,$54,$54,$54,$54,$11,$24,$46,$BD,$F4,$E6 ; $F8DD data/unclassified
        dc.b $7F,$00,$8F,$7C,$00,$8F,$BD,$F4,$BA,$FE,$C0,$9C,$AD,$00,$20,$03 ; $F8ED data/unclassified
        dc.b $BD,$F5,$FF,$B6,$10,$33,$BA,$10,$2D,$84,$40,$26,$F3,$B6,$10,$3A ; $F8FD data/unclassified
        dc.b $8A,$C0,$B7,$10,$3A,$B6,$00,$9A,$84,$DD,$B7,$00,$9A,$C6,$FE,$B6 ; $F90D data/unclassified
        dc.b $00,$8F,$27,$07,$4A,$27,$04,$0D,$59,$20,$F9,$F7,$10,$14,$FE,$C0 ; $F91D data/unclassified
        dc.b $9E,$6E,$00,$BD,$F3,$27,$B6,$10,$3A,$8A,$C0,$B7,$10,$3A,$CE,$10 ; $F92D data/unclassified
        dc.b $46,$8D,$3B,$8D,$39,$8D,$37,$8D,$35,$BD,$F9,$DF,$CE,$10,$46,$8D ; $F93D data/unclassified
        dc.b $5F,$8D,$5D,$8D,$5B,$8D,$59,$FE,$C0,$A0,$AD,$00,$C6,$1E,$BD,$F5 ; $F94D data/unclassified
        dc.b $B9,$8D,$03,$7E,$F7,$64                         ; $F95D data/unclassified
        dc.b $CE,$10,$3F                                     ; $F963 unconfirmed: LDX #$103f
        dc.b $BD,$F8,$21                                     ; $F966 unconfirmed: JSR $f821
        dc.b $8C,$10,$62                                     ; $F969 unconfirmed: CPX #$1062
        dc.b $27,$0C                                         ; $F96C unconfirmed: BEQ $f97a
        dc.b $A6,$00                                         ; $F96E unconfirmed: LDAA $0,X
        dc.b $81,$9F                                         ; $F970 unconfirmed: CMPA #$9f
        dc.b $23,$F2                                         ; $F972 unconfirmed: BLS $f966
        dc.b $6F,$00                                         ; $F974 unconfirmed: CLR $0,X
        dc.b $6F,$01                                         ; $F976 unconfirmed: CLR $1,X
        dc.b $20,$EC                                         ; $F978 unconfirmed: BRA $f966
        dc.b $39                                             ; $F97A unconfirmed: RTS
        dc.b $FF,$10,$17,$BD,$F6,$38,$BD,$F6,$68,$CE,$16,$18,$BD,$F6,$38,$BD ; $F97B data/unclassified
        dc.b $F6,$26,$25,$11                                 ; $F98B data/unclassified
        dc.b $CE,$16,$43                                     ; $F98F unconfirmed: LDX #$1643
        dc.b $BD,$F6,$C9                                     ; $F992 unconfirmed: JSR $f6c9
        dc.b $F6,$16,$83                                     ; $F995 unconfirmed: LDAB $1683
        dc.b $C4,$30                                         ; $F998 unconfirmed: ANDB #$30
        dc.b $FE,$C0,$A8                                     ; $F99A unconfirmed: LDX $c0a8
        dc.b $BD,$F3,$5C                                     ; $F99D unconfirmed: JSR $f35c
        dc.b $FE,$10,$17                                     ; $F9A0 unconfirmed: LDX $1017
        dc.b $7E,$F8,$21                                     ; $F9A3 unconfirmed: JMP $f821
        dc.b $8D,$02,$8D,$00,$7E,$F6,$F8,$FF,$10,$17,$BD,$F6,$38,$BD,$F6,$68 ; $F9A6 data/unclassified
        dc.b $CE,$16,$18,$BD,$F6,$38,$BD,$F6,$26,$25,$DF,$FE,$10,$17,$BD,$F6 ; $F9B6 data/unclassified
        dc.b $38,$CE,$16,$18,$BD,$F6,$98,$BD,$EA,$C0,$20,$CE ; $F9C6 data/unclassified
        dc.b $B6,$00,$83                                     ; $F9D2 unconfirmed: LDAA.w $0083
        dc.b $BA,$00,$84                                     ; $F9D5 unconfirmed: ORAA.w $0084
        dc.b $BA,$00,$85                                     ; $F9D8 unconfirmed: ORAA.w $0085
        dc.b $BA,$00,$86                                     ; $F9DB unconfirmed: ORAA.w $0086
        dc.b $39                                             ; $F9DE unconfirmed: RTS
        dc.b $CE,$16,$84,$BD,$F6,$38,$BD,$F9,$D2,$27,$0B,$CE,$10,$46,$8D,$0A ; $F9DF data/unclassified
        dc.b $8D,$08,$8D,$06,$8D,$04,$CE,$10,$46,$39,$FF,$10,$17,$BD,$F6,$38 ; $F9EF data/unclassified
        dc.b $BD,$F6,$68,$CE,$16,$84,$BD,$F6,$38,$BD,$F6,$26,$25,$0A,$86,$0C ; $F9FF data/unclassified
        dc.b $C6,$30,$BD,$F5,$C2,$BD,$EA,$19,$7E,$F9,$A0     ; $FA0F data/unclassified
NORMALIZE_PENDING_SCORE_DIGITS:
; Normalize the pending-score digits 0094-0098 by carrying each value of ten into the next decimal place.
        LDAA.w PENDING_SCORE_10S     ; $FA1A: $B6,$00,$94
        SUBA #$a                     ; $FA1D: $80,$0A
        BCS $fa29                    ; $FA1F: $25,$08
        STAA.w PENDING_SCORE_10S     ; $FA21: $B7,$00,$94
        INC.w PENDING_SCORE_100S     ; $FA24: $7C,$00,$95
        BRA $fa1d                    ; $FA27: $20,$F4
        LDAA.w PENDING_SCORE_100S    ; $FA29: $B6,$00,$95
        SUBA #$a                     ; $FA2C: $80,$0A
        BCS $fa38                    ; $FA2E: $25,$08
        STAA.w PENDING_SCORE_100S    ; $FA30: $B7,$00,$95
        INC.w PENDING_SCORE_1000S    ; $FA33: $7C,$00,$96
        BRA $fa2c                    ; $FA36: $20,$F4
        LDAA.w PENDING_SCORE_1000S   ; $FA38: $B6,$00,$96
        SUBA #$a                     ; $FA3B: $80,$0A
        BCS $fa47                    ; $FA3D: $25,$08
        STAA.w PENDING_SCORE_1000S   ; $FA3F: $B7,$00,$96
        INC.w PENDING_SCORE_10000S   ; $FA42: $7C,$00,$97
        BRA $fa3b                    ; $FA45: $20,$F4
        LDAA.w PENDING_SCORE_10000S  ; $FA47: $B6,$00,$97
        SUBA #$a                     ; $FA4A: $80,$0A
        BCS $f9de                    ; $FA4C: $25,$90
        STAA.w PENDING_SCORE_10000S  ; $FA4E: $B7,$00,$97
        INC.w PENDING_SCORE_100000S  ; $FA51: $7C,$00,$98
        BRA $fa4a                    ; $FA54: $20,$F4
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FA56 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FA66 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FA76 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FA86 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FA96 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FAA6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FAB6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FAC6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FAD6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FAE6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FAF6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB06 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB16 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB26 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB36 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB46 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB56 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB66 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB76 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB86 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FB96 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FBA6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FBB6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FBC6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FBD6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FBE6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FBF6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC06 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC16 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC26 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC36 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC46 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC56 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC66 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC76 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC86 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FC96 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FCA6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FCB6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FCC6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FCD6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FCE6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FCF6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD06 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD16 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD26 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD36 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD46 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD56 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD66 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD76 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD86 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FD96 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FDA6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FDB6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FDC6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FDD6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FDE6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FDF6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE06 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE16 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE26 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE36 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE46 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE56 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE66 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE76 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE86 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FE96 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FEA6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FEB6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FEC6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FED6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FEE6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FEF6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF06 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF16 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF26 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF36 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF46 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF56 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF66 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF76 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF86 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FF96 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FFA6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FFB6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FFC6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF ; $FFD6 data/unclassified
        dc.b $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF         ; $FFE6 data/unclassified
