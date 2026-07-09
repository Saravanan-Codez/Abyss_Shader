#version 150 compatibility
#include "/shaders.settings"

out vec4 vColor;
out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec3 vNormal;

uniform float frameTimeCounter;

void main() {
    vColor = gl_Color;
    vTexCoord = gl_MultiTexCoord0.st;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    vNormal = normalize(gl_NormalMatrix * gl_Normal);

    vec4 position = gl_Vertex;

    #ifndef PROFILE_POTATO
        if (gl_Color.g > 0.8 && gl_Color.r < 0.2) {
            float time = frameTimeCounter * 2.0;
            position.x += sin(time + position.z * 1.5) * 0.05;
            position.y += cos(time + position.x * 1.5) * 0.05;
        }
    #endif

    gl_Position = gl_ModelViewProjectionMatrix * position;
}
