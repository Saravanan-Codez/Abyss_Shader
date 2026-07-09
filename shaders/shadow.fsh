#version 150 compatibility
#include "/shaders.settings"

// Explicit shadow map dimensions for Iris/OptiFine buffer allocator
const int shadowMapResolution = 2048;
const float shadowDistance = 120.0;

in vec2 vTexCoord;
in vec4 vColor;

uniform sampler2D gtexture;

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vColor;
    
    // Discard transparent pixels so they do not cast solid shadows
    if (albedo.a < 0.1) discard;
    
    // Output base color for colored shadows later
    gl_FragData[0] = albedo;
}
