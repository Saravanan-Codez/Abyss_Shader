#version 150 compatibility

in vec2 vTexCoord;

uniform sampler2D colortex0;

#define BLOOM_ON

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 fragColor;

// ACES Tone Mapping Formula
vec3 ACESFilm(vec3 x) {
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((x*(a*x+b))/(x*(c*x+d)+e), 0.0, 1.0);
}

void main() {
    vec4 color = texture(colortex0, vTexCoord);

    #if BLOOM == 1
    // Fast offset downsampled bloom extraction
    vec2 offset = vec2(0.002, 0.002);
    vec4 bloom = texture(colortex0, vTexCoord + offset);
    bloom += texture(colortex0, vTexCoord - offset);
    bloom += texture(colortex0, vTexCoord + vec2(-offset.x, offset.y));
    bloom += texture(colortex0, vTexCoord + vec2(offset.x, -offset.y));
    
    // Add glow back to original color
    color.rgb += (bloom.rgb * 0.1); 
    #endif

    // Apply exposure multiplier to lift dynamic range details (matches BSL)
    color.rgb *= 1.45;

    // ACES Tone Mapping with strict display clamping to prevent blowout
    color.rgb = clamp(ACESFilm(color.rgb), 0.0, 1.0);
    
    // Final Gamma Encoding for display
    color.rgb = pow(color.rgb, vec3(1.0 / 2.2));

    fragColor = vec4(color.rgb, 1.0);
}
