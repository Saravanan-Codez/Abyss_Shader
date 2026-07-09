// Abyss Shader Sky Rendering module

// Procedural dynamic sky gradient based on look direction and sun elevation
vec3 getSkyColor(vec3 dir) {
    vec3 viewDir = normalize(dir);
    vec3 sunDir  = normalize(sunPosition);
    float sunElev = sunDir.y;
    float viewElev = viewDir.y;
    
    vec3 daySkyTop = vec3(0.1, 0.4, 0.8);
    vec3 daySkyBot = vec3(0.5, 0.7, 0.9);
    vec3 sunsetTop = vec3(0.1, 0.2, 0.4);
    vec3 sunsetBot = vec3(0.8, 0.4, 0.1);
    vec3 nightSkyTop = vec3(0.0, 0.0, 0.02);
    vec3 nightSkyBot = vec3(0.02, 0.05, 0.1);
    
    float dayFactor = smoothstep(-0.05, 0.2, sunElev);
    float sunsetFactor = smoothstep(-0.1, 0.1, sunElev) * (1.0 - smoothstep(0.1, 0.3, sunElev));
    
    vec3 topColor = mix(nightSkyTop, daySkyTop, dayFactor);
    topColor = mix(topColor, sunsetTop, sunsetFactor);
    
    vec3 botColor = mix(nightSkyBot, daySkyBot, dayFactor);
    botColor = mix(botColor, sunsetBot, sunsetFactor);
    
    float gradient = smoothstep(0.0, 0.6, max(viewElev, 0.0));
    return mix(botColor, topColor, gradient);
}
