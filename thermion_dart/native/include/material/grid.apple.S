    .global _GRID_GRID_OFFSET;
    .global _GRID_GRID_SIZE;

    .global _GRID_PACKAGE
    .section __TEXT,__const
_GRID_PACKAGE:
    .incbin "grid.bin"
_GRID_GRID_OFFSET:
    .int 0
_GRID_GRID_SIZE:
    .int 50913

