#version 150 compatibility
#include "/shaders.settings"

in vec4 vColor;
in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec3 vViewPos;

uniform sampler2D gtexture;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;
layout(location = 3) out vec4 colortex4; // r=emissive strength, g=AO placeholder

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;
    if (albedo.a < 0.1) discard;

    // Calculate exact screen-space face normal in view space
    vec3 normal = normalize(cross(dFdx(vViewPos), dFdy(vViewPos)));
    if (dot(normal, vViewPos) > 0.0) normal = -normal;

    // Remap lightmap from OptiFine/Iris [1/32, 31/32] → [0, 1]
    // Raw coords come from gl_TextureMatrix[1] * gl_MultiTexCoord1 which puts them
    // in the 0.03125–0.96875 range. Without this, torch and sky light look ~50% too dim.
    vec2 lm = clamp((vLightmapCoord - 0.03125) / (0.9375), 0.0, 1.0);

    // Emissive heuristic: high-brightness albedo + near-max block light (rescaled coords)
    float luma = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
    float emissive = 0.0;
    #if !defined(POTATO)
        if (luma > 0.75 && lm.x > 0.85) {
            emissive = smoothstep(0.75, 1.0, luma);
        }
    #endif

    // Output Raw G-Buffer Data — store rescaled lightmap coords
    colortex0 = albedo;
    colortex1 = vec4(normal * 0.5 + 0.5, 0.0);
    colortex2 = vec4(lm, 0.0, 1.0);
    colortex4 = vec4(emissive, 1.0, 0.0, 1.0);
}
