#version 150
#include "/shaders.settings"

in vec4 vColor;
in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec3 vNormal;
in vec4 vRefractionVector;

uniform sampler2D gcolor;

layout(location = 0) out vec4 colortex0; // Albedo + Alpha
layout(location = 1) out vec4 colortex1; // Normal + Refraction setup
layout(location = 2) out vec4 colortex2; // Lightmap

void main() {
    vec4 albedo = texture(gcolor, vTexCoord) * vColor;

    // Translucency check
    if (albedo.a < 0.05) discard;

    // For water, we'll store the alpha explicitly so the composite pass can blend
    colortex0 = albedo;

    // Output Normal (encode from [-1, 1] to [0, 1])
    vec3 normal = normalize(vNormal) * 0.5 + 0.5;
    
    // Store refraction displacement in the alpha channel for later (placeholder 0.5)
    colortex1 = vec4(normal, 0.5); 

    // Output Lightmap Coordinates
    colortex2 = vec4(vLightmapCoord, 0.0, 1.0);
}
