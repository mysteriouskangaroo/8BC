// Export the canonical Eight Ball Champ listing as address-preserving DASM
// source. Instructions already recognized by Ghidra are emitted as 6803
// mnemonics; data and unclassified bytes remain dc.b declarations.
//
// Run only against src/originals/ghidra/EightBallChamp.gpr after applying the
// canonical hardware and rules annotation scripts. The first script argument
// is the output directory (normally src/originals/asm).

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.CodeUnit;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolIterator;

public class ExportEightBallChampCanonicalAsm extends GhidraScript {
    private static final Pattern GHIDRA_HEX = Pattern.compile("0x([0-9a-fA-F]+)");

    private static class Module {
        final int start;
        final int end;
        final String fileName;
        final String title;
        final String purpose;

        Module(int start, int end, String fileName, String title, String purpose) {
            this.start = start;
            this.end = end;
            this.fileName = fileName;
            this.title = title;
            this.purpose = purpose;
        }
    }

    private static final Module[] MODULES = {
        new Module(0xc000, 0xc497, "00_tables_lamps_sound.asm",
            "Low-ROM tables, lamp effects, and sound transport",
            "Dispatch tables and early shared routines, including periodic lamp effects and controller-to-sound-board output."),
        new Module(0xc498, 0xc918, "10_game_state_and_drop_reset.asm",
            "Game and ball state",
            "New-game/per-ball state, player transitions, and the pool-ball drop-target reset/rearm sequence."),
        new Module(0xc919, 0xcdd7, "20_scoring_and_switch_rules.asm",
            "Scoring and switch rules",
            "Pending-score helpers, CHAMP multiplier state, Rebound, and other normal-play switch handlers."),
        new Module(0xcdd8, 0xdfff, "30_drop_targets_and_game_rules.asm",
            "Drop targets and later game rules",
            "Pool-ball first-sink/5,000 handlers and the remaining high-level rule code before the interrupt region."),
        new Module(0xe000, 0xe387, "40_interrupts_switches_lamps.asm",
            "Interrupts and periodic physical I/O",
            "Timer/PIA interrupt flow, switch-matrix scan and debounce, lamp refresh, and momentary-solenoid pulse expiry."),
        new Module(0xe388, 0xed3f, "50_reset_initialization_main_loop.asm",
            "Reset, initialization, and main control flow",
            "Reset/SWI entry, PIA setup, main-loop dispatch, and service-mode control leading up to the automatic solenoid test."),
        new Module(0xed40, 0xefff, "60_service_tests.asm",
            "Service tests",
            "Automatic solenoid-test sequencing, displayed test-number handling, and adjacent diagnostics."),
        new Module(0xf000, 0xffef, "70_helpers_displays_io.asm",
            "Shared helpers, displays, and output drivers",
            "Display/score helpers and low-level sound, timing, and momentary-solenoid output routines."),
        new Module(0xfff0, 0xffff, "80_vectors.asm",
            "6803 vectors",
            "SCI, timer, IRQ, SWI, NMI, and reset vectors.")
    };

    // Confirmed internal entries sometimes sit inside a larger auto-named
    // Ghidra function rather than at its entry. These ranges have been traced
    // directly and are safe to emit as mnemonics. The initial byte-identical
    // build verifies this mechanical export; later deliberate restructuring
    // is governed by structural and behavioral validation instead.
    private static final int[][] CONFIRMED_INTERNAL_RANGES = {
        { 0xc9c4, 0xca13 }, // 500/3,000/5,000 scoring and multiplier helpers
        { 0xca1b, 0xca31 }, // 10-point pending-score helper
        { 0xca95, 0xcab6 }, // Rebound and common sound/score gate
        { 0xe022, 0xe0a8 }, // interrupt entries and momentary-pulse expiry
        { 0xe1e9, 0xe215 }, // switch scan, sampling, and debounce latch
        { 0xe28c, 0xe2a6 }, // periodic multiplexed I/O refresh anchor
        { 0xe50f, 0xe547 }, // PIA initialization and mode selection
        { 0xf5c2, 0xf5fa }  // blocking and timed momentary-solenoid helpers
    };

    private Address at(int offset) {
        return currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(offset);
    }

    private List<String> userLabelsAt(int offset) {
        List<String> names = new ArrayList<>();
        for (Symbol symbol : currentProgram.getSymbolTable().getSymbols(at(offset))) {
            if (symbol.getSource() == SourceType.USER_DEFINED && !symbol.isDynamic()) {
                // Ghidra can expose the vector-table label again as a local
                // symbol on its referenced handler. DASM has one global
                // namespace, so keep VECTOR_* only at the actual vector table.
                if (symbol.getName().startsWith("VECTOR_") && offset < 0xfff0) continue;
                names.add(symbol.getName());
            }
        }
        Collections.sort(names);
        return names;
    }

    private boolean hasUserLabel(int offset) {
        return !userLabelsAt(offset).isEmpty();
    }

    private String dasmInstruction(Instruction instruction) {
        // Ghidra's MC6801/6803 textual form is already close to DASM. DASM
        // uses '$' rather than Ghidra's '0x' hexadecimal prefix.
        String ghidraSource = instruction.toString();
        String numericSource = ghidraSource.replaceAll("0x([0-9a-fA-F]+)", "\\$$1");
        String source = symbolizeOperands(ghidraSource).replaceAll("0x([0-9a-fA-F]+)", "\\$$1");
        // DASM normally shortens an address below $0100 to direct-page mode.
        // Preserve an original three-byte extended access by forcing the
        // mnemonic's word form (for example LDAA.w $009B).
        if (instruction.getLength() == 3 && numericSource.matches("^[A-Za-z]+ \\$00[0-9a-fA-F]{2}$")) {
            int separator = source.indexOf(' ');
            source = source.substring(0, separator) + ".w" + source.substring(separator);
        }
        return source;
    }

    private String symbolizeOperands(String source) {
        Matcher matcher = GHIDRA_HEX.matcher(source);
        StringBuffer result = new StringBuffer();
        while (matcher.find()) {
            int value = Integer.parseInt(matcher.group(1), 16);
            boolean immediate = matcher.start() > 0 && source.charAt(matcher.start() - 1) == '#';
            boolean indexedOffset = matcher.end() + 1 < source.length() &&
                source.charAt(matcher.end()) == ',' &&
                (source.charAt(matcher.end() + 1) == 'X' || source.charAt(matcher.end() + 1) == 'x');
            List<String> names = userLabelsAt(value);
            if (!indexedOffset && (!immediate || value >= 0xc000) && !names.isEmpty()) {
                matcher.appendReplacement(result, Matcher.quoteReplacement(names.get(0)));
            }
            else {
                matcher.appendReplacement(result, Matcher.quoteReplacement(matcher.group()));
            }
        }
        matcher.appendTail(result);
        return result.toString();
    }

    private boolean isConfirmedInstruction(Instruction instruction) {
        int offset = (int)instruction.getAddress().getOffset();
        for (int[] range : CONFIRMED_INTERNAL_RANGES) {
            if (offset >= range[0] && offset <= range[1]) return true;
        }
        Function function = currentProgram.getFunctionManager().getFunctionContaining(instruction.getAddress());
        if (function == null) return false;
        if (function.getSymbol().getSource() == SourceType.USER_DEFINED) return true;
        return !userLabelsAt((int)function.getEntryPoint().getOffset()).isEmpty();
    }

    private byte[] bytesAt(int offset, int length) throws Exception {
        byte[] bytes = new byte[length];
        int read = currentProgram.getMemory().getBytes(at(offset), bytes);
        if (read != length) throw new IOException("Could not read ROM bytes at " + String.format("%04X", offset));
        return bytes;
    }

    private String hexBytes(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (int i = 0; i < bytes.length; i++) {
            if (i != 0) result.append(',');
            result.append(String.format("$%02X", bytes[i] & 0xff));
        }
        return result.toString();
    }

    private void writeComment(BufferedWriter writer, String text) throws IOException {
        if (text == null || text.length() == 0) return;
        for (String line : text.split("\\R")) {
            writer.write("; " + line);
            writer.newLine();
        }
    }

    private void writeLabels(BufferedWriter writer, int offset) throws IOException {
        for (String name : userLabelsAt(offset)) {
            writer.write(name + ":");
            writer.newLine();
        }
    }

    private void writeModule(Path moduleDirectory, Module module) throws Exception {
        Path output = moduleDirectory.resolve(module.fileName);
        try (BufferedWriter writer = Files.newBufferedWriter(output, StandardCharsets.US_ASCII)) {
            writer.write("; " + module.title);
            writer.newLine();
            writer.write("; Address range: $" + String.format("%04X", module.start) + "-$" + String.format("%04X", module.end));
            writer.newLine();
            writer.write("; " + module.purpose);
            writer.newLine();
            writer.write("; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.");
            writer.newLine();
            writer.newLine();

            int offset = module.start;
            while (offset <= module.end) {
                Instruction instruction = currentProgram.getListing().getInstructionAt(at(offset));
                if (instruction != null && offset + instruction.getLength() - 1 <= module.end) {
                    writeLabels(writer, offset);
                    writeComment(writer, instruction.getComment(CodeUnit.PRE_COMMENT));
                    String source = dasmInstruction(instruction);
                    byte[] bytes = bytesAt(offset, instruction.getLength());
                    if (isConfirmedInstruction(instruction)) {
                        writer.write(String.format("        %-28s ; $%04X: %s", source, offset, hexBytes(bytes)));
                    }
                    else {
                        writer.write(String.format("        dc.b %-47s ; $%04X unconfirmed: %s",
                            hexBytes(bytes), offset, source));
                    }
                    writer.newLine();
                    writeComment(writer, instruction.getComment(CodeUnit.EOL_COMMENT));
                    offset += instruction.getLength();
                    continue;
                }

                writeLabels(writer, offset);
                CodeUnit unit = currentProgram.getListing().getCodeUnitAt(at(offset));
                if (unit != null) {
                    writeComment(writer, unit.getComment(CodeUnit.PRE_COMMENT));
                }

                int length = 1;
                while (length < 16 && offset + length <= module.end) {
                    int candidate = offset + length;
                    if (hasUserLabel(candidate)) break;
                    if (currentProgram.getListing().getInstructionAt(at(candidate)) != null) break;
                    CodeUnit candidateUnit = currentProgram.getListing().getCodeUnitAt(at(candidate));
                    if (candidateUnit != null && (candidateUnit.getComment(CodeUnit.PRE_COMMENT) != null ||
                            candidateUnit.getComment(CodeUnit.EOL_COMMENT) != null)) break;
                    length++;
                }
                byte[] bytes = bytesAt(offset, length);
                writer.write(String.format("        dc.b %-47s ; $%04X data/unclassified", hexBytes(bytes), offset));
                writer.newLine();
                if (unit != null) writeComment(writer, unit.getComment(CodeUnit.EOL_COMMENT));
                offset += length;
            }
        }
    }

    private void writeSymbols(Path outputDirectory) throws Exception {
        List<Symbol> symbols = new ArrayList<>();
        SymbolIterator iterator = currentProgram.getSymbolTable().getAllSymbols(true);
        while (iterator.hasNext()) {
            Symbol symbol = iterator.next();
            long offset = symbol.getAddress().getOffset();
            if (symbol.getSource() == SourceType.USER_DEFINED && !symbol.isDynamic() && offset < 0xc000) {
                symbols.add(symbol);
            }
        }
        symbols.sort(Comparator.comparingLong((Symbol symbol) -> symbol.getAddress().getOffset())
            .thenComparing((Symbol symbol) -> symbol.getName()));

        try (BufferedWriter writer = Files.newBufferedWriter(outputDirectory.resolve("symbols.inc"), StandardCharsets.US_ASCII)) {
            writer.write("; Canonical RAM and memory-mapped hardware names exported from Ghidra.");
            writer.newLine();
            writer.write("; These are equates only; they do not allocate or emit bytes.");
            writer.newLine();
            writer.newLine();
            for (Symbol symbol : symbols) {
                writer.write(String.format("%-44s equ $%04X", symbol.getName(), symbol.getAddress().getOffset()));
                writer.newLine();
            }
        }
    }

    @Override
    public void run() throws Exception {
        String[] arguments = getScriptArgs();
        if (arguments.length != 1) {
            throw new IllegalArgumentException("Expected one output-directory argument");
        }

        Path outputDirectory = Paths.get(arguments[0]).toAbsolutePath().normalize();
        Path moduleDirectory = outputDirectory.resolve("modules");
        Files.createDirectories(moduleDirectory);
        writeSymbols(outputDirectory);
        for (Module module : MODULES) writeModule(moduleDirectory, module);
        println("Exported canonical DASM source modules to " + outputDirectory);
    }
}
