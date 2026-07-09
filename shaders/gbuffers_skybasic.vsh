#version 150 compatibility
#include "/shaders.settings"

out vec3 vPos;

void main() {
    // Pass view space position to fragment shader
    vPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
}
