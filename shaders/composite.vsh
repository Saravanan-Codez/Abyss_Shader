#version 150
#include "/shaders.settings"

// Input attributes
in vec4 vaPosition;
in vec2 vaUV0;

// Outputs to Fragment Shader
out vec2 vTexCoord;

void main() {
    vTexCoord = vaUV0;
    // Standard full-screen quad projection
    gl_Position = vec4(vaPosition.xy * 2.0 - 1.0, 0.0, 1.0);
}
