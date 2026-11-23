# Eight Ball Champ name table for the libpinmame game tests (data only; load
# with Import-PowerShellDataFile). Each value names its evidence: a document
# table, a ROM address in src/originals/asm/modules, or the test in
# tests/kit/names.tests.ps1 that measures it in libpinmame (pinned tag
# v3.7.0-477-6589fc5, driver eballchp, GEN_BY6803).
@{
    # Page 1-18 switch numbers, from HARDWARE_MAP.md "Page 1-18 switch assembly
    # identification" (26 and 32 as corrected there). libpinmame switch n is
    # matrix strobe (n-1)/8, return (n-1)%8 (core.c core_swSeq2m: n+7), so these
    # numbers go to PinmameSetSwitch unchanged. Measured: "Coin adds a credit",
    # "Start sets players", "Score buffers match display", "Switch debounce".
    Switches = @{
        'Right Thumper Bumper'   = 1
        'Left Thumper Bumper'    = 2
        'Right Slingshot'        = 3
        'Left Slingshot'         = 4
        'Saucer'                 = 5
        'Credit'                 = 6
        'Rebound'                = 7
        'Outhole'                = 8
        'Coin III (Right)'       = 9
        'Coin I (Left)'          = 10
        'Coin II (Middle)'       = 11
        'Left Rollover Button'   = 12
        'Right Rollover Button'  = 13
        'Not Used 14'            = 14
        'Tilt'                   = 15
        'Slam'                   = 16
        '"C" Return Lane'        = 17
        '"H" Top Lane'           = 18
        '"A" Top Lane'           = 19
        '"M" Top Lane'           = 20
        '"P" Return Lane'        = 21
        'Not Used 22'            = 22
        'Left Outlane'           = 23
        'Right Outlane'          = 24
        'Drop Target 1,2,9,10'   = 25
        'Lane Change (Cabinet)'  = 26
        'Drop Target 3,11'       = 27
        'Drop Target 4,5,12,13'  = 28
        'Center Rollover Button' = 29
        'Drop Target 6,14'       = 30
        'Drop Target 7,15'       = 31
        'Spinner'                = 32
        'Drop Target "E"'        = 33
        'Drop Target "I"'        = 34
        'Drop Target "G"'        = 35
        'Drop Target "H"'        = 36
        'Drop Target "T"'        = 37
    }

    # BY6803_SWSELFTEST in pinmame src/wpc/by6803.h; it drives PIA0 CA1, whose
    # interrupt at E043-E058 sets 009A bit 2. Measured: "Self-test switch
    # enters service mode".
    SelfTestSwitch = -7

    # Service-mode keys. The ROM reads them from strobe-0 events (1026) while
    # in service mode: EA38-EA4A takes bit 0 to advance the test number, bit 2
    # (Clear) to restart and bit 3 to leave service mode (JMP E50D). E6C5-E6DC
    # enters the switch test (94) when a return 0-3 switch on strobes 0-3
    # (except strobe 0 return 2) is held as the self-test switch is pressed. These share matrix positions
    # with page 1-18 switches 01-04; pinmame by6803.h names them "KP: Enter",
    # "KP: 0", "KP: Clear" and "KP: Cancel". Measured: "Solenoid test order is
    # page 1-18" (Zero held + self-test reaches 94, self-test then 90, Enter
    # twice reaches 92, Cancel returns to attract).
    #
    # The digit keys 1-9 sit on strobes 1-3, returns 0-2 (pinmame by6803.h
    # port 3 "KP: 3/2/1/6/5/4/9/8/7" and by6803.c SWITCH_UPDATE, which puts
    # port 3 nibbles 1-3 in matrix columns 2-4), sharing page 1-18 switches
    # 9-11, 17-19 and 25-27. Measured: "Set-EbcAdjustment changes a setting"
    # (keys 2, 3 and 5 select register 23 and store 5; the other digits
    # rest on the pinmame source only).
    ServiceKeys = @{
        Enter  = 1
        Zero   = 2
        Clear  = 3
        Cancel = 4
        Three  = 9
        Two    = 10
        One    = 11
        Six    = 17
        Five   = 18
        Four   = 19
        Nine   = 25
        Eight  = 26
        Seven  = 27
    }

    # Page 1-18 solenoid test name -> libpinmame solenoid number. The ROM's
    # automatic test (RUN_AUTOMATIC_SOLENOID_SELF_TEST, ED40) fires selectors
    # C0BA = M0,M1,M2,M3,M4,M7,M8,M9,M10,M11,M13,M14 then writes BF to PIA1
    # port B (EDBA) for test 13. libpinmame reports M<n> as solenoid n+1
    # (by6803.c pia1b_w: bit n of the pulsed mask; core.c numbers bits from 1)
    # and the BF upper nibble as solenoid 19 (((BF ^ F0) & F0) << 12 = bit 18).
    # Measured: "Solenoid test order is page 1-18" and "libpinmame solenoid is M+1".
    Solenoids = @{
        'Drop Target 1,2,9,10'      = 1
        'Drop Target 3,11'          = 2
        'Drop Target 4,5,12,13'     = 3
        'Drop Target 6,14'          = 4
        'Drop Target 7,15'          = 5
        'Saucer'                    = 8
        'Right Thumper Bumper'      = 9
        'Left Thumper Bumper'       = 10
        'Right Slingshot'           = 11
        'Left Slingshot'            = 12
        'Outhole'                   = 14
        'Knocker'                   = 15
        'K1 Relay (Flipper Enable)' = 19
    }

    # Lamps used by a test, as libpinmame numbers. OPS manual "Eight Ball Champ
    # lamp driver locations" (PDF p. 61) puts BONUS 120,000 on J13-13 and
    # BONUS 240,000 on J13-5, both phase B; the pinmame src/wpc/by6803.c header
    # table converts J13-13 to 29 and J13-05 to 45 and numbers phase B x+48.
    # Measured: tests/originals/saucer.tests.ps1 (77 lights at the first
    # 8-ball collection, 93 stays dark). Checked in names.tests.ps1 "Bonus
    # lamps are J13-13 and J13-5 phase B".
    #
    # The same table puts the "B" of B-A-L-L on J10-18, phase B; by6803.c
    # converts J10-18 to 35, so it is 35 + 48 = 83. Measured:
    # tests/originals/eight-targets.tests.ps1 (83 lights when E-I-G-H-T is
    # first completed). Checked in names.tests.ps1 "B-A-L-L B lamp is J10-18
    # phase B".
    #
    # The table's second page (PDF p. 62) puts "5,000 DROP TARGET 3" on
    # J13-10, phase A; by6803.c converts J13-10 to 46, phase A unchanged.
    # Measured: tests/8bc-deluxe/sunk-ball-awards.tests.ps1 (46 flashes once
    # Drop Target 3,11 is reset with ball 3 sunk, and goes dark when the reset
    # target is hit) and tests/compare/original-vs-deluxe-5000-lamp.tests.ps1
    # (the original ROM lights it identically). Checked in
    # names.tests.ps1 "5,000 drop target 3 lamp is J13-10 phase A".
    #
    # The table's first page lists the fourteen numbered DROP TARGET lamps,
    # all phase A: 1 J10-18, 2 J10-4, 3 J10-11, 4 J10-19, 5 J10-5, 6 J10-12,
    # 7 J10-14, 9 J10-10, 10 J10-13, 11 J11-8, 12 J11-16, 13 J11-6, 14 J11-12,
    # 15 J11-11. by6803.c converts them to 35, 4, 20, 36, 5, 21, 37, 22, 38,
    # 7, 23, 39, 8, 24 (HARDWARE_MAP.md "Numbered pool-ball drop-target lamps"
    # gives the same numbers). Measured: tests/8bc-deluxe/called-ball.tests.ps1
    # (the spoken ball's lamp flashes). Checked in names.tests.ps1 "Numbered
    # drop-target lamps are the manual's J10/J11 phase A pins".
    #
    # The table's first page puts ROLLOVER LANES 10,000 / 20,000 / 30,000 /
    # 40,000 / SPECIAL (the orbit-value arrows and orbit Special) on J12-4,
    # J13-1, J13-8, J13-6 and J13-2, all phase B; by6803.c converts them to
    # 43, 12, 28, 44 and 13, so they are 91, 60, 76, 92 and 61. Measured:
    # tests/8bc-deluxe/orbits.tests.ps1 (the arrows chase upward on a collect
    # and the lit legends add up to the value the next collect scores).
    # Checked in names.tests.ps1 "Orbit-value lamps are the manual's rollover
    # lane pins, phase B".
    Lamps = @{
        'Bonus 120,000'         = 77
        'Bonus 240,000'         = 93
        'Ball "B"'              = 83
        '5,000 Drop Target 3'   = 46
        'Drop Target 1'         = 35
        'Drop Target 2'         = 4
        'Drop Target 3'         = 20
        'Drop Target 4'         = 36
        'Drop Target 5'         = 5
        'Drop Target 6'         = 21
        'Drop Target 7'         = 37
        'Drop Target 9'         = 22
        'Drop Target 10'        = 38
        'Drop Target 11'        = 7
        'Drop Target 12'        = 23
        'Drop Target 13'        = 39
        'Drop Target 14'        = 8
        'Drop Target 15'        = 24
        'Rollover Lanes 10,000' = 91
        'Rollover Lanes 20,000' = 60
        'Rollover Lanes 30,000' = 76
        'Rollover Lanes 40,000' = 92
        'Rollover Lanes Special' = 61
    }

    # E-I-G-H-T standup -> the pool-ball drop group behind it. A standup's
    # handler (CC7C) continues only while that group is down: CDAA maps the
    # standups E, I, G, H, T (33-37) to drop latches 10C5 bits 20, 01, 04, 08,
    # 40, set by switches 30, 25, 27, 28 and 31. The hit then pulses the
    # group's reset coil (CD4C, table CDCE). Measured: drop-targets, saucer
    # and eight-targets.tests.ps1 wait for each standup's hit to pulse the
    # group's solenoid. Not described in GAME_RULE_TRACES.md or gamerules.md,
    # so tests use it to reach states, not as an expected rule.
    StandupDropGroups = @{
        'Drop Target "E"' = 'Drop Target 6,14'
        'Drop Target "I"' = 'Drop Target 1,2,9,10'
        'Drop Target "G"' = 'Drop Target 3,11'
        'Drop Target "H"' = 'Drop Target 4,5,12,13'
        'Drop Target "T"' = 'Drop Target 7,15'
    }

    # Sound command bytes. libpinmame reports each command as two sound events:
    # the whole byte, then the byte shifted right four (C26D writes both).
    Sounds = @{
        # GAME_RULE_TRACES.md "Switch 07: Rebound" (CA95). Measured: "Rebound
        # sound reaches the sound board".
        Rebound      = 0x22
        # HARDWARE_MAP.md Squawk & Talk table, "60 Prompt to rack the balls".
        # Measured: "Start sets players" (sent when a game starts).
        RackTheBalls = 0x60
    }

    # Display index -> use, as libpinmame numbers them (by6803 dispBy7C).
    # Measured in every play test: 0-3 show player scores, 4 the credits, 5 the
    # ball in play, the match number and the service test number.
    Displays = @{
        Player1 = 0
        Player2 = 1
        Player3 = 2
        Player4 = 3
        Credits = 4
        Status  = 5
        Count   = 6
    }

    # RAM addresses. The first group is src/originals/asm/symbols.inc verbatim.
    Ram = @{
        PIA0_PORTA_OR_DDRA                = 0x0020
        PIA0_CRA                          = 0x0021
        PIA0_PORTB_OR_DDRB                = 0x0022
        PIA0_CRB                          = 0x0023
        PIA1_PORTA_OR_DDRA                = 0x0040
        PIA1_CRA                          = 0x0041
        PIA1_PORTB_OR_DDRB                = 0x0042
        PIA1_CRB                          = 0x0043
        PENDING_SCORE_10S                 = 0x0094
        PENDING_SCORE_100S                = 0x0095
        PENDING_SCORE_1000S               = 0x0096
        PENDING_SCORE_10000S              = 0x0097
        PENDING_SCORE_100000S             = 0x0098
        PENDING_SCORE_1000000S            = 0x0099
        WORK_RAM_U4_6116_START            = 0x1000
        PENDING_SOUND_COMMAND             = 0x1024
        SWITCH_EVENTS_STROBE0             = 0x1026
        SWITCH_EVENTS_STROBE1             = 0x1027
        SWITCH_EVENTS_STROBE2             = 0x1028
        SWITCH_EVENTS_STROBE3             = 0x1029
        SWITCH_EVENTS_STROBE4             = 0x102A
        SWITCH_SAMPLE_CURRENT_STROBE0     = 0x102C
        SWITCH_SAMPLE_CURRENT_STROBE1     = 0x102D
        SWITCH_SAMPLE_CURRENT_STROBE2     = 0x102E
        SWITCH_SAMPLE_CURRENT_STROBE3     = 0x102F
        SWITCH_SAMPLE_CURRENT_STROBE4     = 0x1030
        SWITCH_SAMPLE_PREVIOUS_STROBE0    = 0x1032
        SWITCH_SAMPLE_PREVIOUS_STROBE1    = 0x1033
        SWITCH_SAMPLE_PREVIOUS_STROBE2    = 0x1034
        SWITCH_SAMPLE_PREVIOUS_STROBE3    = 0x1035
        SWITCH_SAMPLE_PREVIOUS_STROBE4    = 0x1036
        LAMP_SHADOW_BANK_A_BYTE0          = 0x103A
        DROP_TARGET_5000_LAMP_SHADOW      = 0x103F
        CHAMP_LANE_STATE                  = 0x1040
        CHAMP_MULTIPLIER_LAMP_SHADOW      = 0x1041
        DROP_TARGET_5000_LAMP_FLASH_MASK  = 0x10BF
        CHAMP_COMPLETION_STATE            = 0x10C0
        SUNK_POOL_BALLS_1_TO_7            = 0x10C3
        DROP_TARGET_SWITCH_CLOSURE_LATCHES = 0x10C5
        WORK_RAM_U4_6116_END              = 0x17FF

        # Credits: two digit bytes, ones first, digit in the high nibble, F =
        # blank (credits = 10 * hi(1628) + hi(1627)). F711 increments it, F6E6
        # runs on it at a start, F735-F738 copy it to the credit display.
        # Measured: "Coin adds a credit".
        Credits       = 0x1627
        # Ball in play: high nibble of 008E (F4E6 adds 10; F4EE copies it to
        # the status display). Player count: low nibble of 008E (F83D INC).
        # Current player: 008F, 1-based (F4D0 indexes 0090 by it). Measured:
        # "Start sets players".
        BallInPlay    = 0x008E
        PlayerCount   = 0x008E
        CurrentPlayer = 0x008F
        # Game over: 009A bit 5 (RamMasks.GameOver); F829-F835 sets it at the
        # end of a game, F85E-F86A clears it at a start. Measured: "Start sets
        # players" (set in attract before the Credit press, clear after it).
        GameOver      = 0x009A
        # Match number: high nibble of 106A is its tens digit, which F7F8-F804
        # compares with each score's tens digit. It comes from the free-running
        # BCD counter 1013 (E08D-E093) through F78F-F7B1. Measured:
        # tests/originals/match.tests.ps1 (over 12 games, the status display
        # shows this digit followed by 0 at game end, and a credit is added
        # exactly when it equals the score's tens digit).
        MatchDigit    = 0x106A
        # HARDWARE_MAP.md "U4 RAM: dedicated player-score display buffers":
        # seven bytes each, ones first, digit in the high nibble (F = blank).
        # Measured: "Score buffers match display".
        ScoreBuffer1  = 0x1046
        ScoreBuffer2  = 0x104D
        ScoreBuffer3  = 0x1054
        ScoreBuffer4  = 0x105B
        # Balls per game (operator register 23, manual p. 1-4): high nibble of
        # NVRAM 161F (adjustment table entry at EB43: 17 16 1F; factory value from
        # C14B at EAB3). Measured: "Set-EbcAdjustment changes a setting"
        # (30 fresh, 50 after storing 5).
        BallsPerGame  = 0x161F
    }

    # Bit masks for the RAM entries that share a byte (see Ram comments).
    RamMasks = @{
        BallInPlay  = 0xF0
        PlayerCount = 0x0F
        GameOver    = 0x20
        MatchDigit  = 0xF0
        BallsPerGame = 0xF0
    }

    # Emulated frames per second, derived, not measured directly. Measured
    # ("Frames per second"): 100C falls by exactly 1,200 over 600 frames, 2
    # ticks per frame. 100C is decremented at E06F, reached from the timer
    # input-capture service (E05C) and from the PIA0 CB1 path of the IRQ
    # service (E032-E041, BRA E06B). Derived: the ROM counts 7,200 of these
    # ticks per minute (E0FB reloads 1C20 for the audit at 1666), so 120 a
    # second, giving 60 frames a second; pinmame core.c also sets
    # MDRV_FRAMES_PER_SECOND(60).
    FramesPerSecond = 60

    # Shortest switch closure and gap the ROM's debounce accepts, in frames.
    # E1FD-E213 takes a closure seen in two successive scans after an open
    # scan; the scan runs from the output-compare service (E022, every 0A1E
    # E-cycles, about 5.8 per frame). Measured: "Switch debounce" (Rebound
    # closed 1 frame, open 1, closed 1 queues 0x22 twice).
    SwitchMinCloseFrames = 1
    SwitchMinOpenFrames  = 1
}
