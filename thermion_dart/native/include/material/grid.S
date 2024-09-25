    .global GRID_GRID_OFFSET;
    .global GRID_GRID_SIZE;

    .global GRID_PACKAGE
    .section .rodata
GRID_PACKAGE:
    .incbin "grid.bin"
GRID_GRID_OFFSET:
    .int 0
GRID_GRID_SIZE:
    .int 30210

