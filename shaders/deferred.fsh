#version 150
#include "/shaders.settings"

in vec2 vTexCoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 sunPosition;
uniform float frameTimeCounter;
uniform float wetness;

layout(location = 0) out vec4 fragColor;

vec3 getWorldPos(vec2 uv, float depth) {
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewSpace = gbufferProjectionInverse * clipSpace;
    viewSpace /= viewSpace.w;
    vec4 worldSpace = gbufferModelViewInverse * viewSpace;
    return worldSpace.xyz;
}

// Procedural pseudo-3D noise (Hash based)
float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise3D(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(p + vec3(0,0,0)), hash(p + vec3(1,0,0)),f.x),
                   mix(hash(p + vec3(0,1,0)), hash(p + vec3(1,1,0)),f.x),f.y),
               mix(mix(hash(p + vec3(0,0,1)), hash(p + vec3(1,0,1)),f.x),
                   mix(hash(p + vec3(0,1,1)), hash(p + vec3(1,1,1)),f.x),f.y),f.z);
}

// 3D Ray-marched Volumetric Fog interacting with Shadow Map
vec3 calculateVolumetricFog(vec3 startPos, vec3 endPos, vec3 lightDir) {
    int maxSteps = 16; 
    #ifdef PROFILE_HIGH
        maxSteps = 32;
    #elif defined(PROFILE_ULTRA)
        maxSteps = 64;
    #endif

    vec3 rayDir = endPos - startPos;
    float rayLength = length(rayDir);
    rayDir /= rayLength;

    float stepSize = min(rayLength / float(maxSteps), 10.0); // Limit max distance per step
    vec3 currentPos = startPos;
    float fogAccumulation = 0.0;

    // Wind translation vector
    vec3 windOffset = vec3(frameTimeCounter * 0.5, 0.0, frameTimeCounter * 0.2);

    for (int i = 0; i < maxSteps; i++) {
        if (length(currentPos - startPos) >= rayLength) break;

        // Sample noise
        float density = noise3D(currentPos * 0.1 + windOffset) * VOLUMETRIC_FOG_DENSITY;
        density = max(density - 0.3, 0.0); // Threshold to create distinct clouds/patches
        
        // Increase atmospheric density heavily during rain
        density *= (1.0 + wetness * 3.0);

        if (density > 0.0) {
            // Shadow map intersection for God-Rays/Crepuscular Rays
            vec4 shadowSpacePos = shadowProjection * shadowModelView * vec4(currentPos, 1.0);
            vec3 projCoords = shadowSpacePos.xyz / shadowSpacePos.w;
            projCoords = projCoords * 0.5 + 0.5;

            // Only calculate shadows if within shadow map bounds
            if (projCoords.x > 0.0 && projCoords.x < 1.0 && projCoords.y > 0.0 && projCoords.y < 1.0) {
                float shadowDepth = texture(shadowtex0, projCoords.xy).r;
                float inShadow = (projCoords.z - 0.001 > shadowDepth) ? 0.0 : 1.0;
                fogAccumulation += density * inShadow * stepSize * 0.1;
            } else {
                // Base scattering if outside shadow map
                fogAccumulation += density * stepSize * 0.1;
            }
        }

        currentPos += rayDir * stepSize;
    }

    vec3 fogColor = vec3(0.8, 0.85, 0.9); // Base color
    fogColor = mix(fogColor, vec3(0.3, 0.35, 0.4), wetness); // Darker in rain

    return fogColor * min(fogAccumulation, 1.0);
}

void main() {
    vec3 color = texture(colortex0, vTexCoord).rgb;
    float depth = texture(depthtex0, vTexCoord).r;
    
    vec3 viewPos = gbufferModelViewInverse[3].xyz;
    vec3 worldPos = getWorldPos(vTexCoord, depth);
    
    // If we hit the sky, fix ray length to evaluate fog against the sky backdrop
    if (depth == 1.0) {
        vec3 rayDir = normalize(worldPos - viewPos);
        worldPos = viewPos + rayDir * 100.0;
    }
    
    vec3 lightDir = normalize(sunPosition);
    vec3 fog = calculateVolumetricFog(viewPos, worldPos, lightDir);
    
    color += fog; // Additive blend for god rays
    
    // General atmospheric absorption dynamically driven by weather states
    color *= (1.0 - wetness * 0.2); 

    fragColor = vec4(color, 1.0);
}
