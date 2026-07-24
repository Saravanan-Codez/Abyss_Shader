#version 150 compatibility

// Abyss Shader — deferred: TAA Resolve + Bloom Upsample Pass
//
// Execution order in the pipeline:
//   composite  → composite1 → composite2 → [deferred] → final
//
// Inputs:
//   colortex3  — current-frame HDR scene (with SSAO applied, from composite2)
//   colortex5  — TAA history buffer (previous frame HDR, persists across frames)
//   colortex6  — bloom extraction (13-tap Kawase from composite2)
//   depthtex0  — opaque depth (for reprojection)
//
// Outputs:
//   colortex3  — TAA-resolved + bloom-composited HDR (read by final.fsh)
//   colortex5  — updated history (current frame stored for next frame)

in vec2 vTexCoord;

/* DRAWBUFFERS:35 */
layout(location = 0) out vec4 colortex3Out; // TAA + bloom result → read by final
layout(location = 1) out vec4 colortex5Out; // History update for next frame

#include "/shaders.settings"
#include "/common/common.glsl"
#include "/utils/utils.glsl"

// All uniforms (colortex5, colortex6, gbufferPreviousProjection, etc.)
// are declared in common/common.glsl — no local re-declarations needed.

// ---------------------------------------------------------------------------
// TAA — Temporal Anti-Aliasing
// ---------------------------------------------------------------------------

// Reproject current pixel into previous frame's UV space.
// Returns vec3: xy = previous UV, z = 1.0 if valid (on-screen), 0.0 if not.
vec3 reprojectUV(vec2 uv, float depth) {
    // Reconstruct current view-space position
    vec3 viewPos   = reconstructViewPos(uv, depth);
    // Transform to player (world-relative) space
    vec3 playerPos = reconstructPlayerPos(viewPos);
    // Shift by camera delta to get previous-frame player position
    vec3 prevPlayerPos = playerPos + (previousCameraPosition - cameraPosition);
    // Project through previous frame matrices
    vec4 prevClip = gbufferPreviousProjection * gbufferPreviousModelView * vec4(prevPlayerPos, 1.0);
    prevClip.xyz /= prevClip.w;
    vec2 prevUV   = prevClip.xy * 0.5 + 0.5;
    float valid   = float(prevUV.x >= 0.0 && prevUV.x <= 1.0 &&
                          prevUV.y >= 0.0 && prevUV.y <= 1.0);
    return vec3(prevUV, valid);
}

// Neighbourhood AABB clamping — prevents ghosting by constraining the history
// sample to the colour range of the current pixel's 3×3 neighbourhood.
vec3 clampHistory(sampler2D currentTex, vec2 uv, vec3 history) {
    vec2 texelSize = vec2(1.0) / vec2(textureSize(currentTex, 0));

    vec3 minCol = vec3( 1e9);
    vec3 maxCol = vec3(-1e9);

    // Sample 3×3 neighbourhood (9 taps)
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec3 s = texture(currentTex, uv + vec2(float(x), float(y)) * texelSize).rgb;
            minCol = min(minCol, s);
            maxCol = max(maxCol, s);
        }
    }

    return clamp(history, minCol, maxCol);
}

// ---------------------------------------------------------------------------
// Bloom upsample — 4-tap Kawase upsample (reverse tent filter)
// Reconstructs a full-resolution bloom from the half-res extraction in colortex6.
// ---------------------------------------------------------------------------
vec3 kawaseUpsample(sampler2D bloomTex, vec2 uv) {
    vec2 texelSize = vec2(1.0) / vec2(textureSize(bloomTex, 0));
    float r = 1.5; // Upsample radius in texels

    vec3 result  = texture(bloomTex, uv + texelSize * vec2(-r,  0.0)).rgb;
    result      += texture(bloomTex, uv + texelSize * vec2( r,  0.0)).rgb;
    result      += texture(bloomTex, uv + texelSize * vec2( 0.0, -r)).rgb;
    result      += texture(bloomTex, uv + texelSize * vec2( 0.0,  r)).rgb;
    // Diagonal taps for a smoother circular spread
    result      += texture(bloomTex, uv + texelSize * vec2(-r, -r) * 0.7071).rgb * 0.5;
    result      += texture(bloomTex, uv + texelSize * vec2( r, -r) * 0.7071).rgb * 0.5;
    result      += texture(bloomTex, uv + texelSize * vec2(-r,  r) * 0.7071).rgb * 0.5;
    result      += texture(bloomTex, uv + texelSize * vec2( r,  r) * 0.7071).rgb * 0.5;

    // Normalise (4 cardinal + 4 diagonal * 0.5 = 6 total weight)
    return result / 6.0;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
void main() {
    vec3  currentColor = texture(colortex3, vTexCoord).rgb;
    float depth        = texture(depthtex0, vTexCoord).r;

    // -------------------------------------------------------------------------
    // 1. TAA Resolve
    // -------------------------------------------------------------------------
    vec3 resolvedColor = currentColor;

    #if TAA_TOGGLE == 1
        if (depth < 1.0) {
            // Reproject current pixel to find its location in the previous frame
            vec3  reproj   = reprojectUV(vTexCoord, depth);
            vec2  prevUV   = reproj.xy;
            float isValid  = reproj.z;

            if (isValid > 0.5) {
                vec3 history = texture(colortex5, prevUV).rgb;

                // Clamp history to the current neighbourhood to kill ghosts
                history = clampHistory(colortex3, vTexCoord, history);

                // Blend: high history weight (TAA_FEEDBACK) for strong temporal smoothing.
                // Falls back to current-only if reprojection is off-screen.
                resolvedColor = mix(currentColor, history, TAA_FEEDBACK);
            }
        }
        // Sky pixels: no reprojection, just pass through (sky moves with camera)
    #endif

    // -------------------------------------------------------------------------
    // 2. Bloom Upsample + Composite
    // -------------------------------------------------------------------------
    #if BLOOM == 1
        vec3 bloom     = kawaseUpsample(colortex6, vTexCoord);
        resolvedColor += bloom * BLOOM_STRENGTH;
    #endif

    // -------------------------------------------------------------------------
    // Write outputs
    // -------------------------------------------------------------------------
    // colortex3: final HDR ready for tone-mapping in final.fsh
    colortex3Out = vec4(resolvedColor, 1.0);

    // colortex5: store current resolved frame as next frame's history.
    // We store the TAA-resolved colour (not the raw current) so the history
    // accumulates smoothed frames rather than aliased ones.
    colortex5Out = vec4(resolvedColor, 1.0);
}
