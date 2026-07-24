#version 150 compatibility
#include "/shaders.settings"

in vec3 vPos;

uniform vec3 sunPosition;
uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;
layout(location = 3) out vec4 colortex4; // sky pixels: zero emissive, AO irrelevant

// ---------------------------------------------------------------------------
// Noise helpers
// ---------------------------------------------------------------------------

// Classic value noise hash (2D → float)
float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

// Smooth value noise (bilinear interpolation)
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f); // smoothstep curve
    return mix(mix(hash21(i + vec2(0,0)), hash21(i + vec2(1,0)), u.x),
               mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), u.x), u.y);
}

// FBM — fractional Brownian motion (octave stacking)
float fbm(vec2 p, int octaves) {
    float v = 0.0, amp = 0.5, freq = 1.0;
    for (int i = 0; i < octaves; i++) {
        v    += amp * valueNoise(p * freq);
        amp  *= 0.5;
        freq *= 2.0;
    }
    return v;
}

// ---------------------------------------------------------------------------
// Sky gradient
// ---------------------------------------------------------------------------
vec3 getSkyGradient(vec3 viewDir, vec3 sunDir) {
    float sunElev  = sunDir.y;
    float viewElev = viewDir.y;

    vec3 daySkyTop  = vec3(0.10, 0.40, 0.80);
    vec3 daySkyBot  = vec3(0.50, 0.70, 0.90);
    vec3 sunsetTop  = vec3(0.10, 0.20, 0.40);
    vec3 sunsetBot  = vec3(0.80, 0.40, 0.10);
    vec3 nightTop   = vec3(0.00, 0.00, 0.02);
    vec3 nightBot   = vec3(0.02, 0.05, 0.10);

    float dayF    = smoothstep(-0.05, 0.20, sunElev);
    float sunsetF = smoothstep(-0.10, 0.10, sunElev) * (1.0 - smoothstep(0.10, 0.30, sunElev));

    vec3 topColor = mix(nightTop, daySkyTop, dayF);
    topColor = mix(topColor, sunsetTop, sunsetF);

    vec3 botColor = mix(nightBot, daySkyBot, dayF);
    botColor = mix(botColor, sunsetBot, sunsetF);

    float gradient = smoothstep(0.0, 0.6, max(viewElev, 0.0));
    return mix(botColor, topColor, gradient);
}

// ---------------------------------------------------------------------------
// Sun disc + corona
// ---------------------------------------------------------------------------
vec3 drawSunDisc(vec3 viewDir, vec3 sunDir, float sunElev) {
    if (sunElev < -0.05) return vec3(0.0);

    float cosAngle = dot(viewDir, sunDir);

    // Sharp disc core
    float disc    = smoothstep(0.9997, 0.99985, cosAngle);
    // Soft corona halo — wider falloff, dimmer
    float corona  = smoothstep(0.994, 0.9997, cosAngle) * 0.35;

    // Sun colour shifts from white at noon to orange/red near horizon
    vec3 sunColor = mix(vec3(1.0, 0.55, 0.15), vec3(1.4, 1.3, 1.1),
                        smoothstep(0.0, 0.25, sunElev));

    return sunColor * (disc + corona) * smoothstep(-0.05, 0.05, sunElev);
}

// ---------------------------------------------------------------------------
// Moon disc (opposite direction of sun, cool white)
// ---------------------------------------------------------------------------
vec3 drawMoonDisc(vec3 viewDir, vec3 sunDir, float sunElev) {
    if (sunElev > 0.05) return vec3(0.0);

    vec3  moonDir  = -sunDir;
    float cosAngle = dot(viewDir, moonDir);

    float disc   = smoothstep(0.9995, 0.9998, cosAngle);
    float corona = smoothstep(0.997, 0.9995, cosAngle) * 0.15;

    vec3 moonColor = vec3(0.85, 0.90, 1.0);
    return moonColor * (disc + corona) * smoothstep(0.05, -0.05, sunElev);
}

// ---------------------------------------------------------------------------
// Stars — point hash field that fades in at night
// ---------------------------------------------------------------------------
vec3 drawStars(vec3 viewDir, float sunElev) {
    // Stars only visible when sun is below horizon
    float starVis = smoothstep(0.05, -0.10, sunElev);
    if (starVis < 0.001) return vec3(0.0);

    // Map view direction to a 2D grid for stable star placement.
    // Using a spherical UV that doesn't alias at poles for cardinal directions.
    vec2 starUV = vec2(
        atan(viewDir.x, viewDir.z) * (1.0 / 6.28318),
        viewDir.y
    ) * vec2(200.0, 100.0);

    vec2  cell    = floor(starUV);
    vec2  cellUV  = fract(starUV) - 0.5;

    // Each cell gets one star at a pseudo-random position within it
    float rng     = hash21(cell);
    float rng2    = hash21(cell + 17.3);
    vec2  starPos = (vec2(rng, rng2) - 0.5) * 0.8;

    // Distance from this pixel to the star centre
    float dist    = length(cellUV - starPos);

    // Only keep the brightest ~25% of cells as visible stars
    float visible = step(0.75, rng);

    // Tight point with a slight twinkle using frameTimeCounter
    float twinkle = 0.8 + 0.2 * sin(frameTimeCounter * 3.0 + rng * 6.28318);
    float star    = visible * twinkle * smoothstep(0.08, 0.0, dist);

    // Stars are blue-white with slight colour variation
    vec3 starColor = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.9, 0.75), rng);

    return starColor * star * starVis * 0.9;
}

// ---------------------------------------------------------------------------
// Procedural clouds (skipped entirely on POTATO)
// ---------------------------------------------------------------------------
#if !defined(POTATO)

vec4 drawClouds(vec3 viewDir, vec3 sunDir, float sunElev) {
    // Only render clouds in the upper hemisphere
    if (viewDir.y < 0.02) return vec4(0.0);

    // Cloud FBM octave count determined at compile-time by profile tier
    int cloudOctaves = 1; // MEDIUM default
    #if defined(ULTRA)
        cloudOctaves = 3;
    #elif defined(HIGH)
        cloudOctaves = 2;
    #endif

    // Cloud layer is a virtual flat plane at a normalised height.
    // We project the view ray onto that plane using Y component.
    float planeDist = 1.0 / max(viewDir.y, 0.02);
    vec2  cloudUV   = viewDir.xz * planeDist;

    // Animate clouds drifting in the wind
    float time     = frameTimeCounter * CLOUD_SPEED * 0.05;
    cloudUV       += vec2(time, time * 0.4);

    // Scale UVs to control cloud size
    cloudUV *= 0.6;

    float density  = fbm(cloudUV, cloudOctaves);

    // Remap density to a coverage-controlled binary-ish shape
    float coverage = smoothstep(1.0 - CLOUD_COVERAGE, 1.0, density);
    if (coverage < 0.01) return vec4(0.0);

    // Lighting: cloud top is lit by sun, underside is darker
    vec3 upVec     = vec3(0.0, 1.0, 0.0);
    float sunLight = max(dot(upVec, sunDir), 0.0);

    // Day/sunset/night cloud colours
    vec3 cloudLit  = mix(vec3(0.85, 0.50, 0.25),  // sunset lit
                         vec3(1.00, 1.00, 1.00),   // day lit
                         smoothstep(0.0, 0.3, sunElev));
    vec3 cloudDark = mix(vec3(0.10, 0.12, 0.20),  // night dark
                         vec3(0.55, 0.58, 0.65),   // day shadow
                         smoothstep(-0.1, 0.2, sunElev));

    // Blend lit and shadow based on sun angle
    float litFactor = clamp(sunLight * 2.0 + 0.3, 0.0, 1.0);
    vec3  cloudColor = mix(cloudDark, cloudLit, litFactor);

    // Fade clouds out near the horizon to hide the sharp clip
    float horizonFade = smoothstep(0.02, 0.15, viewDir.y);

    float alpha = coverage * horizonFade * 0.92;
    return vec4(cloudColor, alpha);
}

#endif // !POTATO

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
void main() {
    // Transform from view space to world space (rotation only, no translation)
    vec3 worldViewDir = normalize((gbufferModelViewInverse * vec4(vPos, 0.0)).xyz);
    vec3 worldSunDir  = normalize((gbufferModelViewInverse * vec4(normalize(sunPosition), 0.0)).xyz);

    float sunElev = worldSunDir.y;

    // 1. Base sky gradient
    vec3 skyColor = getSkyGradient(worldViewDir, worldSunDir);

    // 2. Stars (drawn before sun so the disc overwrites them)
    skyColor += drawStars(worldViewDir, sunElev);

    // 3. Sun disc
    skyColor += drawSunDisc(worldViewDir, worldSunDir, sunElev);

    // 4. Moon disc
    skyColor += drawMoonDisc(worldViewDir, worldSunDir, sunElev);

    // 5. Procedural clouds (not on Potato)
    #if !defined(POTATO)
        vec4 clouds = drawClouds(worldViewDir, worldSunDir, sunElev);
        skyColor    = mix(skyColor, clouds.rgb, clouds.a);
    #endif

    // Output to G-Buffers (no normal or lightmap data for sky)
    colortex0 = vec4(skyColor, 1.0);
    colortex1 = vec4(0.0);
    colortex2 = vec4(0.0);
    colortex4 = vec4(0.0, 1.0, 0.0, 1.0); // sky: no emissive, AO unused
}
