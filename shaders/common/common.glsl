// Abyss Shader Common Uniforms & Constants Declarations
// Preserves G-buffer layout configurations and game state variables

uniform sampler2D colortex0; // Albedo
uniform sampler2D colortex1; // Normal (rgb), material flag (a: 1.0=water)
uniform sampler2D colortex2; // Lightmap UVs (rg), Material ID (b)
uniform sampler2D colortex3; // HDR lit scene color (written by composite, read by composite1+)
uniform sampler2D colortex4; // r=emissive strength, g=AO occlusion factor (written by gbuffers, updated by composite2)
uniform sampler2D colortex5; // TAA history buffer (previous frame HDR, read/written by deferred)
uniform sampler2D colortex6; // Bloom extraction chain (half-res Kawase, written by composite2, read by deferred)
uniform sampler2D depthtex0; // Opaque Depth
uniform sampler2D depthtex1; // Translucent Depth
uniform sampler2D shadowtex0; // Shadow Map

uniform sampler2D lightmap;

uniform vec3 sunPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

// Previous-frame matrices and camera delta — used by TAA reprojection in deferred.fsh
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;

uniform int isEyeInWater; // 0 = air, 1 = water, 2 = lava

uniform vec3 fogColor;
uniform float rainStrength;
uniform float frameTimeCounter;
