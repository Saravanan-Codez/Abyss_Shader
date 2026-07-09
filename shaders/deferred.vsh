#version 150
#include "/shaders.settings"

in vec3 vaPosition;
in vec2 vaUV0;

out vec2 vTexCoord;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

void main() {
    vTexCoord = vaUV0;
    gl_Position = vec4(vaUV0 * 2.0 - 1.0, 0.0, 1.0);
}
