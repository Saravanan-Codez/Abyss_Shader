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

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;
    if (albedo.a < 0.1) discard;
    
    // Output Raw G-Buffer Data
    colortex0 = albedo;
    colortex1 = vec4(normalize(vNormal) * 0.5 + 0.5, 0.0); // alpha = 0.0 for standard material
    colortex2 = vec4(vLightmapCoord, 0.0, 1.0);
}
