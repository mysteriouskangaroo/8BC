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
PENDING_SCORE_10S                            equ $0094
PENDING_SCORE_100S                           equ $0095
PENDING_SCORE_1000S                          equ $0096
PENDING_SCORE_10000S                         equ $0097
PENDING_SCORE_100000S                        equ $0098
PENDING_SCORE_1000000S                       equ $0099
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
DROP_TARGET_5000_LAMP_SHADOW                 equ $103F
CHAMP_LANE_STATE                             equ $1040
CHAMP_MULTIPLIER_LAMP_SHADOW                 equ $1041
SHARED_ORBIT_VALUE_LAMP_STATE                equ $1044
EIGHT_LETTER_STATE                           equ $1045
DROP_TARGET_5000_LAMP_FLASH_MASK             equ $10BF
CHAMP_COMPLETION_STATE                       equ $10C0
ORBIT_SPECIAL_FLASH_MASK                     equ $10C2
SUNK_POOL_BALLS_1_TO_7                       equ $10C3
DROP_TARGET_SWITCH_CLOSURE_LATCHES           equ $10C5
; Deluxe per-ball state follows the original four 9-byte player records at
; $10C7-$10EA. These bytes are reset/captured by DELUXE_INITIALIZE_BALL.
DELUXE_COLLECT_STATE                         equ $10EB
DELUXE_SPINNER_IDLE_TIMER                    equ $10EC
DELUXE_CHAMP_COMPLETION_COUNT                equ $10ED
DELUXE_SPINNER_VALUE_MASK                    equ $10EE
DELUXE_ORBIT_VALUE_STATE                     equ $10EF

DELUXE_COLLECT_LOCATION_MASK                 equ $03
DELUXE_COLLECT_ACTIVE                        equ $04
DELUXE_COLLECT_STATE_MASK                    equ $07
DELUXE_COLLECT_LEFT_ORBIT                    equ $01
DELUXE_COLLECT_SPINNER                       equ $02
DELUXE_COLLECT_RIGHT_ORBIT                   equ $03
DELUXE_HOLE_WAITING_FOR_LEFT_COLLECT         equ $40
DELUXE_LEFT_COLLECT_AUTHORIZED               equ $80

DELUXE_SPINNER_1000_LAMP                     equ $20
DELUXE_SPINNER_3000_LAMP                     equ $40
DELUXE_SPINNER_5000_LAMP                     equ $80
DELUXE_SPINNER_ALL_VALUE_LAMPS               equ $E0
DELUXE_SPINNER_INACTIVITY_TICKS              equ $78
ORBIT_SPECIAL_LAMP_BIT                       equ $10
ORBIT_SPECIAL_ALREADY_COLLECTED_BIT          equ $20
WORK_RAM_U4_6116_END                         equ $17FF
