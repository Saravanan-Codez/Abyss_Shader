#version 150
#include "/shaders.settings"

in vec4 vaPosition;
in vec2 vaUV0;
out vec2 vTexCoord;

void main() {
    vTexCoord = vaUV0;
    gl_Position = vec4(vaPosition.xy * 2.0 - 1.0, 0.0, 1.0);
}
