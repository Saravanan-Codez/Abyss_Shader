#version 150
#include "/shaders.settings"

in vec3 vaPosition;
in vec2 vaUV0;

out vec2 vTexCoord;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

void main() {
    vTexCoord = vaUV0;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(vaPosition, 1.0);
}
