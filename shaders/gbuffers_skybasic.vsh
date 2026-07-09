#version 150 compatibility
#include "/shaders.settings"

in vec4 vaPosition;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec3 vWorldPos;

void main() {
    // Transform sky vertices into world space for scattering calculations
    vWorldPos = (modelViewMatrix * vaPosition).xyz;
    gl_Position = projectionMatrix * modelViewMatrix * vaPosition;
}
