#version 150 compatibility

// Abyss Shader Core Entry Program (Deferred Pass)
// Orchestrates modular passes using include headers

in vec2 vTexCoord;

/* DRAWBUFFERS:03 */
layout(location = 0) out vec4 fragColor;   // colortex0: preserved albedo (sky fallback path)
layout(location = 1) out vec4 colortex3Out; // colortex3: HDR lit scene output

#include "/shaders.settings"
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

    #if GODRAY_STEPS == 0
        return vec3(0.0);
    #endif

    vec3 rayStart = vec3(0.0);
    vec3 rayEnd = viewPos;
    vec3 rayDir = normalize(rayEnd - rayStart);
    float rayLength = length(rayEnd - rayStart);

    // Limit maximum ray march distance to avoid sampling outside shadow map boundaries
    rayLength = min(rayLength, far * 0.75);

    int steps = GODRAY_STEPS;
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
    vec3 worldSunDir = (gbufferModelViewInverse * vec4(sunDir, 0.0)).xyz;
    float sunVisible = clamp(worldSunDir.y * 4.0, 0.0, 1.0); // True rotation-invariant sun height-dependent godray scaling
    
    // Fade godrays out during weather transitions (rain/snow)
    return directColor * volumeFactor * 0.04 * skyLight * sunVisible * (1.0 - rainStrength);
}

void main() {
    // Read raw normal from normal G-buffer (Material ID alpha channel is dropped, so we read it from colortex2 instead!)
    vec4 normalData = texture(colortex1, vTexCoord);
    vec3 normal = normalize(normalData.rgb * 2.0 - 1.0);
    
    // Read lightmap coordinates (rg) and material ID (b) from colortex2 to preserve it safely
    vec4 lightmapData = texture(colortex2, vTexCoord);
    vec2 lmCoord = lightmapData.rg;
    float materialID = lightmapData.b; // 1.0 for Water, 0.0 for terrain
    
    // Read combined depth (translucent + opaque)
    float depth = texture(depthtex1, vTexCoord).r;
    
    // Sky fallback: copy albedo through for both outputs
    if (depth >= 1.0) {
        fragColor = texture(colortex0, vTexCoord);
        colortex3Out = fragColor;
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
        // Clamp to valid UV range — large wave normals can push coords off-screen,
        // causing undefined texture fetches on some drivers.
        refractedCoord = clamp(refractedCoord, vec2(0.001), vec2(0.999));
        
        // Sample albedo using refracted coordinates to create water wobble.
        // Guard: only replace if the refracted sample has actual geometry behind it
        // (deeper than the water surface) — prevents sampling sky or geometry in front
        // of the water surface through the floor.
        float refractedDepth = texture(depthtex1, refractedCoord).r;
        if (refractedDepth < 1.0 && refractedDepth > depth) {
            albedo = texture(colortex0, refractedCoord);
        }
    }
    
    // --- 2. INDIRECT LIGHTING (PBR Decoupled Lightmap) ---
    vec3 lightVector = normalize(sunPosition);
    vec3 worldSunDir = (gbufferModelViewInverse * vec4(lightVector, 0.0)).xyz;
    float sunElev = worldSunDir.y;

    // Lambertian with a small wrap term so back faces get a hint of light
    float nDotL = max(dot(normal, lightVector) * 0.5 + 0.5, 0.0);
    nDotL = nDotL * nDotL; // Re-square to restore physical behaviour at front faces

    // Dynamic ambient: dark blue-grey at night, warm grey-blue at day
    vec3 ambientColor = mix(vec3(0.06, 0.10, 0.22), vec3(0.52, 0.58, 0.65),
                            smoothstep(-0.1, 0.2, sunElev));

    // Torch/block light — quadratic falloff on rescaled lmCoord.x for proper distance feel.
    // Multiplier 5.0 accounts for ACES compression (input HDR > 1.0 is valid and desirable).
    vec3 torchColor = vec3(1.0, 0.52, 0.14) * 5.0;
    float torchFalloff = lmCoord.x * lmCoord.x; // quadratic: dim at distance, bright nearby

    // Sky ambient scales with sky light coordinate
    vec3 skyAmbient = ambientColor * lmCoord.y;

    // Minimum ambient so caves are not pitch black — slightly warm to feel like bounce light
    vec3 minAmbient = vec3(0.08, 0.07, 0.06);

    // Combine: torch + sky ambient + minimum. Rain does NOT darken this — you still see
    // your torch in the rain.
    vec3 indirectLight = torchColor * torchFalloff + skyAmbient + minAmbient;

    // Direct sunlight: day/night ramp — this IS affected by rain fading out the sun
    vec3 directColor = mix(vec3(0.08, 0.16, 0.28), vec3(1.35, 1.25, 1.1),
                           smoothstep(-0.05, 0.3, sunElev));

    // Scale direct lighting by sky light to prevent sun leakage in caves
    float skyLight = lmCoord.y;
    float shadowIntensity = 1.0;

    // rainFactor only affects sun — torch and ambient stay full during rain
    float rainFactor = 1.0 - rainStrength;
    float opaqueDepth = texture(depthtex0, vTexCoord).r;
    
    // --- 3. 3D SHADOW PROJECTION ---
    // Skip shadow tracing for sky, very distant elements, and caves with no sky light
    if (opaqueDepth < 1.0 && skyLight > 0.01) {
        vec3 viewPosO = reconstructViewPos(vTexCoord, opaqueDepth);
        vec3 playerPosO = reconstructPlayerPos(viewPosO);
        shadowIntensity = calculateShadows(playerPosO, nDotL);
    }

    // Indirect light (torch + sky ambient) is always full — unaffected by rain.
    // Direct sun contribution fades to zero in heavy rain; shadows also fade.
    vec3 finalColor = albedo.rgb * (indirectLight + directColor * nDotL * skyLight * shadowIntensity * rainFactor);
    
    // --- 4. WATER SHADING (Beer's Law & Reflections & Specular Glint) ---
    if (materialID > 0.5) {
        vec3 viewDir = normalize(-viewPos);
        vec3 viewNormal = normalize((gbufferModelView * vec4(waterWaveNormal, 0.0)).xyz);
        
        // 4a. Volumetric Light Absorption (Beer's Law)
        vec3 viewPosO = reconstructViewPos(vTexCoord, opaqueDepth);
        vec3 playerPosO = reconstructPlayerPos(viewPosO);
        // Compute exact thickness along the view ray vector (BSL/Solas method)
        float waterThickness = length(viewPosO - viewPos);
        finalColor = applyWaterAbsorption(finalColor, waterThickness);
        
        // 4b. Dynamic Sky Horizon Reflections
        float fresnel = pow(1.0 - max(dot(viewNormal, viewDir), 0.0), 3.0);
        vec3 reflectDir = reflect(-viewDir, viewNormal);
        vec3 worldReflectDir = (gbufferModelViewInverse * vec4(reflectDir, 0.0)).xyz;
        vec3 reflectionColor = getSkyColor(worldReflectDir, worldSunDir);
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
    vec3 worldViewDir = (gbufferModelViewInverse * vec4(viewPos, 0.0)).xyz;
    vec3 dynamicFogColor = mix(getSkyColor(-worldViewDir, worldSunDir), fogColor, rainStrength);
    finalColor = applyDistanceFog(finalColor, viewPos, dynamicFogColor);
    
    // --- 6. 3D VOLUMETRIC LIGHT SHAFT INJECTION (GODRAYS) ---
    finalColor += calculateVolumetricLight(viewPos, depth, directColor, skyLight);
    
    fragColor = vec4(finalColor, albedo.a);
    colortex3Out = vec4(finalColor, albedo.a);
}
