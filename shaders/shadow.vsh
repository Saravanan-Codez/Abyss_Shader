#version 150 compatibility
#include "/shaders.settings"

// Explicit shadow map dimensions for Iris/OptiFine buffer allocator
const int shadowMapResolution = SHADOW_MAP_RESOLUTION; 
const float shadowDistance = 120.0;

out vec2 vTexCoord;
out vec4 vColor;

void main() {
    vTexCoord = gl_MultiTexCoord0.st;
    vColor = gl_Color;
    gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * gl_Vertex);
}
