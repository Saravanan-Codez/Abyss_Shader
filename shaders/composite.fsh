#version 150 compatibility

in vec2 vTexCoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0; // Opaque shadow depth

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#define SHADOW_BLUR_ON

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 fragColor;

void main() {
    vec4 color = texture(colortex0, vTexCoord);
    float depth = texture(depthtex0, vTexCoord).r;

    // Do not calculate shadows for the sky
    if (depth < 1.0) {
        // 1. Convert Screen Space to Normalized Device Coordinates (NDC)
        vec4 ndcPos = vec4(vTexCoord.x * 2.0 - 1.0, vTexCoord.y * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
        
        // 2. Reconstruct View Space
        vec4 viewPos = gbufferProjectionInverse * ndcPos;
        viewPos /= viewPos.w;
        
        // 3. Reconstruct Player Space
        vec4 playerPos = gbufferModelViewInverse * viewPos;
        
        // 4. Transform to Shadow Space
        vec4 shadowSpace = shadowProjection * shadowModelView * playerPos;
        
        // 5. Convert Shadow NDC to Texture Coordinates [0, 1]
        vec3 shadowCoord = shadowSpace.xyz * 0.5 + 0.5;
        
        // 6. Occlusion Test with optional PCF Blur
        float shadowIntensity = 1.0;
        float bias = 0.001; 
        
        #ifdef SHADOW_BLUR_ON
            // 4-tap PCF blur to soften jagged shadow edges
            float mapSize = 1.0 / 2048.0; // Assume 2048 shadow map resolution
            float shadowSum = 0.0;
            
            vec2 offsets[4] = vec2[](
                vec2(-1.0, -1.0), vec2( 1.0, -1.0),
                vec2(-1.0,  1.0), vec2( 1.0,  1.0)
            );
            
            for(int i = 0; i < 4; i++) {
                float sampledDepth = texture(shadowtex0, shadowCoord.xy + offsets[i] * mapSize).r;
                if(shadowCoord.z - bias > sampledDepth) {
                    shadowSum += 1.0; // Pixel is occluded
                }
            }
            shadowIntensity = 1.0 - (shadowSum * 0.125); // Max darken by 50%
        #else
            float sampledDepth = texture(shadowtex0, shadowCoord.xy).r;
            if (shadowCoord.z - bias > sampledDepth) {
                shadowIntensity = 0.5; // Binary hard shadow
            }
        #endif
        
        color.rgb *= shadowIntensity;
    }

    fragColor = color;
}
