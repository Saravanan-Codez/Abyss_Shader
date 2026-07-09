#version 150 compatibility
#include "/shaders.settings"

in vec4 vColor;
in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec3 vNormal;

uniform sampler2D gtexture;
uniform sampler2D lightmap;

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
    
    colortex0 = vec4(finalColor, albedo.a);
    colortex1 = vec4(normalize(vNormal) * 0.5 + 0.5, 1.0);
    colortex2 = vec4(vLightmapCoord, 0.0, 1.0);
}
