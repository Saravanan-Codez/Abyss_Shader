#version 150 compatibility
#include "/shaders.settings"

in vec4 vColor;
in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec3 vNormal;
in vec4 vShadowCoord;

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex0;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;
    if (albedo.a < 0.05) discard;
    
    vec4 light = texture(lightmap, vLightmapCoord);
    vec3 finalColor = albedo.rgb * light.rgb;
    
    // --- CUSTOM ATMOSPHERICS ---
    float skyExposure = smoothstep(0.0, 1.0, vLightmapCoord.t);
    vec3 tint = mix(vec3(0.8, 0.9, 1.2), vec3(1.1, 1.05, 0.9), skyExposure);
    finalColor.rgb *= tint;
    
    // --- FRESNEL (Phase 4) ---
    float fresnel = pow(1.0 - max(dot(normalize(vNormal), vec3(0.0, 1.0, 0.0)), 0.0), 3.0);
    finalColor.rgb = mix(finalColor.rgb, vec3(0.3, 0.6, 0.9), fresnel * 0.5);

    // --- FORWARD SHADOWS ON WATER ---
    // Fixes the projection seam/streak caused by deferred depth buffer bypass
    vec3 shadowpos = vShadowCoord.xyz * 0.5 + 0.5;
    float shadow = texture(shadowtex0, shadowpos.st).r;
    if(shadowpos.z > shadow + 0.005) { 
        finalColor.rgb *= 0.5; // Match the 50% darkening from composite.fsh
    }
    
    // Artificial brightness boost
    finalColor.rgb *= 1.2;
    colortex0 = vec4(finalColor, albedo.a);
    colortex1 = vec4(normalize(vNormal) * 0.5 + 0.5, 1.0);
    colortex2 = vec4(vLightmapCoord, 0.0, 1.0);
}
