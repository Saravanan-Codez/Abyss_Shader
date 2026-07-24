#version 150 compatibility

// Abyss Shader — composite1: PBR Lighting & Emissive Pass
// Reads the lit HDR scene from colortex3 (written by composite), applies GGX BRDF shading
// and emissive block contribution, then writes back to colortex3.

in vec2 vTexCoord;

/* DRAWBUFFERS:3 */
layout(location = 0) out vec4 colortex3Out;

#include "/shaders.settings"
#include "/common/common.glsl"
#include "/utils/utils.glsl"
#include "/pbr.glsl"

void main() {
    // Read the current HDR lit scene produced by the composite pass
    vec4 hdrScene = texture(colortex3, vTexCoord);

    // Early-out: sky pixels (depth == 1.0) pass through unchanged — no PBR on sky
    float depth = texture(depthtex0, vTexCoord).r;
    if (depth >= 1.0) {
        colortex3Out = hdrScene;
        return;
    }

    // -------------------------------------------------------------------------
    // G-Buffer reads
    // -------------------------------------------------------------------------
    vec4  albedoSample  = texture(colortex0, vTexCoord);
    vec3  albedo        = albedoSample.rgb;

    vec3  normalEnc     = texture(colortex1, vTexCoord).rgb;
    vec3  normal        = normalize(normalEnc * 2.0 - 1.0);

    vec2  lmCoord       = texture(colortex2, vTexCoord).rg;

    vec4  emissiveData  = texture(colortex4, vTexCoord);
    float emissiveMask  = emissiveData.r;  // 0..1 emissive strength written by gbuffers

    // -------------------------------------------------------------------------
    // Reconstruct view & lighting vectors
    // -------------------------------------------------------------------------
    vec3 viewPos  = reconstructViewPos(vTexCoord, depth);
    vec3 viewDir  = normalize(-viewPos);

    // Sun direction in view space
    vec3 lightDir = normalize(sunPosition);

    // -------------------------------------------------------------------------
    // PBR Material — flat PBR baseline (no specular texture yet).
    // Metalness defaults vary by profile; rougher on low-end for performance.
    // -------------------------------------------------------------------------
    Material mat;
    mat.emissive   = emissiveMask;
    mat.height     = 0.0;
    mat.porosity   = 0.0;

    #if defined(POTATO)
        // Potato: skip PBR entirely, just copy HDR through
        colortex3Out = hdrScene;
        return;
    #elif defined(MEDIUM)
        mat.smoothness = 0.2;
        mat.roughness  = 0.8;
        mat.metalness  = 0.0;
        mat.f0         = 0.04;
    #elif defined(HIGH)
        mat.smoothness = 0.3;
        mat.roughness  = 0.7;
        mat.metalness  = 0.0;
        mat.f0         = 0.04;
    #else // ULTRA
        mat.smoothness = 0.35;
        mat.roughness  = 0.65;
        mat.metalness  = 0.0;
        mat.f0         = 0.04;
    #endif

    // -------------------------------------------------------------------------
    // Sun elevation — used to scale specular contribution like composite does
    // -------------------------------------------------------------------------
    vec3 worldSunDir = (gbufferModelViewInverse * vec4(lightDir, 0.0)).xyz;
    float sunElev    = worldSunDir.y;

    // Day/night sun color (matches composite.fsh direct color ramp)
    vec3 directColor = mix(vec3(0.1, 0.2, 0.3), vec3(1.35, 1.25, 1.1),
                           smoothstep(-0.05, 0.3, sunElev));

    // Scale specular by sky light to prevent specular leakage in caves
    float skyLight   = lmCoord.y;

    // -------------------------------------------------------------------------
    // GGX BRDF specular layer — additive on top of the Lambertian-lit HDR scene.
    // We only add the specular lobe (not a full re-light) so we don't double-count
    // the diffuse that composite already computed.
    // -------------------------------------------------------------------------
    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir),  0.0);
    vec3  H     = normalize(lightDir + viewDir);
    float NdotH = max(dot(normal, H),        0.0);
    float VdotH = max(dot(viewDir, H),        0.0);

    // GGX Normal Distribution
    float alpha  = mat.roughness * mat.roughness;
    float alpha2 = alpha * alpha;
    float NdotH2 = NdotH * NdotH;
    float D = alpha2 / max(3.14159265 * pow(NdotH2 * (alpha2 - 1.0) + 1.0, 2.0), 0.001);

    // Smith Geometry
    float k  = (mat.roughness + 1.0); k = (k * k) / 8.0;
    float Gl = NdotL / max(NdotL * (1.0 - k) + k, 0.001);
    float Gv = NdotV / max(NdotV * (1.0 - k) + k, 0.001);
    float G  = Gl * Gv;

    // Fresnel Schlick
    vec3 F0 = mix(vec3(mat.f0), albedo, mat.metalness);
    vec3 F  = F0 + (1.0 - F0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);

    // Specular lobe only (diffuse already in hdrScene)
    vec3 specular = (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);
    vec3 pbrSpecular = specular * NdotL * directColor * skyLight * (1.0 - rainStrength);

    // -------------------------------------------------------------------------
    // Emissive contribution — emissive blocks glow independently of shadows/sun
    // -------------------------------------------------------------------------
    vec3 emissiveColor = albedo * emissiveMask * EMISSIVE_BRIGHTNESS;

    // -------------------------------------------------------------------------
    // Compose final HDR color
    // -------------------------------------------------------------------------
    vec3 finalColor = hdrScene.rgb + pbrSpecular + emissiveColor;

    colortex3Out = vec4(finalColor, hdrScene.a);
}
