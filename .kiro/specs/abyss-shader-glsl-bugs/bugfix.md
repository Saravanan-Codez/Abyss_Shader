# Bugfix Requirements Document

## Introduction

Three confirmed rendering bugs in the Abyss Shader GLSL pipeline affect TAA temporal anti-aliasing, underwater refraction, and water wave animation. The bugs cause visible smearing/doubling artefacts during camera movement, incorrect refraction geometry on water surfaces, and completely suppressed wave animation on most biomes. All three bugs are in separate shader files and are independent of each other.

## Bug Analysis

### Current Behavior (Defect)

**Bug 1 — TAA Camera Delta Inverted (`deferred.fsh`)**

1.1 WHEN the player moves the camera between frames THEN the system adds the camera movement delta instead of subtracting it, projecting the reprojected UV in the wrong direction
1.2 WHEN TAA reprojection is active and the player is moving THEN the system produces ghosting/smearing artefacts in the opposite direction of travel because `prevPlayerPos = playerPos + (cameraPosition - previousCameraPosition)` overshoots the previous camera origin instead of arriving at it

**Bug 2 — Water Refraction Depth Test Inverted (`composite.fsh`)**

1.3 WHEN a water surface pixel is rendered and the refracted coordinate samples geometry that is deeper than the water surface (i.e., valid underwater terrain) THEN the system rejects that sample with `refractedDepth < depth`, because deeper geometry has a *larger* depth value
1.4 WHEN the refracted coordinate samples geometry that is in front of the water surface (closer to camera than the water) THEN the system incorrectly accepts that sample as valid underwater terrain, causing wrong geometry to appear through the water

**Bug 3 — Water Wave Guard Silently Fails (`gbuffers_water.vsh`)**

1.5 WHEN water geometry is rendered in any standard biome where the vertex colour blue channel is not above 0.8 THEN the system skips all wave vertex displacement, producing flat, motionless water
1.6 WHEN the vertex colour heuristic `gl_Color.b > 0.8 && gl_Color.r < 0.3` is evaluated in `gbuffers_water.vsh` THEN the system suppresses wave animation because biome water tinting makes this condition false for most naturally occurring water surfaces

---

### Expected Behavior (Correct)

**Bug 1 — TAA Camera Delta**

2.1 WHEN reprojecting a world-space point to its previous-frame UV, THEN the system SHALL subtract the camera delta so that `prevPlayerPos = playerPos + (previousCameraPosition - cameraPosition)`, correctly locating the point relative to the previous frame's camera origin
2.2 WHEN TAA reprojection is active and the player is moving THEN the system SHALL produce stable, ghost-free temporal accumulation with smooth anti-aliasing

**Bug 2 — Water Refraction Depth Test**

2.3 WHEN a refracted coordinate is sampled during water rendering THEN the system SHALL only accept the sample when `refractedDepth > depth`, confirming that the sampled geometry is behind (deeper than) the water surface
2.4 WHEN the refracted coordinate samples geometry at or in front of the water surface THEN the system SHALL discard the refracted sample and leave the albedo unchanged

**Bug 3 — Water Wave Guard**

2.5 WHEN wave animation is enabled (`WAVING_LEAVES == 1`) and a vertex is processed by `gbuffers_water.vsh` THEN the system SHALL apply wave displacement to all water vertices unconditionally, because this vertex shader only processes water geometry
2.6 WHEN wave displacement is applied THEN the system SHALL animate all water surfaces uniformly regardless of biome water colour

---

### Unchanged Behavior (Regression Prevention)

3.1 WHEN TAA is disabled (`TAA_TOGGLE != 1`) THEN the system SHALL CONTINUE TO pass the current frame colour through without any reprojection
3.2 WHEN the player is stationary and TAA is active THEN the system SHALL CONTINUE TO blend history and current frame correctly, producing temporal smoothing
3.3 WHEN a water pixel's refracted coordinate samples sky (depth = 1.0) THEN the system SHALL CONTINUE TO reject the sample via the existing `refractedDepth < 1.0` guard
3.4 WHEN rendering non-water terrain geometry THEN the system SHALL CONTINUE TO apply the opaque lighting path unchanged
3.5 WHEN wave animation is disabled (`WAVING_LEAVES != 1`) THEN the system SHALL CONTINUE TO render flat, static water with no vertex displacement
3.6 WHEN bloom, godrays, fog, and shadow passes execute THEN the system SHALL CONTINUE TO function correctly and be unaffected by these three fixes

---

### Bug Condition Pseudocode

**Bug 1 — TAA Camera Delta**

```pascal
FUNCTION isBugCondition_TAA(frame)
  INPUT: frame with cameraPosition != previousCameraPosition
  OUTPUT: boolean
  RETURN cameraPosition != previousCameraPosition  // any camera movement triggers the bug
END FUNCTION

// Fix Checking
FOR ALL frames WHERE isBugCondition_TAA(frame) DO
  prevPlayerPos ← playerPos + (previousCameraPosition - cameraPosition)  // F'
  ASSERT reprojected UV maps to correct previous-frame pixel
END FOR

// Preservation Checking
FOR ALL frames WHERE NOT isBugCondition_TAA(frame) DO
  ASSERT F(frame) = F'(frame)  // stationary camera: delta = 0, both expressions equal
END FOR
```

**Bug 2 — Water Refraction Depth**

```pascal
FUNCTION isBugCondition_Refraction(refractedDepth, depth)
  INPUT: refractedDepth (sampled behind water), depth (water surface depth)
  OUTPUT: boolean
  RETURN refractedDepth > depth  // valid underwater geometry is always deeper
END FUNCTION

// Fix Checking
FOR ALL samples WHERE isBugCondition_Refraction(refractedDepth, depth) DO
  result ← use refractedCoord albedo sample  // F': accept when refractedDepth > depth
  ASSERT result shows correct underwater terrain through water
END FOR

// Preservation Checking
FOR ALL samples WHERE NOT isBugCondition_Refraction(refractedDepth, depth) DO
  ASSERT albedo remains unchanged (no spurious geometry substitution)
END FOR
```

**Bug 3 — Water Wave Guard**

```pascal
FUNCTION isBugCondition_Wave(vertex)
  INPUT: vertex processed by gbuffers_water.vsh with WAVING_LEAVES enabled
  OUTPUT: boolean
  RETURN true  // all vertices in this shader are water and should wave
END FUNCTION

// Fix Checking
FOR ALL vertices WHERE isBugCondition_Wave(vertex) AND WAVING_LEAVES == 1 DO
  result ← apply wave displacement unconditionally  // F': no colour guard
  ASSERT position.y is displaced by sine wave
END FOR

// Preservation Checking
FOR ALL vertices WHERE WAVING_LEAVES != 1 DO
  ASSERT position is unchanged (feature toggle respected)
END FOR
```
