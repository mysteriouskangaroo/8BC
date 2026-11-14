// Annotate the canonical Eight Ball Champ 6803 analysis with game-rule traces.
// Hardware addresses and physical I/O remain in AnnotateEightBallChampHardware.
//
// Run after SeedEightBallChamp.java and AnnotateEightBallChampHardware.java:
//   analyzeHeadless.bat <project-dir> EightBallChamp -process u3_cpu.128
//     -postScript AnnotateEightBallChampRules.java -noanalysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.CodeUnit;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;

public class AnnotateEightBallChampRules extends GhidraScript {
    private Address at(int offset) {
        return currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(offset);
    }

    private void label(int offset, String name) throws Exception {
        Address address = at(offset);
        SymbolTable symbols = currentProgram.getSymbolTable();
        if (symbols.getSymbol(name, address, currentProgram.getGlobalNamespace()) == null) {
            symbols.createLabel(address, name, SourceType.USER_DEFINED);
        }
    }

    private void ensureFunction(int offset, String name) throws Exception {
        Address address = at(offset);
        disassemble(address);
        Function function = currentProgram.getFunctionManager().getFunctionAt(address);
        if (function == null) function = createFunction(address, name);
        else if (function.getName().startsWith("FUN_")) function.setName(name, SourceType.USER_DEFINED);
    }

    private void renameOurLabel(int offset, String oldName, String newName) throws Exception {
        Address address = at(offset);
        SymbolTable symbols = currentProgram.getSymbolTable();
        Symbol oldSymbol = symbols.getSymbol(oldName, address, currentProgram.getGlobalNamespace());
        Symbol newSymbol = symbols.getSymbol(newName, address, currentProgram.getGlobalNamespace());
        if (oldSymbol != null && newSymbol == null) oldSymbol.setName(newName, SourceType.USER_DEFINED);
        else if (oldSymbol != null) oldSymbol.delete();
        else if (newSymbol == null) symbols.createLabel(address, newName, SourceType.USER_DEFINED);
    }

    private void addComment(int offset, int type, String text) {
        CodeUnit unit = currentProgram.getListing().getCodeUnitAt(at(offset));
        if (unit == null) return;
        String existing = unit.getComment(type);
        if (existing == null || existing.length() == 0) unit.setComment(type, text);
        else if (!existing.contains(text)) unit.setComment(type, existing + "\n" + text);
    }

    private void preComment(int offset, String text) {
        addComment(offset, CodeUnit.PRE_COMMENT, text);
    }

    private void replaceCommentText(int offset, int type, String oldText, String newText) {
        CodeUnit unit = currentProgram.getListing().getCodeUnitAt(at(offset));
        if (unit == null) return;
        String existing = unit.getComment(type);
        if (existing != null && existing.contains(oldText)) unit.setComment(type, existing.replace(oldText, newText));
        else addComment(offset, type, newText);
    }

    private void managedEolComment(int offset, String prefix, String text) {
        CodeUnit unit = currentProgram.getListing().getCodeUnitContaining(at(offset));
        if (unit == null) return;
        String existing = unit.getComment(CodeUnit.EOL_COMMENT);
        String retained = "";
        if (existing != null) {
            for (String line : existing.split("\\n")) {
                if (!line.startsWith(prefix)) retained += (retained.length() == 0 ? "" : "\n") + line;
            }
        }
        unit.setComment(CodeUnit.EOL_COMMENT, retained.length() == 0 ? text : retained + "\n" + text);
    }

    @Override
    public void run() throws Exception {
        ensureFunction(0xcad4, "HANDLE_CHAMP_LANE_SWITCH");
        ensureFunction(0xcdd8, "HANDLE_PAIRED_POOL_BALL_DROP_TARGET");
        ensureFunction(0xd005, "HANDLE_SINGLE_POOL_BALL_DROP_TARGET");
        ensureFunction(0xc9f3, "AWARD_3000_POINTS_WITH_PLAYFIELD_MULTIPLIER");
        ensureFunction(0xc498, "START_GAME_AND_INITIALIZE_FIRST_BALL");

        label(0xe5bd, "PROCESS_SWITCH_EVENTS");
        label(0xc011, "PLAYFIELD_SWITCH_HANDLER_TABLE");
        label(0xc013, "SWITCH_07_REBOUND_HANDLER_ENTRY");
        label(0xca95, "HANDLE_SWITCH_07_REBOUND");
        renameOurLabel(0xcaaa, "QUEUE_REBOUND_SOUND_AND_CHECK_SCORE_GATE", "QUEUE_SOUND_AND_CHECK_SCORE_GATE");
        label(0xf4df, "CHECK_SCORE_GATE_LAMP_BITS");
        label(0xca1b, "AWARD_10_POINTS_WITH_PLAYFIELD_MULTIPLIER");
        label(0xca2f, "ADD_PENDING_SCORE_LOW_DIGIT");
        label(0xfa1a, "NORMALIZE_PENDING_SCORE_DIGITS");
        label(0xf38c, "APPLY_PENDING_SCORE");
        label(0xc26d, "SEND_SOUND_COMMAND_TO_BOARD");
        renameOurLabel(0xc14e, "UPDATE_CHAMP_MULTIPLIER_LAMP_FLASH", "PERIODIC_GAMEPLAY_TIMERS_AND_EFFECTS");
        label(0xc1b3, "FLASH_CHAMP_MULTIPLIER_LAMPS");
        label(0xc9f9, "AWARD_B_THOUSAND_WITH_PLAYFIELD_MULTIPLIER");
        label(0xca0b, "ADD_PENDING_SCORE_1000S");
        label(0xcb07, "ADVANCE_CHAMP_COMPLETION_STATE");
        label(0xcb18, "RECORD_LATER_CHAMP_COMPLETION");
        label(0xcb23, "STORE_CHAMP_COMPLETION_STATE");
        label(0xc4f6, "START_BALL_STATE");
        label(0xc043, "SWITCH_31_DROP_TARGET_7_15_HANDLER_ENTRY");
        label(0xc045, "SWITCH_30_DROP_TARGET_6_14_HANDLER_ENTRY");
        label(0xc049, "SWITCH_28_DROP_TARGET_4_5_12_13_HANDLER_ENTRY");
        label(0xc04b, "SWITCH_27_DROP_TARGET_3_11_HANDLER_ENTRY");
        label(0xc04f, "SWITCH_25_DROP_TARGET_1_2_9_10_HANDLER_ENTRY");
        label(0xce07, "AWARD_FIRST_SINK_AND_RECORD_POOL_BALL");
        label(0xd034, "AWARD_LIT_DROP_TARGET_5000");
        label(0xc9c4, "AWARD_500_POINTS_WITH_PLAYFIELD_MULTIPLIER");
        label(0xc9ef, "AWARD_5000_POINTS_WITH_PLAYFIELD_MULTIPLIER");
        label(0xc6b8, "RESET_AND_REARM_POOL_BALL_DROP_TARGETS");
        label(0xc6c9, "PULSE_ALL_POOL_BALL_DROP_TARGET_RESET_COILS");
        label(0xc6f2, "PULSE_ONE_DROP_TARGET_RESET_COIL");

        label(0x1024, "PENDING_SOUND_COMMAND");
        label(0x1040, "CHAMP_LANE_STATE");
        label(0x1041, "CHAMP_MULTIPLIER_LAMP_SHADOW");
        label(0x10c3, "SUNK_POOL_BALLS_1_TO_7");
        label(0x10c5, "DROP_TARGET_SWITCH_CLOSURE_LATCHES");
        label(0x10bf, "DROP_TARGET_5000_LAMP_FLASH_MASK");
        label(0x103f, "DROP_TARGET_5000_LAMP_SHADOW");
        label(0x0094, "PENDING_SCORE_10S");
        label(0x0095, "PENDING_SCORE_100S");
        label(0x0096, "PENDING_SCORE_1000S");
        label(0x0097, "PENDING_SCORE_10000S");
        label(0x0098, "PENDING_SCORE_100000S");
        label(0x0099, "PENDING_SCORE_1000000S");
        renameOurLabel(0x10c0, "PLAYFIELD_SCORE_MULTIPLIER_FLAGS", "CHAMP_COMPLETION_STATE");

        preComment(0xe5bd, "Normal-play switch dispatcher. It scans event bytes 1026-102A in strobe order and each byte from bit 7 down to bit 0, clears one event, and calls the corresponding pointer in the table at C011. Switch 07 (strobe 0, return 6) selects the C013 pointer to CA95.");
        replaceCommentText(0xca95, CodeUnit.PRE_COMMENT,
            "Switch 07 Rebound handler. Queue sound command 22, pass the common score gate, then award the manual's 10-point value through CA1B.",
            "Switch 07 Rebound handler. Queue sound command 0x22, pass the common score gate, then award the manual's 10-point value through CA1B.");
        replaceCommentText(0xcaaa, CodeUnit.PRE_COMMENT,
            "Rebound setup/gate. Store sound command 22 at 1024, then continue to scoring only if lamp-shadow byte 103A has bits 7 and 6 both set. The exact physical lamp identities of those two gate bits remain untraced.",
            "Common switch setup/gate. Store the caller-provided sound command in B at 1024, then continue to scoring only if lamp-shadow byte 103A has bits 7 and 6 both set. The exact physical lamp identities of those two gate bits remain untraced.");
        replaceCommentText(0xcaaa, CodeUnit.PRE_COMMENT,
            "Rebound setup/gate. Store sound command 0x22 at 1024, then continue to scoring only if lamp-shadow byte 103A has bits 7 and 6 both set. The exact physical lamp identities of those two gate bits remain untraced.",
            "Common switch setup/gate. Store the caller-provided sound command in B at 1024, then continue to scoring only if lamp-shadow byte 103A has bits 7 and 6 both set. The exact physical lamp identities of those two gate bits remain untraced.");
        preComment(0xf4df, "Common score-handler gate: return Z set only when bits 7 and 6 of lamp-shadow byte 103A are both set. This is used by the Rebound handler and another table dispatcher; do not infer physical lamp names without completing the schematic trace.");
        replaceCommentText(0xca1b, CodeUnit.PRE_COMMENT,
            "Common 10-point award. Add one lowest-place pending-score unit normally, two when 10C0 bit 4 is set (playfield double), or three when bit 5 alone is set (playfield triple). The game normally treats these multiplier states as mutually exclusive.",
            "Common 10-point award. Read CHAMP_COMPLETION_STATE at 10C0: 0x10 means playfield double and 0x20 means playfield triple. Valid game states keep those bits mutually exclusive; test 0x20 first, then 0x10, when adding new rules.");
        preComment(0xca2f, "Add B to the lowest pending-score digit at 0094, then normalize carries through FA1A. One unit here is 10 displayed points.");
        preComment(0xfa1a, "Normalize the pending-score digits 0094-0098 by carrying each value of ten into the next decimal place.");
        preComment(0xf38c, "Apply the pending score in 0094-0099 to the active player's displayed score over successive main-loop passes.");
        replaceCommentText(0xc26d, CodeUnit.PRE_COMMENT,
            "Controller-to-sound-board command output. A queued byte from 1024 can be split across the 6803 ports and strobed to the sound board; the Rebound handler queues command 22.",
            "Controller-to-sound-board command output. A queued byte from 1024 can be split across the 6803 ports and strobed to the sound board; the Rebound handler queues command 0x22.");
        preComment(0xcad4, "Shared handler for switches 17-21 (C, H, A, M, P lanes). It scores the lane first, then records its bit in lamp/state byte 1040. Completing all five advances CHAMP_COMPLETION_STATE at 10C0: 00 -> 10 (double) -> 20 (triple) -> 60 -> E0.");
        preComment(0xc9f3, "Award the manual's 3,000-point CHAMP lane value through the common playfield multiplier. This runs before a just-completed CHAMP advances 10C0, so the completing lane uses the multiplier that was active before completion.");
        replaceCommentText(0xc14e, CodeUnit.PRE_COMMENT,
            "Lamp animation only: XOR authoritative CHAMP_COMPLETION_STATE at 10C0 into lamp shadow 1041. Because 1041 blinks, new gameplay rules must test 10C0 instead: 0x20 means triple; otherwise 0x10 means double.",
            "Periodic gameplay timers and effects. The CHAMP multiplier lamp flash occurs specifically at C1B3-C1B8; see that instruction-level comment.");
        preComment(0xc1b3, "CHAMP lamp animation only. XOR authoritative CHAMP_COMPLETION_STATE at 10C0 into CHAMP_MULTIPLIER_LAMP_SHADOW at 1041. Because the shadow blinks, gameplay rules must read 10C0 instead: test 0x20 for triple first, then 0x10 for double.");
        preComment(0xc4f6, "Per-ball initialization entry (also reached by the full new-game path at C498). It clears CHAMP_COMPLETION_STATE at C507, so playfield double/triple last only for the current ball, including later CHAMP completions on that ball.");
        preComment(0xcdd8, "Paired pool-ball drop-target handler for switches 25 (balls 1/2) and 28 (balls 4/5). Ignore a closure already latched in 10C5. Otherwise latch it, award 500 and record the first unsunk ball bit in 10C3; only after both bits in the pair are set does a later rearmed hit take the 5,000-point branch at D034.");
        preComment(0xd005, "Single pool-ball drop-target handler for switches 27, 30, and 31 (balls 3, 6, and 7). Ignore a closure already latched in 10C5. Otherwise award 500 and set its 10C3 sunk bit on the first hit, or take the 5,000-point branch at D034 when already sunk.");
        preComment(0xce07, "First-sink path. C9C4 awards 500 points through the active playfield double/triple multiplier, then this code ORs the selected ball bit into SUNK_POOL_BALLS_1_TO_7 at 10C3 and starts its ball/lamp effects.");
        preComment(0xd034, "Already-sunk drop-target path. C9EF awards 5,000 points through the active playfield double/triple multiplier and updates the five drop-target 5,000 lamp effect.");
        preComment(0xc6c9, "Reset and rearm all five pool-ball drop-target groups. Pulse U14 selectors M0-M4 in turn; after each reset, C6F7-C6FC clears only that group's physical closure latch in 10C5. The sunk-ball record at 10C3 is preserved, so the next hit can take the 5,000-point branch.");

        managedEolComment(0xc9f9, "Multiplier award: ", "Multiplier award: mask the authoritative state to the double/triple bits.");
        managedEolComment(0xca00, "Multiplier award: ", "Multiplier award: any active multiplier adds a second copy of the base award.");
        managedEolComment(0xca05, "Multiplier award: ", "Multiplier award: if double bit 0x10 is set, stop at two copies; valid triple states have 0x20 set and 0x10 clear.");
        managedEolComment(0xca09, "Multiplier award: ", "Multiplier award: triple adds the third copy of the base award.");
        managedEolComment(0xcad9, "CHAMP timing: ", "CHAMP timing: score this lane with the currently active multiplier before advancing the completion state.");
        managedEolComment(0xcaee, "CHAMP completion: ", "CHAMP completion: continue only when all five lane bits in 1040 are now set.");
        managedEolComment(0xcb07, "CHAMP state: ", "CHAMP state: inspect the current completion state before advancing it.");
        managedEolComment(0xcb0e, "CHAMP state: ", "CHAMP state: default next value to 0x20 (triple); this is used when the current value has 0x10 (double).");
        managedEolComment(0xcb14, "CHAMP state: ", "CHAMP state: no multiplier was active, so the first completion selects 0x10 (double).");
        managedEolComment(0xcb18, "CHAMP state: ", "CHAMP state: triple is already active; select the third- or fourth-completion milestone bit.");
        managedEolComment(0xcb20, "CHAMP state: ", "CHAMP state: preserve triple bit 0x20 while adding milestone bit 0x40 or 0x80.");
        managedEolComment(0xcb23, "CHAMP state: ", "CHAMP state: store 0x10 after completion 1 (double), 0x20 after completion 2 (triple), then add 0x40 and 0x80 on completions 3 and 4 while triple remains active.");
        managedEolComment(0xc1b5, "CHAMP lamp flash: ", "CHAMP lamp flash: XOR stable state 10C0 into blinking lamp shadow 1041; never use 1041 as a gameplay condition.");
        managedEolComment(0xc507, "CHAMP state: ", "CHAMP state: clear playfield double/triple at the start of every ball.");
        managedEolComment(0xcddd, "Drop target: ", "Drop target: test whether this physical switch group is already latched closed in 10C5; the following branch rejects a repeat.");
        managedEolComment(0xcde8, "Drop target: ", "Drop target: store this group's new physical-closure latch in 10C5.");
        managedEolComment(0xce0a, "Drop target: ", "Drop target: award the first-sink base value of 500 points; the shared helper applies playfield double/triple.");
        managedEolComment(0xce0d, "Drop target: ", "Drop target: preserve this ball as sunk in the seven-bit state at 10C3.");
        managedEolComment(0xd00a, "Drop target: ", "Drop target: test whether this physical switch group is already latched closed in 10C5; the following branch rejects a repeat.");
        managedEolComment(0xd00f, "Drop target: ", "Drop target: preserve the target mask before setting its physical-closure latch in 10C5.");
        managedEolComment(0xd037, "Drop target: ", "Drop target: set the shared 5,000 drop-target lamp shadow at 103F to FF.");
        managedEolComment(0xd039, "Drop target: ", "Drop target: award the already-sunk value of 5,000 points; the shared helper applies playfield double/triple.");
        managedEolComment(0xc6f4, "Drop-target reset: ", "Drop-target reset: pulse the selected M0-M4 reset coil through the blocking momentary-solenoid helper.");
        managedEolComment(0xc6fc, "Drop-target reset: ", "Drop-target reset: clear only this group's closure latch in 10C5; preserve sunk-ball state 10C3.");

        println("Eight Ball Champ game-rule annotations applied.");
    }
}
