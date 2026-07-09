#version 150 compatibility
#include "/shaders.settings"

in vec4 vColor;
in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec3 vNormal;

uniform sampler2D gtexture;
uniform sampler2D lightmap;

uniform float exposure = 1.2; 

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;
    if (albedo.a < 0.05) discard;
    vec4 light = texture(lightmap, vLightmapCoord);
    
    vec4 finalColor = albedo * light;
    
    // --- CUSTOM VISUAL CHANGE START ---
    // Apply a warm tint to the final render (Golden Hour)
    finalColor.rgb *= vec3(1.2, 1.05, 0.9); 
    
    // Artificial brightness boost
    finalColor.rgb *= exposure;
    
    // Apply a simple gamma correction for contrast
    finalColor.rgb = pow(finalColor.rgb, vec3(1.0 / 2.2));
    // --- CUSTOM VISUAL CHANGE END ---

    colortex0 = finalColor;
    colortex1 = vec4(normalize(vNormal) * 0.5 + 0.5, 1.0);
    colortex2 = vec4(vLightmapCoord, 0.0, 1.0);
}
