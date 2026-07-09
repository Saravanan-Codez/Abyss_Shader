// Abyss Shader Water wave dynamics, refraction, and volumetric absorption module

// Generates procedural FBM Wave normals based on world coordinates and time
vec3 calculateWaterWaves(vec3 playerPos, float time) {
    float wave1 = sin(playerPos.x * 1.5 + time * 1.8) * cos(playerPos.z * 1.5 + time * 1.4);
    float wave2 = sin(playerPos.x * 3.5 - time * 2.5) * cos(playerPos.z * 3.5 + time * 2.0);
    
    vec3 waveNormal = vec3(0.0, 1.0, 0.0);
    waveNormal.x += wave1 * 0.10 + wave2 * 0.05;
    waveNormal.z += wave1 * 0.10 - wave2 * 0.05;
    return normalize(waveNormal);
}

// Applies Beer's Law light absorption to water thickness
vec3 applyWaterAbsorption(vec3 color, float thickness) {
    vec3 absorption = exp(-max(thickness, 0.0) * vec3(0.12, 0.06, 0.02));
    return color * absorption;
}

// Offsets texture coordinates dynamically based on wave normal local offsets
vec2 applyWaterRefraction(vec2 coord, vec3 waveNormalLocal) {
    return coord + waveNormalLocal.xz * 0.015;
}
