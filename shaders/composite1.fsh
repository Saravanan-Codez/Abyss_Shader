#version 150 compatibility
#include "/shaders.settings"
#include "/pbr.glsl"

in vec2 vTexCoord;

uniform sampler2D colortex0; // Base Scene Color
uniform sampler2D colortex1; // Normal + Material
uniform sampler2D depthtex0; // Depth buffer
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

layout(location = 0) out vec4 fragColor;

vec3 getViewPos(vec2 uv, float depth) {
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewSpace = gbufferProjectionInverse * clipSpace;
    return viewSpace.xyz / viewSpace.w;
}

#if defined(PROFILE_HIGH) || defined(PROFILE_ULTRA)
// Linear/Hierarchical Z-trace Raymarching Engine for SSR/SSGI
vec3 raymarch(vec3 viewPos, vec3 viewDir, vec3 normal, float roughness) {
    vec3 reflectionDir = reflect(viewDir, normal);
    
    // Adaptive step size based on performance profile
    int maxSteps = 30;
    #ifdef PROFILE_ULTRA
        maxSteps = 60;
    #endif

    float stepSize = 0.05 + roughness * 0.1; // Rougher surfaces blur ray steps
    vec3 currentPos = viewPos;
    
    for (int i = 0; i < maxSteps; i++) {
        currentPos += reflectionDir * stepSize;
        
        vec4 projectedCoord = gbufferProjection * vec4(currentPos, 1.0);
        projectedCoord.xy /= projectedCoord.w;
        vec2 screenCoord = projectedCoord.xy * 0.5 + 0.5;

        // Out of bounds
        if (screenCoord.x < 0.0 || screenCoord.x > 1.0 || screenCoord.y < 0.0 || screenCoord.y > 1.0) {
            break;
        }

        float depthMapValue = texture(depthtex0, screenCoord).r;
        vec3 sampledViewPos = getViewPos(screenCoord, depthMapValue);

        // Intersection bounds check
        if (currentPos.z < sampledViewPos.z && currentPos.z > sampledViewPos.z - 0.5) {
            return texture(colortex0, screenCoord).rgb; // Hit geometry
        }
        
        // Increase step size exponentially for distant checks
        stepSize *= 1.1; 
    }
    
    return vec3(0.0);
}

// Spatio-Temporal Variance Guided Filter (SVGF) Simplified Spatial Pass
vec3 spatialFilter(vec2 uv, vec3 baseColor, float depth) {
    vec3 colorSum = vec3(0.0);
    float weightSum = 0.0;
    vec2 texelSize = 1.0 / vec2(textureSize(colortex0, 0));

    // 3x3 Gaussian-like blur guided by depth to preserve geometric edges
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(x, y) * texelSize;
            float sampleDepth = texture(depthtex0, uv + offset).r;
            vec3 sampleColor = texture(colortex0, uv + offset).rgb;

            // Edge preserving weight based on depth discontinuity
            float w = exp(-abs(depth - sampleDepth) * 1000.0);
            colorSum += sampleColor * w;
            weightSum += w;
        }
    }
    return colorSum / max(weightSum, 0.001);
}
#endif

void main() {
    vec3 color = texture(colortex0, vTexCoord).rgb;
    
    #if defined(PROFILE_HIGH) || defined(PROFILE_ULTRA)
        float depth = texture(depthtex0, vTexCoord).r;
        
        if (depth < 1.0) { // Only process geometry, skip sky
            vec3 viewPos = getViewPos(vTexCoord, depth);
            vec3 viewDir = normalize(viewPos);
            vec4 normalData = texture(colortex1, vTexCoord);
            vec3 normal = normalize(normalData.xyz * 2.0 - 1.0);
            
            // Extract material roughness from LabPBR encoding (Placeholder usage)
            Material mat = decodeLabPBR(vec4(0.2, 0.5, 0.0, 0.0)); // Dummy PBR properties

            // Only compute SSR for somewhat smooth surfaces
            if (mat.roughness < 0.8) {
                vec3 reflection = raymarch(viewPos, viewDir, normal, mat.roughness);
                
                // Microfacet GGX Fresnel Blend
                float NdotV = max(dot(normal, -viewDir), 0.0);
                float fresnel = pow(1.0 - NdotV, 5.0) * (1.0 - mat.roughness); // Stronger at grazing angles
                
                // Composite SSR
                vec3 rawComposite = mix(color, reflection, fresnel);
                
                // Denoise stochastic rays using SVGF spatial filter
                color = spatialFilter(vTexCoord, rawComposite, depth);
            }
        }
    #endif

    fragColor = vec4(color, 1.0);
}
