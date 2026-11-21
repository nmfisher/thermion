// Air / dielectric film / effective substrate, evaluated for both polarization
// states and nine wavelengths. RGB band averages approximate spectral color;
// this is not a full spectral BRDF or the KHR_materials_iridescence extension.
vec3 airyReflectance(float r01, float r12, vec3 phase, vec3 attenuation) {
    vec3 interference = 2.0 * r01 * r12 * cos(phase) * attenuation;
    return (r01 * r01 + r12 * r12 + interference) /
           max(vec3(1.0 + r01 * r01 * r12 * r12) + interference, vec3(.00001));
}
vec3 thinFilm(float cosine, float thickness, float filmIor, float substrateIor) {
    float c0 = clamp(cosine, .04, 1.0);
    float n1 = max(filmIor, 1.001), n2 = max(substrateIor, 1.0);
    float sineSq = 1.0 - c0 * c0;
    float c1 = sqrt(max(1.0 - sineSq / (n1 * n1), .0001));
    float c2 = sqrt(max(1.0 - sineSq / (n2 * n2), .0001));
    float r01s = (c0 - n1 * c1) / (c0 + n1 * c1);
    float r12s = (n1 * c1 - n2 * c2) / (n1 * c1 + n2 * c2);
    float r01p = (n1 * c0 - c1) / (n1 * c0 + c1);
    float r12p = (n2 * c1 - n1 * c2) / (n2 * c1 + n1 * c2);
    float path = 12.566371 * n1 * max(thickness, 0.0) * c1;
    vec3 result = vec3(0.0);
    for (int sampleIndex = 0; sampleIndex < 3; sampleIndex++) {
        vec3 wavelength = vec3(650, 550, 450) + (float(sampleIndex) - 1.0) * 25.0;
        vec3 phase = path / wavelength;
        vec3 footprint = fwidth(phase);
        vec3 attenuation = exp(-.5 * footprint * footprint);
        result += .5 * (airyReflectance(r01s, r12s, phase, attenuation) +
                        airyReflectance(r01p, r12p, phase, attenuation));
    }
    return clamp(result / 3.0, 0.0, 1.0);
}
// Filament 75 exposes specular/glossiness rather than native iridescence.
// Invert its Schlick factor at N.V to approximate a colored F0 for direct/IBL
// lighting. The coating therefore uses N.V, not each light's microfacet V.H.
vec3 filmSpecularF0(vec3 reflectance, float cosine) {
    float grazing = pow(1.0 - clamp(cosine, .04, 1.0), 5.0);
    return clamp((reflectance - grazing) / max(1.0 - grazing, .0001), .0, .98);
}
float filmFlow(vec3 p, float t) {
    float wave = sin(p.x * 3.0 + sin(p.y * 4.0 + t * .35) + p.z * 2.0);
    wave += .5 * sin(p.y * 6.0 - p.z * 3.0 + sin(p.x * 4.0 - t * .2));
    return wave / 1.5;
}
