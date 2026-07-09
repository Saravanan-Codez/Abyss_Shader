#version 150
#include "/shaders.settings"

// Input attributes
in vec4 vaPosition;
in vec4 vaColor;
in vec2 vaUV0; // Base texture
in vec2 vaUV2; // Lightmap
in vec3 vaNormal;

// Uniforms
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform float frameTimeCounter;

// Outputs to Fragment Shader
out vec4 vColor;
out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec3 vNormal;

void main() {
    vColor = vaColor;
    vTexCoord = vaUV0;
    vLightmapCoord = vaUV2;
    vNormal = normalize(mat3(modelViewMatrix) * vaNormal);

    vec4 position = vaPosition;

    // Vertex Waving Animations (leaves, grass)
    #ifndef PROFILE_POTATO
        // Simple heuristic for waving: mostly green, very little red
        if (vaColor.g > 0.8 && vaColor.r < 0.2) {
            float time = frameTimeCounter * 2.0;
            position.x += sin(time + position.z * 1.5) * 0.05;
            position.y += cos(time + position.x * 1.5) * 0.05;
        }
    #endif

    gl_Position = projectionMatrix * modelViewMatrix * position;
}
