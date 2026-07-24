// Abyss Shader — Lighting helpers
//
// calculateIndirectLight: combines torch (block) light and sky ambient.
// This matches the formula used inline in composite.fsh so they stay in sync.
//
// Parameters:
//   lmCoord     — rescaled [0,1] lightmap UV (x=block light, y=sky light)
//   ambientColor — sky ambient colour for the current time-of-day (computed in composite.fsh)
//
// Returns the total indirect (non-shadow) light contribution before albedo multiplication.
vec3 calculateIndirectLight(vec2 lmCoord, vec3 ambientColor) {
    // Warm orange torch colour. Multiplier 5.0 gives HDR headroom so ACES compression
    // can produce a bright saturated halo near the source.
    vec3 torchColor = vec3(1.0, 0.52, 0.14) * 5.0;

    // Quadratic falloff on the block-light coordinate: bright right next to the source,
    // rapidly falling off at distance. Matches the lmCoord.x^2 used in composite.fsh.
    float torchFalloff = lmCoord.x * lmCoord.x;

    // Sky ambient (directional diffuse from the open sky).
    vec3 skyAmbient = ambientColor * lmCoord.y;

    // Hard floor so caves are never completely black — very slightly warm (bounce light).
    vec3 minAmbient = vec3(0.08, 0.07, 0.06);

    return torchColor * torchFalloff + skyAmbient + minAmbient;
}

// Blinn-Phong specular — used for water glints and wet-surface highlights.
vec3 calculateSpecularHighlight(vec3 viewNormal, vec3 lightDir, vec3 viewDir,
                                vec3 directColor, float shininess) {
    vec3  halfDir = normalize(lightDir + viewDir);
    float spec    = pow(max(dot(viewNormal, halfDir), 0.0), shininess);
    return directColor * spec;
}
