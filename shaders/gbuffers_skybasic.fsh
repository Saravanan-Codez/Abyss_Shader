#version 150 compatibility
#include "/shaders.settings"

in vec3 vPos;

uniform vec3 sunPosition;

layout(location = 0) out vec4 colortex0;
layout(location = 1) out vec4 colortex1;
layout(location = 2) out vec4 colortex2;

void main() {
    vec3 viewDir = normalize(vPos);
    vec3 sunDir  = normalize(sunPosition);
    
    // Sun elevation (-1 to 1)
    float sunElev = sunDir.y;
    
    // View elevation (-1 to 1)
    float viewElev = viewDir.y;
    
    // PBR Sky Colors
    vec3 daySkyTop = vec3(0.1, 0.4, 0.8);
    vec3 daySkyBot = vec3(0.5, 0.7, 0.9);
    
    vec3 sunsetTop = vec3(0.1, 0.2, 0.4);
    vec3 sunsetBot = vec3(0.8, 0.4, 0.1);
    
    vec3 nightSkyTop = vec3(0.0, 0.0, 0.02);
    vec3 nightSkyBot = vec3(0.02, 0.05, 0.1);
    
    // Smooth time-of-day blending
    float dayFactor = smoothstep(-0.05, 0.2, sunElev);
    float sunsetFactor = smoothstep(-0.1, 0.1, sunElev) * (1.0 - smoothstep(0.1, 0.3, sunElev));
    
    vec3 topColor = mix(nightSkyTop, daySkyTop, dayFactor);
    topColor = mix(topColor, sunsetTop, sunsetFactor);
    
    vec3 botColor = mix(nightSkyBot, daySkyBot, dayFactor);
    botColor = mix(botColor, sunsetBot, sunsetFactor);
    
    // Vertical horizon-to-zenith gradient
    float gradient = smoothstep(0.0, 0.6, max(viewElev, 0.0));
    vec3 skyColor = mix(botColor, topColor, gradient);
    
    // Output directly to G-Buffers
    colortex0 = vec4(skyColor, 1.0);
    colortex1 = vec4(0.0);
    colortex2 = vec4(0.0);
}
