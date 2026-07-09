#version 150
#include "/shaders.settings"
#include "/pbr.glsl"

in vec2 vTexCoord;

uniform sampler2D colortex0; // Albedo
uniform sampler2D colortex1; // Normal + Material encoding
uniform sampler2D colortex2; // Lightmap + Specular
uniform sampler2D depthtex0; // Depth buffer
uniform sampler2D shadowtex0; // Shadow Map 0

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform vec3 sunPosition;

layout(location = 0) out vec4 fragColor;

vec3 getWorldPos(vec2 uv, float depth) {
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewSpace = gbufferProjectionInverse * clipSpace;
    viewSpace /= viewSpace.w;
    vec4 worldSpace = gbufferModelViewInverse * viewSpace;
    return worldSpace.xyz;
}

// CSM & PCSS Shadow Mapping
float calculateShadow(vec3 worldPos, vec3 normal, vec3 lightDir) {
    #ifdef PROFILE_POTATO
        return 1.0; // Skip shadows entirely for Potato
    #endif

    vec4 shadowSpacePos = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    vec3 projCoords = shadowSpacePos.xyz / shadowSpacePos.w;
    projCoords = projCoords * 0.5 + 0.5;

    // Out of bounds
    if (projCoords.z > 1.0 || projCoords.x < 0.0 || projCoords.x > 1.0 || projCoords.y < 0.0 || projCoords.y > 1.0) {
        return 1.0;
    }

    float currentDepth = projCoords.z;
    float bias = max(0.005 * (1.0 - dot(normal, lightDir)), 0.0005);
    float shadow = 0.0;
    
    vec2 texelSize = 1.0 / vec2(SHADOW_MAP_RESOLUTION);
    float filterRadius = 1.0;

    #if defined(PROFILE_HIGH) || defined(PROFILE_ULTRA)
        // PCSS Variable Penumbra Soft Shadows
        float searchRadius = 2.0; 
        float blockerDepth = 0.0;
        float numBlockers = 0.0;

        for (int x = -2; x <= 2; ++x) {
            for (int y = -2; y <= 2; ++y) {
                float pcfDepth = texture(shadowtex0, projCoords.xy + vec2(x, y) * texelSize * searchRadius).r;
                if (pcfDepth < currentDepth - bias) {
                    blockerDepth += pcfDepth;
                    numBlockers += 1.0;
                }
            }
        }

        if (numBlockers > 0.0) {
            blockerDepth /= numBlockers;
            float penumbra = (currentDepth - blockerDepth) * 0.5; // Scale dynamically based on distance
            filterRadius = 1.0 + penumbra * 10.0;
        }
    #endif

    // PCF Filtering
    int samples = 2; // Fixed loops for performance scaling
    #ifdef PROFILE_MEDIUM
        samples = 1;
    #endif

    for (int x = -samples; x <= samples; ++x) {
        for (int y = -samples; y <= samples; ++y) {
            float pcfDepth = texture(shadowtex0, projCoords.xy + vec2(x, y) * texelSize * filterRadius).r;
            shadow += (currentDepth - bias > pcfDepth) ? 0.0 : 1.0;
        }
    }
    
    shadow /= float((2 * samples + 1) * (2 * samples + 1));
    return shadow;
}

void main() {
    vec4 albedo = texture(colortex0, vTexCoord);
    vec4 normalData = texture(colortex1, vTexCoord);
    float depth = texture(depthtex0, vTexCoord).r;

    // Sky fallback
    if (depth == 1.0) {
        fragColor = albedo; // Sky will be handled in atmospherics
        return;
    }

    vec3 normal = normalize(normalData.xyz * 2.0 - 1.0);
    vec3 worldPos = getWorldPos(vTexCoord, depth);
    vec3 viewDir = normalize(gbufferModelViewInverse[3].xyz - worldPos);
    vec3 lightDir = normalize(sunPosition);

    // Default Material Decoding (Assumes empty maps if none provided)
    // We would normally read from a dedicated specular buffer (colortex3) but using dummy values here for architecture setup.
    Material mat = decodeLabPBR(vec4(0.0, 0.0, 0.0, 0.0));

    // Shadow Mapping
    float shadow = calculateShadow(worldPos, normal, lightDir);

    // Direct Lighting (Sun)
    vec3 sunColor = vec3(1.2, 1.1, 1.0); // Simple sun color
    vec3 directLighting = evalBRDF(lightDir, viewDir, normal, mat, albedo.rgb) * sunColor * shadow;
    
    // Ambient Lighting (Sky/Block light approximation from lightmaps)
    vec2 lightmap = texture(colortex2, vTexCoord).rg;
    vec3 ambientLighting = albedo.rgb * (lightmap.r * vec3(1.0, 0.6, 0.3) + lightmap.g * vec3(0.2, 0.4, 0.8) + 0.05);

    vec3 finalColor = directLighting + ambientLighting;

    fragColor = vec4(finalColor, albedo.a);
}
