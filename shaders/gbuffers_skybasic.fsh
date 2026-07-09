#version 150
#include "/shaders.settings"

in vec3 vWorldPos;

uniform vec3 sunPosition;
uniform float wetness;

layout(location = 0) out vec4 colortex0; // Base Scene Color

void main() {
    vec3 viewDir = normalize(vWorldPos);
    vec3 sunDir = normalize(sunPosition);
    
    // Rayleigh and Mie Scattering approximations
    float cosTheta = dot(viewDir, sunDir);
    float rayleighPhase = 0.75 * (1.0 + cosTheta * cosTheta);
    
    // Sunset/Sunrise color blending
    vec3 zenithColor = vec3(0.1, 0.3, 0.6);
    vec3 horizonColor = vec3(0.6, 0.7, 0.8);
    vec3 sunColor = vec3(1.0, 0.9, 0.7);
    
    // Darken sky dome dynamically during rain
    zenithColor = mix(zenithColor, vec3(0.15, 0.15, 0.2), wetness);
    horizonColor = mix(horizonColor, vec3(0.2, 0.2, 0.25), wetness);
    
    // Compute gradient
    float elevation = clamp(viewDir.y, 0.0, 1.0);
    vec3 skyColor = mix(horizonColor, zenithColor, elevation);
    
    // Add sun glare (Mie)
    float sunGlare = pow(max(cosTheta, 0.0), 256.0) * 5.0;
    skyColor += sunColor * sunGlare * (1.0 - wetness); // Remove glare during rain
    
    colortex0 = vec4(skyColor, 1.0);
}
