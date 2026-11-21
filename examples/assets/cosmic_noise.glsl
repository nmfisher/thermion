// Shared deterministic noise and angular star field. No external textures.
float cosmicHash(vec3 p) {
    p = fract(p * .1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float cosmicNoise(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(cosmicHash(i), cosmicHash(i + vec3(1,0,0)), f.x),
                   mix(cosmicHash(i + vec3(0,1,0)), cosmicHash(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(cosmicHash(i + vec3(0,0,1)), cosmicHash(i + vec3(1,0,1)), f.x),
                   mix(cosmicHash(i + vec3(0,1,1)), cosmicHash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float cosmicFbm(vec3 p) {
    float value = 0.0, amplitude = .55;
    for (int octave = 0; octave < 4; octave++) {
        value += amplitude * cosmicNoise(p);
        p = p * 2.03 + vec3(7.1, 3.7, 11.3);
        amplitude *= .48;
    }
    return value;
}
vec3 cosmicStars(vec3 ray, float amount) {
    vec2 sky = vec2(atan(ray.z, ray.x) / 6.283185 + .5,
                    asin(clamp(ray.y, -1.0, 1.0)) / 3.141593 + .5);
    vec3 color = vec3(0.0);
    for (int layer = 0; layer < 2; layer++) {
        vec2 grid = vec2(640.0, 320.0) * (1.0 + float(layer) * .63);
        vec2 p = sky * grid;
        vec2 cell = floor(p);
        float seed = cosmicHash(vec3(cell, float(layer) * 27.0));
        vec2 center = vec2(cosmicHash(vec3(cell, 3.7)), cosmicHash(vec3(cell, 8.3)));
        vec2 delta = fract(p) - (.15 + center * .7);
        // The minimum radius is the pixel footprint, so stars remain stable
        // when the dome is seen through a wider lens or a smaller viewport.
        float footprint = max(length(fwidth(p)) * .45, .045);
        float radius = max(.075, footprint);
        float star = exp(-dot(delta, delta) / (radius * radius));
        star *= step(1.0 - .02 * amount, seed);
        star *= .005625 / (radius * radius);
        vec3 tint = mix(vec3(.55, .7, 1), vec3(1, .77, .48), center.x);
        color += tint * star * (.1 + pow(seed, 35.0) * .7);
    }
    return color;
}
