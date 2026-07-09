#version 150 compatibility

in vec2 vTexCoord;

uniform sampler2D colortex0;

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 fragColor;

void main() {
    fragColor = texture(colortex0, vTexCoord);
}
