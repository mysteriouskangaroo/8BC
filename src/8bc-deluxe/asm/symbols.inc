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
; Deluxe working state follows the original four 9-byte player records at
; $10C7-$10EA. $10F6-$1102 provide parallel persistent values for players 1-4;
; the other bytes hold active-player, per-ball, and temporary bonus state.
DELUXE_COLLECT_STATE                         equ $10EB
DELUXE_SPINNER_IDLE_TIMER                    equ $10EC
DELUXE_CHAMP_COMPLETION_COUNT                equ $10ED
DELUXE_SPINNER_VALUE_MASK                    equ $10EE
DELUXE_ORBIT_VALUE_STATE                     equ $10EF
DELUXE_COMPLETED_EIGHT_BALL_RACKS            equ $10F0
DELUXE_BONUS_RACKS_REMAINING                 equ $10F1
DELUXE_SAVED_CREDIT_DISPLAY_ONES             equ $10F2
DELUXE_SAVED_CREDIT_DISPLAY_TENS             equ $10F3
DELUXE_COMPLETED_BALL_LETTERS                equ $10F4
DELUXE_BONUS_BALL_LETTERS_REMAINING          equ $10F5
DELUXE_PLAYER_RACK_COUNTS                    equ $10F6
DELUXE_PLAYER_BALL_LETTER_COUNTS             equ $10FA
DELUXE_CALLED_BALL_SCORE_1000S               equ $10FE
DELUXE_PLAYER_CALLED_BALL_SCORE_1000S        equ $10FF
DELUXE_CALLED_BALL_FLASH_APPLIED_ID          equ $1103
DELUXE_SPINNER_PREVIEW_TIMER                 equ $1104
DELUXE_ORBIT_SWEEP_WAIT_TIMER_HIGH           equ $1105
DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW            equ $1106
DELUXE_ORBIT_SWEEP_PHASE                     equ $1107
DELUXE_ORBIT_SWEEP_PHASE_TIMER               equ $1108
DELUXE_PHASE_B_LAMP_OUTPUT_BUFFER             equ $1109
; Temporary sunk-ball award display. The seven digit bytes use the canonical
; player-score layout (ones first, digit in the high nibble). While active,
; the four live score buffers at 1046-1061 are backed up at 111B-1136; only
; the three displays that do not belong to the scoring player are overlaid.
; Start after the directional sweep's six-byte 1109-110E output buffer.
DELUXE_SUNK_BALL_SCORE_DIGITS                 equ $110F
DELUXE_SUNK_BALL_SCORE_TIMER                  equ $1116
DELUXE_SUNK_BALL_SCORE_ACTIVE_PLAYER          equ $1117
DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER         equ $1118
DELUXE_SUNK_BALL_SCORE_BINARY_WORK            equ $1119
DELUXE_SUNK_BALL_SCORE_DISPLAY_BACKUP         equ $111B

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
DELUXE_COLLECT_LEFT_ORBIT                    equ $01
DELUXE_COLLECT_SPINNER                       equ $02
DELUXE_COLLECT_RIGHT_ORBIT                   equ $03
DELUXE_HOLE_WAITING_FOR_LEFT_COLLECT         equ $40
DELUXE_LEFT_COLLECT_AUTHORIZED               equ $80

HOLE_BONUS_2X_STATE                          equ $01
HOLE_BONUS_3X_STATE                          equ $02
HOLE_BONUS_5X_STATE                          equ $04
HOLE_100000_STATE                            equ $08

DELUXE_SPINNER_1000_LAMP                     equ $20
DELUXE_SPINNER_3000_LAMP                     equ $40
DELUXE_SPINNER_5000_LAMP                     equ $80
DELUXE_SPINNER_ALL_VALUE_LAMPS               equ $E0
DELUXE_SPINNER_INACTIVITY_TICKS              equ $78
; $BF is about 3.2 seconds at this tick rate and begins bit 4 at the start of
; a complete visible blink phase instead of entering halfway through one.
DELUXE_SPINNER_PREVIEW_TICKS                 equ $BF
; One 15-tick all-off pause (about 250 ms) plus six 12-tick H/A/M lamp steps
; lasts about 1.45 seconds. Waiting 213 ticks after that produces a roughly
; five-second start-to-start roll cadence at the periodic gameplay tick rate.
DELUXE_ORBIT_SWEEP_PHASE_TICKS               equ $0C
DELUXE_ORBIT_SWEEP_BLACKOUT_TICKS            equ $0F
DELUXE_ORBIT_SWEEP_WAIT_TICKS_HIGH           equ $00
DELUXE_ORBIT_SWEEP_WAIT_TICKS_LOW            equ $D5
DELUXE_ORBIT_SWEEP_PHASE_COUNT               equ $07
DELUXE_ORBIT_SWEEP_BLACKOUT_PHASE            equ $01
DELUXE_CHAMP_ROLL_LAMP_MASK                  equ $0E
DELUXE_H_ROLLOVER_LAMP_BIT                   equ $02
DELUXE_A_ROLLOVER_LAMP_BIT                   equ $04
DELUXE_M_ROLLOVER_LAMP_BIT                   equ $08
; The gameplay periodic hook runs at about 60 Hz. $B4 is roughly three
; seconds; bit 4 supplies a clearly visible roughly half-second blink cycle.
DELUXE_SUNK_BALL_SCORE_DISPLAY_TICKS          equ $B4
DELUXE_SUNK_BALL_SCORE_BLINK_BIT              equ $10
DELUXE_SUNK_BALL_SCORE_OVERLAY_ACTIVE         equ $A5
DELUXE_SCORE_DISPLAY_BLANK_DIGIT              equ $F0
DELUXE_SCORE_DISPLAY_BACKUP_OFFSET            equ DELUXE_SUNK_BALL_SCORE_DISPLAY_BACKUP-PLAYER_SCORE_DISPLAY_START
DELUXE_BALL_BONUS_PASS_DELAY                 equ $10
DELUXE_BALL_BONUS_STEP_DELAY                 equ $08
DELUXE_EIGHT_BONUS_LETTER_DELAY              equ $09
SQUAWK_TALK_SUPER_COMMAND                    equ $6F
ORBIT_SPECIAL_LAMP_BIT                       equ $10
ORBIT_SPECIAL_ALREADY_COLLECTED_BIT          equ $20
WORK_RAM_U4_6116_END                         equ $17FF
