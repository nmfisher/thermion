// Shared vertex deformation for the three fabric BRDFs. The demo is an XY
// grid, UV V points upward, and the top edge is pinned to the display rail.
vec3 clothOffset(vec2 uv) {
    float loose = 1.0 - uv.y;
    float pin = smoothstep(0.0, .12, loose);
    float t = materialParams.time * materialParams.windSpeed;
    float pleat = sin(uv.x * 18.84956 + loose * .65) * (.085 + loose * .11);
    pleat += sin(uv.x * 37.6991 - loose * 1.7) * .023;
    float flutter = sin(uv.x * 8.0 + uv.y * 5.0 - t * 2.1) * .12;
    flutter += sin(uv.x * 17.0 - uv.y * 8.0 - t * 3.2) * .035;
    float z = pin * pleat + materialParams.windStrength * loose * loose * flutter;
    float y = -.07 * pin * sin(uv.x * 3.141593) * sin(uv.x * 3.141593);
    return vec3(0.0, y, z);
}
void materialVertex(inout MaterialVertexInputs material) {
    vec2 uv = material.uv0;
    vec3 offset = clothOffset(uv);
    const float epsilon = .002;
    vec3 du = vec3(materialParams.clothSize.x * epsilon, 0, 0) + clothOffset(uv + vec2(epsilon, 0)) - offset;
    vec3 dv = vec3(0, materialParams.clothSize.y * epsilon, 0) + clothOffset(uv + vec2(0, epsilon)) - offset;
    material.worldPosition.xyz += (getWorldFromModelMatrix() * vec4(offset, 0.0)).xyz;
    material.worldNormal = normalize(getWorldFromModelNormalMatrix() * normalize(cross(du, dv)));
}
