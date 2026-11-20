; Eight Ball Champ Deluxe rules
; Address range: $D3B2-$DFFF (verified $FF padding in the canonical ROM)
;
; Existing handlers jump here so their surrounding addresses, animation data,
; service code, and hardware timing remain fixed. See ../../gamerules.md for
; the complete rule contract.

DELUXE_PERIODIC_TICK:
; C14E calls this in place of its original LDX $10B3. Preserve A, process the
; spinner-collecting overlay and value-preview timers, then execute that displaced
; load last so C151 sees the same X value and condition codes as canonical.
        PSHA
        LDAA DELUXE_SPINNER_COLLECTING_TIMER
        BEQ DELUXE_SPINNER_PREVIEW_TICK
        DECA
        STAA DELUXE_SPINNER_COLLECTING_TIMER
        BNE DELUXE_SPINNER_PREVIEW_TICK
; Spinner collecting is independent of the current collect location. The first
; pulse already advanced that location to orbit inactive, and a new pool ball
; may since have activated the orbit. Expiration ends only the spinner scoring
; overlay and must not overwrite that newer location state. If another spinner
; stage has already become active, retain its newly displayed value lamps.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_SPINNER_PREVIEW_TICK
        CLR $10b1
        CLR $10b2
; Keep the following routines at their established addresses.
        dc.b $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
DELUXE_SPINNER_PREVIEW_TICK:
; A newly collected E-I-G-H-T letter starts this roughly 3.2-second lamp-only
; preview while the spinner collect is inactive. Bit 4 supplies a roughly
; half-second blink cycle, and the BF reload begins with a complete visible
; phase. Only 10B1 changes; DELUXE_COLLECT_STATE remains authoritative for
; scoring, so spinner pulses during the preview still take the unlit path.
        LDAA DELUXE_SPINNER_PREVIEW_TIMER
        BEQ DELUXE_ORBIT_PREVIEW_TICK
        DECA
        STAA DELUXE_SPINNER_PREVIEW_TIMER
        BEQ DELUXE_SPINNER_PREVIEW_FINISHED
        BITA #$10
        BEQ DELUXE_SPINNER_PREVIEW_HIDE
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        BRA DELUXE_ORBIT_PREVIEW_TICK
DELUXE_SPINNER_PREVIEW_HIDE:
        CLR $10b1
        BRA DELUXE_ORBIT_PREVIEW_TICK
DELUXE_SPINNER_PREVIEW_FINISHED:
        CLR $10b1
DELUXE_ORBIT_PREVIEW_TICK:
; A completed active right-orbit collect starts an independent preview of the
; newly advanced arrow value. Use the same duration and blink phase as the
; E-I-G-H-T spinner preview, but touch only 1044's orbit-value low nibble.
; The retained state at 10FF remains authoritative throughout the preview.
        LDAA DELUXE_ORBIT_PREVIEW_TIMER
        BEQ DELUXE_PERIODIC_AWARD_DISPLAY_TICK
        DECA
        STAA DELUXE_ORBIT_PREVIEW_TIMER
        BEQ DELUXE_ORBIT_PREVIEW_FINISHED
        BITA #$10
        BEQ DELUXE_ORBIT_PREVIEW_HIDE
        JSR DELUXE_SHOW_ORBIT_PREVIEW_VALUE
        BRA DELUXE_PERIODIC_AWARD_DISPLAY_TICK
DELUXE_ORBIT_PREVIEW_HIDE:
        JSR DELUXE_HIDE_ORBIT_PREVIEW_VALUE
        BRA DELUXE_PERIODIC_AWARD_DISPLAY_TICK
DELUXE_ORBIT_PREVIEW_FINISHED:
        JSR DELUXE_HIDE_ORBIT_PREVIEW_VALUE
DELUXE_PERIODIC_AWARD_DISPLAY_TICK:
        JSR DELUXE_UPDATE_SUNK_BALL_SCORE_DISPLAY
DELUXE_PERIODIC_TICK_DONE:
        PULA
        LDX $10b3
        RTS

DELUXE_SELECT_PHASE_B_LAMP_OUTPUT:
; E111 calls this from the timing-sensitive lamp-refresh interrupt instead of
; loading X with 1040 directly. Outside an active rack/B-A-L-L "more"
; indication, retain the original fast path. Otherwise copy the six Phase-B
; shadow bytes and change only the applicable bonus-lamp output bits. The
; C-H-A-M-P byte at 1040 is always copied unchanged.
        LDAA DELUXE_COMPLETED_EIGHT_BALL_RACKS
        CMPA #DELUXE_RACK_MORE_THRESHOLD
        BCC DELUXE_COPY_PHASE_B_LAMPS
        LDAA DELUXE_COMPLETED_BALL_LETTERS
        CMPA #DELUXE_BALL_MORE_THRESHOLD
        BCC DELUXE_COPY_PHASE_B_LAMPS
        JMP DELUXE_USE_LIVE_PHASE_B_LAMPS

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
DELUXE_APPLY_MORE_LAMP_OUTPUT:
; The canonical lamp-effect edge toggles this phase between $00 and $FF. Once
; the active player owns at least four racks, blink both active-low 120K/240K
; bits together. Once that player owns at least five completed B-A-L-L letters,
; blink active-low $1041 bits 0-3 together. Bits 4-7 drive unrelated playfield
; multiplier/special indications and remain untouched. Only this temporary
; serializer buffer changes; the live shadows and persistent counters do not.
        LDAA DELUXE_MORE_LAMPS_FLASH_PHASE
        BEQ DELUXE_PHASE_B_OUTPUT_READY_WITH_MORE
        LDAA DELUXE_COMPLETED_EIGHT_BALL_RACKS
        CMPA #DELUXE_RACK_MORE_THRESHOLD
        BCS DELUXE_APPLY_BALL_MORE_LAMP_OUTPUT
        LDAA $04,X
        EORA #DELUXE_RACK_MORE_LAMP_MASK
        STAA $04,X
DELUXE_APPLY_BALL_MORE_LAMP_OUTPUT:
        LDAA DELUXE_COMPLETED_BALL_LETTERS
        CMPA #DELUXE_BALL_MORE_THRESHOLD
        BCS DELUXE_PHASE_B_OUTPUT_READY_WITH_MORE
        LDAA $01,X
        EORA #DELUXE_BALL_MORE_LAMP_MASK
        STAA $01,X
DELUXE_PHASE_B_OUTPUT_READY_WITH_MORE:
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
        LDAA #DELUXE_COLLECT_OPENING_ORBIT
        STAA DELUXE_COLLECT_STATE
        CLR DELUXE_SPINNER_COLLECTING_TIMER
        CLR DELUXE_SPINNER_PREVIEW_TIMER
        CLR DELUXE_ORBIT_PREVIEW_TIMER
        CLR DELUXE_CHAMP_COMPLETION_COUNT
        LDAA #$01
        STAA DELUXE_HOLE_BONUS_MULTIPLIER
        STAA DELUXE_HOLE_NEXT_BONUS_MULTIPLIER
        CLR DELUXE_BONUS_MULTIPLIER_PASSES_REMAINING
; Permit the first new C or P return-lane letter of each ball. H/A/M top-lane
; letters never use this latch.
        LDAA #DELUXE_CHAMP_INLANE_ARMED
        STAA DELUXE_CHAMP_INLANE_REARMED
        CLR DELUXE_BONUS_RACKS_REMAINING
        CLR DELUXE_BONUS_BALL_LETTERS_REMAINING
        CLR DELUXE_CALLED_BALL_FLASH_APPLIED_ID
        CLR $10b1
        CLR $10b2
        LDAA #DELUXE_SPINNER_1000_LAMP
        STAA DELUXE_SPINNER_VALUE_MASK
; The canonical player restore at C500 has already loaded the retained orbit
; value into 1044. Keep its low-nibble value in Deluxe RAM, then set the live
; low nibble to all-off while the new ball begins at orbit inactive.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$0f
        STAA DELUXE_ORBIT_VALUE_STATE
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ORAA #$0f
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
; The terminal special may be retained from the player record, but the new
; ball begins at orbit inactive, so its live blinking mask must be hidden.
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
        JSR DELUXE_TEST_SPINNER_COLLECT_VALUE_ACTIVE
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
        JSR DELUXE_TEST_SPINNER_COLLECT_VALUE_ACTIVE
        BNE DELUXE_SCORE_UNLIT_SPINNER

; The first pulse advances the main location to orbit inactive and starts the
; independent spinner-collecting overlay. Every subsequent pulse retains the
; same lit value and refreshes the timer, even if a new pool ball has activated
; the orbit in the meantime. The weighted bits are worth 1k, 3k, and 5k.
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        TST DELUXE_SPINNER_COLLECTING_TIMER
        BNE DELUXE_REFRESH_SPINNER_COLLECTING_TIMER
        JSR DELUXE_BEGIN_SPINNER_COLLECTING
DELUXE_REFRESH_SPINNER_COLLECTING_TIMER:
        LDAA #DELUXE_SPINNER_COLLECTING_TICKS
        STAA DELUXE_SPINNER_COLLECTING_TIMER
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
; Called after each completed C-H-A-M-P word. Completion 1 raises the right
; thumper to a manual/playfield 3,000 (300 displayed); completion 2 selects
; double; completion 3 raises the left thumper to the same 3,000; completion
; 4 selects triple; completion 5 lights both outlane specials and awards a
; base manual/playfield 30,000 (3,000 displayed) through the playfield
; multiplier. Every later completion repeats that multiplier-aware base award.
; The thumper handlers read this per-ball counter and run their elevated values
; through the same authoritative multiplier.
; Completing the word also rearms the C/P anti-shatz latch, irrespective of
; which of the five letters completed it.
        LDAA #DELUXE_CHAMP_INLANE_ARMED
        STAA DELUXE_CHAMP_INLANE_REARMED
        INC DELUXE_CHAMP_COMPLETION_COUNT
        LDAA DELUXE_CHAMP_COMPLETION_COUNT
        CMPA #$02
        BEQ DELUXE_CHAMP_SET_DOUBLE
        CMPA #$04
        BEQ DELUXE_CHAMP_SET_TRIPLE
        CMPA #$05
        BCS DELUXE_CHAMP_DONE
        BNE DELUXE_CHAMP_AWARD_REPEAT_30000
        LDAA #$e0
        BSR DELUXE_CHAMP_STORE_STATE
        BRA DELUXE_CHAMP_AWARD_30000
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
        RTS
DELUXE_CHAMP_AWARD_REPEAT_30000:
; Saturate the milestone count after completion 5 so the pop upgrades cannot
; wrap back to their base values during an exceptionally long ball.
        LDAA #$05
        STAA DELUXE_CHAMP_COMPLETION_COUNT
DELUXE_CHAMP_AWARD_30000:
; B=3 is one Deluxe-scaled 30K playfield/manual base (3K displayed). Send that
; single base value through the common multiplier path; at the fifth and later
; completions the already-earned 3x state makes the milestone award 90K.
        LDAB #$03
        JMP AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER
DELUXE_CHAMP_DONE:
        RTS

DELUXE_HANDLE_LEFT_THUMPER:
; Switch 02. Preserve the stock sound and score/tilt gate. Beginning with the
; third CHAMP completion this pop scores manual/playfield 3,000 (300 displayed)
; through the current 1x/2x/3x playfield multiplier; before that it retains
; the stock 1,000 (100 displayed) value.
        LDAB #$20
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        LDAA DELUXE_CHAMP_COMPLETION_COUNT
        CMPA #$03
        BCC DELUXE_SCORE_THUMPER_3000
        BRA DELUXE_SCORE_THUMPER_BASE

DELUXE_HANDLE_RIGHT_THUMPER:
; Switch 01. The right pop reaches the same multiplier-aware 3,000 value after
; the first CHAMP completion and otherwise retains the stock value.
        LDAB #$20
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        LDAA DELUXE_CHAMP_COMPLETION_COUNT
        CMPA #$01
        BCC DELUXE_SCORE_THUMPER_3000
DELUXE_SCORE_THUMPER_BASE:
        LDAB #$01
        JMP AWARD_B_HUNDRED_WITH_PLAYFIELD_MULTIPLIER
DELUXE_SCORE_THUMPER_3000:
        LDAB #$03
        JMP AWARD_B_HUNDRED_WITH_PLAYFIELD_MULTIPLIER

DELUXE_HANDLE_ORBIT:
; CB4F/CB53 select sound $2A/$29 for right/left before reaching this routine.
; A maxed right orbit must use the left orbit's collect-only sound. Substitute
; $29 before the common gate can queue $2A, then branch explicitly back to the
; right-side rule path after the gate. Otherwise, the common gate stores the
; original selector at 1024 and overwrites B while testing the score-enable
; lamp bits, so use that stored command to identify the side. A failed gate
; still unwinds this call exactly as it did in the original.
        CMPB #RIGHT_ORBIT_ACTIVE_SOUND_COMMAND
        BNE DELUXE_QUEUE_ORBIT_SOUND
        LDAA DELUXE_ORBIT_VALUE_STATE
        BNE DELUXE_QUEUE_ORBIT_SOUND
        LDAB #LEFT_ORBIT_ACTIVE_SOUND_COMMAND
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        BRA DELUXE_HANDLE_RIGHT_ORBIT
DELUXE_QUEUE_ORBIT_SOUND:
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        LDAA PENDING_SOUND_COMMAND
        CMPA #$29
        BEQ DELUXE_HANDLE_LEFT_ORBIT

DELUXE_HANDLE_RIGHT_ORBIT:
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_OPENING_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_HANDLE_ACTIVE_RIGHT_ORBIT
; Both encoded orbit stages accept either physical rollover. Either rollover
; advances the collect to spinner inactive. The left advances the shared arrow
; value once; the right applies a second, saturating value step.
        CMPA #DELUXE_COLLECT_DUAL_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_HANDLE_ACTIVE_RIGHT_ORBIT
        JMP DELUXE_SCORE_UNLIT_ORBIT
DELUXE_HANDLE_ACTIVE_RIGHT_ORBIT:
; Keep the orbit stage active while the original handler runs its fast upward
; arrow chase. Advance to spinner inactive only after that animation returns.
        JMP DELUXE_SCORE_ACTIVE_RIGHT_ORBIT

DELUXE_HANDLE_LEFT_ORBIT:
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_OPENING_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_HANDLE_ACTIVE_LEFT_ORBIT
        CMPA #DELUXE_COLLECT_DUAL_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_HANDLE_ACTIVE_LEFT_ORBIT
; An inactive left orbit always scores the unlit 5,000 and cannot collect or
; advance the retained orbit value. This includes the terminal 100,000/special
; state: its qualification remains stored until an active orbit collect runs
; the original lit-orbit routine.
        JMP DELUXE_SCORE_UNLIT_ORBIT

DELUXE_HANDLE_ACTIVE_LEFT_ORBIT:
; Advance to spinner inactive only after lit scoring and the arrow chase finish.
        JMP DELUXE_SCORE_ACTIVE_LEFT_ORBIT

DELUXE_SCORE_ACTIVE_LEFT_ORBIT:
; Score the lit value and let the canonical chase advance the retained arrow
; value by one 10,000 step. Preserve the original left collect's post-gate B
; value exactly as the earlier working ding path did; do not force a new sound
; selector here. Then share the right path's next-value preview finish without
; its extra value step or double $2A sound.
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        BRA DELUXE_FINISH_ACTIVE_ORBIT_WITH_PREVIEW

DELUXE_SCORE_ACTIVE_RIGHT_ORBIT:
; Finish the original chase before moving the sequence to spinner inactive.
; Preserve only the two saucer flags, and darken the spinner value lamps until
; a newly sunk ball activates that location; sunk balls are never queued. Once
; the chase advances the orbit value, preview that new value with the same
; roughly three-second blink cadence used by the E-I-G-H-T spinner preview.
; The canonical routine advances one 10,000 step. Advance the retained encoding
; one more step afterward for a 20,000 total increase, saturating at the
; 100,000/Special terminal state.
; Send the existing right-orbit command twice back-to-back before scoring and
; the chase. C27E clobbers B, so reload the selector for the second send inside
; DELUXE_RUN_ORIGINAL_LIT_ORBIT. At the terminal value, there is no advance to
; announce: use the left orbit's single collect sound instead.
        LDAA DELUXE_ORBIT_VALUE_STATE
        BEQ DELUXE_RUN_TERMINAL_RIGHT_ORBIT
        LDAA #RIGHT_ORBIT_ACTIVE_SOUND_COMMAND
        JSR $c27e
        LDAB #RIGHT_ORBIT_ACTIVE_SOUND_COMMAND
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        BRA DELUXE_AFTER_RIGHT_ORBIT_SCORE
DELUXE_RUN_TERMINAL_RIGHT_ORBIT:
; The canonical terminal collector independently requests loud Special sound
; $6F after the normal orbit sound. Suppress only that one request so this hit
; retains the same ding as the left rollover while all Special award, latch,
; adjustment, and knocker processing still runs.
        LDAA #$01
        STAA DELUXE_SUPPRESS_NEXT_SPECIAL_SOUND
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        CLR DELUXE_SUPPRESS_NEXT_SPECIAL_SOUND
DELUXE_AFTER_RIGHT_ORBIT_SCORE:
        BSR DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_STEP
DELUXE_FINISH_ACTIVE_ORBIT_WITH_PREVIEW:
        LDAA DELUXE_COLLECT_STATE
        ANDA #$c0
        ORAA #DELUXE_COLLECT_SPINNER
        STAA DELUXE_COLLECT_STATE
        JSR DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION
        CLR $10b1
        CLR $10b2
        LDAA #DELUXE_ORBIT_PREVIEW_TICKS
        STAA DELUXE_ORBIT_PREVIEW_TIMER
; Moving to spinner inactive must hide the orbit Special even while the newly
; advanced numeric arrow value is being previewed.
        JSR DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY
        BRA DELUXE_SHOW_ORBIT_PREVIEW_VALUE

DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_STEP:
; Valid retained states encode 10K through 100K as E,D,B,7,6,5,3,2,1,0.
; Most steps decrement; D->B, B->7, and 5->3 skip unused bit patterns. Zero is
; terminal and must never wrap, so a right-orbit +20K advance clamps at 100K.
        LDAA DELUXE_ORBIT_VALUE_STATE
        BEQ DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_DONE
        CMPA #$0d
        BEQ DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_TO_30K
        CMPA #$0b
        BEQ DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_TO_40K
        CMPA #$05
        BEQ DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_TO_70K
        DECA
        BRA DELUXE_STORE_EXTRA_ORBIT_ADVANCE
DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_TO_30K:
        LDAA #$0b
        BRA DELUXE_STORE_EXTRA_ORBIT_ADVANCE
DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_TO_40K:
        LDAA #$07
        BRA DELUXE_STORE_EXTRA_ORBIT_ADVANCE
DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_TO_70K:
        LDAA #$03
DELUXE_STORE_EXTRA_ORBIT_ADVANCE:
        STAA DELUXE_ORBIT_VALUE_STATE
DELUXE_ADVANCE_ORBIT_VALUE_EXTRA_DONE:
        RTS

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
        CMPA #DELUXE_COLLECT_DUAL_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_SHOW_QUALIFIED_ORBIT_SPECIAL
        CMPA #DELUXE_COLLECT_OPENING_ORBIT+DELUXE_COLLECT_ACTIVE
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
; Suppress the live special flash while retaining qualification at 10FF.
        CLR DELUXE_ORBIT_PREVIEW_TIMER
        JSR DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY
DELUXE_HIDE_ORBIT_PREVIEW_VALUE:
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ORAA #$0f
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
        RTS

DELUXE_SHOW_ORBIT_PREVIEW_VALUE:
; Show only the retained orbit-value low nibble. Preserve 1044's unrelated
; upper pool-bonus/special bits while the preview alternates visible and dark.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$f0
        ORAA DELUXE_ORBIT_VALUE_STATE
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
        RTS

DELUXE_SCORE_UNLIT_ORBIT:
; The first original orbit score-table entry proves the printed base value is
; 5,000; Deluxe's global score scale makes the displayed award 500.
; Bypassing CB5C prevents an unlit hit from advancing the shared value. Use
; command $31 from the playfield's 500-point center rollover at CAA3 so the
; inactive shot is audibly distinct from an active left/right orbit collect.
        LDAA #CENTER_ROLLOVER_500_SOUND_COMMAND
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
; The active byte stores displayed 500-point units: 1-10 corresponds to the
; requested 5K-50K playfield range after Deluxe's divide-by-ten score scale.
; Award the current value through the CHAMP multiplier, then add one unit
; (5K playfield) until the value saturates at 50K. Treat zero from an older
; saved game/NVRAM image as the initial value.
        LDAA DELUXE_CALLED_BALL_SCORE_500S
        BNE DELUXE_CALLED_BALL_SCORE_NONZERO
        LDAA #DELUXE_CALLED_BALL_INITIAL_500S
        STAA DELUXE_CALLED_BALL_SCORE_500S
        BRA DELUXE_CALLED_BALL_SCORE_READY
DELUXE_CALLED_BALL_SCORE_NONZERO:
; Clamp records from an earlier ROM revision before they can exceed the new cap.
        CMPA #DELUXE_CALLED_BALL_MAXIMUM_500S
        BLS DELUXE_CALLED_BALL_SCORE_READY
        LDAA #DELUXE_CALLED_BALL_MAXIMUM_500S
        STAA DELUXE_CALLED_BALL_SCORE_500S
DELUXE_CALLED_BALL_SCORE_READY:
        JSR DELUXE_START_CALLED_BALL_SCORE_DISPLAY
        TAB
        LDAA #$05
        MUL
        JSR AWARD_B_HUNDRED_WITH_PLAYFIELD_MULTIPLIER
        LDAA DELUXE_CALLED_BALL_SCORE_500S
        CMPA #DELUXE_CALLED_BALL_MAXIMUM_500S
        BCC DELUXE_CALLED_BALL_SCORE_ADVANCED
        ADDA #$01
        STAA DELUXE_CALLED_BALL_SCORE_500S
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
; Input A is the active Called ball score in displayed 500-point units (1-10).
; Multiply it by the same authoritative 1x/2x/3x CHAMP state used by the
; scoring helper, convert the resulting award to displayed hundreds, and append
; two zeroes. The maximum formatted award is 15,000 at 50K playfield and 3x.
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
; D is now 1-30 half-thousands. It fits in B, so multiply by five to obtain
; displayed hundreds before formatting the decimal digits.
        LDAA #$05
        MUL
        STD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        JSR DELUXE_BEGIN_SUNK_BALL_SCORE_DISPLAY
; The award is always an integral number of hundreds.
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+0
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+1
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+2
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+3
        CLR DELUXE_SUNK_BALL_SCORE_DIGITS+4
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+5
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+6

DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_LOOP:
        LDD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        SUBD #$0064
        BCS DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_DONE
        STD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        ADDA #$10
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        BRA DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_LOOP
DELUXE_CALLED_BALL_DISPLAY_HUNDREDS_DONE:
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        BNE DELUXE_CALLED_BALL_DISPLAY_TENS_LOOP
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+4

DELUXE_CALLED_BALL_DISPLAY_TENS_LOOP:
        LDD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        SUBD #$000A
        BCS DELUXE_CALLED_BALL_DISPLAY_TENS_DONE
        STD DELUXE_SUNK_BALL_SCORE_BINARY_WORK
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+3
        ADDA #$10
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+3
        BRA DELUXE_CALLED_BALL_DISPLAY_TENS_LOOP
DELUXE_CALLED_BALL_DISPLAY_TENS_DONE:
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+4
        CMPA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        BNE DELUXE_CALLED_BALL_DISPLAY_ONES
        LDAA DELUXE_SUNK_BALL_SCORE_DIGITS+3
        BNE DELUXE_CALLED_BALL_DISPLAY_ONES
        LDAA #DELUXE_SCORE_DISPLAY_BLANK_DIGIT
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+3
DELUXE_CALLED_BALL_DISPLAY_ONES:
        LDAB DELUXE_SUNK_BALL_SCORE_BINARY_WORK+1
        TBA
        ASLA
        ASLA
        ASLA
        ASLA
        STAA DELUXE_SUNK_BALL_SCORE_DIGITS+2
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
; Called ball score and advance it by 5K playfield value, then treat the
; committed 8-ball collect as one new-ball event for Deluxe and record the
; completed rack. The rack counter saturates at 255; the Called Ball helper
; separately saturates its progression at the 50K playfield maximum.
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
; the authoritative score counter at 1100. Preserve B because the displaced
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

DELUXE_RUN_RACK_BONUS_MULTIPLIER:
; C776 enters after the canonical rack/ball state snapshots are complete.
; Run the entire pool-rack bonus once per authoritative numeric multiplier
; unit. C7A6 reloads the completed-rack count for every pass and returns at
; C84A. RTS then returns directly to C765's original caller.
        LDAA DELUXE_HOLE_BONUS_MULTIPLIER
        STAA DELUXE_BONUS_MULTIPLIER_PASSES_REMAINING
DELUXE_RUN_RACK_BONUS_PASS:
        LDAA #DELUXE_RACK_BONUS_STEP_DELAY
        JSR $c7a6
        DEC DELUXE_BONUS_MULTIPLIER_PASSES_REMAINING
        BNE DELUXE_RUN_RACK_BONUS_PASS
        LDAA #$ff
        STAA HOLE_BONUS_LAMP_SHADOW
        RTS

DELUXE_RUN_BALL_BONUS_MULTIPLIER:
; C869 enters after the B-A-L-L/E-I-G-H-T snapshots are complete. C893
; reloads the completed B-A-L-L count for each pass, then returns after the
; complete partial-word bonus. Use the same authoritative multiplier as the
; rack phase, and leave the saucer lamps dark when end-of-ball bonus finishes.
        LDAA DELUXE_HOLE_BONUS_MULTIPLIER
        STAA DELUXE_BONUS_MULTIPLIER_PASSES_REMAINING
DELUXE_RUN_BALL_BONUS_PASS:
        JSR $c893
        DEC DELUXE_BONUS_MULTIPLIER_PASSES_REMAINING
        BNE DELUXE_RUN_BALL_BONUS_PASS
        LDAA #$ff
        STAA HOLE_BONUS_LAMP_SHADOW
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
; initializes each original 13-byte player slot (nine stored bytes followed by
; four reserved stride bytes). Clear the previous game's
; collect state first so DELUXE_LOAD_ORBIT_STATE_FOR_SAVE takes its new-game
; path and stores the freshly initialized live orbit value instead of stale
; DELUXE_ORBIT_VALUE_STATE. Then clear the active Deluxe bonus counters, reset
; Called ball score to 5K playfield value (one displayed 500-point unit), and write
; all three values to the matching parallel record before executing the
; displaced original record initializer at C58C.
; A new game rebuilds all four canonical score displays, so discard any stale
; overlay marker/timer without restoring an old game's backup bytes.
        CLR DELUXE_SUNK_BALL_SCORE_TIMER
        CLR DELUXE_SUNK_BALL_SCORE_OVERLAY_MARKER
        CLR DELUXE_MORE_LAMPS_FLASH_PHASE
        CLR DELUXE_COLLECT_STATE
        CLR DELUXE_COMPLETED_EIGHT_BALL_RACKS
        CLR DELUXE_COMPLETED_BALL_LETTERS
        LDAA #DELUXE_CALLED_BALL_INITIAL_500S
        STAA DELUXE_CALLED_BALL_SCORE_500S
        JSR DELUXE_SAVE_ACTIVE_PLAYER_BONUS_COUNTERS
        JMP $c58c

DELUXE_RESTORE_ACTIVE_PLAYER_BONUS_COUNTERS:
; C603 runs at the end of the original nine-byte player-data restore. Load
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
        LDAA DELUXE_CALLED_BALL_SCORE_500S
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
; Migrate it in place so the first award is 5K playfield / 500 displayed.
        LDAA #DELUXE_CALLED_BALL_INITIAL_500S
        STAA 9,X
DELUXE_LOAD_CALLED_BALL_SCORE:
        STAA DELUXE_CALLED_BALL_SCORE_500S
        PULX
        PULB
        PULA
        RTS

DELUXE_SELECT_ACTIVE_PLAYER_RACK_COUNTER:
; $008F is the same 1-based player number used by the canonical record selector
; at C5C3. The rack array occupies 1106-1109; the B-A-L-L array is four bytes
; later at 110A-110D, and Called ball score is nine bytes later at 110F-1112.
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
        LDAB #DELUXE_BALL_BONUS_STEP_DELAY                   ; 6/8 of prior Deluxe delay (about 33% faster)
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
; Called only after either orbit collect or the first active-spinner pulse has
; changed to the following inactive location. The waiting bit means the previous
; saucer award was collected and the top lamps are dark. A qualifying transition
; authorizes the saucer and makes the whole next award blink: 7x+100K, 8x+100K,
; 10x+100K, then 100K alone after 10x has been earned.
        LDAA $10c1
        BITA #HOLE_100000_STATE
        BEQ DELUXE_COLLECT_DEACTIVATION_100000_DONE
        LDAA DELUXE_COLLECT_STATE
        BITA #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        BEQ DELUXE_COLLECT_DEACTIVATION_100000_DONE
        ANDA #$bf
        ORAA #DELUXE_COLLECT_DEACTIVATION_AUTHORIZED
        STAA DELUXE_COLLECT_STATE
; Once 10x has been earned, every later qualification relights only 100K.
; Before then, blink the physical lamp combination for the next multiplier
; together with 100K. Scoring continues to use the numeric bytes at 1149/114B.
        LDAA DELUXE_HOLE_BONUS_MULTIPLIER
        CMPA #$0a
        BEQ DELUXE_RELIGHT_HOLE_100000_ONLY
        LDAA DELUXE_HOLE_NEXT_BONUS_MULTIPLIER
        CMPA #$07
        BEQ DELUXE_RELIGHT_HOLE_7X_100000
        CMPA #$08
        BEQ DELUXE_RELIGHT_HOLE_8X_100000
        CMPA #$0a
        BEQ DELUXE_RELIGHT_HOLE_10X_100000
DELUXE_RELIGHT_HOLE_100000_ONLY:
        LDAA #HOLE_100000_STATE
        BRA DELUXE_STORE_RELIT_HOLE_FLASH_MASK
DELUXE_RELIGHT_HOLE_7X_100000:
        LDAA #HOLE_NEXT_7X_100000_FLASH_MASK
        BRA DELUXE_STORE_RELIT_HOLE_FLASH_MASK
DELUXE_RELIGHT_HOLE_8X_100000:
        LDAA #HOLE_NEXT_8X_100000_FLASH_MASK
        BRA DELUXE_STORE_RELIT_HOLE_FLASH_MASK
DELUXE_RELIGHT_HOLE_10X_100000:
        LDAA #HOLE_NEXT_10X_100000_FLASH_MASK
DELUXE_STORE_RELIT_HOLE_FLASH_MASK:
        STAA $10c1
DELUXE_COLLECT_DEACTIVATION_100000_DONE:
        RTS

DELUXE_FIRST_SINK_ACTIVATE_ORBIT:
; The original all-off orbit state ($xF in the low nibble) scores 5,000.
; Activating either orbit collect promotes only that baseline to $xE, which
; the original table displays and scores as 10,000. Preserve any higher orbit
; value retained by the operator adjustment.
        CLR DELUXE_ORBIT_PREVIEW_TIMER
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
        JSR DELUXE_UPDATE_ORBIT_SPECIAL_VISIBILITY
        BRA DELUXE_COLLECT_ACTIVATION_DONE

DELUXE_FIRST_SINK_ACTIVATE_SPINNER:
; Activating spinner collect only reveals the value already accumulated in
; DELUXE_SPINNER_VALUE_MASK. It does not advance that value by itself.
        CLR DELUXE_ORBIT_PREVIEW_TIMER
        JSR DELUXE_HIDE_ORBIT_PREVIEW_VALUE
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
        JSR DELUXE_TEST_SPINNER_COLLECT_VALUE_ACTIVE
        BEQ DELUXE_NEW_EIGHT_LETTER_SHOW_ACTIVE_VALUE
        NOP
        NOP
        NOP
        NOP
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
; independently through 2x ($01), 3x ($02), and 5x ($04). Those collections
; update the numeric bonus multiplier to 2, 3, and 5. A hit while 5x is showing
; reaches terminal 100,000 ($08) and lights its first award immediately. Each
; authorized terminal collection earns the currently displayed stage and then
; reveals the next 5x -> 7x -> 8x -> 10x stage; 10x is retained thereafter.
; Every later 100K still requires the existing collect active-to-inactive
; relight transition.
        LDAA $10c1
        BITA #HOLE_100000_STATE
        BNE DELUXE_HOLE_TERMINAL_STATE
        BITA #HOLE_BONUS_5X_STATE
        BNE DELUXE_HOLE_COLLECT_5X
        BITA #HOLE_BONUS_3X_STATE
        BNE DELUXE_HOLE_COLLECT_3X
        BITA #HOLE_BONUS_2X_STATE
        BNE DELUXE_HOLE_COLLECT_2X
        BRA DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH
DELUXE_HOLE_COLLECT_2X:
        LDAB #$02
        STAB DELUXE_HOLE_BONUS_MULTIPLIER
        STAB DELUXE_HOLE_NEXT_BONUS_MULTIPLIER
        BRA DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH
DELUXE_HOLE_COLLECT_3X:
        LDAB #$03
        STAB DELUXE_HOLE_BONUS_MULTIPLIER
        STAB DELUXE_HOLE_NEXT_BONUS_MULTIPLIER
        BRA DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH
DELUXE_HOLE_COLLECT_5X:
        LDAB #$05
        STAB DELUXE_HOLE_BONUS_MULTIPLIER
        STAB DELUXE_HOLE_NEXT_BONUS_MULTIPLIER
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
; At the terminal state without authorization, retain $08 as the dormant 100K
; state, preserve the authoritative earned multiplier, keep every next-award
; lamp dark, and award only the ordinary saucer value. Bypass D08C because its
; original terminal-state dispatch would announce 5x even though nothing is lit.
        LDAA DELUXE_COLLECT_STATE
        ORAA #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        STAA DELUXE_COLLECT_STATE
        JSR AWARD_50_POINTS_WITH_PLAYFIELD_MULTIPLIER
        LDAA #HOLE_100000_STATE
        STAA $10c1
        JMP $d0b4

DELUXE_HOLE_AWARD_ARMED_100000:
; Reproduce the canonical D070-D078 terminal award, then consume this collect-
; deactivation authorization. Collect the currently blinking bonus stage, then
; advance the numeric next stage. Store the dormant $08 state and the waiting
; condition so all next-award lamps remain dark until a collect transition.
        JSR $c96c
        LDAA #$36
        JSR $c27e
        JSR DELUXE_ADVANCE_HOLE_BONUS_MULTIPLIER
        LDAA DELUXE_COLLECT_STATE
        ANDA #$7f
        ORAA #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        STAA DELUXE_COLLECT_STATE
        LDAA #HOLE_100000_STATE
        STAA $10c1
        JMP $d0b4

DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH:
        JMP $d06c

DELUXE_APPLY_HOLE_FLASH_MASK:
; C1BC originally XORed $10C1 directly into the hole lamp shadow. Deluxe uses
; the same path for a complete blinking next-award mask ($0D/$0E/$0F), while
; the separate numeric bytes remain authoritative for drain bonus. Suppress the
; XOR while waiting so no top award is advertised before qualification.
; Preserve B for the periodic lamp-refresh caller.
        PSHB
        LDAB DELUXE_COLLECT_STATE
        BITB #DELUXE_HOLE_WAITING_FOR_COLLECT_DEACTIVATION
        BNE DELUXE_HOLE_FLASH_DONE
        EORA $10c1
DELUXE_HOLE_FLASH_DONE:
        PULB
        RTS

DELUXE_ADVANCE_HOLE_BONUS_MULTIPLIER:
; Collect the stage that was visible with 100K. The first standalone 100K has
; next=5, so it keeps the earned multiplier at 5 while making 7x pending. The
; next qualified hit collects 7x+100K, stores earned=7, and makes 8x pending.
        LDAA DELUXE_HOLE_NEXT_BONUS_MULTIPLIER
        STAA DELUXE_HOLE_BONUS_MULTIPLIER
        CMPA #$05
        BEQ DELUXE_HOLE_SET_7X
        CMPA #$07
        BEQ DELUXE_HOLE_SET_8X
        CMPA #$08
        BEQ DELUXE_HOLE_SET_10X
; Ten is terminal. A defensive unexpected value also normalizes to 10 so a
; corrupt stage cannot wrap or create a zero-pass end-of-ball bonus.
        LDAA #$0a
        BRA DELUXE_HOLE_STORE_EXTENDED_MULTIPLIER
DELUXE_HOLE_SET_7X:
        LDAA #$07
        BRA DELUXE_HOLE_STORE_EXTENDED_MULTIPLIER
DELUXE_HOLE_SET_8X:
        LDAA #$08
        BRA DELUXE_HOLE_STORE_EXTENDED_MULTIPLIER
DELUXE_HOLE_SET_10X:
        LDAA #$0a
DELUXE_HOLE_STORE_EXTENDED_MULTIPLIER:
        STAA DELUXE_HOLE_NEXT_BONUS_MULTIPLIER
        RTS

DELUXE_FINISH_HOLE_ANIMATION:
; Reproduce D0B4's displaced delay, then restore the active-low steady lamps
; for the multiplier actually earned. The low nibble stays $F; periodic refresh
; alone overlays the relit next-award mask from $10C1. This keeps the next award
; dark while waiting and prevents the future multiplier from appearing steady.
        LDAB #$3c
        JSR $c919
        LDAA DELUXE_HOLE_BONUS_MULTIPLIER
        CMPA #$05
        BEQ DELUXE_HOLE_SHOW_5X
        CMPA #$07
        BEQ DELUXE_HOLE_SHOW_7X
        CMPA #$08
        BEQ DELUXE_HOLE_SHOW_8X
        CMPA #$0a
        BNE DELUXE_FINISH_HOLE_ANIMATION_DONE
        LDAA #HOLE_BONUS_10X_LAMP_SHADOW
        BRA DELUXE_HOLE_STORE_LAMP_SHADOW
DELUXE_HOLE_SHOW_5X:
        LDAA #HOLE_BONUS_5X_LAMP_SHADOW
        BRA DELUXE_HOLE_STORE_LAMP_SHADOW
DELUXE_HOLE_SHOW_7X:
        LDAA #HOLE_BONUS_7X_LAMP_SHADOW
        BRA DELUXE_HOLE_STORE_LAMP_SHADOW
DELUXE_HOLE_SHOW_8X:
        LDAA #HOLE_BONUS_8X_LAMP_SHADOW
DELUXE_HOLE_STORE_LAMP_SHADOW:
        STAA HOLE_BONUS_LAMP_SHADOW
DELUXE_FINISH_HOLE_ANIMATION_DONE:
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

DELUXE_ACCEPT_NEW_CHAMP_LETTER:
; CAE4 reaches here only after the lane has scored and the original 1040 test
; has proved that this CHAMP letter is new. A contains the letter bit: C=$01,
; H=$02, A=$04, M=$08, P=$10. H/A/M bypass the latch and always record. Only
; C/P can be blocked, and their already-awarded lane score remains intact.
        BITA #DELUXE_CHAMP_INLANE_MASK
        BEQ DELUXE_ACCEPT_NEW_CHAMP_LETTER_RECORD
        TST DELUXE_CHAMP_INLANE_REARMED
        BNE DELUXE_ACCEPT_NEW_CHAMP_INLANE_ARMED
        JMP CHAMP_LANE_HANDLER_DONE
DELUXE_ACCEPT_NEW_CHAMP_INLANE_ARMED:
        CLR DELUXE_CHAMP_INLANE_REARMED
DELUXE_ACCEPT_NEW_CHAMP_LETTER_RECORD:
; Reproduce the displaced canonical sound increment before recording the bit.
        INC PENDING_SOUND_COMMAND
        JMP RECORD_NEW_CHAMP_LANE

DELUXE_REARM_CHAMP_INLANES_FOR_MEANINGFUL_SWITCH:
; B is the C011 handler-table byte offset, whose order is return 7 down to 0
; within each strobe. Rearm only for intentional shots that carry the ball
; away from an inlane shatz: thumper bumpers (01/02), saucer (05), orbit
; rollovers (12/13), center rollover (29), spinner (32), numbered pool-ball
; drops (25/27/28/30/31), or E-I-G-H-T targets (33-37). Slings/rebound,
; CHAMP lanes, outlanes,
; cabinet/service switches, outhole, and unused matrix positions stay excluded.
        CMPB #$0c                    ; switch 02 Left Thumper Bumper
        BEQ DELUXE_REARM_CHAMP_INLANES
        CMPB #$0e                    ; switch 01 Right Thumper Bumper
        BEQ DELUXE_REARM_CHAMP_INLANES
        CMPB #$06                    ; switch 05 Saucer
        BEQ DELUXE_REARM_CHAMP_INLANES
        CMPB #$16                    ; switch 13 Right Rollover Button
        BEQ DELUXE_REARM_CHAMP_INLANES
        CMPB #$18                    ; switch 12 Left Rollover Button
        BEQ DELUXE_REARM_CHAMP_INLANES
        CMPB #$30                    ; switches 32 down through 25
        BCS DELUXE_REARM_CHAMP_DONE
        CMPB #$40
        BCC DELUXE_REARM_CHAMP_CHECK_EIGHT
        CMPB #$3c                    ; switch 26 Lane Change (Cabinet)
        BEQ DELUXE_REARM_CHAMP_DONE
        BRA DELUXE_REARM_CHAMP_INLANES
DELUXE_REARM_CHAMP_CHECK_EIGHT:
        CMPB #$46                    ; switches 37-33 occupy offsets 46-4E
        BCS DELUXE_REARM_CHAMP_DONE
        CMPB #$50
        BCC DELUXE_REARM_CHAMP_DONE
DELUXE_REARM_CHAMP_INLANES:
        LDAA #DELUXE_CHAMP_INLANE_ARMED
        STAA DELUXE_CHAMP_INLANE_REARMED
DELUXE_REARM_CHAMP_DONE:
        RTS

DELUXE_PREPARE_PLAYFIELD_SWITCH_HANDLER_TABLE:
; E63A enters after the normal-play dispatcher has accepted and cleared one
; switch event. B is the even byte offset into C011's handler-pointer table.
; First update the invisible CHAMP anti-shatz rearm latch from the verified
; shot whitelist. The accepted switch still reaches its original handler.
        BSR DELUXE_REARM_CHAMP_INLANES_FOR_MEANINGFUL_SWITCH
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
; lamps and advance the output-only "more" blink phase. Then maintain a
; reversible overlay on exactly one individually
; numbered called-ball lamp. Recording the ID whose XOR is currently applied
; lets the next edge restore the original shadow state before changing calls or
; ending the flash. Entry X is 103A; preserve X and B for C1B3 onward.
        LDAA $05,X
        EORA DROP_TARGET_5000_LAMP_FLASH_MASK
        STAA $05,X
        COM DELUXE_MORE_LAMPS_FLASH_PHASE
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

DELUXE_HANDLE_SPECIAL_COLLECT_SOUND:
; C1D6 routes every normal Special sound request here. A maxed right-orbit
; collect sets a one-shot flag immediately around the canonical orbit routine;
; consume it by skipping only command $6F and continue at the common Special
; award path. All other collectors reproduce the original sound call.
        TST DELUXE_SUPPRESS_NEXT_SPECIAL_SOUND
        BEQ DELUXE_PLAY_NORMAL_SPECIAL_SOUND
        CLR DELUXE_SUPPRESS_NEXT_SPECIAL_SOUND
        JMP SPECIAL_COLLECT_COMMON
DELUXE_PLAY_NORMAL_SPECIAL_SOUND:
        LDAA #$6f
        JSR $c27e
        JMP SPECIAL_COLLECT_COMMON

DELUXE_TEST_SPINNER_COLLECT_VALUE_ACTIVE:
; Return Z set while either the main state is spinner active or the independent
; post-hit collecting timer is running. This keeps sound, scoring, and E-I-G-H-T
; lamp updates on the lit spinner path while allowing the orbit location to
; advance and reactivate concurrently.
        LDAA DELUXE_SPINNER_COLLECTING_TIMER
        BNE DELUXE_SPINNER_COLLECT_TEST_TRUE
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        RTS
DELUXE_SPINNER_COLLECT_TEST_TRUE:
        CLRA
        RTS

DELUXE_BEGIN_SPINNER_COLLECTING:
; The first pulse consumes spinner active immediately, making orbit inactive
; and available to the next newly sunk pool ball. The timer preserves spinner
; value scoring independently until physical rotation stops. This is the one
; active-to-inactive transition that may qualify the next saucer 100K stage.
        LDAA DELUXE_COLLECT_STATE
        ANDA #$c0
        ORAA #DELUXE_COLLECT_DUAL_ORBIT
        STAA DELUXE_COLLECT_STATE
        JSR DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION
        RTS

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
