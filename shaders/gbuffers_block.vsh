#version 150 compatibility
#include "/shaders.settings"

out vec4 vColor;
out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec3 vNormal;

void main() {
    vColor = gl_Color;
    vTexCoord = gl_MultiTexCoord0.st;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    vNormal = length(gl_Normal) > 0.01 ? normalize(gl_NormalMatrix * gl_Normal) : vec3(0.0, 1.0, 0.0);
    gl_Position = ftransform();
}
