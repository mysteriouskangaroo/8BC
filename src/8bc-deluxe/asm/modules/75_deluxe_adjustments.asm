; Deluxe adjustment, spinner and Special continuations in canonical FF padding.
; Range: FA56-FFEF; the vectors remain fixed at FFF0.
;
; Switch 32 reaches CA3B -> DELUXE_HANDLE_SPINNER -> D516 after the
; canonical E1F0 matrix scan / E63A dispatcher. Each lit pulse reloads the
; independent 1117-1118 timer; C14E decrements it and expires only the overlay.
; Lamp shadows 10B1/10B2 still flow through the canonical periodic PIA output.
; No interrupt, matrix-scan, lamp-refresh or solenoid pulse code is changed.

DELUXE_SPINNER_ADJUSTMENT_DESCRIPTOR:
; Binary register 52 ($34), battery-backed split binary, two-digit type, BCD
; maximum 60. E709/E717 lookup and E96E read/write/display remain canonical.
        dc.b 52
        dc.w DELUXE_SPINNER_SECONDS_REGISTER
        dc.b $02,$60,$FF

DELUXE_SELECT_ADJUSTMENT_TABLE:
; E709 replaces LDX #EAD5. E717 reloads A itself, but retain it here as well.
        PSHA
        LDX #$EAD5
        LDAA.w $008D
        CMPA #52
        BNE DELUXE_ADJUSTMENT_TABLE_SELECTED
        LDX #DELUXE_SPINNER_ADJUSTMENT_DESCRIPTOR
DELUXE_ADJUSTMENT_TABLE_SELECTED:
        PULA
        RTS

DELUXE_INITIALIZE_SPINNER_ADJUSTMENT:
; E5B2 runs after startup RAM recovery and on service Cancel. The original
; program never references 168E-168F. Zero is intentionally left visible as
; zero in service mode and means the 12-second default. Sanitize invalid
; legacy/uninitialized values above 60 to that same default. Type 2 converts
; decimal keypad input to binary, split across these two high nibbles:
; low four bits at 168E, high four bits at 168F (12 is C0,00; 60 is C0,30).
; The low nibbles are unused by the canonical two-digit adjustment format.
        LDAA DELUXE_SPINNER_SECONDS_REGISTER
        LSRA
        LSRA
        LSRA
        LSRA
        LDAB DELUXE_SPINNER_SECONDS_REGISTER_TENS
        ANDB #$F0
        ABA
        CMPA #60
        BLS DELUXE_SPINNER_ADJUSTMENT_INITIALIZED
DELUXE_RESET_SPINNER_ADJUSTMENT:
        CLR DELUXE_SPINNER_SECONDS_REGISTER
        CLR DELUXE_SPINNER_SECONDS_REGISTER_TENS
DELUXE_SPINNER_ADJUSTMENT_INITIALIZED:
; Tail-call the displaced initialization: its A/B/X results reach E5B5 intact.
        JMP $EA7F

DELUXE_RELOAD_ADJUSTABLE_SPINNER_TIMER:
; Read the binary value from the adjustment's high nibbles, not lamp shadows.
; B was unchanged by the fixed reload helper; preserve it across MUL. X is
; untouched, A returns 1 as before. One multiply gives bounded execution;
; there is no value-dependent delay loop on the switch handler.
        PSHB
        LDAA DELUXE_SPINNER_SECONDS_REGISTER
        LSRA
        LSRA
        LSRA
        LSRA
        LDAB DELUXE_SPINNER_SECONDS_REGISTER_TENS
        ANDB #$F0
        ABA
        BNE DELUXE_SPINNER_SECONDS_SELECTED
        LDAA #DELUXE_SPINNER_DEFAULT_SECONDS
DELUXE_SPINNER_SECONDS_SELECTED:
; C14E is observed twice per 60 Hz libpinmame frame. Use 120 ticks/second,
; so 12 seconds = 1440 ticks; 60 seconds = 7200, within the existing 16 bits.
; Earlier comments called 600 ticks ten seconds; it is five in libpinmame.
; Interactive play / physical timing and I/O safety still require review.
        LDAB #DELUXE_SPINNER_TICKS_PER_SECOND
        MUL
        STD DELUXE_SPINNER_COLLECTING_TIMER
        PULB
        LDAA #$01
        STAA DELUXE_SPINNER_COLLECTING_ACTIVE
        RTS

DELUXE_CONSUME_QUALIFIED_SPINNER:
; D513 passes the masked main collect state in A. Only a qualified spinner
; (6) consumes a stage; scoring-window-only pulses do not move the location
; or qualify another saucer award. This also covers a second qualified
; spinner reached while the first scoring window is still counting down.
        CMPA #DELUXE_COLLECT_SPINNER+DELUXE_COLLECT_ACTIVE
        BNE DELUXE_QUALIFIED_SPINNER_DONE
        LDAA DELUXE_COLLECT_STATE
        ANDA #$C0
        ORAA #DELUXE_COLLECT_DUAL_ORBIT
        STAA DELUXE_COLLECT_STATE
        JMP DELUXE_RELIGHT_100000_ON_COLLECT_DEACTIVATION
DELUXE_QUALIFIED_SPINNER_DONE:
        RTS

DELUXE_COMPLETE_SPECIAL_WITH_KNOCKER:
; All actual Special collectors converge through C1DB, including the direct
; rack award and the context-aware orbit sound path. Register 25's packed
; action at 1680 bits 4-5 selects none/points/Extra Ball/replay. Only replay
; normally knocks: F6F8 calls F73C and returns immediately when credits are
; at/above the cap, before calling the C085 knocker pointer or adding credit.
; Below the cap, leave that single normal knock to F6F8. For every other
; case, supply exactly one identical timed pulse without changing credits,
; the selected award, audit counters, Special sound, or scoring scale.
        LDAA $1680
        ANDA #$30
        CMPA #$30
        BNE DELUXE_SPECIAL_NEEDS_KNOCK
        JSR $F73C
        BCS DELUXE_RESUME_SPECIAL_AWARD
DELUXE_SPECIAL_NEEDS_KNOCK:
        JSR CREDIT_AWARD_KNOCKER_PULSE
DELUXE_RESUME_SPECIAL_AWARD:
; The credit comparison and pulse both use X. Restore the displaced Special
; audit pointer before C1DE performs its original increment and action dispatch.
        LDX #$165F
        JMP $C1DE

DELUXE_ADJUSTMENTS_END:
        ds.b $FFF0-DELUXE_ADJUSTMENTS_END,$FF
