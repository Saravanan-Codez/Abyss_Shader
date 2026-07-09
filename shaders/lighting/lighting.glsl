// Abyss Shader PBR Lighting calculations

// Dynamic Block Light (Torch) and Sky Light Indirect Light calculations
vec3 calculateIndirectLight(vec2 lmCoord, vec3 ambientColor) {
    // Custom block light (torch) - bright warm orange
    vec3 torchColor = vec3(1.0, 0.55, 0.25) * 1.5;
    
    // Custom sky light matches the dynamic ambient color
    vec3 skyLightColor = ambientColor;
    
    // Fallback ambient level so caves aren't 100% pitch black
    vec3 minimumLight = vec3(0.04);
    
    // Quadratic attenuation for realistic torch light falloff
    return torchColor * lmCoord.x * lmCoord.x + skyLightColor * lmCoord.y + minimumLight;
}

// Blinn-Phong Specular glints for metallic/reflective surfaces
vec3 calculateSpecularHighlight(vec3 viewNormal, vec3 lightDir, vec3 viewDir, vec3 directColor, float shininess) {
    vec3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(viewNormal, halfDir), 0.0), shininess);
    return directColor * spec;
}
