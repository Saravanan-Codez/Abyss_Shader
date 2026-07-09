#version 150 compatibility

in vec2 vTexCoord;

uniform sampler2D colortex0; // Albedo
uniform sampler2D colortex1; // Normal (rgb) and Material ID (a)
uniform sampler2D colortex2; // Lightmap UVs (rg)
uniform sampler2D depthtex0; // Opaque Depth
uniform sampler2D depthtex1; // Translucent Depth
uniform sampler2D shadowtex0; // Shadow Map

uniform sampler2D lightmap;

uniform vec3 sunPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView; // For fresnel vector

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 fragColor;

void main() {
    // Read raw data from G-Buffers
    vec4 albedo = texture(colortex0, vTexCoord);
    vec4 normalData = texture(colortex1, vTexCoord);
    vec3 normal = normalData.rgb * 2.0 - 1.0;
    float materialID = normalData.a; // 1.0 for Water, 0.0 for terrain
    
    vec2 lmCoord = texture(colortex2, vTexCoord).rg;
    
    // Read the combined depth (water + terrain)
    float depth = texture(depthtex1, vTexCoord).r;
    
    // Default sky color fallback for empty space
    if (depth >= 1.0) {
        fragColor = albedo;
        return;
    }
    
    // --- 1. LIGHTMAP & ATMOSPHERICS (PBR) ---
    vec3 lightVector = normalize(sunPosition);
    float sunElev = lightVector.y;
    
    // Directional Lighting (Lambertian)
    float nDotL = max(dot(normal, lightVector), 0.0);
    
    vec4 light = texture(lightmap, lmCoord);
    
    // Ambient / Directional Colors based on time of day
    vec3 ambientColor = mix(vec3(0.05, 0.1, 0.2), vec3(0.2, 0.3, 0.4), smoothstep(-0.1, 0.2, sunElev));
    vec3 directColor  = mix(vec3(0.1, 0.2, 0.3), vec3(1.2, 1.1, 0.9), smoothstep(-0.05, 0.3, sunElev));
    
    // Scale direct sunlight by the sky light coordinate (lmCoord.y) to prevent sun lighting in caves!
    float skyLight = lmCoord.y;
    float shadowIntensity = 1.0;
    
    // --- 2. 3D SHADOW PROJECTION ---
    float opaqueDepth = texture(depthtex0, vTexCoord).r;
    
    // OPTIMIZATION: Skip shadow map tracing for sky, very distant objects, and caves/rooms with no sky exposure!
    if (opaqueDepth < 1.0 && skyLight > 0.01) {
        vec4 ndcPos = vec4(vTexCoord.x * 2.0 - 1.0, vTexCoord.y * 2.0 - 1.0, opaqueDepth * 2.0 - 1.0, 1.0);
        vec4 viewPos = gbufferProjectionInverse * ndcPos;
        viewPos /= viewPos.w;
        vec4 playerPos = gbufferModelViewInverse * viewPos;
        
        vec4 shadowSpace = shadowProjection * shadowModelView * playerPos;
        shadowSpace.xyz /= (abs(shadowSpace.w) > 0.001 ? shadowSpace.w : 1.0); // Safe division to prevent division-by-zero NaN!
        vec3 shadowCoord = shadowSpace.xyz * 0.5 + 0.5;
        
        // Only sample if the coordinates lie inside the sun's orthographic projection box bounds
        if (shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0) {
            float cosTheta = clamp(nDotL, 0.001, 1.0);
            float dynamicBias = clamp(0.001 * (sqrt(max(1.0 - cosTheta * cosTheta, 0.0)) / cosTheta), 0.001, 0.01); 
            
            #if SHADOW_BLUR == 1
                float mapSize = 1.0 / 2048.0;
                float shadowSum = 0.0;
                vec2 offsets[4] = vec2[](
                    vec2(-1.0, -1.0), vec2( 1.0, -1.0),
                    vec2(-1.0,  1.0), vec2( 1.0,  1.0)
                );
                for(int i = 0; i < 4; i++) {
                    float sampledDepth = texture(shadowtex0, shadowCoord.xy + offsets[i] * mapSize).r;
                    if(shadowCoord.z - dynamicBias > sampledDepth) {
                        shadowSum += 1.0;
                    }
                }
                shadowIntensity = 1.0 - (shadowSum * 0.22); // Max darken direct light by 88%
            #else
                float sampledDepth = texture(shadowtex0, shadowCoord.xy).r;
                if (shadowCoord.z - dynamicBias > sampledDepth) {
                    shadowIntensity = 0.12; // Max darken direct light by 88%
                }
            #endif
        }
    }
    
    // Apply PBR formula: shadows ONLY affect direct sunlight, leaving ambient light/torches untouched!
    // This permanently prevents crushed blacks.
    vec3 finalColor = albedo.rgb * (ambientColor * light.rgb + directColor * nDotL * skyLight * shadowIntensity);
    
    // --- 3. WATER FRESNEL ---
    // Check if the current pixel is water (Material ID == 1.0)
    if (materialID > 0.5) {
        // Reconstruct view vector for Fresnel
        vec4 ndcPosW = vec4(vTexCoord.x * 2.0 - 1.0, vTexCoord.y * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
        vec4 viewPosW = gbufferProjectionInverse * ndcPosW;
        viewPosW /= viewPosW.w; // ADDED: Fix perspective division for correct view direction!
        vec3 viewDir = normalize(-viewPosW.xyz);
        
        // Transform normal to view space
        vec3 viewNormal = normalize((gbufferModelView * vec4(normal, 0.0)).xyz);
        
        float fresnel = pow(1.0 - max(dot(viewNormal, viewDir), 0.0), 3.0);
        finalColor = mix(finalColor, vec3(0.3, 0.6, 0.9), fresnel * 0.5);
    }
    
    fragColor = vec4(finalColor, albedo.a);
}
