; Canonical RAM and memory-mapped hardware names exported from Ghidra.
; These are equates only; they do not allocate or emit bytes.

PIA0_PORTA_OR_DDRA                           equ $0020
PIA0_CRA                                     equ $0021
PIA0_PORTB_OR_DDRB                           equ $0022
PIA0_CRB                                     equ $0023
PIA1_PORTA_OR_DDRA                           equ $0040
PIA1_CRA                                     equ $0041
PIA1_PORTB_OR_DDRB                           equ $0042
PIA1_CRB                                     equ $0043
; Deluxe applies every queued award at one tenth of the canonical value. The
; queue addresses are unchanged, but their displayed decimal places shift down
; one position so the previously unused ones digit becomes meaningful.
PENDING_SCORE_1S                             equ $0094
PENDING_SCORE_10S                            equ $0095
PENDING_SCORE_100S                           equ $0096
PENDING_SCORE_1000S                          equ $0097
PENDING_SCORE_10000S                         equ $0098
PENDING_SCORE_100000S                        equ $0099
WORK_RAM_U4_6116_START                       equ $1000
PENDING_SOUND_COMMAND                        equ $1024
SWITCH_EVENTS_STROBE0                        equ $1026
SWITCH_EVENTS_STROBE1                        equ $1027
SWITCH_EVENTS_STROBE2                        equ $1028
SWITCH_EVENTS_STROBE3                        equ $1029
SWITCH_EVENTS_STROBE4                        equ $102A
SWITCH_SAMPLE_CURRENT_STROBE0                equ $102C
SWITCH_SAMPLE_CURRENT_STROBE1                equ $102D
SWITCH_SAMPLE_CURRENT_STROBE2                equ $102E
SWITCH_SAMPLE_CURRENT_STROBE3                equ $102F
SWITCH_SAMPLE_CURRENT_STROBE4                equ $1030
SWITCH_SAMPLE_PREVIOUS_STROBE0               equ $1032
SWITCH_SAMPLE_PREVIOUS_STROBE1               equ $1033
SWITCH_SAMPLE_PREVIOUS_STROBE2               equ $1034
SWITCH_SAMPLE_PREVIOUS_STROBE3               equ $1035
SWITCH_SAMPLE_PREVIOUS_STROBE4               equ $1036
LAMP_SHADOW_BANK_A_BYTE0                     equ $103A
DROP_TARGET_BALLS_1_TO_7_LAMP_SHADOW         equ $103B
DROP_TARGET_BALLS_9_TO_15_LAMP_SHADOW        equ $103C
DROP_TARGET_5000_LAMP_SHADOW                 equ $103F
CHAMP_LANE_STATE                             equ $1040
CHAMP_MULTIPLIER_LAMP_SHADOW                 equ $1041
SHARED_ORBIT_VALUE_LAMP_STATE                equ $1044
EIGHT_LETTER_STATE                           equ $1045
HOLE_BONUS_LAMP_SHADOW                       equ $1043
DROP_TARGET_5000_LAMP_FLASH_MASK             equ $10BF
CHAMP_COMPLETION_STATE                       equ $10C0
ORBIT_SPECIAL_FLASH_MASK                     equ $10C2
SUNK_POOL_BALLS_1_TO_7                       equ $10C3
CALLED_POOL_BALL_SOUND_ID                    equ $10C4
DROP_TARGET_SWITCH_CLOSURE_LATCHES           equ $10C5
CALLED_BALL_SPEECH_DELAY_TIMER                equ $10B3
; Canonical player slots use a 13-byte stride: $10C7, $10D4, $10E1, $10EE.
; Each slot stores nine bytes and reserves four, so Player 4 owns $10EE-$10FA.
; Deluxe begins at the first byte after all four slots. $1106-$1112 provide
; parallel persistent values for players 1-4; the other bytes hold active-
; player, per-ball, and temporary bonus/display state.
DELUXE_COLLECT_STATE                         equ $10FB
DELUXE_SPINNER_IDLE_TIMER                    equ $10FC
DELUXE_CHAMP_COMPLETION_COUNT                equ $10FD
DELUXE_SPINNER_VALUE_MASK                    equ $10FE
DELUXE_ORBIT_VALUE_STATE                     equ $10FF
DELUXE_COMPLETED_EIGHT_BALL_RACKS            equ $1100
DELUXE_BONUS_RACKS_REMAINING                 equ $1101
DELUXE_SAVED_CREDIT_DISPLAY_ONES             equ $1102
DELUXE_SAVED_CREDIT_DISPLAY_TENS             equ $1103
DELUXE_COMPLETED_BALL_LETTERS                equ $1104
DELUXE_BONUS_BALL_LETTERS_REMAINING          equ $1105
DELUXE_PLAYER_RACK_COUNTS                    equ $1106
DELUXE_PLAYER_BALL_LETTER_COUNTS             equ $110A
; Called Ball progression is stored in displayed 500-point units. Values 1-10
; represent the requested 5,000-50,000 playfield range after Deluxe scaling.
DELUXE_CALLED_BALL_SCORE_500S                 equ $110E
DELUXE_PLAYER_CALLED_BALL_SCORE_500S          equ $110F
DELUXE_CALLED_BALL_FLASH_APPLIED_ID          equ $1113
DELUXE_SPINNER_PREVIEW_TIMER                 equ $1114
DELUXE_ORBIT_PREVIEW_TIMER                   equ $1115
DELUXE_PHASE_B_LAMP_OUTPUT_BUFFER             equ $1119
; Temporary sunk-ball award display. The seven digit bytes use the canonical
; player-score layout (ones first, digit in the high nibble). While active,
; the four live score buffers at 1046-1061 are backed up at 112B-1146; only
; the three displays that do not belong to the scoring player are overlaid.
; Start after the "more" indicators' six-byte 1119-111E output buffer.
DELUXE_SUNK_BALL_SCORE_DIGITS                 equ $111F
DELUXE_SUNK_BALL_SCORE_TIMER                  equ $1126
DELUXE_SUNK_BALL_SCORE_ACTIVE_PLAYER          equ $1127
DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER         equ $1128
DELUXE_SUNK_BALL_SCORE_BINARY_WORK            equ $1129
DELUXE_SUNK_BALL_SCORE_DISPLAY_BACKUP         equ $112B
; Output-only phase used by the "more" indicators. The score-display backup
; occupies $112B-$1146, so this byte begins immediately after it.
DELUXE_MORE_LAMPS_FLASH_PHASE                 equ $1147
; Per-ball anti-shatz latch for the C/P return lanes only. A newly awarded
; inlane letter locks C/P progress until a whitelisted shot rearms it.
DELUXE_CHAMP_INLANE_REARMED                    equ $1148
; Keep the earned saucer multiplier separate from the pending terminal stage
; that will blink after qualification and from the active-low lamp combinations.
DELUXE_HOLE_BONUS_MULTIPLIER                    equ $1149
DELUXE_BONUS_MULTIPLIER_PASSES_REMAINING        equ $114A
DELUXE_HOLE_NEXT_BONUS_MULTIPLIER               equ $114B

PLAYER_SCORE_DISPLAY_START                    equ $1046
PLAYER_SCORE_DISPLAY_END                      equ $1062

; C9A6 accepts B as a count of displayed 1,000-point units and applies the
; authoritative CHAMP playfield multiplier before normalizing pending score.
AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER   equ $C9A6

CREDIT_DISPLAY_ONES                          equ $1069
CREDIT_DISPLAY_TENS                          equ $106A

DELUXE_COLLECT_LOCATION_MASK                 equ $03
DELUXE_COLLECT_ACTIVE                        equ $04
DELUXE_COLLECT_STATE_MASK                    equ $07
; Both legacy orbit encodings now accept either physical rollover.
DELUXE_COLLECT_DUAL_ORBIT                    equ $01
DELUXE_COLLECT_SPINNER                       equ $02
DELUXE_COLLECT_OPENING_ORBIT                 equ $03
DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION equ $40
DELUXE_COLLECT_DEACTIVATION_AUTHORIZED       equ $80
DELUXE_CHAMP_INLANE_LOCKED                   equ $00
DELUXE_CHAMP_INLANE_ARMED                    equ $01
DELUXE_CHAMP_INLANE_MASK                     equ $11

HOLE_BONUS_2X_STATE                          equ $01
HOLE_BONUS_3X_STATE                          equ $02
HOLE_BONUS_5X_STATE                          equ $04
HOLE_100000_STATE                            equ $08
; Active-low steady earned-multiplier lamps in HOLE_BONUS_LAMP_SHADOW. The
; low nibble remains off until the periodic refresh XORs in the relit next-award
; mask from $10C1.
HOLE_BONUS_5X_LAMP_SHADOW                    equ $BF
HOLE_BONUS_7X_LAMP_SHADOW                    equ $AF
HOLE_BONUS_8X_LAMP_SHADOW                    equ $9F
HOLE_BONUS_10X_LAMP_SHADOW                   equ $8F
; Blinking next-award combinations. Physical 7x/8x/10x are represented by
; combinations of the original 2x, 3x, and 5x lamps plus the 100K lamp.
HOLE_NEXT_7X_100000_FLASH_MASK                equ $0D
HOLE_NEXT_8X_100000_FLASH_MASK                equ $0E
HOLE_NEXT_10X_100000_FLASH_MASK               equ $0F

DELUXE_SPINNER_1000_LAMP                     equ $20
DELUXE_SPINNER_3000_LAMP                     equ $40
DELUXE_SPINNER_5000_LAMP                     equ $80
DELUXE_SPINNER_ALL_VALUE_LAMPS               equ $E0
DELUXE_SPINNER_INACTIVITY_TICKS              equ $78
; $BF is about 3.2 seconds at this tick rate and begins bit 4 at the start of
; a complete visible blink phase instead of entering halfway through one.
DELUXE_SPINNER_PREVIEW_TICKS                 equ $BF
DELUXE_ORBIT_PREVIEW_TICKS                   equ DELUXE_SPINNER_PREVIEW_TICKS
; The gameplay periodic hook runs at about 60 Hz. $B4 is roughly three
; seconds; bit 4 supplies a clearly visible roughly half-second blink cycle.
DELUXE_SUNK_BALL_SCORE_DISPLAY_TICKS          equ $B4
DELUXE_CALLED_BALL_INITIAL_500S                equ $01
DELUXE_CALLED_BALL_MAXIMUM_500S                equ $0A
DELUXE_SUNK_BALL_SCORE_BLINK_BIT              equ $10
DELUXE_SUNK_BALL_SCORE_OVERLAY_ACTIVE         equ $A5
DELUXE_SCORE_DISPLAY_BLANK_DIGIT              equ $F0
DELUXE_SCORE_DISPLAY_BACKUP_OFFSET            equ DELUXE_SUNK_BALL_SCORE_DISPLAY_BACKUP-PLAYER_SCORE_DISPLAY_START
DELUXE_BALL_BONUS_PASS_DELAY                 equ $10
DELUXE_BALL_BONUS_STEP_DELAY                 equ $08
DELUXE_EIGHT_BONUS_LETTER_DELAY              equ $09
DELUXE_RACK_MORE_THRESHOLD                   equ $04
DELUXE_BALL_MORE_THRESHOLD                   equ $05
DELUXE_RACK_MORE_LAMP_MASK                    equ $60
; Phase-B $1041 bits 0-3 are B-A-L-L. Bits 4-7 are unrelated
; multiplier/special outputs and must never be included in this overlay.
DELUXE_BALL_MORE_LAMP_MASK                    equ $0F
SQUAWK_TALK_SUPER_COMMAND                    equ $6F
CENTER_ROLLOVER_500_SOUND_COMMAND            equ $31
LEFT_ORBIT_ACTIVE_SOUND_COMMAND              equ $29
RIGHT_ORBIT_ACTIVE_SOUND_COMMAND             equ $2A
ORBIT_SPECIAL_LAMP_BIT                       equ $10
ORBIT_SPECIAL_ALREADY_COLLECTED_BIT          equ $20
WORK_RAM_U4_6116_END                         equ $17FF
