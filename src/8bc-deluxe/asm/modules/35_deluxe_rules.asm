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
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_PERIODIC_TICK_DONE
; Each active spinner pulse restarts this inactivity timer.  A pulse inside
; the window continues the same collect; only about two seconds with no
; further pulse closes it and advances to right-orbit inactive. Preserve the
; two saucer-qualification flags while clearing active and selecting right.
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
        LDAA #DELUXE_COLLECT_LEFT_ORBIT
        STAA DELUXE_COLLECT_STATE
        CLR DELUXE_SPINNER_IDLE_TIMER
        CLR DELUXE_CHAMP_COMPLETION_COUNT
        CLR $10b1
        CLR $10b2
        LDAA #DELUXE_SPINNER_1000_LAMP
        STAA DELUXE_SPINNER_VALUE_MASK
; The canonical player restore at C500 has already loaded the retained orbit
; value into 1044. Keep its low-nibble value in Deluxe RAM, then set the live
; low nibble to all-off while the new ball begins at left-orbit inactive.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$0f
        STAA DELUXE_ORBIT_VALUE_STATE
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ORAA #$0f
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
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
; chase. Advance to left-orbit inactive only after that animation returns.
        JMP DELUXE_SCORE_ACTIVE_RIGHT_ORBIT

DELUXE_HANDLE_LEFT_ORBIT:
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_LEFT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_HANDLE_ACTIVE_LEFT_ORBIT
; Deluxe normally makes an inactive left orbit worth 5,000 without advancing
; its shared value. The exception is the original terminal 100,000/special
; state: re-enter CB5C so its special collect remains fully functional even
; when the Deluxe collect is currently at the spinner or right orbit.
        LDAA DELUXE_ORBIT_VALUE_STATE
        BEQ DELUXE_HANDLE_LEFT_ORBIT_TERMINAL
        JMP DELUXE_SCORE_UNLIT_ORBIT
DELUXE_HANDLE_LEFT_ORBIT_TERMINAL:
; The terminal value is retained in the Deluxe shadow while an orbit stage is
; inactive. Restore it before entering the canonical 100,000/special handler.
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$f0
        ORAA DELUXE_ORBIT_VALUE_STATE
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
        BRA DELUXE_SCORE_LIT_ORBIT

DELUXE_HANDLE_ACTIVE_LEFT_ORBIT:
; Authorize the eventual 100,000 saucer award, but leave left active until the
; original fast arrow chase has completed. The state transition follows it.
        LDAA DELUXE_COLLECT_STATE
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
        BRA DELUXE_LEFT_ORBIT_FINISH
DELUXE_LEFT_ORBIT_STORE_STATE:
        STAA DELUXE_COLLECT_STATE
DELUXE_LEFT_ORBIT_FINISH:
        JMP DELUXE_SCORE_ACTIVE_LEFT_ORBIT

DELUXE_SCORE_LIT_ORBIT:
; Re-enter the original handler after its gate/sound setup. It awards the
; synchronized lit value, advances it by 10,000, and retains its adjustment
; behavior and light/sound animation. This entry does not move the Deluxe
; collect state; it is used for the terminal left-orbit special exception.
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        BRA DELUXE_UPDATE_ORBIT_LAMP_VISIBILITY

DELUXE_SCORE_ACTIVE_LEFT_ORBIT:
; Finish the original chase before changing location. Then advance to spinner
; inactive and darken both the shared orbit value and spinner value lamps.
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        LDAA DELUXE_COLLECT_STATE
        ANDA #$c0
        ORAA #DELUXE_COLLECT_SPINNER
        STAA DELUXE_COLLECT_STATE
        CLR $10b1
        CLR $10b2
        BRA DELUXE_HIDE_INACTIVE_ORBIT_LAMPS

DELUXE_SCORE_ACTIVE_RIGHT_ORBIT:
; Finish the original chase before returning the sequence to left inactive.
; Preserve only the two saucer flags; sunk balls are never queued forward.
        BSR DELUXE_RUN_ORIGINAL_LIT_ORBIT
        LDAA DELUXE_COLLECT_STATE
        ANDA #$c0
        ORAA #DELUXE_COLLECT_LEFT_ORBIT
        STAA DELUXE_COLLECT_STATE
        BRA DELUXE_HIDE_INACTIVE_ORBIT_LAMPS

DELUXE_RUN_ORIGINAL_LIT_ORBIT:
        TBA
        JSR $c27e
        JSR $cb5c
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ANDA #$0f
        STAA DELUXE_ORBIT_VALUE_STATE
        RTS

DELUXE_UPDATE_ORBIT_LAMP_VISIBILITY:
; A terminal left-orbit special can be collected while another orbit remains
; active. In that case retain the shared value display for that active stage.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_LEFT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_SCORE_LIT_ORBIT_DONE
        CMPA #DELUXE_COLLECT_RIGHT_ORBIT+DELUXE_COLLECT_ACTIVE
        BEQ DELUXE_SCORE_LIT_ORBIT_DONE
DELUXE_HIDE_INACTIVE_ORBIT_LAMPS:
        LDAA SHARED_ORBIT_VALUE_LAMP_STATE
        ORAA #$0f
        STAA SHARED_ORBIT_VALUE_LAMP_STATE
DELUXE_SCORE_LIT_ORBIT_DONE:
        RTS

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
        BITA #DELUXE_COLLECT_ACTIVE
        BNE DELUXE_FIRST_SINK_COLLECT_ALREADY_ACTIVE
; A newly sunk ball activates exactly the current waiting location. If already
; active, later sunk balls are not queued and do not change this state.
        ORAA #DELUXE_COLLECT_ACTIVE
        STAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_LOCATION_MASK
        CMPA #DELUXE_COLLECT_LEFT_ORBIT
        BEQ DELUXE_FIRST_SINK_ACTIVATE_LEFT
        CMPA #DELUXE_COLLECT_SPINNER
        BEQ DELUXE_FIRST_SINK_ACTIVATE_SPINNER
        BRA DELUXE_FIRST_SINK_SHOW_ORBIT

DELUXE_FIRST_SINK_ACTIVATE_LEFT:
; The original all-off orbit state ($xF in the low nibble) scores 5,000.
; Activating left collect promotes only that baseline to $xE, which the
; original table displays and scores as 10,000. Preserve any higher orbit
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
        BRA DELUXE_FIRST_SINK_COLLECT_ALREADY_ACTIVE

DELUXE_FIRST_SINK_ACTIVATE_SPINNER:
; Activating spinner collect only reveals the value already accumulated in
; DELUXE_SPINNER_VALUE_MASK. It does not advance that value by itself.
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
        CLR $10b2
DELUXE_FIRST_SINK_COLLECT_ALREADY_ACTIVE:
        PULA

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
; Update the live lamp state only while spinner collect is active. Otherwise
; the accumulated value remains hidden in 10EE until a pool ball activates it.
        LDAA DELUXE_COLLECT_STATE
        ANDA #DELUXE_COLLECT_STATE_MASK
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_NEW_EIGHT_LETTER_DONE
        LDAA DELUXE_SPINNER_VALUE_MASK
        STAA $10b1
DELUXE_NEW_EIGHT_LETTER_DONE:
; X still points at 1045. Resume where the original code reloads that byte and
; checks whether all five E-I-G-H-T letters have completed.
        JMP $cc96

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
