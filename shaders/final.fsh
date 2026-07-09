#version 150
#include "/shaders.settings"

in vec2 vTexCoord;

uniform sampler2D colortex0; // Final Deferred Image
uniform sampler2D depthtex0; // Depth buffer
uniform sampler2D colortex4; // History buffer for TAA (standard Iris binding)

uniform vec2 taaJitter; // Sub-pixel jitter matrix provided by Iris
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 previousProjection;
uniform mat4 previousModelView;

uniform float viewWidth;
uniform float viewHeight;
#define viewPortSize vec2(viewWidth, viewHeight)

// Custom Tonemapping sliders
float exposure = 1.2;
float contrast = 1.05;

layout(location = 0) out vec4 fragColor;

vec3 getWorldPos(vec2 uv, float depth) {
    vec4 clipSpace = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewSpace = gbufferProjectionInverse * clipSpace;
    viewSpace /= viewSpace.w;
    vec4 worldSpace = gbufferModelViewInverse * viewSpace;
    return worldSpace.xyz;
}

vec2 getVelocity(vec2 uv, float depth, vec3 worldPos) {
    vec4 previousClipPos = previousProjection * previousModelView * vec4(worldPos, 1.0);
    vec2 previousUV = (previousClipPos.xy / previousClipPos.w) * 0.5 + 0.5;
    return uv - previousUV;
}

vec3 ACESFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 applyBloom(sampler2D tex, vec2 uv) {
    vec3 bloomColor = vec3(0.0);
    float blurRadius = 0.005; 
    
    // Multi-stage downsample/upsample approximation (Single-pass for architecture demonstration)
    for (int x = -2; x <= 2; ++x) {
        for (int y = -2; y <= 2; ++y) {
            vec3 sampleColor = texture(tex, uv + vec2(x, y) * blurRadius).rgb;
            // Extract high-intensity pixels (Emissive / Specular glints)
            float luma = dot(sampleColor, vec3(0.299, 0.587, 0.114));
            if (luma > 1.0) {
                bloomColor += sampleColor;
            }
        }
    }
    return bloomColor / 25.0; // Normalize
}

void main() {
    vec2 currentUV = vTexCoord;
    vec3 sceneColor = texture(colortex0, currentUV).rgb;

    #ifdef PROFILE_POTATO
        // Fast FXAA Fallback (Edge Detection)
        float lumaCenter = dot(sceneColor, vec3(0.299, 0.587, 0.114));
        float lumaLeft = dot(textureOffset(colortex0, currentUV, ivec2(-1, 0)).rgb, vec3(0.299, 0.587, 0.114));
        float lumaRight = dot(textureOffset(colortex0, currentUV, ivec2(1, 0)).rgb, vec3(0.299, 0.587, 0.114));
        float lumaTop = dot(textureOffset(colortex0, currentUV, ivec2(0, -1)).rgb, vec3(0.299, 0.587, 0.114));
        float lumaBottom = dot(textureOffset(colortex0, currentUV, ivec2(0, 1)).rgb, vec3(0.299, 0.587, 0.114));
        
        float edge = abs(lumaLeft - lumaCenter) + abs(lumaRight - lumaCenter) + abs(lumaTop - lumaCenter) + abs(lumaBottom - lumaCenter);
        if (edge > 0.1) {
            sceneColor = (textureOffset(colortex0, currentUV, ivec2(-1, 0)).rgb + textureOffset(colortex0, currentUV, ivec2(1, 0)).rgb + textureOffset(colortex0, currentUV, ivec2(0, -1)).rgb + textureOffset(colortex0, currentUV, ivec2(0, 1)).rgb + sceneColor) * 0.2;
        }
    #else
        #if defined(TAA_TOGGLE) && TAA_TOGGLE == 1
            float currentDepth = texture(depthtex0, currentUV).r;
            vec3 currentWorldPos = getWorldPos(currentUV, currentDepth);
            
            // Calculate pixel velocity
            vec2 velocity = getVelocity(currentUV, currentDepth, currentWorldPos);

            // Reproject UV with velocity and sub-pixel jitter
            vec2 reprojectedUV = currentUV - velocity + taaJitter / viewPortSize;

            // Fetch historical frame
            vec3 historyColor = texture(colortex4, reprojectedUV).rgb; 

            // Neighborhood Clamping to prevent ghosting
            vec3 minColor = sceneColor;
            vec3 maxColor = sceneColor;
            vec2 texelSize = 1.0 / viewPortSize;
            
            for (int x = -1; x <= 1; ++x) {
                for (int y = -1; y <= 1; ++y) {
                    vec3 neighborColor = texture(colortex0, currentUV + vec2(x, y) * texelSize).rgb;
                    minColor = min(minColor, neighborColor);
                    maxColor = max(maxColor, neighborColor);
                }
            }
            historyColor = clamp(historyColor, minColor, maxColor);

            // Temporal blend
            sceneColor = mix(sceneColor, historyColor, 0.9);
        #endif
    #endif

    // Bloom Pass
    #ifndef PROFILE_POTATO
        vec3 bloom = applyBloom(colortex0, currentUV);
        sceneColor += bloom * 0.5;
    #endif

    // Master Tone Mapping (ACES Filmic)
    sceneColor *= exposure;
    sceneColor = ACESFilm(sceneColor);

    // Contrast Correction
    sceneColor = mix(vec3(0.5), sceneColor, contrast);

    // Write final output (also writes to colortex4 implicitly via Iris/OptiFine pipeline routing for next frame's TAA history)
    fragColor = vec4(sceneColor, 1.0);
}
