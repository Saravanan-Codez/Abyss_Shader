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
    vNormal = length(gl_Normal) > 0.01 ? normalize(gl_NormalMatrix * gl_Normal) : vec3(0.0, 1.0, 0.0);

    vec4 position = gl_Vertex;

    #if WAVING_LEAVES == 1
        if (gl_Color.b > 0.8 && gl_Color.r < 0.3) {
            float time = frameTimeCounter * 3.0;
            position.y += sin(time + position.x * 2.0 + position.z * 2.0) * 0.05;
        }
    #endif

    gl_Position = gl_ModelViewProjectionMatrix * position;
}
