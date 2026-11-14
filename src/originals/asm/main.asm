; Eight Ball Champ canonical 6803 source
; This must produce a validated, behaviorally faithful 16 KiB CPU ROM.

        processor 6803

        include "symbols.inc"
        include "../build/rom_checksum.inc"

        org $C000
        include "modules/00_tables_lamps_sound.asm"
        include "modules/10_game_state_and_drop_reset.asm"
        include "modules/20_scoring_and_switch_rules.asm"
        include "modules/30_drop_targets_and_game_rules.asm"
        include "modules/40_interrupts_switches_lamps.asm"
        include "modules/50_reset_initialization_main_loop.asm"
        include "modules/60_service_tests.asm"
        include "modules/70_helpers_displays_io.asm"
        include "modules/80_vectors.asm"
