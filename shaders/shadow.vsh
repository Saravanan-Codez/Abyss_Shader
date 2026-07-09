#version 150 compatibility
#include "/shaders.settings"

out vec2 vTexCoord;
out vec4 vColor;

void main() {
    vTexCoord = gl_MultiTexCoord0.st;
    vColor = gl_Color;
    gl_Position = ftransform();
}
