#define linearstep(p0, p1, v) (clamp(((v) - (p0)) / abs((p1) - (p0)), 0.0, 1.0))
#define AXIS_COLOR_X vec3(1.0f, 0.0f, 0.0f)
#define AXIS_COLOR_Y vec3(0.0f, 1.0f, 0.0f)
#define AXIS_COLOR_Z vec3(0.0f, 0.0f, 1.0f)