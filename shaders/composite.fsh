#version 150 compatibility

// Abyss Shader Core Entry Program (Deferred Pass)
// Orchestrates modular passes using include headers

#include "/common/common.glsl"
#include "/utils/utils.glsl"
#include "/sky/sky.glsl"
#include "/lighting/lighting.glsl"
#include "/shadow/shadow.glsl"
#include "/water/water.glsl"
#include "/fog/fog.glsl"

// Core deferred lighting computations

// True 3D Volumetric Light Shafts (Godrays) using Ray-Marching through the Shadow Map
vec3 calculateVolumetricLight(vec3 viewPos, float depth, vec3 directColor, float skyLight) {
    // Optimization: Skip inside caves or under heavy cover, and disable godrays completely during heavy rain or underwater
    if (skyLight < 0.05 || rainStrength > 0.9 || isEyeInWater == 1) return vec3(0.0);

    vec3 rayStart = vec3(0.0);
    vec3 rayEnd = viewPos;
    vec3 rayDir = normalize(rayEnd - rayStart);
    float rayLength = length(rayEnd - rayStart);

    // Limit maximum ray march distance to avoid sampling outside shadow map boundaries
    rayLength = min(rayLength, far * 0.75);

    int steps = 8; 
    float stepSize = rayLength / float(steps);
    vec3 stepVec = rayDir * stepSize;

    // Standard high-performance pseudo-random dither noise to completely eliminate banding/striping
    float dither = getDitherNoise(vTexCoord);
    
    // Offset the starting position by the dither factor to blur the samples smoothly
    vec3 currentPos = rayStart + stepVec * dither;
    float litVolume = 0.0;

    for (int i = 0; i < steps; i++) {
        // Project 3D view space position to Player Space, then to Shadow Space
        vec4 playerPos = gbufferModelViewInverse * vec4(currentPos, 1.0);
        vec4 shadowSpace = shadowProjection * shadowModelView * playerPos;
        
        // Safeguard division by zero
        shadowSpace.xyz /= (abs(shadowSpace.w) > 0.001 ? shadowSpace.w : 1.0);
        
        // Standard linear shadow mapping coordinates
        vec3 shadowCoord = shadowSpace.xyz * 0.5 + 0.5;

        // Check if sample coordinate falls inside the shadow projection box
        if (shadowCoord.x >= 0.0 && shadowCoord.x <= 1.0 && shadowCoord.y >= 0.0 && shadowCoord.y <= 1.0) {
            float sampledDepth = texture(shadowtex0, shadowCoord.xy).r;
            float bias = 0.005; // Tight bias for volumetric precision
            if (shadowCoord.z - bias <= sampledDepth) {
                // Smoothly fade out volumetric godrays near the shadow map edges to hide the cutoff plane!
                float edgeX = min(shadowCoord.x, 1.0 - shadowCoord.x);
                float edgeY = min(shadowCoord.y, 1.0 - shadowCoord.y);
                float edgeFade = smoothstep(0.0, 0.1, min(edgeX, edgeY));
                
                litVolume += edgeFade; 
            }
        }
        currentPos += stepVec;
    }

    float volumeFactor = litVolume / float(steps);
    
    // Scale volumetric light shafts based on sun vertical angle (sunrise/noon/sunset transitions)
    vec3 sunDir = normalize(sunPosition);
    float sunVisible = clamp(dot(sunDir, vec3(0.0, 0.0, -1.0)), 0.0, 1.0); // Check if sun is in player FOV
    
    // Fade godrays out during weather transitions (rain/snow)
    return directColor * volumeFactor * 0.04 * skyLight * sunVisible * (1.0 - rainStrength);
}

void main() {
    // Read raw normal from normal G-buffer (Material ID alpha channel is dropped, so we read it from colortex2 instead!)
    vec4 normalData = texture(colortex1, vTexCoord);
    vec3 normal = normalData.rgb * 2.0 - 1.0;
    
    // Read lightmap coordinates (rg) and material ID (b) from colortex2 to preserve it safely
    vec4 lightmapData = texture(colortex2, vTexCoord);
    vec2 lmCoord = lightmapData.rg;
    float materialID = lightmapData.b; // 1.0 for Water, 0.0 for terrain
    
    // Read combined depth (translucent + opaque)
    float depth = texture(depthtex1, vTexCoord).r;
    
    // Default sky color fallback for empty space
    if (depth >= 1.0) {
        fragColor = texture(colortex0, vTexCoord);
        return;
    }
    
    // Reconstruct 3D Position in View Space & Player Space
    vec3 viewPos = reconstructViewPos(vTexCoord, depth);
    vec3 playerPos = reconstructPlayerPos(viewPos);
    
    vec4 albedo = texture(colortex0, vTexCoord);
    
    // --- 1. ADVANCED WATER WAVE GENERATION & REAL-TIME REFRACTION ---
    vec3 waterWaveNormal = normal;
    
    if (materialID > 0.5) {
        // Calculate dynamic wave normals
        waterWaveNormal = calculateWaterWaves(playerPos, frameTimeCounter * 1.5);
        
        // Calculate wave offset for refraction (distorts underwater terrain)
        vec2 refractedCoord = applyWaterRefraction(vTexCoord, waterWaveNormal);
        
        // Sample albedo using refracted coordinates to create water wobble
        float refractedDepth = texture(depthtex1, refractedCoord).r;
        if (refractedDepth < 1.0) {
            albedo = texture(colortex0, refractedCoord);
        }
    }
    
    // --- 2. INDIRECT LIGHTING (PBR Decoupled Lightmap) ---
    vec3 lightVector = normalize(sunPosition);
    float sunElev = lightVector.y;
    
    // Directional Lighting (Lambertian)
    float nDotL = max(dot(normal, lightVector), 0.0);
    
    // Dynamic sky color matches dynamic ambient color (boosted for daylight shadow visibility)
    vec3 ambientColor = mix(vec3(0.06, 0.12, 0.25), vec3(0.55, 0.60, 0.65), smoothstep(-0.1, 0.2, sunElev));
    
    // Boosted block light color and linear falloff for better visibility
    vec3 torchColor = vec3(1.0, 0.50, 0.15) * 2.5; 
    vec3 indirectLight = torchColor * lmCoord.x + ambientColor * lmCoord.y + vec3(0.04);
    
    // Ambient / Directional colors mapping day/night cycles (boosted direct sunlight)
    vec3 directColor  = mix(vec3(0.1, 0.2, 0.3), vec3(1.35, 1.25, 1.1), smoothstep(-0.05, 0.3, sunElev));
    
    // Scale direct lighting by sky light coordinate to prevent sun leakage in caves/indoors
    float skyLight = lmCoord.y;
    float shadowIntensity = 1.0;
    
    // --- 3. 3D SHADOW PROJECTION ---
    float opaqueDepth = texture(depthtex0, vTexCoord).r;
    
    // Skip shadow tracing for sky, very distant elements, and caves with no sky light
    if (opaqueDepth < 1.0 && skyLight > 0.01) {
        vec3 viewPosO = reconstructViewPos(vTexCoord, opaqueDepth);
        vec3 playerPosO = reconstructPlayerPos(viewPosO);
        shadowIntensity = calculateShadows(playerPosO, nDotL);
    }
    
    // Apply PBR formula: direct sunlight and shadows fade out dynamically during rain
    float rainFactor = 1.0 - rainStrength;
    vec3 finalColor = albedo.rgb * (indirectLight + directColor * nDotL * skyLight * shadowIntensity * rainFactor);
    
    // --- 4. WATER SHADING (Beer's Law & Reflections & Specular Glint) ---
    if (materialID > 0.5) {
        vec3 viewDir = normalize(-viewPos);
        vec3 viewNormal = normalize((gbufferModelView * vec4(waterWaveNormal, 0.0)).xyz);
        
        // 4a. Volumetric Light Absorption (Beer's Law)
        vec3 viewPosO = reconstructViewPos(vTexCoord, opaqueDepth);
        vec3 playerPosO = reconstructPlayerPos(viewPosO);
        float waterThickness = getEuclideanDistance(viewPosO) - getEuclideanDistance(viewPos);
        finalColor = applyWaterAbsorption(finalColor, waterThickness);
        
        // 4b. Dynamic Sky Horizon Reflections
        float fresnel = pow(1.0 - max(dot(viewNormal, viewDir), 0.0), 3.0);
        vec3 reflectDir = reflect(-viewDir, viewNormal);
        vec3 reflectionColor = getSkyColor(reflectDir);
        finalColor = mix(finalColor, reflectionColor, fresnel * 0.45);
        
        // 4c. Specular Sun Shimmer (Water Glint)
        vec3 specularGlint = calculateSpecularHighlight(viewNormal, lightVector, viewDir, directColor, 128.0);
        finalColor += specularGlint * shadowIntensity * rainFactor * 0.8;
        
        // 4d. Animated Water Caustics projected onto the underwater floor
        float causticTime = frameTimeCounter * 2.0;
        float caustic1 = sin(playerPosO.x * 2.0 + causticTime) * cos(playerPosO.z * 2.0 - causticTime);
        float caustic2 = sin(playerPosO.x * 4.0 - causticTime * 1.5) * cos(playerPosO.z * 4.0 + causticTime * 1.2);
        float caustics = max(caustic1 + caustic2, 0.0) * 0.12;
        finalColor += caustics * directColor * shadowIntensity * rainFactor;
    }
    
    // --- 5. SEAMLESS HORIZON FOG (Synces dynamically with skybox color to prevent white-clipping) ---
    vec3 dynamicFogColor = mix(getSkyColor(-viewPos), fogColor, rainStrength);
    finalColor = applyDistanceFog(finalColor, viewPos, dynamicFogColor);
    
    // --- 6. 3D VOLUMETRIC LIGHT SHAFT INJECTION (GODRAYS) ---
    finalColor += calculateVolumetricLight(viewPos, depth, directColor, skyLight);
    
    fragColor = vec4(finalColor, albedo.a);
}
