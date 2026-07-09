#version 150
#include "/shaders.settings"

in vec3 vaPosition;
in vec4 vaColor;
in vec2 vaUV0;
in ivec2 vaUV2;
in vec3 vaNormal;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;

out vec4 vColor;
out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec3 vNormal;

void main() {
    vColor = vaColor;
    vTexCoord = vaUV0;
    vLightmapCoord = vec2(vaUV2) / 256.0;
    vNormal = length(vaNormal) > 0.1 ? normalize(mat3(modelViewMatrix) * vaNormal) : vec3(0.0, 1.0, 0.0);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(vaPosition, 1.0);
}
