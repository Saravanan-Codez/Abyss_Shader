#version 150 compatibility
#include "/shaders.settings"
#include "/common/common.glsl"

in vec2 vTexCoord;

layout(location = 0) out vec4 fragColor;

// ACES Filmic Tone Mapping
vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec3 color = texture(colortex3, vTexCoord).rgb;

    // Bloom is applied in deferred.fsh — this pass only tone-maps and gamma-encodes.

    // Exposure: lift to make full use of the HDR range before ACES compression
    color *= 1.45;

    // ACES tone mapping
    color = ACESFilm(color);

    // Gamma encode for sRGB display
    color = pow(max(color, vec3(0.0)), vec3(1.0 / 2.2));

    fragColor = vec4(color, 1.0);
}
