#version 150 compatibility
#include "/shaders.settings"

out vec4 vColor;
out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec3 vNormal;
out vec4 vShadowCoord;

uniform float frameTimeCounter;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

void main() {
    vColor = gl_Color;
    vTexCoord = gl_MultiTexCoord0.st;
    vLightmapCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).st;
    vNormal = normalize(gl_NormalMatrix * gl_Normal);

    vec4 position = gl_Vertex;

    #ifndef PROFILE_POTATO
        if (gl_Color.b > 0.8 && gl_Color.r < 0.3) {
            float time = frameTimeCounter * 3.0;
            position.y += sin(time + position.x * 2.0 + position.z * 2.0) * 0.05;
        }
    #endif

    gl_Position = gl_ModelViewProjectionMatrix * position;

    // Calculate shadow coordinate for the water surface
    vec4 worldPos = gl_ModelViewMatrix * position;
    vShadowCoord = shadowProjection * shadowModelView * worldPos;
}
