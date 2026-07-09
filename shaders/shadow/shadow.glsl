// Abyss Shader Shadow Projection & Occlusion module

// Reconstructs coordinates in shadow map space and samples occlusion
float calculateShadows(vec3 playerPos, float nDotL) {
    vec4 shadowSpace = shadowProjection * shadowModelView * vec4(playerPos, 1.0);
    shadowSpace.xyz /= (abs(shadowSpace.w) > 0.001 ? shadowSpace.w : 1.0);
    
    // Standard linear projection coordinates
    vec3 shadowCoord = shadowSpace.xyz * 0.5 + 0.5;
    float shadowIntensity = 1.0;
    
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
            shadowIntensity = 1.0 - (shadowSum * 0.22); // Max darken by 88%
        #else
            float sampledDepth = texture(shadowtex0, shadowCoord.xy).r;
            if (shadowCoord.z - dynamicBias > sampledDepth) {
                shadowIntensity = 0.12;
            }
        #endif
    }
    
    return shadowIntensity;
}
