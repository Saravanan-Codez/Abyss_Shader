#version 150 compatibility
#include "/shaders.settings"

in vec4 vColor;
in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec3 vNormal;

uniform sampler2D gtexture;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;
layout(location = 3) out vec4 colortex4; // r=emissive strength, g=AO placeholder

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;
    if (albedo.a < 0.1) discard;

    // Remap lightmap from OptiFine/Iris [1/32, 31/32] → [0, 1]
    vec2 lm = clamp((vLightmapCoord - 0.03125) / 0.9375, 0.0, 1.0);

    colortex0 = albedo;
    colortex1 = vec4(normalize(vNormal) * 0.5 + 0.5, 0.0);
    colortex2 = vec4(lm, 0.0, 1.0);
    colortex4 = vec4(0.0, 1.0, 0.0, 1.0);
}
