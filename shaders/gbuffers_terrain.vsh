#version 150 compatibility
#include "/shaders.settings"

out vec4 vColor;
out vec2 vTexCoord;
out vec2 vLightmapCoord;
out vec3 vViewPos;

uniform float frameTimeCounter;

void main() {
    vColor = gl_Color;
    vTexCoord = gl_MultiTexCoord0.st;
    vLightmapCoord = gl_MultiTexCoord1.xy;

    vec4 position = gl_Vertex;

    #if WAVING_LEAVES == 1
        // Detect foliage blocks (green tints)
        if (gl_Color.g > 0.5 && gl_Color.r < 0.45) {
            float time = frameTimeCounter * 2.0;
            // Anchor roots: wave leaves entirely, but only sway the top half of grass/flowers (V coordinate close to 0.0)
            float waveScale = (gl_MultiTexCoord0.t < 0.55) ? 1.0 : 0.0;
            
            position.x += sin(time + position.x * 2.0 + position.z * 1.5) * 0.045 * waveScale;
            position.y += cos(time * 1.5 + position.y * 1.5) * 0.02 * waveScale;
        }
    #endif

    vec4 viewPos = gl_ModelViewMatrix * position;
    vViewPos = viewPos.xyz;
    gl_Position = gl_ProjectionMatrix * viewPos;
}
