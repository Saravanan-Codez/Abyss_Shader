// Abyss Shader Math Utilities & Coordinate Space Transformations

// Reconstruct physical Euclidean distance in blocks
float getEuclideanDistance(vec3 pos) {
    return length(pos);
}

// Reconstruct 3D Position in View Space from Screen Position and Depth
vec3 reconstructViewPos(vec2 coord, float depthVal) {
    vec4 ndc = vec4(coord.x * 2.0 - 1.0, coord.y * 2.0 - 1.0, depthVal * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / (abs(view.w) > 0.0001 ? view.w : 1.0);
}

// Transform View Space Coordinate to Player-Relative Space
vec3 reconstructPlayerPos(vec3 viewPos) {
    vec4 player = gbufferModelViewInverse * vec4(viewPos, 1.0);
    return player.xyz;
}

// Pseudo-random 2D dither noise generator to eliminate banding/striping
float getDitherNoise(vec2 coord) {
    return fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
}
