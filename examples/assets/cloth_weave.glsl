// Filter the thread frequencies as they become smaller than a pixel; the
// fabric should converge to its average tone, rather than shimmer at distance.
vec3 threadDetail(vec2 uv, float scale, out float weave) {
    vec2 p = uv * vec2(scale, scale * materialParams.clothSize.y / materialParams.clothSize.x);
    vec2 footprint = fwidth(p);
    vec2 visibility = vec2(1.0) - smoothstep(vec2(.25), vec2(.65), footprint);
    vec2 phase = p * 6.283185;
    vec2 strand = (.5 + .5 * cos(phase)) * visibility;
    float overUnder = mod(floor(p.x) + floor(p.y), 2.0);
    float resolved = min(visibility.x, visibility.y);
    overUnder = mix(.5, overUnder, resolved);
    weave = mix(strand.x, strand.y, overUnder) - .25 * (visibility.x + visibility.y);
    vec2 slope = sin(phase) * visibility * mix(vec2(1.0, .3), vec2(.3, 1.0), overUnder);
    return normalize(vec3(slope * materialParams.weaveStrength * .26, 1.0));
}
