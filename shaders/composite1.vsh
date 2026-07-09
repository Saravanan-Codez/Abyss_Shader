#version 150
#include "/shaders.settings"

in vec3 vaPosition;
in vec2 vaUV0;

out vec2 vTexCoord;

void main() {
    gl_Position = vec4(vaPosition * 2.0 - 1.0, 1.0);
    vTexCoord = vaUV0;
}
