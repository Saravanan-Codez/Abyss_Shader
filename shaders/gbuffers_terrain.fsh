#version 150
#include "/shaders.settings"

in vec4 vColor;
in vec2 vTexCoord;
in vec2 vLightmapCoord;
in vec3 vNormal;

uniform sampler2D gcolor;

/* G-Buffer Output Layouts
 * colortex0: Albedo (RGB) + Alpha (A)
 * colortex1: View-space Normal (RGB) + Reserved Specular/Roughness info (A)
 * colortex2: Lightmap (RG) + Unused (B) + Unused (A)
 */
layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
    vec4 albedo = texture(gcolor, vTexCoord) * vColor;
    
    // Alpha test
    if (albedo.a < 0.1) discard;

    // Output Base Color (Albedo)
    colortex0 = albedo;

    // Output Normal (encode from [-1, 1] to [0, 1])
    vec3 normal = normalize(vNormal) * 0.5 + 0.5;
    colortex1 = vec4(normal, 1.0); // 1.0 is placeholder for material data

    // Output Lightmap Coordinates
    colortex2 = vec4(vLightmapCoord, 0.0, 1.0);
}
