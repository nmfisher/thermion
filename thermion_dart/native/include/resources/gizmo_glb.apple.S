    .global _GIZMO_GLB_GIZMO_OFFSET;
    .global _GIZMO_GLB_GIZMO_SIZE;

    .global _GIZMO_GLB_PACKAGE
    .section __TEXT,__const
_GIZMO_GLB_PACKAGE:
    .incbin "gizmo_glb.bin"
_GIZMO_GLB_GIZMO_OFFSET:
    .int 0
_GIZMO_GLB_GIZMO_SIZE:
    .int 13184

