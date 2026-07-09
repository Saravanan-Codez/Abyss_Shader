#version 150 compatibility

in vec2 vTexCoord;

uniform sampler2D colortex0;

#define BLOOM_ON

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 fragColor;

void main() {
    vec4 color = texture(colortex0, vTexCoord);

    #ifdef BLOOM_ON
    // Fast offset downsampled bloom extraction
    vec2 offset = vec2(0.002, 0.002);
    vec4 bloom = texture(colortex0, vTexCoord + offset);
    bloom += texture(colortex0, vTexCoord - offset);
    bloom += texture(colortex0, vTexCoord + vec2(-offset.x, offset.y));
    bloom += texture(colortex0, vTexCoord + vec2(offset.x, -offset.y));
    
    // Add glow back to original color
    color.rgb += (bloom.rgb * 0.1); 
    #endif

    fragColor = vec4(color.rgb, 1.0);
}
