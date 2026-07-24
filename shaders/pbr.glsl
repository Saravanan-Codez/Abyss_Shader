#ifndef PBR_GLSL
#define PBR_GLSL
#include "/shaders.settings"

struct Material {
    float smoothness;
    float roughness;
    float metalness;
    float f0;
    float porosity;
    float emissive;
    float height;
};

// Decodes standard LabPBR 1.3 data from the specular buffer (or normal buffer w/ layout)
Material decodeLabPBR(vec4 specularMap) {
    Material mat;
    // Channel 1: Smoothness
    mat.smoothness = specularMap.r;
    mat.roughness = 1.0 - mat.smoothness;
    
    // Channel 2: Metalness
    mat.metalness = specularMap.g;
    mat.f0 = specularMap.g * 0.96 + 0.04;
    
    // Channel 3: Porosity / Emissive
    mat.porosity = specularMap.b > 0.5 ? (specularMap.b - 0.5) * 2.0 : 0.0;
    mat.emissive = specularMap.b < 0.5 ? specularMap.b * 2.0 : 0.0;
    
    // Channel 4: Height / SSS
    mat.height = specularMap.a;
    return mat;
}

vec2 getParallaxCoords(vec2 texCoords, vec3 viewDirTangent, sampler2D heightMap, float heightScale) {
    int maxSteps = 8;
    int minSteps = 4;
    
    #if defined(MEDIUM)
        maxSteps = 16;
        minSteps = 8;
    #elif defined(HIGH)
        maxSteps = 32;
        minSteps = 12;
    #elif defined(ULTRA)
        maxSteps = 64;
        minSteps = 16;
    #endif

    // Scale step count dynamically based on the view angle (increases steps at grazing angles)
    int steps = int(mix(float(maxSteps), float(minSteps), abs(viewDirTangent.z)));
    float layerDepth = 1.0 / float(steps);
    float currentLayerDepth = 0.0;
    vec2 P = viewDirTangent.xy * heightScale;
    vec2 currentTexCoords = texCoords;
    float currentDepthMapValue = texture(heightMap, currentTexCoords).a;

    for (int i = 0; i < maxSteps; ++i) {
        if (i >= steps) break; // Dynamic early exit
        if (currentLayerDepth >= currentDepthMapValue) break;
        currentTexCoords -= P * layerDepth;
        currentDepthMapValue = texture(heightMap, currentTexCoords).a;
        currentLayerDepth += layerDepth;
    }

    return currentTexCoords;
}

// Standard GGX BRDF Evaluation
vec3 evalBRDF(vec3 lightDir, vec3 viewDir, vec3 normal, Material mat, vec3 albedo) {
    vec3 H = normalize(lightDir + viewDir);
    float NdotL = max(dot(normal, lightDir), 0.0);
    float NdotV = max(dot(normal, viewDir), 0.0);
    float NdotH = max(dot(normal, H), 0.0);
    float VdotH = max(dot(viewDir, H), 0.0);
    
    // Diffuse
    vec3 diffuse = albedo / 3.1415926535;

    // Microfacet Specular GGX
    float alpha = mat.roughness * mat.roughness;
    float alpha2 = alpha * alpha;
    float NdotH2 = NdotH * NdotH;
    float num = alpha2;
    float denom = (NdotH2 * (alpha2 - 1.0) + 1.0);
    denom = 3.1415926535 * denom * denom;
    float D = num / max(denom, 0.001); // Normal Distribution Function

    // Geometry Smith
    float k = (mat.roughness + 1.0); k = (k * k) / 8.0;
    float gl = NdotL / (NdotL * (1.0 - k) + k);
    float gv = NdotV / (NdotV * (1.0 - k) + k);
    float G = gl * gv; // Geometry Function

    // Fresnel Schlick
    vec3 F0 = mix(vec3(0.04), albedo, mat.metalness);
    vec3 F = F0 + (1.0 - F0) * pow(clamp(1.0 - VdotH, 0.0, 1.0), 5.0);

    vec3 specular = (D * G * F) / max(4.0 * NdotV * NdotL, 0.001);
    
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - mat.metalness;

    return (kD * diffuse + specular) * NdotL;
}
#endif
