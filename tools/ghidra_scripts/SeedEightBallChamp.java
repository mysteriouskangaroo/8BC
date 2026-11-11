// Seeds the Ghidra MC6801/6803 disassembler from Eight Ball Champ's vectors.
// Run as a pre-analysis script; it does not alter the original ROM image.
import ghidra.app.script.GhidraScript;
import ghidra.program.disassemble.ReDisassembler;

public class SeedEightBallChamp extends GhidraScript {
	private static final long[] ENTRY_POINTS = {
		0xE05B, // SCI and timer overflow
		0xE022, // timer output compare
		0xE05C, // timer input capture
		0xE032, // IRQ
		0xE388, // SWI and reset
		0xE387  // NMI
	};

	private static final String[] LABELS = {
		"VECTOR_SCI", "VECTOR_TIMER_OUTPUT_COMPARE", "VECTOR_TIMER_INPUT_CAPTURE",
		"VECTOR_IRQ", "RESET", "VECTOR_NMI"
	};

	@Override
	protected void run() throws Exception {
		ReDisassembler disassembler = new ReDisassembler(currentProgram);
		for (int index = 0; index < ENTRY_POINTS.length; index++) {
			createLabel(toAddr(ENTRY_POINTS[index]), LABELS[index], true);
			disassembler.disassemble(toAddr(ENTRY_POINTS[index]), monitor);
		}
	}
}
