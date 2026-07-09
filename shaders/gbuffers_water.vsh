#version 150
#include "/shaders.settings"

in vec3 vaPosition;
in vec4 vaColor;
in vec2 vaUV0;
in ivec2 vaUV2;
in vec3 vaNormal;

uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform float frameTimeCounter;

out vec4 vColor;
out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec3 vNormal;
out vec4 vRefractionVector;

void main() {
    vColor = vaColor;
    vTexCoord = vaUV0;
    vLightmapCoord = vec2(vaUV2);
    vNormal = normalize(mat3(modelViewMatrix) * vaNormal);

    vec4 position = vec4(vaPosition, 1.0);

    // Water surface waving
    #ifndef PROFILE_POTATO
        float time = frameTimeCounter * 3.0;
        position.y += sin(time + position.x * 2.0 + position.z * 2.0) * 0.05;
    #endif

    vec4 viewPos = modelViewMatrix * position;
    gl_Position = projectionMatrix * viewPos;
    
    // Pass projection space position for refraction calculations
    vRefractionVector = gl_Position;
}
