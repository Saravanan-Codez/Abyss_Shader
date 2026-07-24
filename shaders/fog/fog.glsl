// Abyss Shader — Atmospheric Distance Fog module

// Applies distance-based linear fog synced to native Minecraft colours and render distance.
// isEyeInWater is declared in common/common.glsl.
vec3 applyDistanceFog(vec3 color, vec3 viewPos, vec3 nativeFogColor) {
    float distance = length(viewPos);
    
    // If the player is underwater, apply a realistic thick underwater blue-teal fog instead of air fog
    if (isEyeInWater == 1) {
        float fogFactor = clamp(distance / 20.0, 0.0, 1.0); // Thick fog ending at 20 blocks
        vec3 waterFogColor = vec3(0.04, 0.12, 0.25); // Deep blue-teal underwater color
        return mix(color, waterFogColor, fogFactor * 0.90);
    }
    
    // Near-Threshold safety check: prevent fog from entering the camera lens
    if (distance > 0.5) {
        // Fog starts at 60% and ends at 95% of active render distance (far plane)
        float fogStart = far * 0.60;
        float fogEnd   = far * 0.95;
        
        float fogRange = fogEnd - fogStart;
        
        // Safeguard check: prevent division-by-zero when far is uninitialized or 0.0!
        if (fogRange > 1.0) {
            float fogFactor = clamp((distance - fogStart) / fogRange, 0.0, 1.0);
            return mix(color, nativeFogColor, fogFactor * 0.85); // 85% max fog density
        }
    }
    
    return color;
}
