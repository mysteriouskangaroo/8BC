// Annotate the canonical Eight Ball Champ 6803 analysis with only the
// hardware facts established by the ROM and the operations manual.
//
// Run after SeedEightBallChamp.java, with the original Ghidra project closed:
//   analyzeHeadless.bat <project-dir> EightBallChamp -process u3_cpu.128
//     -postScript AnnotateEightBallChampHardware.java -noanalysis

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.CodeUnit;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;

public class AnnotateEightBallChampHardware extends GhidraScript {

    private Address at(int offset) {
        return currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(offset);
    }

    private void label(int offset, String name) throws Exception {
        Address address = at(offset);
        SymbolTable symbols = currentProgram.getSymbolTable();
        Symbol existing = symbols.getSymbol(name, address, currentProgram.getGlobalNamespace());
        if (existing == null) {
            symbols.createLabel(address, name, SourceType.USER_DEFINED);
        }
    }

    private void renameOurLabel(int offset, String oldName, String newName) throws Exception {
        Address address = at(offset);
        SymbolTable symbols = currentProgram.getSymbolTable();
        Symbol oldSymbol = symbols.getSymbol(oldName, address, currentProgram.getGlobalNamespace());
        Symbol newSymbol = symbols.getSymbol(newName, address, currentProgram.getGlobalNamespace());
        if (oldSymbol != null && newSymbol == null) {
            oldSymbol.setName(newName, SourceType.USER_DEFINED);
        }
        else if (oldSymbol != null) {
            // A prior run used the old generated name. Remove only that
            // exact label once its replacement already exists.
            oldSymbol.delete();
        }
        else if (newSymbol == null) {
            symbols.createLabel(address, newName, SourceType.USER_DEFINED);
        }
    }

    private void addComment(int offset, int type, String text) {
        CodeUnit unit = currentProgram.getListing().getCodeUnitAt(at(offset));
        if (unit != null) {
            String existing = unit.getComment(type);
            if (existing == null || existing.length() == 0) {
                unit.setComment(type, text);
            }
            else if (!existing.contains(text)) {
                unit.setComment(type, existing + "\n" + text);
            }
        }
    }

    private void preComment(int offset, String text) {
        addComment(offset, CodeUnit.PRE_COMMENT, text);
    }

    private void commentReferencesTo(int targetOffset, String text) {
        ReferenceIterator references = currentProgram.getReferenceManager().getReferencesTo(at(targetOffset));
        while (references.hasNext()) {
            Reference reference = references.next();
            CodeUnit unit = currentProgram.getListing().getCodeUnitContaining(reference.getFromAddress());
            if (unit != null) {
                String existing = unit.getComment(CodeUnit.EOL_COMMENT);
                // Replace only this script's previous I/O line; preserve all
                // researcher-written comments on the same instruction.
                if (existing != null) {
                    String[] lines = existing.split("\\n");
                    String retained = "";
                    for (String line : lines) {
                        if (!line.startsWith("I/O: ")) {
                            retained += (retained.length() == 0 ? "" : "\n") + line;
                        }
                    }
                    existing = retained;
                }
                unit.setComment(CodeUnit.EOL_COMMENT,
                    existing == null || existing.length() == 0 ? text : existing + "\n" + text);
            }
        }
    }

    private void managedEolComment(int offset, String prefix, String text) {
        CodeUnit unit = currentProgram.getListing().getCodeUnitContaining(at(offset));
        if (unit == null) return;

        String existing = unit.getComment(CodeUnit.EOL_COMMENT);
        String retained = "";
        if (existing != null) {
            for (String line : existing.split("\\n")) {
                if (!line.startsWith(prefix)) {
                    retained += (retained.length() == 0 ? "" : "\n") + line;
                }
            }
        }
        unit.setComment(CodeUnit.EOL_COMMENT,
            retained.length() == 0 ? text : retained + "\n" + text);
    }

    private void piaModeComment(int offset, String text) {
        managedEolComment(offset, "PIA mode: ", "PIA mode: " + text);
    }

    private void replaceCommentText(int offset, int type, String oldText, String newText) {
        CodeUnit unit = currentProgram.getListing().getCodeUnitAt(at(offset));
        if (unit == null) return;
        String existing = unit.getComment(type);
        if (existing != null && existing.contains(oldText)) {
            unit.setComment(type, existing.replace(oldText, newText));
        }
        else {
            addComment(offset, type, newText);
        }
    }

    @Override
    public void run() throws Exception {
        // Interrupt/reset vector table.
        label(0xfff0, "VECTOR_SCI");
        label(0xfff2, "VECTOR_TIMER_OVERFLOW");
        label(0xfff4, "VECTOR_TIMER_OUTPUT_COMPARE");
        label(0xfff6, "VECTOR_TIMER_INPUT_CAPTURE");
        label(0xfff8, "VECTOR_EXTERNAL_IRQ");
        label(0xfffa, "VECTOR_SWI");
        label(0xfffc, "VECTOR_NMI");
        label(0xfffe, "VECTOR_RESET");
        preComment(0xfff0, "6803 interrupt/reset vector table.  The 16-bit values here point to the service entries named below.");

        // Vector targets / control-flow anchors.
        label(0xe022, "IRQ_TIMER_OUTPUT_COMPARE");
        label(0xe032, "IRQ_EXTERNAL_PIA");
        label(0xe05b, "IRQ_SCI_AND_TIMER_OVERFLOW");
        label(0xe05c, "IRQ_TIMER_INPUT_CAPTURE");
        label(0xe387, "IRQ_NMI");
        label(0xe388, "RESET_AND_SWI_ENTRY");
        label(0xe50f, "PIA_INITIALIZATION");
        label(0xe28c, "PERIODIC_IO_REFRESH");
        label(0xe1f0, "SWITCH_MATRIX_SCAN");
        label(0xe0a1, "MOMENTARY_SOLENOID_PULSE_END");
        label(0xf5df, "MOMENTARY_SOLENOID_PULSE");
        replaceCommentText(0xe032, CodeUnit.PRE_COMMENT,
            "External IRQ service.  This path accesses the PIA at 0020-0023; it is a key switch/input-processing anchor.",
            "External PIA interrupt service. It acknowledges PIA control/port activity at 0020-0023; the specific input source remains untraced.");
        preComment(0xe022, "Timer output-compare service. It enters the periodic I/O refresh at E28C.");
        preComment(0xe1f0, "Switch-matrix scan: drive the five one-hot strobes 10, 08, 04, 02, 01 through PIA0 port A (0020); after a short delay read the eight returns from PIA0 port B (0022) and debounce the samples in RAM. See HARDWARE_MAP.md for switch numbers.");
        preComment(0xe28c, "Periodic I/O refresh. It multiplexes the lamp path at PIA0 and services other board I/O.");
        replaceCommentText(0xe0a1, CodeUnit.PRE_COMMENT,
            "Momentary-solenoid pulse end: when RAM 100D expires, force PIA1 port-B's low nibble to F (off/unwired U14 selection).",
            "Momentary-solenoid pulse end: when RAM 100D expires, force PIA1 port-B's low nibble to F (U14 M15, which the available material does not assign to a coil).");
        preComment(0xf5df, "Momentary-solenoid pulse helper: A bits 0-3 select U14 M0-M15 through PIA1 PB10-PB13; A bit 7 selects CB12's bank; starts the four-tick pulse timer at 100D.");
        preComment(0xe388, "Reset and SWI vector target.  Startup initializes the 6803 and external I/O before normal game operation.");
        preComment(0xe50f, "PIA setup sequence.  It configures both external 6821-compatible I/O address blocks.");

        // Board-level memory map. PIA0/PIA1 identify the schematic nets, not
        // the as-yet-untraced U7/U8 package positions.
        renameOurLabel(0x0020, "PIA_0020_PORTA_OR_DDRA", "PIA0_PORTA_OR_DDRA");
        renameOurLabel(0x0020, "PIA0_PORTA_LAMP_ADDRESS", "PIA0_PORTA_OR_DDRA");
        renameOurLabel(0x0020, "PIA0_PORTA_LAMP_ADDRESS_AND_SWITCH_STROBE", "PIA0_PORTA_OR_DDRA");
        renameOurLabel(0x0021, "PIA_0020_CRA", "PIA0_CRA");
        renameOurLabel(0x0022, "PIA_0020_PORTB_OR_DDRB", "PIA0_PORTB_OR_DDRB");
        renameOurLabel(0x0022, "PIA0_PORTB_SWITCH_RETURNS", "PIA0_PORTB_OR_DDRB");
        renameOurLabel(0x0023, "PIA_0020_CRB", "PIA0_CRB");
        renameOurLabel(0x0023, "PIA0_CRB_LAMP_STROBE", "PIA0_CRB");
        renameOurLabel(0x0040, "PIA_0040_PORTA_OR_DDRA", "PIA1_PORTA_OR_DDRA");
        renameOurLabel(0x0041, "PIA_0040_CRA", "PIA1_CRA");
        renameOurLabel(0x0042, "PIA_0040_PORTB_OR_DDRB", "PIA1_PORTB_OR_DDRB");
        renameOurLabel(0x0042, "PIA1_PORTB_MOMENTARY_SOLENOID_DATA", "PIA1_PORTB_OR_DDRB");
        renameOurLabel(0x0043, "PIA_0040_CRB", "PIA1_CRB");
        renameOurLabel(0x0043, "PIA1_CRB_SOLENOID_BANK_SELECT", "PIA1_CRB");
        label(0x1000, "WORK_RAM_U4_6116_START");
        label(0x17ff, "WORK_RAM_U4_6116_END");

        // The I/O registers themselves have no allocated listing units.  Put
        // the explanatory text on every instruction that touches them, where
        // it is useful while following the control flow.
        commentReferencesTo(0x0020, "I/O: PIA0 port A / DDRA. During lamp refresh, PA00-PA03 select a lamp driver and PA05-PA07 select the U15-U17 bank. At E1F0 the same port drives the five one-hot switch-matrix strobes. U7/U8 package assignment is untraced.");
        commentReferencesTo(0x0021, "I/O: PIA0 control register A. Bit 2 selects port-data versus data-direction access at 0020.");
        commentReferencesTo(0x0022, "I/O: PIA0 port B / DDRB (CRB bit 2 selects). In peripheral-data mode this is the eight switch-matrix return inputs; E1F0 samples it once per strobe.");
        commentReferencesTo(0x0023, "I/O: PIA0 control register B. Its CB2 output is CB02, the common lamp-strobe signal.");
        commentReferencesTo(0x0040, "I/O: PIA1 port A / DDRA. Its physical function is not yet traced.");
        commentReferencesTo(0x0041, "I/O: PIA1 control register A. Bit 2 selects port-data versus data-direction access at 0040.");
        commentReferencesTo(0x0042, "I/O: PIA1 port B / DDRB. In peripheral-data mode bits 0-3 are PB10-PB13: the momentary-solenoid number to U14. The upper nibble is preserved by the pulse helper.");
        commentReferencesTo(0x0043, "I/O: PIA1 control register B. Its CB2 output is CB12, the momentary-solenoid bank select.");

        // Mode-selected data/DDR accesses. These comments state what the
        // instruction reaches at that point in control flow; the address
        // labels above remain neutral because CRA/CRB bit 2 can bank the
        // corresponding port address between its DDR and peripheral data.
        piaModeComment(0xe520, "PIA0 CRA bit 2 is clear, so 0020 accesses DDRA.");
        piaModeComment(0xe522, "PIA0 CRB bit 2 is clear, so 0022 accesses DDRB.");
        piaModeComment(0xe524, "PIA1 CRA bit 2 is clear, so 0040 accesses DDRA.");
        piaModeComment(0xe526, "PIA1 CRB bit 2 is clear, so 0042 accesses DDRB.");
        piaModeComment(0xe537, "PIA0 CRA bit 2 is set, so 0020 accesses port-A peripheral data.");
        piaModeComment(0xe539, "PIA1 CRA bit 2 is set, so 0040 accesses port-A peripheral data.");
        piaModeComment(0xe547, "PIA0 CRB bit 2 is set, so 0022 accesses port-B peripheral data.");

        piaModeComment(0xe1e9, "CRB was just written with 30 (bit 2 clear); this zero write programs PIA0 DDRB as all inputs for the switch returns.");
        piaModeComment(0xe1ed, "Writing 34 sets CRB bit 2, restoring PIA0 port-B peripheral-data access before the scan.");
        piaModeComment(0xe1f6, "PIA0 CRA bit 2 is set; this writes the next one-hot switch strobe to port A.");
        piaModeComment(0xe20b, "PIA0 CRB bit 2 is set; this reads the eight switch returns from port B.");

        piaModeComment(0xe29c, "CRB was just written with 30 (bit 2 clear), so this instruction writes PIA0 DDRB.");
        piaModeComment(0xe2a0, "Writing 34 sets CRB bit 2, selecting PIA0 port-B peripheral data.");
        piaModeComment(0xe2a2, "PIA0 CRB bit 2 is set, so this instruction writes port-B peripheral data.");
        piaModeComment(0xe2a4, "PIA0 CRA bit 2 is set, so this instruction writes port-A peripheral data for the multiplexed I/O path.");

        piaModeComment(0xe0a3, "PIA1 CRB bit 2 is set; this reads port-B peripheral data before selecting U14 M15.");
        piaModeComment(0xe0a5, "PIA1 CRB bit 2 is set; this writes U14 selector F to end the momentary pulse.");
        piaModeComment(0xf5e6, "Both 34 and 3C keep CRB bit 2 set, selecting PIA1 port-B peripheral data; bit 3 controls CB12.");
        piaModeComment(0xf5ea, "PIA1 CRB bit 2 is set; this reads port-B peripheral data so the upper nibble can be preserved.");
        piaModeComment(0xf5f4, "PIA1 CRB bit 2 is set; this writes the momentary-solenoid selector through port B.");

        println("Eight Ball Champ hardware annotations applied.");
    }
}
