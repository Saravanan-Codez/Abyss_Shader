// Abyss Shader Common Uniforms & Constants Declarations
// Preserves G-buffer layout configurations and game state variables

#define RGBA8 0 // Satisfaction define for GLSL compiler (Iris parses the token string)

in vec2 vTexCoord;
layout(location = 0) out vec4 fragColor;

uniform sampler2D colortex0; // Albedo
uniform sampler2D colortex1; // Normal (rgb) and Material ID (a)
uniform sampler2D colortex2; // Lightmap UVs (rg)
uniform sampler2D depthtex0; // Opaque Depth
uniform sampler2D depthtex1; // Translucent Depth
uniform sampler2D shadowtex0; // Shadow Map

uniform sampler2D lightmap;

uniform vec3 sunPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;

uniform float near;
uniform float far;

uniform vec3 fogColor;
uniform float rainStrength;
uniform float frameTimeCounter;

// Force Iris/OptiFine to allocate standard 4-channel textures (preserves alpha for materialID)
const int colortex0Format = RGBA8;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA8;
