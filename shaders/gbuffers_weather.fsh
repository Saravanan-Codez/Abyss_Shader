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
layout(location = 3) out vec4 colortex4;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;

    // Rain/snow particles have very low alpha — vanilla values go as low as 0.02.
    // The old 0.1 threshold was discarding most rain sprites, making rain invisible.
    if (albedo.a < 0.01) discard;

    // Remap lightmap from OptiFine/Iris [1/32, 31/32] → [0, 1]
    vec2 lm = clamp((vLightmapCoord - 0.03125) / 0.9375, 0.0, 1.0);

    // Tint rain/snow slightly blue-grey for realism
    vec3 weatherColor = mix(albedo.rgb, vec3(0.75, 0.82, 0.92), 0.35);

    colortex0 = vec4(weatherColor, albedo.a);
    colortex1 = vec4(normalize(vNormal) * 0.5 + 0.5, 0.0);
    colortex2 = vec4(lm, 0.0, 1.0);
    colortex4 = vec4(0.0, 1.0, 0.0, 1.0);
}
