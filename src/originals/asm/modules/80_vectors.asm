; 6803 vectors
; Address range: $FFF0-$FFFF
; SCI, timer, IRQ, SWI, NMI, and reset vectors.
; Generated from the canonical Ghidra listing; later restructuring requires build and behavior validation.

VECTOR_SCI:
; 6803 interrupt/reset vector table.  The 16-bit values here point to the service entries named below.
        dc.b $E0,$5B                                         ; $FFF0 data/unclassified
VECTOR_TIMER_OVERFLOW:
        dc.b $E0,$5B                                         ; $FFF2 data/unclassified
VECTOR_TIMER_OUTPUT_COMPARE:
        dc.b $E0,$22                                         ; $FFF4 data/unclassified
VECTOR_TIMER_INPUT_CAPTURE:
        dc.b $E0,$5C                                         ; $FFF6 data/unclassified
VECTOR_EXTERNAL_IRQ:
        dc.b $E0,$32                                         ; $FFF8 data/unclassified
VECTOR_SWI:
        dc.b $E3,$88                                         ; $FFFA data/unclassified
VECTOR_NMI:
        dc.b $E3,$87                                         ; $FFFC data/unclassified
VECTOR_RESET:
        dc.b $E3,$88                                         ; $FFFE data/unclassified
