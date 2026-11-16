; Eight Ball Champ Deluxe rules
; Address range: $D3B2-$DFFF (verified $FF padding in the canonical ROM)
;
; Existing handlers jump here so their surrounding addresses, animation data,
; service code, and hardware timing remain fixed. See ../../gamerules.md for
; the complete rule contract.

DELUXE_PERIODIC_TICK:
; C14E calls this in place of its original LDX $10B3. Preserve A, process the
; spinner inactivity and value-preview timers, then execute that displaced
; load last so C151 sees the same X value and condition codes as canonical.
        PSHA
        LDAA DELUXE_SPINNER_IDLE_TIMER
        BEQ DELUXE_SPINNER_PREVIEW_TICK
        DECA
        STAA DELUXE_SPINNER_IDLE_TIMER
        BNE DELUXE_SPINNER_PREVIEW_TICK
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_SPINNER_PREVIEW_TICK
; Each active spinner pulse restarts this inactivity timer.  A pulse inside
; the window continues the same collect; only about two seconds with no
; further pulse closes it and advances to left-orbit inactive. Preserve the
; two saucer-qualification flags while clearing active and selecting left.
        LDAA DELUXE_COLLECT_STATE
        ANDA #$C0
        ORAA #DELUXE_COLLECT_LEFT_ORBIT
        STAA DELUXE_COLLECT_STATE
        JSR DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION
        CLR $10b1
        CLR $10b2
DELUXE_SPINNER_PREVIEW_TICK:
; A newly collected E-I-G-H-T letter starts this roughly 3.2-second lamp-only
; preview while the spinner collect is inactive. Bit 4 supplies a roughly
; half-second blink cycle, and the BF reload begins with a complete visible
; phase. Only 10B1 changes; DELUXE_COLLECT_STATE remains authoritative for
; scoring, so spinner pulses during the preview still take the unlit path.
        LDAA DELUXE_SPINNER_PREVIEW_TIMER
        BEQ DELUXE_ORBIT_SWEEP_TICK
        DECA
        STAA DELUXE_SPINNER_PREVIEW_TIMER
        BEQ DELUXE_SPINNER_PREVIEW_FINISHED
        BITA #$10
        BEQ DELUXE_SPINNER_PREVIEW_HIDE
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        BRA DELUXE_ORBIT_SWEEP_TICK
DELUXE_SPINNER_PREVIEW_HIDE:
        CLR $10b1
        BRA DELUXE_ORBIT_SWEEP_TICK
DELUXE_SPINNER_PREVIEW_FINISHED:
        CLR $10b1
DELUXE_ORBIT_SWEEP_TICK:
        JSR DELUXE_UPDATE_SUNK_BALL_SCORE_DISPLAY
        BSR DELUXE_UPDATE_ORBIT_SWEEP
DELUXE_PERIODIC_TICK_DONE:
        PULA
        LDX $10b3
        RTS

DELUXE_UPDATE_ORBIT_SWEEP:
; Only an active left or right orbit receives the directional sweep. The
; output helper validates the state again inside the lamp-refresh interrupt,
; so a collect transition cannot leave a stale overlay on the next location.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_LEFT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_ORBIT_SWEEP_ADVANCE
        CMPA #DELUXE_COLLECT_RIGHT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_ORBIT_SWEEP_ADVANCE
        CLR DELUXE_ORBIT_SWEEP_PHASE
        CLR DELUXE_ORBIT_SWEEP_PHASE_TIMER
        CLR DELUXE_ORBIT_SWEEP_WAIT_TIMER_HIGH
        CLR DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW
        RTS

DELUXE_ORBIT_SWEEP_ADVANCE:
        LDAA DELUXE_ORBIT_SWEEP_PHASE
        BEQ DELUXE_ORBIT_SWEEP_WAIT
        DEC DELUXE_ORBIT_SWEEP_PHASE_TIMER
        BNE DELUXE_ORBIT_SWEEP_UPDATE_DONE
        INCA
        CMPA #DELUXE_ORBIT_SWEEP_PHASE_COUNT+1
        BEQ DELUXE_ORBIT_SWEEP_FINISH
        STAA DELUXE_ORBIT_SWEEP_PHASE
        LDAA #DELUXE_ORBIT_SWEEP_PHASE_TICKS
        STAA DELUXE_ORBIT_SWEEP_PHASE_TIMER
        RTS

DELUXE_ORBIT_SWEEP_FINISH:
        CLR DELUXE_ORBIT_SWEEP_PHASE
        LDAA #DELUXE_ORBIT_SWEEP_WAIT_TICKS_HIGH
        STAA DELUXE_ORBIT_SWEEP_WAIT_TIMER_HIGH
        LDAA #DELUXE_ORBIT_SWEEP_WAIT_TICKS_LOW
        STAA DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW
        RTS

DELUXE_ORBIT_SWEEP_WAIT:
        LDAA DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW
        BNE DELUXE_ORBIT_SWEEP_DECREMENT_LOW
        LDAA DELUXE_ORBIT_SWEEP_WAIT_TIMER_HIGH
        BEQ DELUXE_ORBIT_SWEEP_BEGIN
        DECA
        STAA DELUXE_ORBIT_SWEEP_WAIT_TIMER_HIGH
        LDAA #$ff
        STAA DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW
        RTS
DELUXE_ORBIT_SWEEP_DECREMENT_LOW:
        DECA
        STAA DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW
DELUXE_ORBIT_SWEEP_UPDATE_DONE:
        RTS
DELUXE_ORBIT_SWEEP_BEGIN:
        BRA DELUXE_START_ORBIT_SWEEP

DELUXE_START_ORBIT_SWEEP:
; Start with all three roll lamps off, followed by six H/A/M phases. The output
; routine changes only its temporary copy, so no phase can collect or clear a
; CHAMP letter.
        CLR DELUXE_ORBIT_SWEEP_WAIT_TIMER_HIGH
        CLR DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW
        LDAA #DELUXE_ORBIT_SWEEP_BLACKOUT_PHASE
        STAA DELUXE_ORBIT_SWEEP_PHASE
        LDAA #DELUXE_ORBIT_SWEEP_BLACKOUT_TICKS
        STAA DELUXE_ORBIT_SWEEP_PHASE_TIMER
        RTS

DELUXE_SELECT_PHASE_B_LAMP_OUTPUT:
; E111 calls this from the timing-sensitive lamp-refresh interrupt instead of
; loading X with 1040 directly. Outside a sweep, retain the original fast path.
; During a roll, copy the six Phase-B shadow bytes, clear H/A/M in the copy,
; and then set at most one of them. Gameplay continues to read and write the
; authoritative CHAMP state at 1040.
        LDAA DELUXE_ORBIT_SWEEP_PHASE
        BEQ DELUXE_USE_LIVE_PHASE_B_LAMPS
        LDAB DELUXE_COLLECT_STATE
        ANDB #DELUXE_COLLECT_STATE_MASK
        CMPB #DELUXE_COLLECT_LEFT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_COPY_PHASE_B_LAMPS
        CMPB #DELUXE_COLLECT_RIGHT_ORBIT+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_USE_LIVE_PHASE_B_LAMPS

DELUXE_COPY_PHASE_B_LAMPS:
        LDX #DELUXE_PHASE_B_LAMP_OUTPUT_BUFFER
        LDAA $1040
        STAA $00,X
        LDAA $1041
        STAA $01,X
        LDAA $1042
        STAA $02,X
        LDAA $1043
        STAA $03,X
        LDAA $1044
        STAA $04,X
        LDAA $1045
        STAA $05,X
; The Phase-B CHAMP lamps are active-low at the serializer. Set all three bits
; for the opening all-off pause; later phases begin from this same black base.
        LDAA $00,X
        ORAA #DELUXE_CHAMP_ROLL_LAMP_MASK
        STAA $00,X
        LDAA DELUXE_ORBIT_SWEEP_PHASE
        CMPA #DELUXE_ORBIT_SWEEP_BLACKOUT_PHASE
        BEQ DELUXE_PHASE_B_OUTPUT_READY
; Remove the blackout phase, then normalize roll steps 4-6 to 1-3 so the same
; three-lamp roll runs twice.
        DECA
        CMPA #$04
        BCS DELUXE_ORBIT_SWEEP_PHASE_NORMALIZED
        SUBA #$03
DELUXE_ORBIT_SWEEP_PHASE_NORMALIZED:
        CMPA #$02
        BEQ DELUXE_SWEEP_A_LAMP
        CMPB #DELUXE_COLLECT_LEFT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_SELECT_LEFT_SWEEP_END_LAMP
; Right phases 1/3 select H/M respectively.
        CMPA #$01
        BEQ DELUXE_SWEEP_H_LAMP
        BRA DELUXE_SWEEP_M_LAMP
; Left phases 1/3 select M/H respectively.
DELUXE_SELECT_LEFT_SWEEP_END_LAMP:
        CMPA #$01
        BEQ DELUXE_SWEEP_M_LAMP
DELUXE_SWEEP_H_LAMP:
        LDAA $00,X
        ANDA #$FF-DELUXE_H_ROLLOVER_LAMP_BIT
        BRA DELUXE_STORE_SWEEP_CHAMP_LAMP
DELUXE_SWEEP_A_LAMP:
        LDAA $00,X
        ANDA #$FF-DELUXE_A_ROLLOVER_LAMP_BIT
        BRA DELUXE_STORE_SWEEP_CHAMP_LAMP
DELUXE_SWEEP_M_LAMP:
        LDAA $00,X
        ANDA #$FF-DELUXE_M_ROLLOVER_LAMP_BIT
DELUXE_STORE_SWEEP_CHAMP_LAMP:
        STAA $00,X
DELUXE_PHASE_B_OUTPUT_READY:
        RTS

DELUXE_USE_LIVE_PHASE_B_LAMPS:
        LDX #CHAMP_LANE_STATE
        RTS

DELUXE_INITIALIZE_BALL:
; The collect feature, spinner value, saucer authorization, CHAMP milestone
; count, and playfield multiplier are per-ball. Completed racks and B-A-L-L
; letters are per-player and were restored at C603, so do not clear them here.
; C507 clears the original multiplier state; this helper resets only the
; additional Deluxe per-ball and bonus-working state.
; If the previous ball drained during the three-second award display, restore
; all three overlaid scores before the newly selected player can begin scoring.
        JSR DELUXE_CANCEL_SUNK_BALL_SCORE_DISPLAY
        LDAA #DELUXE_COLLECT_RIGHT_ORBIT
        STAA DELUXE_COLLECT_STATE
        CLR DELUXE_SPINNER_IDLE_TIMER
        CLR DELUXE_SPINNER_PREVIEW_TIMER
        CLR DELUXE_ORBIT_SWEEP_WAIT_TIMER_HIGH
        CLR DELUXE_ORBIT_SWEEP_WAIT_TIMER_LOW
        CLR DELUXE_ORBIT_SWEEP_PHASE
        CLR DELUXE_ORBIT_SWEEP_PHASE_TIMER
        CLR DELUXE_CHAMP_COMPLETION_COUNT
        CLR DELUXE_BONUS_RACKS_REMAINING
        CLR DELUXE_BONUS_BALL_LETTERS_REMAINING
        CLR DELUXE_CALLED_BALL_FLASH_APPLIED_ID
        CLR $10b1
        CLR $10b2
        LDAA #DELUXE_SPINNER_1000_LAMP
        STAA DELUXE_SPINNER_VALUE_MASK
; The canonical player restore at C500 has already loaded the retained orbit
; value into 1044. Keep its low-nibble value in Deluxe RAM, then set the live
; low nibble to all-off while the new ball begins at right-orbit inactive.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$0f
        STAA DELUXE_ORBIT_VALUE_STATE
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ORAA #$0f
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
; The terminal special may be retained from the player record, but the new
; ball begins at right-orbit inactive, so its live blinking mask must be hidden.
        JSR DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY
; High bits of 1040 are active-low spinner-value lamps. Keep them dark until
; the collect reaches the spinner, while preserving the five CHAMP lane bits.
        LDAA CHAMP_LANE_STATE
        ORAA #DELUXE_SPINNER_ALL_VALUE_LAMPS
        STAA CHAMP_LANE_STATE
        RTS

DELUXE_HANDLE_SPINNER:
; Switch 32. Select the original sound for the current value tier before the
; common gameplay/tilt gate queues it. Combined binary values use the sound of
; their highest lit value: 3K/4K use the 3K sound and 5K/6K/8K/9K use 5K.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_SPINNER_SELECT_100_SOUND
        LDAA DELUXE_SPINNER_VALUE_MASK
        BITA #DELUXE_SPINNER_5000_LAMP
        BNE DELUXE_SPINNER_SELECT_5000_SOUND
        BITA #DELUXE_SPINNER_3000_LAMP
        BNE DELUXE_SPINNER_SELECT_3000_SOUND
        LDAB #$2c
        BRA DELUXE_SPINNER_QUEUE_SOUND
DELUXE_SPINNER_SELECT_5000_SOUND:
        LDAB #$2e
        BRA DELUXE_SPINNER_QUEUE_SOUND
DELUXE_SPINNER_SELECT_3000_SOUND:
        LDAB #$2d
        BRA DELUXE_SPINNER_QUEUE_SOUND
DELUXE_SPINNER_SELECT_100_SOUND:
        LDAB #$2b
DELUXE_SPINNER_QUEUE_SOUND:
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_SCORE_UNLIT_SPINNER

; Keep the value lamps live and restart the inactivity countdown on every
; pulse. The weighted bits are worth 1k, 3k, and 5k respectively.
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        LDAA #DELUXE_SPINNER_INACTIVITY_TICKS
        STAA DELUXE_SPINNER_IDLE_TIMER
        CLRB
        LDAA DELUXE_SPINNER_VALUE_MASK
        BITA #DELUXE_SPINNER_1000_LAMP
        BEQ DELUXE_SPINNER_SKIP_1000
        INCB
DELUXE_SPINNER_SKIP_1000:
        BITA #DELUXE_SPINNER_3000_LAMP
        BEQ DELUXE_SPINNER_SKIP_3000
        ADDB #$03
DELUXE_SPINNER_SKIP_3000:
        BITA #DELUXE_SPINNER_5000_LAMP
        BEQ DELUXE_SPINNER_SCORE_READY
        ADDB #$05
DELUXE_SPINNER_SCORE_READY:
        JMP AWARD_B_HUNDRED_WITH_PLAYFIELD_MULTIPLIER

DELUXE_SCORE_UNLIT_SPINNER:
; Unlike the lit collect value, the unlit 100-point value is deliberately
; independent of the CHAMP playfield multiplier.
        LDAB #$01
        JMP $c9e0

DELUXE_ADVANCE_CHAMP:
; Called after each completed C-H-A-M-P word. Low milestones intentionally do
; nothing: completion 2 selects double, 4 selects triple, and 6 adds both
; outlane-special bits while retaining triple.
        INC DELUXE_CHAMP_COMPLETION_COUNT
        LDAA DELUXE_CHAMP_COMPLETION_COUNT
        CMPA #$02
        BEQ DELUXE_CHAMP_SET_DOUBLE
        CMPA #$04
        BEQ DELUXE_CHAMP_SET_TRIPLE
        CMPA #$06
        BNE DELUXE_CHAMP_DONE
        LDAA #$e0
        BRA DELUXE_CHAMP_STORE_STATE
DELUXE_CHAMP_SET_DOUBLE:
        LDAA #$10
        BRA DELUXE_CHAMP_STORE_STATE
DELUXE_CHAMP_SET_TRIPLE:
        LDAA #$20
DELUXE_CHAMP_STORE_STATE:
        STAA CHAMP_COMPLETION_STATE
; Begin each newly reached milestone from the lamps' off phase. The canonical
; periodic XOR at C1B3 then supplies the normal flashing animation.
        LDAA CHAMP_MULTIPLIER_LAMP_SHADOW
        ORAA #$f0
        STAA CHAMP_MULTIPLIER_LAMP_SHADOW
DELUXE_CHAMP_DONE:
        RTS

DELUXE_HANDLE_ORBIT:
; CB4F/CB53 select sound $2A/$29 for right/left before reaching this routine.
; The common gate stores that selector at 1024, then overwrites B while testing
; the score-enable lamp bits. Read the stored command to identify the side; B
; is no longer a valid discriminator after the call. A failed gate still
; unwinds this call exactly as it did in the original.
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        LDAA PENDING_SOUND_COMMAND
        CMPA #$29
        BEQ DELUXE_HANDLE_LEFT_ORBIT

DELUXE_HANDLE_RIGHT_ORBIT:
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_RIGHT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_HANDLE_ACTIVE_RIGHT_ORBIT
        JMP DELUXE_SCORE_UNLIT_ORBIT
DELUXE_HANDLE_ACTIVE_RIGHT_ORBIT:
; Keep right active while the original handler runs its fast upward arrow
; chase. Advance to spinner inactive only after that animation returns.
        JMP DELUXE_SCORE_ACTIVE_RIGHT_ORBIT

DELUXE_HANDLE_LEFT_ORBIT:
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_LEFT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_HANDLE_ACTIVE_LEFT_ORBIT
; An inactive left orbit always scores the unlit 5,000 and cannot collect or
; advance the retained orbit value. This includes the terminal 100,000/special
; state: its qualification remains stored until an active orbit collect runs
; the original lit-orbit routine.
        JMP DELUXE_SCORE_UNLIT_ORBIT

DELUXE_HANDLE_ACTIVE_LEFT_ORBIT:
; The active-to-inactive transition and 100,000 relight occur only after the
; original lit-orbit scoring and arrow chase complete.
        JMP DELUXE_SCORE_ACTIVE_LEFT_ORBIT

DELUXE_SCORE_ACTIVE_LEFT_ORBIT:
; Finish the original chase before changing location. Then advance to right-
; orbit inactive and darken the shared orbit value lamps.
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        LDAA DELUXE_COLLECT_STATE
        ANDA #$c0
        ORAA #DELUXE_COLLECT_RIGHT_ORBIT
        STAA DELUXE_COLLECT_STATE
        JSR DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION
        BRA DELUXE_HIDE_INACTIVE_ORBIT_LAMPS

DELUXE_SCORE_ACTIVE_RIGHT_ORBIT:
; Finish the original chase before moving the sequence to spinner inactive.
; Preserve only the two saucer flags, and darken the spinner value lamps until
; a newly sunk ball activates that location; sunk balls are never queued.
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        LDAA DELUXE_COLLECT_STATE
        ANDA #$c0
        ORAA #DELUXE_COLLECT_SPINNER
        STAA DELUXE_COLLECT_STATE
        JSR DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION
        CLR $10b1
        CLR $10b2
        BRA DELUXE_HIDE_INACTIVE_ORBIT_LAMPS

DELUXE_RUN_ORIGINAL_LIT_ORBIT:
        TBA
        JSR $c27e
        JSR $cb5c
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$0f
        STAA DELUXE_ORBIT_VALUE_STATE
; Reconcile the live blinking mask with the retained terminal qualification
; while this orbit is still active. The caller will hide it again when the
; collect moves to its next inactive location.
        JSR DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY
        RTS

DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY:
; $10C2 bit $10 is the live XOR mask used by the periodic lamp flasher, not a
; suitable hidden qualification store. Show it only while either orbit is the
; active Deluxe collect and the retained value is the terminal 100,000 state.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_LEFT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_SHOW_QUALIFIED_ORBIT_SPECIAL
        CMPA #DELUXE_COLLECT_RIGHT_ORBIT+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_HIDE_ORBIT_SPECIAL
DELUXE_SHOW_QUALIFIED_ORBIT_SPECIAL:
        LDAA DELUXE_ORBIT_VALUE_STATE
        BNE DELUXE_HIDE_ORBIT_SPECIAL
        LDAA $10a0
        BITA #ORBIT_SPECIAL_ALREADY_COLLECTED_BIT
        BNE DELUXE_HIDE_ORBIT_SPECIAL
        LDAA ORBIT_SPECIAL_FLASH_MASK
        ORAA #ORBIT_SPECIAL_LAMP_BIT
        STAA ORBIT_SPECIAL_FLASH_MASK
        RTS
DELUXE_HIDE_ORBIT_SPECIAL:
        LDAA ORBIT_SPECIAL_FLASH_MASK
        ANDA #$ef
        STAA ORBIT_SPECIAL_FLASH_MASK
        RTS

DELUXE_HIDE_INACTIVE_ORBIT_LAMPS:
; The caller has already moved the collect to an inactive non-orbit location.
; Suppress the live special flash while retaining qualification at 10EF.
        JSR DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ORAA #$0f
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
        RTS

DELUXE_SCORE_UNLIT_ORBIT:
; The first original orbit score-table entry proves the printed base value is
; 5,000; Deluxe's global score scale makes the displayed award 500.
; Bypassing CB5C prevents an unlit hit from advancing the shared value.
        TBA
        JSR $c27e
        JMP AWARD_500_POINTS_WITH_PLAYFIELD_MULTIPLIER

DELUXE_AWARD_SCALED_2500:
; CC85 calls here for every E-I-G-H-T target hit. Pool-ball first sinks also
; tail-call here when they do not match the currently spoken ball. Apply
; Deluxe's global divide-by-ten score scale to the 2,500 playfield value: one
; multiplier-aware 50-point award plus two multiplier-aware 100-point units
; produces displayed scores of 250 / 500 / 750 at 1x / 2x / 3x. The later
; already-sunk pool-ball path remains at D034 and still drives the physical
; 5,000 lamp effect independently.
        JSR AWARD_50_POINTS_WITH_PLAYFIELD_MULTIPLIER
        LDAB #$02
        JMP AWARD_B_HUNDRED_WITH_PLAYFIELD_MULTIPLIER

DELUXE_AWARD_POOL_BALL_FIRST_SINK:
; CE08 enters with A equal to the single target bit for balls 1-7. Reproduce
; the canonical CE1A-CE28 conversion from target bit to the player-specific
; spoken sound ID, then compare it with the current call at 10C4. Odd-numbered
; players use IDs 51-57 and even-numbered players use 59-5F.
        TAB
        LDAA #$50
DELUXE_CALLED_BALL_ID_LOOP:
        INCA
        LSRB
        BNE DELUXE_CALLED_BALL_ID_LOOP
        LDAB.w $008f
        LSRB
        BCS DELUXE_COMPARE_CALLED_BALL_ID
        ADDA #$08
DELUXE_COMPARE_CALLED_BALL_ID:
        CMPA CALLED_POOL_BALL_SOUND_ID
        BNE DELUXE_AWARD_UNCALLED_POOL_BALL
        BSR DELUXE_AWARD_AND_ADVANCE_CALLED_BALL_SCORE
        JSR DELUXE_SAVE_ACTIVE_PLAYER_BONUS_COUNTERS
        RTS

DELUXE_AWARD_AND_ADVANCE_CALLED_BALL_SCORE:
; The active byte stores displayed thousands: 1, 2, 3... corresponds to the
; requested 10K, 20K, 30K... playfield values after Deluxe's divide-by-ten
; score scale. Award the current value through the CHAMP multiplier, then add
; one displayed thousand (10K playfield). Values above 240 are split across
; two normalized queue additions so B plus the existing decimal digit cannot
; overflow; this does not alter the score or multiplier. Treat zero from an
; older saved game/NVRAM image as the initial value, and saturate at 255.
        LDAA DELUXE_CALLED_BALL_SCORE_1000S
        BNE DELUXE_CALLED_BALL_SCORE_READY
        INCA
        STAA DELUXE_CALLED_BALL_SCORE_1000S
DELUXE_CALLED_BALL_SCORE_READY:
        JSR DELUXE_START_CALLED_BALL_SCORE_DISPLAY
        TAB
        CMPB #$f1
        BCS DELUXE_AWARD_CALLED_BALL_SCORE_LOW_CHUNK
        SUBB #$f0
        JSR AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER
        LDAB #$f0
DELUXE_AWARD_CALLED_BALL_SCORE_LOW_CHUNK:
        JSR AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER
        LDAA DELUXE_CALLED_BALL_SCORE_1000S
        CMPA #$ff
        BEQ DELUXE_CALLED_BALL_SCORE_ADVANCED
        ADDA #$01
        STAA DELUXE_CALLED_BALL_SCORE_1000S
DELUXE_CALLED_BALL_SCORE_ADVANCED:
        RTS

DELUXE_AWARD_UNCALLED_POOL_BALL:
; A newly sunk ball that is not the current call earns the normal scaled 250
; points. Show that exact post-multiplier award on the other three player
; displays, then retain the existing multiplier-aware scoring path.
        JSR DELUXE_START_NORMAL_BALL_SCORE_DISPLAY
        JMP DELUXE_AWARD_SCALED_2500

DELUXE_START_NORMAL_BALL_SCORE_DISPLAY:
; Build 250, 500, or 750 in the canonical seven-byte display format. Bytes
; are ordered ones through millions and carry the digit in their high nibble.
        PSHA
        PSHB
        PSHX
        JSR DELUXE_BEGIN_SUNK_BALL_SCORE_DISPLAY
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+0
        LDAA #$50
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+1
        LDAA #$20
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+2
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+3
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+5
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+6
        LDAA CHAMP_COMPLETION_STATE
        BITA #$20
        BNE DELUXE_FORMAT_NORMAL_BALL_TRIPLE
        BITA #$10
        BEQ DELUXE_NORMAL_BALL_SCORE_READY
; Double: 500.
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+1
        LDAA #$50
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+2
        BRA DELUXE_NORMAL_BALL_SCORE_READY
DELUXE_FORMAT_NORMAL_BALL_TRIPLE:
; Triple: 750.
        LDAA #$70
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+2
DELUXE_NORMAL_BALL_SCORE_READY:
        JSR DELUXE_APPLY_SUNK_BALL_SCORE_DISPLAY
        PULX
        PULB
        PULA
        RTS

DELUXE_START_CALLED_BALL_SCORE_DISPLAY:
; Input A is the active Called ball score in displayed thousands (1-255).
; Multiply it by the same authoritative 1x/2x/3x CHAMP state used by the
; scoring helper, convert the resulting 1-765 thousands to decimal, and append
; three zeroes. MUL leaves the 16-bit binary product in D.
        PSHA
        PSHB
        PSHX
        TAB
        LDAA CHAMP_COMPLETION_STATE
        BITA #$20
        BNE DELUXE_CALLED_BALL_DISPLAY_TRIPLE
        BITA #$10
        BNE DELUXE_CALLED_BALL_DISPLAY_DOUBLE
        LDAA #$01
        BRA DELUXE_CALLED_BALL_DISPLAY_MULTIPLY
DELUXE_CALLED_BALL_DISPLAY_DOUBLE:
        LDAA #$02
        BRA DELUXE_CALLED_BALL_DISPLAY_MULTIPLY
DELUXE_CALLED_BALL_DISPLAY_TRIPLE:
        LDAA #$03
DELUXE_CALLED_BALL_DISPLAY_MULTIPLY:
        MUL
        STD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        JSR DELUXE_BEGIN_SUNK_BALL_SCORE_DISPLAY
; The award is always an integral number of thousands.
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+0
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+1
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+2
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+3
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+4
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+5
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+6

DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_LOOP:
        LDD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        SUBD #$0064
        BCS DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_DONE
        STD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+5
        ADDA #$10
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+5
        BRA DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_LOOP
DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_DONE:
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+5
        BNE DELUXE_CALLED_BALL_DISPLAY_TENS_LOOP
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+5

DELUXE_CALLED_BALL_DISPLAY_TENS_LOOP:
        LDD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        SUBD #$000A
        BCS DELUXE_CALLED_BALL_DISPLAY_TENS_DONE
        STD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        ADDA #$10
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        BRA DELUXE_CALLED_BALL_DISPLAY_TENS_LOOP
DELUXE_CALLED_BALL_DISPLAY_TENS_DONE:
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+5
        CMPA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        BNE DELUXE_CALLED_BALL_DISPLAY_ONES
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        BNE DELUXE_CALLED_BALL_DISPLAY_ONES
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
DELUXE_CALLED_BALL_DISPLAY_ONES:
        LDAB DELUXE_SUNK_BALL_SCORE_BINARY_WORK+1
        TBA
        ASLA
        ASLA
        ASLA
        ASLA
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+3
        JSR DELUXE_APPLY_SUNK_BALL_SCORE_DISPLAY
        PULX
        PULB
        PULA
        RTS

DELUXE_BEGIN_SUNK_BALL_SCORE_DISPLAY:
; Preserve the real four-player display bytes only on the first award in a
; popup. A second sink during the same three-second window replaces the shown
; value and restarts the timer without backing up the temporary overlay.
        LDAA DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER
        CMPA #DELUXE_SUNK_BALL_SCORE_OVERLAY_ACTIVE
        BEQ DELUXE_RESTART_SUNK_BALL_SCORE_DISPLAY
        JSR DELUXE_BACKUP_PLAYER_SCORE_DISPLAYS
        LDAA.w $008f
        STAA DELUXE_SUNK_BALL_SCORE_ACTIVE_PLAYER
        LDAA #DELUXE_SUNK_BALL_SCORE_OVERLAY_ACTIVE
        STAA DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER
DELUXE_RESTART_SUNK_BALL_SCORE_DISPLAY:
        LDAA #DELUXE_SUNK_BALL_SCORE_DISPLAY_TICKS
        STAA DELUXE_SUNK_BALL_SCORE_TIMER
        RTS

DELUXE_BACKUP_PLAYER_SCORE_DISPLAYS:
        PSHA
        PSHX
        LDX #PLAYER_SCORE_DISPLAY_START
DELUXE_BACKUP_PLAYER_SCORE_DISPLAY_LOOP:
        LDAA $00,X
        STAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET,X
        INX
        CPX #PLAYER_SCORE_DISPLAY_END
        BNE DELUXE_BACKUP_PLAYER_SCORE_DISPLAY_LOOP
        PULX
        PULA
        RTS

DELUXE_UPDATE_SUNK_BALL_SCORE_DISPLAY:
; Called by the existing gameplay periodic hook. Alternate the three non-active
; displays between the award and blank digits for roughly three seconds. The
; scoring player's display remains live throughout.
        LDAA DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER
        CMPA #DELUXE_SUNK_BALL_SCORE_OVERLAY_ACTIVE
        BNE DELUXE_SUNK_BALL_SCORE_DISPLAY_UPDATE_DONE
        LDAA DELUXE_SUNK_BALL_SCORE_TIMER
        BEQ DELUXE_SUNK_BALL_SCORE_DISPLAY_EXPIRED
        DECA
        STAA DELUXE_SUNK_BALL_SCORE_TIMER
        BEQ DELUXE_SUNK_BALL_SCORE_DISPLAY_EXPIRED
        BITA #DELUXE_SUNK_BALL_SCORE_BLINK_BIT
        BEQ DELUXE_SUNK_BALL_SCORE_DISPLAY_BLANK_PHASE
        JSR DELUXE_APPLY_SUNK_BALL_SCORE_DISPLAY
        RTS
DELUXE_SUNK_BALL_SCORE_DISPLAY_BLANK_PHASE:
        JSR DELUXE_BLANK_SUNK_BALL_SCORE_DISPLAYS
DELUXE_SUNK_BALL_SCORE_DISPLAY_UPDATE_DONE:
        RTS
DELUXE_SUNK_BALL_SCORE_DISPLAY_EXPIRED:
        JMP DELUXE_CANCEL_SUNK_BALL_SCORE_DISPLAY

DELUXE_APPLY_SUNK_BALL_SCORE_DISPLAY:
        PSHA
        PSHB
        PSHX
        LDX #PLAYER_SCORE_DISPLAY_START
        LDAB #$01
DELUXE_APPLY_SUNK_BALL_SCORE_PLAYER_LOOP:
        CMPB DELUXE_SUNK_BALL_SCORE_ACTIVE_PLAYER
        BEQ DELUXE_APPLY_SUNK_BALL_SCORE_NEXT_PLAYER
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+0
        STAA $00,X
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+1
        STAA $01,X
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+2
        STAA $02,X
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+3
        STAA $03,X
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        STAA $04,X
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+5
        STAA $05,X
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+6
        STAA $06,X
DELUXE_APPLY_SUNK_BALL_SCORE_NEXT_PLAYER:
        INX
        INX
        INX
        INX
        INX
        INX
        INX
        INCB
        CMPB #$05
        BNE DELUXE_APPLY_SUNK_BALL_SCORE_PLAYER_LOOP
        PULX
        PULB
        PULA
        RTS

DELUXE_BLANK_SUNK_BALL_SCORE_DISPLAYS:
        PSHA
        PSHB
        PSHX
        LDX #PLAYER_SCORE_DISPLAY_START
        LDAB #$01
DELUXE_BLANK_SUNK_BALL_SCORE_PLAYER_LOOP:
        CMPB DELUXE_SUNK_BALL_SCORE_ACTIVE_PLAYER
        BEQ DELUXE_BLANK_SUNK_BALL_SCORE_NEXT_PLAYER
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA $00,X
        STAA $01,X
        STAA $02,X
        STAA $03,X
        STAA $04,X
        STAA $05,X
        STAA $06,X
DELUXE_BLANK_SUNK_BALL_SCORE_NEXT_PLAYER:
        INX
        INX
        INX
        INX
        INX
        INX
        INX
        INCB
        CMPB #$05
        BNE DELUXE_BLANK_SUNK_BALL_SCORE_PLAYER_LOOP
        PULX
        PULB
        PULA
        RTS

DELUXE_CANCEL_SUNK_BALL_SCORE_DISPLAY:
; Restore only the displays that were overlaid. The scoring player's buffer was
; never replaced and may have continued changing while the award was visible.
        LDAA DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER
        CMPA #DELUXE_SUNK_BALL_SCORE_OVERLAY_ACTIVE
        BNE DELUXE_CANCEL_SUNK_BALL_SCORE_DISPLAY_DONE
        PSHA
        PSHB
        PSHX
        LDX #PLAYER_SCORE_DISPLAY_START
        LDAB #$01
DELUXE_RESTORE_SUNK_BALL_SCORE_PLAYER_LOOP:
        CMPB DELUXE_SUNK_BALL_SCORE_ACTIVE_PLAYER
        BEQ DELUXE_RESTORE_SUNK_BALL_SCORE_NEXT_PLAYER
        LDAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET+0,X
        STAA $00,X
        LDAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET+1,X
        STAA $01,X
        LDAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET+2,X
        STAA $02,X
        LDAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET+3,X
        STAA $03,X
        LDAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET+4,X
        STAA $04,X
        LDAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET+5,X
        STAA $05,X
        LDAA DELUXE_SCORE_DISPLAY_BACKUP_OFFSET+6,X
        STAA $06,X
DELUXE_RESTORE_SUNK_BALL_SCORE_NEXT_PLAYER:
        INX
        INX
        INX
        INX
        INX
        INX
        INX
        INCB
        CMPB #$05
        BNE DELUXE_RESTORE_SUNK_BALL_SCORE_PLAYER_LOOP
        CLR DELUXE_SUNK_BALL_SCORE_TIMER
        CLR DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER
        PULX
        PULB
        PULA
DELUXE_CANCEL_SUNK_BALL_SCORE_DISPLAY_DONE:
        RTS

DELUXE_AFTER_FIRST_SINK:
; CE13 jumps here with A equal to the newly updated sunk-ball mask and the
; selected target bit saved on top of the stack. Restore that exact stack
; shape before returning to the canonical first-sink animation at CE1A.
; Already-sunk targets never reach this hook: they branch to the canonical
; scaled 500-point path (original 5,000) at D034 and cannot change the Deluxe
; collect state.
        PULB
        PSHB
        PSHA
        JSR DELUXE_ACTIVATE_CURRENT_COLLECT_IF_INACTIVE
        PULA
        JMP DELUXE_FIRST_SINK_CONTINUE

DELUXE_AFTER_EIGHT_BALL:
; CFAE calls this immediately after the original 8-ball completion sequence
; clears the balls-1-through-7 rack state. Award the active player's current
; Called ball score and advance it by 10K playfield value, then treat the
; committed 8-ball collect as one new-ball event for Deluxe and record the
; completed rack. Saturating at 255 prevents theoretical counter/value wraps.
; The activation helper is deliberately a no-op if the current stage is active,
; so an 8-ball is never queued for the following stage.
        JSR DELUXE_AWARD_AND_ADVANCE_CALLED_BALL_SCORE
; The canonical 8-ball speech reminder leaves both its pseudo call ID and its
; 16-bit reminder delay live after 10C3 starts the next rack. Restore any lamp
; XOR still applied for the old call before discarding that ID, then expire the
; delay so the normal selector immediately calls the first ball of the new rack.
        LDAA DELUXE_CALLED_BALL_FLASH_APPLIED_ID
        BEQ DELUXE_AFTER_EIGHT_BALL_FLASH_RESTORED
        JSR DELUXE_XOR_CALLED_BALL_LAMP_FOR_ID
        CLR DELUXE_CALLED_BALL_FLASH_APPLIED_ID
DELUXE_AFTER_EIGHT_BALL_FLASH_RESTORED:
        LDX #$0000
        STX CALLED_BALL_SPEECH_DELAY_TIMER
        CLR CALLED_POOL_BALL_SOUND_ID
        LDAA DELUXE_COMPLETED_EIGHT_BALL_RACKS
        CMPA #$ff
        BEQ DELUXE_AFTER_EIGHT_BALL_COUNTED
        INCA
        STAA DELUXE_COMPLETED_EIGHT_BALL_RACKS
DELUXE_AFTER_EIGHT_BALL_COUNTED:
        JSR DELUXE_SAVE_ACTIVE_PLAYER_BONUS_COUNTERS
        JSR DELUXE_ACTIVATE_CURRENT_COLLECT_IF_INACTIVE
        JMP $c6b8

DELUXE_BEGIN_BALL_BONUS_DISPLAY:
; C765 is entered once for the complete end-of-ball bonus, outside the nested
; multiplier passes. Save the actual credit-display bytes, then temporarily
; show completed racks in decimal while bonus is counted. The physical credit
; display has only two digits, so 100-255 racks display as 99 without changing
; the authoritative score counter at 10F0. Preserve B because the displaced
; C84B routine does not alter it.
; Restore any live sunk-ball display overlay before bonus or later end-of-ball
; score comparisons can inspect the four canonical player-score buffers.
        JSR DELUXE_CANCEL_SUNK_BALL_SCORE_DISPLAY
        PSHB
        LDAA CREDIT_DISPLAY_ONES
        STAA DELUXE_SAVED_CREDIT_DISPLAY_ONES
        LDAA CREDIT_DISPLAY_TENS
        STAA DELUXE_SAVED_CREDIT_DISPLAY_TENS
        LDAA DELUXE_COMPLETED_EIGHT_BALL_RACKS
        JSR DELUXE_SHOW_COUNT_ON_CREDIT_DISPLAY
        PULB
; Execute C765's displaced setup call and let its RTS return to C768.
        JMP $c84b

DELUXE_SHOW_COUNT_ON_CREDIT_DISPLAY:
; Render the unsigned count in A on the two credit digits. Preserve B for all
; callers. The display caps at 99, while its source counter remains unchanged.
        PSHB
        CMPA #$64
        BCS DELUXE_COUNT_DISPLAY_CONVERT_DECIMAL
        LDAA #$63
DELUXE_COUNT_DISPLAY_CONVERT_DECIMAL:
        CLRB
DELUXE_COUNT_DISPLAY_TENS_LOOP:
        CMPA #$0a
        BCS DELUXE_COUNT_DISPLAY_DIGITS_READY
        SUBA #$0a
        INCB
        BRA DELUXE_COUNT_DISPLAY_TENS_LOOP
DELUXE_COUNT_DISPLAY_DIGITS_READY:
; The interrupt uses the high nibble of each display byte: 1069 is the ones
; digit and 106A is the tens digit. Shift each binary digit into that nibble.
        ASLA
        ASLA
        ASLA
        ASLA
        STAA CREDIT_DISPLAY_ONES
        TBA
        ASLA
        ASLA
        ASLA
        ASLA
        STAA CREDIT_DISPLAY_TENS
        PULB
        RTS

DELUXE_SHOW_BALL_COUNT_AFTER_RACK_BONUS:
; C75C runs after every pool-rack multiplier pass has completed. Replace the
; rack total with the number of B-A-L-L letters earned, then perform C75C's
; displaced load for the canonical transition into the second bonus phase.
        LDAA DELUXE_COMPLETED_BALL_LETTERS
        JSR DELUXE_SHOW_COUNT_ON_CREDIT_DISPLAY
        LDAA $10b9
        RTS

DELUXE_RUN_BALL_BONUS_AND_RESTORE_CREDITS:
; C762 originally tail-jumped directly to C859. Call that complete B-A-L-L /
; partial E-I-G-H-T bonus phase, restore the untouched credit count only after
; all of its multiplier passes return, then return to the original caller.
        JSR $c859
        LDAA DELUXE_SAVED_CREDIT_DISPLAY_ONES
        STAA CREDIT_DISPLAY_ONES
        LDAA DELUXE_SAVED_CREDIT_DISPLAY_TENS
        STAA CREDIT_DISPLAY_TENS
        RTS

DELUXE_AFTER_EIGHT_WORD_COMPLETION:
; CCD4 is reached exactly once after all five E-I-G-H-T targets have completed
; and the original animation is about to award the next B-A-L-L lamp. Count
; every such completion even after the four physical lamps are saturated.
        JSR $d21f
        PSHA
        LDAA DELUXE_COMPLETED_BALL_LETTERS
        CMPA #$ff
        BEQ DELUXE_AFTER_EIGHT_WORD_COUNTED
        INCA
        STAA DELUXE_COMPLETED_BALL_LETTERS
DELUXE_AFTER_EIGHT_WORD_COUNTED:
        JSR DELUXE_SAVE_ACTIVE_PLAYER_BONUS_COUNTERS
        PULA
        RTS

DELUXE_INITIALIZE_PLAYER_BONUS_RECORD:
; The canonical new-game loop at C4E6 visits player numbers 4, 3, 2, and 1 and
; initializes each original nine-byte player record. Clear the previous game's
; collect state first so DELUXE_LOAD_ORBIT_STATE_FOR_SAVE takes its new-game
; path and stores the freshly initialized live orbit value instead of stale
; DELUXE_ORBIT_VALUE_STATE. Then clear the active Deluxe bonus counters, reset
; Called ball score to 10K playfield value (one displayed thousand), and write
; all three values to the matching parallel record before executing the
; displaced original record initializer at C58C.
; A new game rebuilds all four canonical score displays, so discard any stale
; overlay marker/timer without restoring an old game's backup bytes.
        CLR DELUXE_SUNK_BALL_SCORE_TIMER
        CLR DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER
        CLR DELUXE_COLLECT_STATE
        CLR DELUXE_COMPLETED_EIGHT_BALL_RACKS
        CLR DELUXE_COMPLETED_BALL_LETTERS
        LDAA #$01
        STAA DELUXE_CALLED_BALL_SCORE_1000S
        JSR DELUXE_SAVE_ACTIVE_PLAYER_BONUS_COUNTERS
        JMP $c58c

DELUXE_RESTORE_ACTIVE_PLAYER_BONUS_COUNTERS:
; C603 runs at the end of the original nine-byte player-record restore. Load
; the extended counters and Called ball score for the same 1-based player
; number in 008F, then execute C603's displaced call. Tail-jumping preserves
; F197's return state.
        JSR DELUXE_LOAD_ACTIVE_PLAYER_BONUS_COUNTERS
        JMP $f197

DELUXE_SAVE_ACTIVE_PLAYER_BONUS_COUNTERS:
; Write through on every completed rack, B-A-L-L letter, or Called ball score
; advance. This keeps the parallel player record current independent of later
; drain/bonus animation.
        PSHA
        PSHB
        PSHX
        BSR DELUXE_SELECT_ACTIVE_PLAYER_RACK_COUNTER
        LDAA DELUXE_COMPLETED_EIGHT_BALL_RACKS
        STAA 0,X
        LDAA DELUXE_COMPLETED_BALL_LETTERS
        STAA 4,X
        LDAA DELUXE_CALLED_BALL_SCORE_1000S
        STAA 9,X
        PULX
        PULB
        PULA
        RTS

DELUXE_LOAD_ACTIVE_PLAYER_BONUS_COUNTERS:
        PSHA
        PSHB
        PSHX
        BSR DELUXE_SELECT_ACTIVE_PLAYER_RACK_COUNTER
        LDAA 0,X
        STAA DELUXE_COMPLETED_EIGHT_BALL_RACKS
        LDAA 4,X
        STAA DELUXE_COMPLETED_BALL_LETTERS
        LDAA 9,X
        BNE DELUXE_LOAD_CALLED_BALL_SCORE
; A zero record predates Called ball score or is otherwise uninitialized.
; Migrate it in place so the first award is 10K playfield / 1K displayed.
        INCA
        STAA 9,X
DELUXE_LOAD_CALLED_BALL_SCORE:
        STAA DELUXE_CALLED_BALL_SCORE_1000S
        PULX
        PULB
        PULA
        RTS

DELUXE_SELECT_ACTIVE_PLAYER_RACK_COUNTER:
; $008F is the same 1-based player number used by the canonical record selector
; at C5C3. The rack array occupies 10F6-10F9; the B-A-L-L array is four bytes
; later at 10FA-10FD, and Called ball score is nine bytes later at 10FF-1102.
        LDX #DELUXE_PLAYER_RACK_COUNTS-1
        LDAB.w $008f
DELUXE_SELECT_ACTIVE_PLAYER_RACK_COUNTER_LOOP:
        INX
        DECB
        BNE DELUXE_SELECT_ACTIVE_PLAYER_RACK_COUNTER_LOOP
        RTS

DELUXE_BEGIN_BALL_LETTER_BONUS_PASS:
; C893 begins each complete 1x/2x/3x/5x pass through the B-A-L-L bonus. Reload
; a working copy so every multiplier pass scores all completed letters, then
; execute C893's displaced load of the partial E-I-G-H-T state.
        LDAB DELUXE_COMPLETED_BALL_LETTERS
        STAB DELUXE_BONUS_BALL_LETTERS_REMAINING
        LDAA $10ba
        RTS

DELUXE_PROCESS_COMPLETED_BALL_LETTER_BONUS:
; C8A6 is reached after the current partial E-I-G-H-T letters have been worth
; a scaled 1,000 each. Feed one completed B-A-L-L letter back through the
; five-letter loop at C8A1, producing 5 * 1,000 = 5,000 per B-A-L-L letter on
; every bonus-multiplier pass.
        LDAA DELUXE_BONUS_BALL_LETTERS_REMAINING
        BEQ DELUXE_BALL_LETTER_BONUS_DONE
        DECA
        STAA DELUXE_BONUS_BALL_LETTERS_REMAINING
        TAB
; Four active-low lamp bits can show only zero through four letters. Keep all
; four lit for counts of four or more, then count them down normally below four.
        LDAA CHAMP_MULTIPLIER_LAMP_SHADOW
        ORAA #$0f
        CMPB #$04
        BCC DELUXE_BONUS_SHOW_FOUR_OR_MORE_BALL_LETTERS
        CMPB #$03
        BEQ DELUXE_BONUS_SHOW_THREE_BALL_LETTERS
        CMPB #$02
        BEQ DELUXE_BONUS_SHOW_TWO_BALL_LETTERS
        CMPB #$01
        BEQ DELUXE_BONUS_SHOW_ONE_BALL_LETTER
        BRA DELUXE_BONUS_STORE_BALL_LETTERS
DELUXE_BONUS_SHOW_FOUR_OR_MORE_BALL_LETTERS:
        ANDA #$f0
        BRA DELUXE_BONUS_STORE_BALL_LETTERS
DELUXE_BONUS_SHOW_THREE_BALL_LETTERS:
        ANDA #$f8
        BRA DELUXE_BONUS_STORE_BALL_LETTERS
DELUXE_BONUS_SHOW_TWO_BALL_LETTERS:
        ANDA #$fc
        BRA DELUXE_BONUS_STORE_BALL_LETTERS
DELUXE_BONUS_SHOW_ONE_BALL_LETTER:
        ANDA #$fe
DELUXE_BONUS_STORE_BALL_LETTERS:
        STAA CHAMP_MULTIPLIER_LAMP_SHADOW
        LDAA #$e0
        STAA EIGHT_LETTER_STATE
        LDAB #DELUXE_BALL_BONUS_STEP_DELAY
        JMP $c8a1
DELUXE_BALL_LETTER_BONUS_DONE:
; C916 is the canonical return from the current B-A-L-L multiplier pass.
        JMP $c916

DELUXE_BEGIN_BONUS_PASS:
; C7A6 begins one complete pass through the end-of-ball bonus. The canonical
; routine calls it once at 1x, twice at 2x, three times at 3x, or five times at
; 5x. Preserve its delay selector in 10BB, and give every pass a fresh working
; copy of the completed-rack count so the original multiplier behavior remains
; exact.
        STAA $10bb
        LDAB DELUXE_COMPLETED_EIGHT_BALL_RACKS
        STAB DELUXE_BONUS_RACKS_REMAINING
        RTS

DELUXE_PROCESS_COMPLETED_RACK_BONUS:
; C809 reaches this after all individually sunk balls in the current partial
; rack have received their scaled 1,500-point bonus unit. Feed one completed
; rack at a time back through the eight-ball unit loop at C81C. Each rack
; therefore contributes 8 * 1,500 = 12,000 on every multiplier pass.
        LDAA DELUXE_BONUS_RACKS_REMAINING
        BEQ DELUXE_COMPLETED_RACK_BONUS_DONE
        DECA
        STAA DELUXE_BONUS_RACKS_REMAINING
        TAB
; The two center inserts can display only 120K, 240K, or 120K+240K. During
; bonus countdown, show the exact remaining count through two racks and cap
; the display at both inserts for three or more; RAM remains authoritative.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ORAA #$60
        CMPB #$03
        BCC DELUXE_BONUS_SHOW_THREE_OR_MORE_RACKS
        CMPB #$02
        BEQ DELUXE_BONUS_SHOW_TWO_RACKS
        CMPB #$01
        BEQ DELUXE_BONUS_SHOW_ONE_RACK
        BRA DELUXE_BONUS_STORE_RACK_LAMPS
DELUXE_BONUS_SHOW_THREE_OR_MORE_RACKS:
        ANDA #$9f
        BRA DELUXE_BONUS_STORE_RACK_LAMPS
DELUXE_BONUS_SHOW_TWO_RACKS:
        ANDA #$bf
        BRA DELUXE_BONUS_STORE_RACK_LAMPS
DELUXE_BONUS_SHOW_ONE_RACK:
        ANDA #$df
DELUXE_BONUS_STORE_RACK_LAMPS:
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
        LDAA #$ff
        STAA SUNK_POOL_BALLS_1_TO_7
        JSR $c83f
        JMP $c81c
DELUXE_COMPLETED_RACK_BONUS_DONE:
; C84A is the canonical return from the current multiplier pass.
        JMP $c84a

DELUXE_ACTIVATE_CURRENT_COLLECT_IF_INACTIVE:
; Shared by first sinks of balls 1-7 and by the lit 8-ball saucer collection.
; Activate the current location only; never change or queue its location here.
        LDAA DELUXE_COLLECT_STATE
        BITA #DELUXE_COLLECT_ACTIVE
        BNE DELUXE_COLLECT_ACTIVATION_DONE
; A newly sunk ball activates exactly the current waiting location. If already
; active, later sunk balls are not queued and do not change this state.
        ORAA #DELUXE_COLLECT_ACTIVE
        STAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        CMPA #DELUXE_COLLECT_SPINNER
        BEQ DELUXE_FIRST_SINK_ACTIVATE_SPINNER
        BRA DELUXE_FIRST_SINK_ACTIVATE_ORBIT

DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION:
; Called only after right orbit, spinner, or left orbit has changed from active
; to the following inactive location. Relight 100,000 only after 5x has already
; been collected. The post-5x waiting bit is set while 100,000 is dark; if it is
; clear, the award is already lit and this transition deliberately does nothing.
        LDAA $10c1
        BITA #HOLE_100000_STATE
        BEQ DELUXE_COLLECT_DEACTIVATION_100000_DONE
        LDAA DELUXE_COLLECT_STATE
        BITA #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        BEQ DELUXE_COLLECT_DEACTIVATION_100000_DONE
        ANDA #$bf
        ORAA #DELUXE_COLLECT_DEACTIVATION_AUTHORIZED
        STAA DELUXE_COLLECT_STATE
DELUXE_COLLECT_DEACTIVATION_100000_DONE:
        RTS

DELUXE_FIRST_SINK_ACTIVATE_ORBIT:
; The original all-off orbit state ($xF in the low nibble) scores 5,000.
; Activating either orbit collect promotes only that baseline to $xE, which
; the original table displays and scores as 10,000. Preserve any higher orbit
; value retained by the operator adjustment.
        LDAA DELUXE_ORBIT_VALUE_STATE
        CMPA #$0f
        BNE DELUXE_FIRST_SINK_SHOW_ORBIT
        ANDA #$fe
        STAA DELUXE_ORBIT_VALUE_STATE

DELUXE_FIRST_SINK_SHOW_ORBIT:
; Restore the retained low-nibble value while preserving 1044's unrelated
; upper pool-bonus/special bits.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$f0
        ORAA DELUXE_ORBIT_VALUE_STATE
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
        JSR DELUXE_START_ORBIT_SWEEP
        JSR DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY
        BRA DELUXE_COLLECT_ACTIVATION_DONE

DELUXE_FIRST_SINK_ACTIVATE_SPINNER:
; Activating spinner collect only reveals the value already accumulated in
; DELUXE_SPINNER_VALUE_MASK. It does not advance that value by itself.
        CLR DELUXE_SPINNER_PREVIEW_TIMER
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        CLR $10b2
DELUXE_COLLECT_ACTIVATION_DONE:
        RTS

DELUXE_FIRST_SINK_CONTINUE:
        LDAA PENDING_SOUND_COMMAND
        DECA
        PULB
        PSHB
        PSHA
        JMP $ce1a

DELUXE_RECORD_NEW_EIGHT_LETTER:
; The shared switch-33-through-37 handler reaches CC91 only when the dedicated
; E/I/G/H/T target's active-low bit at 1045 is still set. Perform the three
; displaced original instructions first, then advance the spinner value once.
; A repeated hit on a letter whose lamp is already on branches around this
; hook at CC8F, so it cannot advance the spinner.
        COMA
        ANDA 0,X
        STAA 0,X
        LDAA DELUXE_SPINNER_VALUE_MASK
        CMPA #DELUXE_SPINNER_ALL_VALUE_LAMPS
        BEQ DELUXE_NEW_EIGHT_LETTER_DONE
; The weighted three-lamp sequence is $20,$40,$60,$80,$A0,$C0,$E0:
; 1K -> 3K -> 4K -> 5K -> 6K -> 8K -> 9K.
        ADDA #DELUXE_SPINNER_1000_LAMP
        STAA DELUXE_SPINNER_VALUE_MASK
; While spinner is inactive, preview the new value by blinking its lamps for
; about three seconds. This changes only the lamp mask; scoring continues to use
; DELUXE_COLLECT_STATE and therefore cannot collect the previewed value.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_NEW_EIGHT_LETTER_SHOW_ACTIVE_VALUE
        LDAA #DELUXE_SPINNER_PREVIEW_TICKS
        STAA DELUXE_SPINNER_PREVIEW_TIMER
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        BRA DELUXE_NEW_EIGHT_LETTER_DONE
DELUXE_NEW_EIGHT_LETTER_SHOW_ACTIVE_VALUE:
        CLR DELUXE_SPINNER_PREVIEW_TIMER
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
DELUXE_NEW_EIGHT_LETTER_DONE:
; X still points at 1045. Resume where the original code reloads that byte and
; checks whether all five E-I-G-H-T letters have completed.
        JMP $cc96

DELUXE_HANDLE_HOLE_STATE:
; D069 jumps here after canonical sound/effect setup. The low nibble progresses
; independently through 2x ($01), 3x ($02), and 5x ($04). A hit while 5x is
; showing collects 5x, reaches terminal 100,000 ($08), and lights its first
; award immediately. Only later relights require active-to-inactive transitions.
        LDAA $10c1
        BITA #HOLE_100000_STATE
        BNE DELUXE_HOLE_TERMINAL_STATE
        BITA #HOLE_BONUS_5X_STATE
        BEQ DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH
; Let the original state dispatch advance 5x to 100,000. Clear any stale
; waiting state and authorize this initial 100,000 independently of the collect
; feature; transitions are required only after this award has been collected.
        LDAB DELUXE_COLLECT_STATE
        ANDB #$bf
        ORAB #DELUXE_COLLECT_DEACTIVATION_AUTHORIZED
        STAB DELUXE_COLLECT_STATE
        BRA DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH

DELUXE_HOLE_TERMINAL_STATE:
        LDAB DELUXE_COLLECT_STATE
        BITB #DELUXE_COLLECT_DEACTIVATION_AUTHORIZED
        BNE DELUXE_HOLE_AWARD_ARMED_100000
; At the post-5x state without authorization, retain $08 so the bonus remains
; 5x, keep 100K hidden, and award only the ordinary saucer value.
        LDAA DELUXE_COLLECT_STATE
        ORAA #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        STAA DELUXE_COLLECT_STATE
        JSR AWARD_50_POINTS_WITH_PLAYFIELD_MULTIPLIER
        LDAA $10c1
        JMP $d08c

DELUXE_HOLE_AWARD_ARMED_100000:
; Reproduce the canonical D070-D078 terminal award, then consume this collect-
; deactivation authorization. Keep $10C1 at $08 so the bonus remains 5x, store the
; unarmed condition in the separate waiting flag, and force the 100K flash
; phase off. A later active-to-inactive collect transition can reveal one more.
        JSR $c96c
        LDAA #$36
        JSR $c27e
        LDAA DELUXE_COLLECT_STATE
        ANDA #$7f
        ORAA #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        STAA DELUXE_COLLECT_STATE
        LDAA HOLE_BONUS_LAMP_SHADOW
        ORAA #HOLE_100000_STATE
        STAA HOLE_BONUS_LAMP_SHADOW
        JMP $d0b4

DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH:
        JMP $d06c

DELUXE_APPLY_HOLE_FLASH_MASK:
; C1BC originally XORed $10C1 directly into the hole lamp shadow. State $08
; must remain set after 5x is collected because drain bonus reads that state,
; but its low bit also flashes 100K. Suppress only that XOR while the post-5x
; award is waiting for another collect deactivation. Preserve B for the periodic
; lamp-refresh caller.
        PSHB
        LDAB DELUXE_COLLECT_STATE
        BITB #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        BNE DELUXE_HOLE_FLASH_DONE
        EORA $10c1
DELUXE_HOLE_FLASH_DONE:
        PULB
        RTS

DELUXE_LOAD_ORBIT_STATE_FOR_SAVE:
; C5B5 calls here while X addresses the current player's nine-byte record.
; Save the retained Deluxe orbit value even when the live lamp nibble is off.
; The full new-game path can save once before Deluxe initialization; location
; zero identifies that condition and leaves the canonical live value intact.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        BEQ DELUXE_LOAD_LIVE_ORBIT_STATE_FOR_SAVE
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$f0
        ORAA DELUXE_ORBIT_VALUE_STATE
        RTS
DELUXE_LOAD_LIVE_ORBIT_STATE_FOR_SAVE:
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        RTS

DELUXE_PREPARE_PLAYFIELD_SWITCH_HANDLER_TABLE:
; E63A enters after the normal-play dispatcher has accepted and cleared one
; switch event. B is the even byte offset into C011's handler-pointer table.
; While no called ball has yet been selected, expire the ball-start speech
; delay on the first genuine scoring/playfield closure. Deliberately exclude
; Outhole (offset 00), Credit (04), coin/tilt/slam/unused cabinet positions
; (10-14, 1A-1E), Lane Change cabinet (3C), and unused switches 38-40 (40-44).
; The accepted switch still reaches its original handler after this returns.
; Once 10C4 is nonzero, all later reminder timing remains canonical.
        LDAA CALLED_POOL_BALL_SOUND_ID
        BNE DELUXE_FIRST_SWITCH_CALL_DELAY_DONE
        CMPB #$02
        BEQ DELUXE_EXPIRE_INITIAL_CALLED_BALL_DELAY
        CMPB #$06
        BCS DELUXE_FIRST_SWITCH_CALL_DELAY_DONE
        CMPB #$10
        BCS DELUXE_EXPIRE_INITIAL_CALLED_BALL_DELAY
        CMPB #$16
        BCS DELUXE_FIRST_SWITCH_CALL_DELAY_DONE
        CMPB #$1A
        BCS DELUXE_EXPIRE_INITIAL_CALLED_BALL_DELAY
        CMPB #$20
        BCS DELUXE_FIRST_SWITCH_CALL_DELAY_DONE
        CMPB #$3C
        BCS DELUXE_EXPIRE_INITIAL_CALLED_BALL_DELAY
        CMPB #$3E
        BEQ DELUXE_EXPIRE_INITIAL_CALLED_BALL_DELAY
        CMPB #$46
        BCS DELUXE_FIRST_SWITCH_CALL_DELAY_DONE
DELUXE_EXPIRE_INITIAL_CALLED_BALL_DELAY:
        LDX #$0000
        STX CALLED_BALL_SPEECH_DELAY_TIMER
DELUXE_FIRST_SWITCH_CALL_DELAY_DONE:
        LDX #PLAYFIELD_SWITCH_HANDLER_TABLE
        RTS

DELUXE_FLASH_DROP_TARGET_LAMPS:
; C1AC calls this only when the canonical lamp-flash divider reaches its edge.
; First reproduce the displaced 103F/10BF operation for the five shared 5,000
; lamps. Then maintain a reversible overlay on exactly one individually
; numbered called-ball lamp. Recording the ID whose XOR is currently applied
; lets the next edge restore the original shadow state before changing calls or
; ending the flash. Entry X is 103A; preserve X and B for C1B3 onward.
        LDAA $05,X
        EORA DROP_TARGET_5000_LAMP_FLASH_MASK
        STAA $05,X
        PSHB
        PSHX
        LDAA DELUXE_CALLED_BALL_FLASH_APPLIED_ID
        BEQ DELUXE_CALLED_BALL_FLASH_CHECK_CURRENT
        CMPA CALLED_POOL_BALL_SOUND_ID
        BNE DELUXE_CALLED_BALL_FLASH_RESTORE_PREVIOUS
; The same call is still active. Removing the prior overlay is this edge's
; off-phase; leave it unapplied until the next canonical flash edge.
        BSR DELUXE_XOR_CALLED_BALL_LAMP_FOR_ID
        CLR DELUXE_CALLED_BALL_FLASH_APPLIED_ID
        BRA DELUXE_CALLED_BALL_FLASH_DONE
DELUXE_CALLED_BALL_FLASH_RESTORE_PREVIOUS:
        BSR DELUXE_XOR_CALLED_BALL_LAMP_FOR_ID
        CLR DELUXE_CALLED_BALL_FLASH_APPLIED_ID
DELUXE_CALLED_BALL_FLASH_CHECK_CURRENT:
        LDAA CALLED_POOL_BALL_SOUND_ID
        BEQ DELUXE_CALLED_BALL_FLASH_DONE
        ANDA #$07
        BEQ DELUXE_CALLED_BALL_FLASH_DONE
        LDAB #$01
DELUXE_CALLED_BALL_LAMP_MASK_LOOP:
        DECA
        BEQ DELUXE_CALLED_BALL_LAMP_MASK_READY
        ASLB
        BRA DELUXE_CALLED_BALL_LAMP_MASK_LOOP
DELUXE_CALLED_BALL_LAMP_MASK_READY:
        BITB SUNK_POOL_BALLS_1_TO_7
        BNE DELUXE_CALLED_BALL_FLASH_DONE
        LDAA CALLED_POOL_BALL_SOUND_ID
        BSR DELUXE_XOR_CALLED_BALL_LAMP_FOR_ID
        LDAA CALLED_POOL_BALL_SOUND_ID
        STAA DELUXE_CALLED_BALL_FLASH_APPLIED_ID
DELUXE_CALLED_BALL_FLASH_DONE:
        PULX
        PULB
        RTS

DELUXE_XOR_CALLED_BALL_LAMP_FOR_ID:
; Input A is a valid called speech ID. IDs 51-57 map to balls 1-7 in 103B;
; IDs 59-5F map to balls 9-15 in 103C. In either bank, the low three ID bits
; select the exact target lamp bit 0-6.
        CMPA #$59
        BCS DELUXE_CALLED_BALL_SELECT_SOLIDS_LAMP
        LDX #DROP_TARGET_BALLS_9_TO_15_LAMP_SHADOW
        BRA DELUXE_CALLED_BALL_SELECT_LAMP_BIT
DELUXE_CALLED_BALL_SELECT_SOLIDS_LAMP:
        LDX #DROP_TARGET_BALLS_1_TO_7_LAMP_SHADOW
DELUXE_CALLED_BALL_SELECT_LAMP_BIT:
        ANDA #$07
        LDAB #$01
DELUXE_CALLED_BALL_XOR_MASK_LOOP:
        DECA
        BEQ DELUXE_CALLED_BALL_XOR_MASK_READY
        ASLB
        BRA DELUXE_CALLED_BALL_XOR_MASK_LOOP
DELUXE_CALLED_BALL_XOR_MASK_READY:
        TBA
        EORA $00,X
        STAA $00,X
        RTS

DELUXE_PREPEND_STARTUP_SUPER:
; C45B has confirmed that speech is enabled, and C462-C46B has completed the
; canonical pre-announcement delay. Send "Super", restore C46D's displaced
; adjustment load immediately, then resume the canonical "Eight Ball, 3 Ball"
; / "Eight Ball, 5 Ball" selector without an added inter-command pause.
        LDAA #SQUAWK_TALK_SUPER_COMMAND
        JSR $c27e
        LDAB $161f
        JMP $c470

DELUXE_AWARD_SPECIAL_POINTS:
; All original special collectors converge at C1DB. Award an additional
; scaled 25,000 through the same multiplier-aware helpers used by normal
; scoring: 10,000 + 10,000 + 5,000 gives 25K/50K/75K at 1x/2x/3x.
; Then execute C1DB's displaced instruction and resume the original special
; processing, including its adjustment-controlled award and knocker behavior.
        JSR $c96c
        JSR $c96c
        JSR $c994
        LDX #$165f
        JMP $c1de

DELUXE_RULES_END:
; Preserve the canonical $FF fill up to the fixed interrupt module at $E000.
        ds.b $E000-DELUXE_RULES_END,$FF
