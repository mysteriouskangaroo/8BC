; Eight Ball Champ Deluxe rules
; Address range: $D3B2-$DFFF (verified $FF padding in the canonical ROM)
;
; Existing handlers jump here so their surrounding addresses, animation data,
; service code, and hardware timing remain fixed. See ../../gamerules.md for
; the complete rule contract.

DELUXE_PERIODIC_TICK:
; C14E calls this in place of its original LDX $10B3. Preserve A, process the
; spinner inactivity timer, then execute that displaced load last so C151 sees
; the same X value and condition codes as the canonical routine.
        PSHA
        LDAA DELUXE_SPINNER_IDLE_TIMER
        BEQ DELUXE_PERIODIC_TICK_DONE
        DECA
        STAA DELUXE_SPINNER_IDLE_TIMER
        BNE DELUXE_PERIODIC_TICK_DONE
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        CMPA #DELUXE_COLLECT_SPINNER
        BNE DELUXE_PERIODIC_TICK_DONE
; Each active spinner pulse restarts this inactivity timer.  A pulse inside
; the window continues the same collect; only about two seconds with no
; further pulse closes it and advances the collect to the right orbit.
; Preserve the two saucer-qualification flags while selecting right orbit.
        LDAA DELUXE_COLLECT_STATE
        ANDA #$C0
        ORAA #DELUXE_COLLECT_RIGHT_ORBIT
        STAA DELUXE_COLLECT_STATE
        CLR $10b1
        CLR $10b2
DELUXE_PERIODIC_TICK_DONE:
        PULA
        LDX $10b3
        RTS

DELUXE_INITIALIZE_BALL:
; The collect feature, spinner value, saucer authorization, CHAMP milestone
; count, and playfield multiplier are all per-ball. C507 clears the original
; multiplier state; this helper resets the additional deluxe state.
        CLR DELUXE_COLLECT_STATE
        CLR DELUXE_SPINNER_IDLE_TIMER
        CLR DELUXE_CHAMP_COMPLETION_COUNT
        CLR $10b1
        CLR $10b2
        LDAA #DELUXE_SPINNER_1000_LAMP
        STAA DELUXE_SPINNER_VALUE_MASK
; High bits of 1040 are active-low spinner-value lamps. Keep them dark until
; the collect reaches the spinner, while preserving the five CHAMP lane bits.
        LDAA CHAMP_LANE_STATE
        ORAA #DELUXE_SPINNER_ALL_VALUE_LAMPS
        STAA CHAMP_LANE_STATE
        RTS

DELUXE_HANDLE_SPINNER:
; Switch 32. The original common gate still owns sound queuing and the normal
; gameplay/tilt guard.
        LDAB #$2e
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        CMPA #DELUXE_COLLECT_SPINNER
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
        JMP AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER

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
; A failed common gate unwinds this call exactly as it did in the original.
        JSR QUEUE_SOUND_AND_CHECK_SCORE_GATE
        CMPB #$29
        BEQ DELUXE_HANDLE_LEFT_ORBIT

DELUXE_HANDLE_RIGHT_ORBIT:
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        CMPA #DELUXE_COLLECT_RIGHT_ORBIT
        BNE DELUXE_SCORE_UNLIT_ORBIT
; Right -> left. XOR changes only low location bits 3 -> 1 and preserves the
; saucer waiting/authorization flags.
        LDAA DELUXE_COLLECT_STATE
        EORA #$02
        STAA DELUXE_COLLECT_STATE
        BRA DELUXE_SCORE_LIT_ORBIT

DELUXE_HANDLE_LEFT_ORBIT:
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        CMPA #DELUXE_COLLECT_LEFT_ORBIT
        BEQ DELUXE_HANDLE_ACTIVE_LEFT_ORBIT
; Deluxe normally makes an inactive left orbit worth 5,000 without advancing
; its shared value. The exception is the original terminal 100,000/special
; state: re-enter CB5C so its special collect remains fully functional even
; when the Deluxe collect is currently at the spinner or right orbit.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$0f
        BEQ DELUXE_SCORE_LIT_ORBIT
        BRA DELUXE_SCORE_UNLIT_ORBIT

DELUXE_HANDLE_ACTIVE_LEFT_ORBIT:
; Left -> spinner and authorize the 100,000 saucer award for this ball.
        LDAA DELUXE_COLLECT_STATE
        EORA #$03
        ORAA #DELUXE_LEFT_COLLECT_AUTHORIZED
        BITA #DELUXE_HOLE_WAITING_FOR_LEFT_COLLECT
        BEQ DELUXE_LEFT_ORBIT_STORE_STATE
; The hole already reached the post-5x step. Clear the waiting flag and light
; the terminal 100,000 state immediately now that both conditions are true.
        ANDA #$bf
        STAA DELUXE_COLLECT_STATE
        LDAA $10c1
        ANDA #$80
        ORAA #$08
        STAA $10c1
        BRA DELUXE_LEFT_ORBIT_SHOW_SPINNER
DELUXE_LEFT_ORBIT_STORE_STATE:
        STAA DELUXE_COLLECT_STATE
DELUXE_LEFT_ORBIT_SHOW_SPINNER:
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        CLR $10b2

DELUXE_SCORE_LIT_ORBIT:
; Re-enter the original handler after its gate/sound setup. It awards the
; synchronized lit value, advances it by 10,000, and retains its adjustment
; behavior and light/sound animation.
        TBA
        JSR $c27e
        JMP $cb5c

DELUXE_SCORE_UNLIT_ORBIT:
; The first original orbit score-table entry proves the base value is 5,000.
; Bypassing CB5C prevents an unlit hit from advancing the shared value.
        TBA
        JSR $c27e
        JMP AWARD_5000_POINTS_WITH_PLAYFIELD_MULTIPLIER

DELUXE_AFTER_FIRST_SINK:
; CE13 jumps here with A equal to the newly updated sunk-ball mask and the
; selected target bit saved on top of the stack. Restore that exact stack
; shape before returning to the canonical first-sink animation at CE1A.
; Already-sunk targets never reach this hook: they branch to the canonical
; 5,000-point path at D034 and cannot change the deluxe collect state.
        PULB
        PSHB
        PSHA
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        BNE DELUXE_FIRST_SINK_COLLECT_ALREADY_ACTIVE
        LDAA DELUXE_COLLECT_STATE
        ANDA #$c0
        ORAA #DELUXE_COLLECT_LEFT_ORBIT
        STAA DELUXE_COLLECT_STATE
; The original all-off orbit state ($xF in the low nibble) scores 5,000.
; Activating left collect promotes only that baseline to $xE, which the
; original table displays and scores as 10,000. Preserve the upper pool-bonus
; lamp bits and any higher orbit value retained by the operator adjustment.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        PSHA
        ANDA #$0f
        CMPA #$0f
        PULA
        BNE DELUXE_FIRST_SINK_COLLECT_ALREADY_ACTIVE
        ANDA #$fe
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
DELUXE_FIRST_SINK_COLLECT_ALREADY_ACTIVE:
        PULA

; B identifies the newly sunk pool ball. Singles 3, 6, and 7 immediately
; complete I/H/T; paired groups complete E/G only when both bits are now set.
        BITB #$64
        BNE DELUXE_NEW_EIGHT_LETTER
        BITB #$03
        BEQ DELUXE_CHECK_G_LETTER
        ANDA #$03
        CMPA #$03
        BEQ DELUXE_NEW_EIGHT_LETTER
        BRA DELUXE_FIRST_SINK_CONTINUE
DELUXE_CHECK_G_LETTER:
        BITB #$18
        BEQ DELUXE_FIRST_SINK_CONTINUE
        ANDA #$18
        CMPA #$18
        BNE DELUXE_FIRST_SINK_CONTINUE

DELUXE_NEW_EIGHT_LETTER:
        LDAA DELUXE_SPINNER_VALUE_MASK
        CMPA #$e0
        BEQ DELUXE_FIRST_SINK_CONTINUE
        ADDA #$20
; The fifth letter reaches binary 6 (8,000); completing the whole E-I-G-H-T
; word supplies the deck's final binary step to 7 (9,000).
        CMPA #$c0
        BNE DELUXE_STORE_SPINNER_VALUE
        LDAA #$e0
DELUXE_STORE_SPINNER_VALUE:
        STAA DELUXE_SPINNER_VALUE_MASK
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        CMPA #DELUXE_COLLECT_SPINNER
        BNE DELUXE_FIRST_SINK_CONTINUE
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1

DELUXE_FIRST_SINK_CONTINUE:
        LDAA PENDING_SOUND_COMMAND
        DECA
        PULB
        PSHB
        PSHA
        JMP $ce1a

DELUXE_HANDLE_HOLE_STATE:
; D069 jumps here after canonical sound/effect setup. Preserve normal 2x/3x/5x
; progression, but do not enter or award terminal 100,000 without left collect.
        LDAA $10c1
        BITA #$08
        BNE DELUXE_HOLE_TERMINAL_STATE
        BITA #$04
        BEQ DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH
        LDAB DELUXE_COLLECT_STATE
        BITB #DELUXE_LEFT_COLLECT_AUTHORIZED
        BNE DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH
; A hit beyond 5x waits without shifting the bonus state. This keeps 100,000
; dark until a later left collect promotes the state to $08.
        ORAB #DELUXE_HOLE_WAITING_FOR_LEFT_COLLECT
        STAB DELUXE_COLLECT_STATE
        JSR AWARD_500_POINTS_WITH_PLAYFIELD_MULTIPLIER
        JMP $d08c

DELUXE_HOLE_TERMINAL_STATE:
        LDAB DELUXE_COLLECT_STATE
        BITB #DELUXE_LEFT_COLLECT_AUTHORIZED
        BNE DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH
; Defensive recovery for a stale terminal state: score the ordinary saucer
; value but never expose the unauthorized jackpot.
        JSR AWARD_500_POINTS_WITH_PLAYFIELD_MULTIPLIER
        JMP $d08c

DELUXE_HOLE_USE_ORIGINAL_STATE_DISPATCH:
        JMP $d06c

DELUXE_AWARD_SPECIAL_POINTS:
; All original special collectors converge at C1DB. Award an additional
; 250,000 through the same multiplier-aware helpers used by normal scoring:
; 100,000 + 100,000 + 50,000 gives 250K/500K/750K at playfield 1x/2x/3x.
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
