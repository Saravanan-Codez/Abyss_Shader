#version 150 compatibility

// Abyss Shader — composite2: SSAO + Bloom Extraction Pass
//
// Two independent jobs in one pass to avoid an extra full-screen blit:
//   1. SSAO  — hemisphere sampling in view space, result written to colortex4.g
//              (replaces the AO=1.0 placeholder that gbuffers wrote)
//   2. Bloom extraction — luminance-threshold Kawase 13-tap downsample into colortex6
//
// Outputs:
//   colortex3  — HDR scene with AO applied to the ambient component
//   colortex4  — updated emissive/AO buffer (r=emissive, g=AO)
//   colortex6  — bloom extraction (bright pixels only, half-res Kawase)

in vec2 vTexCoord;

/* DRAWBUFFERS:346 */
layout(location = 0) out vec4 colortex3Out;
layout(location = 1) out vec4 colortex4Out;
layout(location = 2) out vec4 colortex6Out;

#include "/shaders.settings"
#include "/common/common.glsl"
#include "/utils/utils.glsl"

// ---------------------------------------------------------------------------
// SSAO
// ---------------------------------------------------------------------------

// A small but well-distributed hemisphere kernel (up to 16 taps).
// We keep all 16 declared and dynamically limit iteration count via SSAO_SAMPLES.
// The kernel is in tangent space (+Z = surface normal direction).
// All Z components are positive — tangent-space Z is the surface normal direction,
// so negative Z would sample below the surface and never contribute correctly.
const vec3 SSAO_KERNEL[16] = vec3[](
    vec3( 0.5381,  0.1856,  0.1413),
    vec3( 0.1379,  0.2486,  0.4430),
    vec3( 0.3371,  0.5679,  0.0381),
    vec3(-0.6999, -0.0451,  0.0832),
    vec3( 0.0689, -0.1598,  0.8547),
    vec3( 0.0560,  0.0069,  0.1843),
    vec3(-0.0146,  0.1402,  0.0762),
    vec3( 0.0100, -0.1924,  0.0862),
    vec3(-0.3577, -0.5301,  0.4358),
    vec3(-0.3169,  0.1063,  0.0891),
    vec3( 0.0103, -0.5869,  0.1246),
    vec3(-0.0897, -0.4940,  0.3287),
    vec3( 0.7119, -0.0154,  0.0918),
    vec3(-0.0533,  0.0596,  0.5411),
    vec3( 0.0352, -0.0631,  0.5460),
    vec3(-0.4776,  0.2847,  0.0725)
);

// SSAO radius in view-space units (blocks). Kept intentionally small so it looks
// like contact shadow rather than a halo.
const float SSAO_RADIUS = 0.5;
// Depth-range check: if sample depth differs by more than this, consider it
// a background surface and don't count it as occluder (prevents halo on silhouettes).
const float SSAO_RANGE_CHECK = 1.5;

float calculateSSAO(vec3 viewPos, vec3 normal) {
    // Build a TBN matrix to rotate the kernel into view-space surface orientation.
    vec3 up      = abs(normal.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, normal));
    vec3 bitan   = cross(normal, tangent);
    mat3 TBN     = mat3(tangent, bitan, normal);

    // Pseudo-random rotation angle per pixel to break up the kernel pattern.
    float angle = getDitherNoise(vTexCoord) * 6.28318530718;
    float cosA  = cos(angle);
    float sinA  = sin(angle);

    float occlusion = 0.0;

    for (int i = 0; i < SSAO_SAMPLES; i++) {
        // Rotate kernel sample around Z by random angle to reduce banding
        vec3 kernelSample = SSAO_KERNEL[i];
        kernelSample.xy   = vec2(
            cosA * kernelSample.x - sinA * kernelSample.y,
            sinA * kernelSample.x + cosA * kernelSample.y
        );

        // Transform kernel from tangent space to view space
        vec3 samplePos = viewPos + TBN * kernelSample * SSAO_RADIUS;

        // Project sample to screen space to read its depth
        vec4 offset = gbufferProjection * vec4(samplePos, 1.0);
        offset.xy  /= offset.w;
        offset.xy   = offset.xy * 0.5 + 0.5;

        // Bounds check — skip samples that project off-screen
        if (offset.x < 0.0 || offset.x > 1.0 || offset.y < 0.0 || offset.y > 1.0) continue;

        // Read the actual geometry depth at the projected UV
        float sampleDepth = texture(depthtex0, offset.xy).r;
        vec3  sampleView  = reconstructViewPos(offset.xy, sampleDepth);

        // Range check: don't let distant geometry occlude nearby surfaces
        float rangeCheck = smoothstep(0.0, 1.0, SSAO_RANGE_CHECK / max(abs(viewPos.z - sampleView.z), 0.001));

        if (sampleView.z >= samplePos.z + 0.025) {
            occlusion += rangeCheck;
        }
    }

    // Return normalised AO factor: 1.0 = fully unoccluded, 0.0 = fully occluded
    return clamp(1.0 - (occlusion / float(SSAO_SAMPLES)), 0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Bloom extraction — 13-tap Kawase downsample
// Operates on the HDR scene. Only pixels brighter than BLOOM_THRESHOLD contribute.
// ---------------------------------------------------------------------------

vec3 kawaseDownsample(sampler2D tex, vec2 uv, vec2 texelSize) {
    // 13-tap tent filter (used in Unity's post-stack bloom)
    // Centre-quad weight = 4, corner-quads weight = 1 each, edge-quads weight = 2 each
    vec3 a = texture(tex, uv + texelSize * vec2(-1.0, -1.0)).rgb;
    vec3 b = texture(tex, uv + texelSize * vec2( 0.0, -1.0)).rgb;
    vec3 c = texture(tex, uv + texelSize * vec2( 1.0, -1.0)).rgb;
    vec3 d = texture(tex, uv + texelSize * vec2(-0.5, -0.5)).rgb;
    vec3 e = texture(tex, uv + texelSize * vec2( 0.5, -0.5)).rgb;
    vec3 f = texture(tex, uv + texelSize * vec2(-1.0,  0.0)).rgb;
    vec3 g = texture(tex, uv                               ).rgb;
    vec3 h = texture(tex, uv + texelSize * vec2( 1.0,  0.0)).rgb;
    vec3 i = texture(tex, uv + texelSize * vec2(-0.5,  0.5)).rgb;
    vec3 j = texture(tex, uv + texelSize * vec2( 0.5,  0.5)).rgb;
    vec3 k = texture(tex, uv + texelSize * vec2(-1.0,  1.0)).rgb;
    vec3 l = texture(tex, uv + texelSize * vec2( 0.0,  1.0)).rgb;
    vec3 m = texture(tex, uv + texelSize * vec2( 1.0,  1.0)).rgb;

    // Weighted average: 0.5 for the 4 inner quads, 0.125 for the 4 corner taps,
    // 0.125 for the 4 edge-centre taps.
    vec3 result = g * 0.125;
    result += (d + e + i + j) * 0.125;
    result += (a + c + k + m) * 0.03125;
    result += (b + f + h + l) * 0.0625;
    return result;
}

void main() {
    vec4  hdrScene = texture(colortex3, vTexCoord);
    float depth    = texture(depthtex0, vTexCoord).r;

    // -------------------------------------------------------------------------
    // 1. SSAO
    // -------------------------------------------------------------------------
    float ao = 1.0; // Default: fully unoccluded

    #if SSAO_SAMPLES > 0
        if (depth < 1.0) { // Skip SSAO on sky pixels
            vec3 normalEnc = texture(colortex1, vTexCoord).rgb;
            vec3 normal    = normalize(normalEnc * 2.0 - 1.0);
            vec3 viewPos   = reconstructViewPos(vTexCoord, depth);
            ao = calculateSSAO(viewPos, normal);
        }
    #endif

    // Apply AO — multiply only the indirect (ambient) portion by the AO factor.
    // AO_STRENGTH controls the blend: 0 = no darkening, 1 = full AO darkening.
    // We avoid darkening emissive pixels by reading the emissive mask.
    float emissiveMask = texture(colortex4, vTexCoord).r;
    float aoApply = mix(1.0, ao, AO_STRENGTH) + emissiveMask * (1.0 - mix(1.0, ao, AO_STRENGTH));
    vec3 finalHDR = hdrScene.rgb * aoApply;

    // -------------------------------------------------------------------------
    // 2. Bloom extraction
    // -------------------------------------------------------------------------
    vec3 bloomOut = vec3(0.0);

    #if BLOOM == 1
        // Texel size for the source buffer (full resolution → half-res downsample)
        vec2 texelSize = vec2(1.0) / vec2(textureSize(colortex3, 0));

        vec3 downsampled = kawaseDownsample(colortex3, vTexCoord, texelSize);

        // Isolate bright pixels above the luminance threshold.
        // Using a soft knee (quadratic) around the threshold for smooth falloff.
        float luma     = dot(downsampled, vec3(0.2126, 0.7152, 0.0722));
        float knee     = BLOOM_THRESHOLD * 0.5;
        float soft     = clamp(luma - BLOOM_THRESHOLD + knee, 0.0, 2.0 * knee);
        soft           = (soft * soft) / max(4.0 * knee, 0.0001);
        float contrib  = max(soft, luma - BLOOM_THRESHOLD) / max(luma, 0.0001);
        bloomOut       = downsampled * contrib;
    #endif

    // Update colortex4: preserve emissive (r), write AO factor (g)
    colortex4Out = vec4(emissiveMask, ao, 0.0, 1.0);

    colortex3Out = vec4(finalHDR, hdrScene.a);
    colortex6Out = vec4(bloomOut, 1.0);
}
