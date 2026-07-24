# Abyss Shader GLSL Rendering Bugs — Bugfix Design

## Overview

This document formalizes the fix for three independent GLSL rendering bugs affecting TAA temporal anti-aliasing, water refraction depth testing, and water wave animation. Each bug is a single-line or minimal surgical change requiring no refactoring, new abstractions, or new files.

**Bug 1 — TAA Camera Delta Inverted**: `deferred.fsh` line 42 incorrectly adds camera delta instead of subtracting, causing ghosting during movement.

**Bug 2 — Water Refraction Depth Test Inverted**: `composite.fsh` line 128 incorrectly accepts geometry in front of water surface instead of behind it.

**Bug 3 — Water Wave Animation Suppressed**: `gbuffers_water.vsh` lines 14-18 use an unreliable colour heuristic that silently suppresses wave animation for most biomes.

All three fixes are minimal, targeted, and preserve all existing behaviour for non-buggy inputs.

## Glossary

- **Bug_Condition (C)**: The condition that triggers each bug (camera movement for Bug 1, valid underwater refraction for Bug 2, any water vertex for Bug 3)
- **Property (P)**: The desired correct behavior (correct TAA reprojection, correct refraction depth guard, unconditional wave displacement)
- **Preservation**: Existing behaviors that must remain unchanged (stationary camera TAA, sky rejection in refraction, wave toggle, all other rendering passes)
- **reprojectUV**: Function in `deferred.fsh` that transforms a current-frame pixel coordinate to its previous-frame UV location for TAA
- **prevPlayerPos**: World-space position of a point in the previous frame's coordinate system
- **cameraPosition, previousCameraPosition**: Uniforms tracking current and previous frame camera positions for delta calculation
- **refractedDepth**: Depth value sampled at a refracted UV coordinate during water rendering
- **depth**: Depth value of the water surface pixel itself
- **WAVING_LEAVES**: Preprocessor toggle (0 or 1) controlling wave animation feature
- **gbuffers_water.vsh**: Vertex shader that processes ONLY water geometry (not leaves, not terrain)

## Bug Details

### Bug 1 — TAA Camera Delta Inverted

The bug manifests when the player moves the camera between frames, causing `reprojectUV()` to project the pixel in the wrong direction. The expression `playerPos + (cameraPosition - previousCameraPosition)` computes how far the camera has moved forward from the previous position, then adds it to the current point — overshooting the previous camera origin rather than arriving at it.

**Formal Specification:**
```
FUNCTION isBugCondition_TAA(frame)
  INPUT: frame of type ShaderUniforms
  OUTPUT: boolean

  RETURN cameraPosition != previousCameraPosition
         // Any camera movement triggers the bug; a zero delta means both
         // expressions are equivalent so a stationary camera is not affected.
END FUNCTION
```

**Examples:**
- Player moves right one block: `prevPlayerPos` is displaced 2 blocks to the right instead of returning to the previous origin → history sample is off-screen or misaligned → ghosting
- Player rotates view: camera position may be constant but `reprojectUV` is also called for all on-screen pixels; combined movement causes smearing
- Player stationary: `cameraPosition == previousCameraPosition`, delta = 0, both the buggy and fixed expressions are identical → no artefact visible

### Bug 2 — Water Refraction Depth Test Inverted

The bug manifests when a water surface pixel is rendered and the refracted coordinate samples geometry that is correctly behind the water surface (deeper). Because depth buffer values increase with distance, valid underwater terrain has `refractedDepth > depth`. The buggy guard `refractedDepth < depth` rejects these valid samples and accepts invalid ones (geometry in front of the water surface).

**Formal Specification:**
```
FUNCTION isBugCondition_Refraction(refractedDepth, depth)
  INPUT: refractedDepth (float, [0, 1]), depth (float, water surface depth)
  OUTPUT: boolean

  RETURN refractedDepth < 1.0               // not sky
         AND refractedDepth > depth          // geometry is BEHIND the water surface
         // These are the samples that SHOULD be accepted (bug: they are rejected)
END FUNCTION
```

**Examples:**
- Refracted coord samples a stone floor 2m below: `refractedDepth (0.92) > depth (0.85)` → correct underwater geometry. Buggy code rejects it, fixed code accepts it.
- Refracted coord samples a chest on the water bank closer to camera: `refractedDepth (0.80) < depth (0.85)` → geometry in front of water. Buggy code accepts it, fixed code rejects it.
- Refracted coord samples sky: `refractedDepth = 1.0` → both buggy and fixed code reject via the first `< 1.0` guard.

### Bug 3 — Water Wave Animation Suppressed

The bug manifests for every water vertex processed by `gbuffers_water.vsh` when `WAVING_LEAVES == 1`. The colour guard `gl_Color.b > 0.8 && gl_Color.r < 0.3` was copied from a general geometry shader where a colour heuristic is needed to identify leaves versus other blocks. In `gbuffers_water.vsh`, which exclusively processes water geometry, this guard is both unnecessary and harmful — most naturally biome-tinted water surfaces fail the blue-channel test.

**Formal Specification:**
```
FUNCTION isBugCondition_Wave(vertex)
  INPUT: vertex processed by gbuffers_water.vsh, WAVING_LEAVES compile-time flag
  OUTPUT: boolean

  RETURN WAVING_LEAVES == 1
         AND NOT (gl_Color.b > 0.8 AND gl_Color.r < 0.3)
         // All vertices reaching this shader are water. The colour guard
         // is always a false restriction — any vertex that fails it is a bug.
END FUNCTION
```

**Examples:**
- Forest biome water (greenish tint): `gl_Color.b ≈ 0.62`, guard fails → no wave displacement → flat water
- Default biome water (slight blue): `gl_Color.b ≈ 0.75`, guard fails → flat water
- Exactly deep ocean water (pure blue, rare): `gl_Color.b = 0.85`, guard passes → waves visible
- `WAVING_LEAVES == 0`: entire block compiled out → no bug, static water (intended behaviour)

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- TAA with a stationary camera must continue to blend history and current frame correctly for temporal smoothing
- TAA when disabled (`TAA_TOGGLE != 1`) must continue to pass the current frame colour through without reprojection
- Water refraction when sampling sky (`refractedDepth = 1.0`) must continue to be rejected by the existing `< 1.0` guard
- Water refraction when disabled (`REFRACTION_TOGGLE` if present) or for opaque terrain must continue to work unchanged
- Water wave animation when disabled (`WAVING_LEAVES != 1`) must continue to render flat, static water
- All rendering for non-water geometry (terrain, entities, sky, particles) must continue to execute unchanged
- Bloom, godrays, fog, shadow projection, SSAO, and tone-mapping must continue to function correctly

**Scope:**
All inputs that do NOT involve the three specific bug conditions should be completely unaffected by these fixes. This includes:
- Bug 1: any frame where the camera is stationary (`cameraPosition == previousCameraPosition`)
- Bug 2: any refracted sample that points to sky or geometry in front of the water surface
- Bug 3: any water vertex when `WAVING_LEAVES` is disabled, and all non-water geometry

## Hypothesized Root Cause

Based on the confirmed bug manifestations and manual inspection of the shader code:

1. **Bug 1 — TAA Camera Delta**: The expression was written as if transforming a point *in camera space* by the camera delta, but the calculation occurs *after* transforming to player (world) space. Player space is world-relative and stationary, so the correction must undo the camera movement rather than amplify it. The delta sign is inverted — `(cameraPosition - previousCameraPosition)` should be `(previousCameraPosition - cameraPosition)`.

2. **Bug 2 — Water Refraction Depth**: The guard was written with the mental model that "smaller depth = behind the surface" (as in Z-axis ordering), but depth buffer values increase with distance. Valid underwater geometry always has a *larger* depth value than the water surface. The comparison is backwards — `refractedDepth < depth` should be `refractedDepth > depth`.

3. **Bug 3 — Water Wave Guard**: The colour heuristic `gl_Color.b > 0.8 && gl_Color.r < 0.3` was copied from a general-purpose shader that processes mixed geometry (leaves, terrain, etc.). In `gbuffers_water.vsh`, which is bound exclusively to water blocks by Optifine's block ID mapping, the guard is a non-functional safety check. Because biome water tinting modulates the blue channel downward, the guard silently fails for most water surfaces. The fix is to remove the guard entirely.

## Correctness Properties

Property 1: Bug Condition — TAA Reprojection Correctness

_For any_ frame where the camera moves (cameraPosition ≠ previousCameraPosition), the fixed reprojectUV function SHALL compute prevPlayerPos using the inverted camera delta `prevPlayerPos = playerPos + (previousCameraPosition - cameraPosition)`, correctly locating the pixel's previous-frame UV and producing stable temporal anti-aliasing without ghosting or smearing.

**Validates: Requirements 2.1, 2.2**

Property 2: Bug Condition — Water Refraction Depth Test Correctness

_For any_ refracted coordinate sampled during water rendering where the sampled geometry is behind the water surface (refractedDepth > depth) and not sky (refractedDepth < 1.0), the fixed refraction guard SHALL accept the sample and use the refracted albedo, correctly displaying underwater terrain through the water wave distortion.

**Validates: Requirements 2.3, 2.4**

Property 3: Bug Condition — Water Wave Displacement Unconditional

_For any_ water vertex processed by gbuffers_water.vsh when wave animation is enabled (WAVING_LEAVES == 1), the fixed vertex shader SHALL apply wave displacement unconditionally using `position.y += sin(...)`, animating all water surfaces uniformly regardless of biome water colour.

**Validates: Requirements 2.5, 2.6**

Property 4: Preservation — TAA Stationary Camera Unchanged

_For any_ frame where the camera is stationary (cameraPosition == previousCameraPosition), the fixed TAA code SHALL produce exactly the same behaviour as the original code, because the camera delta is zero and both `playerPos + (cameraPosition - previousCameraPosition)` and `playerPos + (previousCameraPosition - cameraPosition)` are equivalent.

**Validates: Requirements 3.1, 3.2**

Property 5: Preservation — Water Refraction Non-Buggy Inputs

_For any_ refracted coordinate that samples sky (refractedDepth = 1.0) or geometry in front of the water surface (refractedDepth ≤ depth), the fixed refraction guard SHALL produce the same rejection behavior as the original code, leaving the albedo unchanged.

**Validates: Requirements 3.3, 3.4**

Property 6: Preservation — Water Wave Toggle Respected

_For any_ water vertex when wave animation is disabled (WAVING_LEAVES != 1), the fixed vertex shader SHALL produce the same flat, static water as the original code, because the entire wave block is compiled out by the preprocessor.

**Validates: Requirements 3.5, 3.6**

## Fix Implementation

### Changes Required

All three fixes are surgical single-line changes. No new functions, no new includes, no refactoring.

---

**Fix 1**

**File**: `shaders/deferred.fsh`

**Function**: `reprojectUV(vec2 uv, float depth)`

**Line**: 42 (the `vec3 prevPlayerPos` assignment)

**Specific Change**:
- **Invert camera delta operand order**: Replace `(cameraPosition - previousCameraPosition)` with `(previousCameraPosition - cameraPosition)`

Before:
```glsl
vec3 prevPlayerPos = playerPos + (cameraPosition - previousCameraPosition);
```
After:
```glsl
vec3 prevPlayerPos = playerPos + (previousCameraPosition - cameraPosition);
```

**Why this is the minimal correct fix**: The only semantic error is the operand order. The function structure, uniform names, coordinate space chain (`viewPos → playerPos → prevPlayerPos → prevClip → prevUV`), and history-blending logic are all correct. Swapping the two operands inverts the delta from "how far we moved forward" to "how far we must step back", which is exactly what is needed to locate the point in the previous frame.

---

**Fix 2**

**File**: `shaders/composite.fsh`

**Block**: Water refraction guard inside `if (materialID > 0.5)`, approximately line 128

**Specific Change**:
- **Invert depth comparison operator**: Replace `refractedDepth < depth` with `refractedDepth > depth`

Before:
```glsl
if (refractedDepth < 1.0 && refractedDepth < depth) {
```
After:
```glsl
if (refractedDepth < 1.0 && refractedDepth > depth) {
```

**Why this is the minimal correct fix**: The two-part guard is semantically correct in structure — reject sky, accept only valid underwater geometry. Only the comparison direction is wrong. The first operand (`refractedDepth < 1.0`) correctly rejects sky. Changing `<` to `>` in the second operand correctly accepts geometry that is deeper (further behind the camera) than the water surface.

---

**Fix 3**

**File**: `shaders/gbuffers_water.vsh`

**Block**: `#if WAVING_LEAVES == 1` block, lines 14–18

**Specific Change**:
- **Remove the unreliable colour guard**: Delete the `if (gl_Color.b > 0.8 && gl_Color.r < 0.3)` branch and its closing brace, leaving the wave displacement as the unconditional body of the `#if` block

Before:
```glsl
#if WAVING_LEAVES == 1
    if (gl_Color.b > 0.8 && gl_Color.r < 0.3) {
        float time = frameTimeCounter * 3.0;
        position.y += sin(time + position.x * 2.0 + position.z * 2.0) * 0.05;
    }
#endif
```
After:
```glsl
#if WAVING_LEAVES == 1
    float time = frameTimeCounter * 3.0;
    position.y += sin(time + position.x * 2.0 + position.z * 2.0) * 0.05;
#endif
```

**Why this is the minimal correct fix**: The wave computation itself is correct. The outer `#if WAVING_LEAVES == 1` toggle correctly controls the feature. Only the inner `if` branch needs removal. No changes are required to the displacement formula, the `frameTimeCounter` uniform, or any other shader.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach for each bug: first, surface counterexamples that demonstrate the bug on unfixed code (exploratory), then verify the fix works correctly (fix checking) and preserves existing behavior (preservation checking).

All three bugs are in rendering code, so testing will use a combination of manual in-game observation and shader output analysis. Property-based testing using automated random inputs is not directly applicable to GPU shader pipelines, so the emphasis is on carefully designed manual test cases covering the input domain.

---

### Bug 1 — TAA Camera Delta

#### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the ghosting/smearing artefact BEFORE implementing the fix. Confirm that camera movement causes visible TAA artefacts.

**Test Plan**: Load the shader pack in Minecraft with TAA enabled (`TAA_TOGGLE == 1`). Move the camera in various patterns and observe for ghosting, smearing, or double-image artefacts in the opposite direction of travel. Capture screenshots or video to document the bug manifestation.

**Test Cases**:
1. **Horizontal Pan**: Look left/right while stationary → observe smearing on vertical edges (trees, walls) lagging behind the movement (will fail on unfixed code)
2. **Forward Sprint**: Move forward rapidly through a forest → observe tree trunks doubling or smearing backwards (will fail on unfixed code)
3. **Quick Rotation**: Spin view 180° rapidly → observe the entire scene ghosting in the rotation direction (will fail on unfixed code)
4. **Stationary View**: Stand completely still for 10 seconds → observe clean, stable image with no ghosting (should pass on unfixed code because camera delta = 0)

**Expected Counterexamples**:
- Ghosting/smearing visible during all camera movement
- Possible causes: inverted reprojection delta, incorrect UV calculation, broken history sampling

#### Fix Checking

**Goal**: Verify that for all frames where the camera moves, the fixed TAA code produces stable, ghost-free temporal accumulation.

**Pseudocode:**
```
FOR ALL frames WHERE cameraPosition != previousCameraPosition DO
  result := reprojectUV_fixed(vTexCoord, depth)
  ASSERT result.xy maps to correct previous-frame pixel location
  ASSERT no ghosting or smearing visible on screen
END FOR
```

**Test Cases**:
1. Repeat all four exploratory test cases with the fixed shader code
2. Compare side-by-side screenshots (unfixed vs fixed) for each camera movement pattern
3. Verify edges remain sharp and stable during movement

#### Preservation Checking

**Goal**: Verify that for all frames where the camera is stationary, the fixed TAA code produces the same result as the original code.

**Pseudocode:**
```
FOR ALL frames WHERE cameraPosition == previousCameraPosition DO
  ASSERT reprojectUV_original(uv, depth) = reprojectUV_fixed(uv, depth)
END FOR
```

**Test Cases**:
1. **Stationary Blend**: Stand still, observe that TAA continues to blend history and current frame smoothly (no regression)
2. **TAA Disabled**: Set `TAA_TOGGLE = 0`, verify that the shader continues to pass current-frame colour through unmodified

---

### Bug 2 — Water Refraction Depth Test

#### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate incorrect refraction geometry BEFORE implementing the fix. Confirm that water surfaces display wrong geometry.

**Test Plan**: Load the shader pack and observe water surfaces from various angles, looking through the water at underwater terrain. Note any cases where the refracted view shows geometry that is clearly not underwater (e.g., blocks on the shoreline appearing through the water).

**Test Cases**:
1. **Underwater Floor**: Stand at water surface, look down at stone floor 2m below → observe whether refracted view shows the correct underwater terrain (will fail on unfixed code — floor rejected, fallback to unrefracted)
2. **Shoreline Geometry**: Stand in shallow water, look at a chest on the bank → observe whether the chest incorrectly appears through the water surface (will fail on unfixed code — chest accepted as valid underwater terrain)
3. **Sky Reflection**: Look at water surface from above at a shallow angle → observe whether sky reflection is correctly preserved (should pass on both unfixed and fixed code via the `< 1.0` guard)

**Expected Counterexamples**:
- Underwater terrain not visible through refracted water (rejected by buggy `< depth` guard)
- Shoreline geometry bleeding through water surface (accepted by buggy `< depth` guard)
- Possible causes: inverted depth comparison, wrong coordinate clamping

#### Fix Checking

**Goal**: Verify that for all refracted samples where the sampled geometry is behind the water surface, the fixed code accepts the sample and displays correct underwater terrain.

**Pseudocode:**
```
FOR ALL refractionSamples WHERE refractedDepth < 1.0 AND refractedDepth > depth DO
  result := albedo_from_refractedCoord
  ASSERT result shows correct underwater terrain through water wave distortion
END FOR
```

**Test Cases**:
1. Repeat all three exploratory test cases with the fixed shader code
2. Verify underwater terrain is correctly visible and distorted by water waves
3. Verify shoreline geometry no longer bleeds through the water surface

#### Preservation Checking

**Goal**: Verify that for all refracted samples that point to sky or geometry in front of the water surface, the fixed code produces the same rejection behavior as the original code.

**Pseudocode:**
```
FOR ALL refractionSamples WHERE refractedDepth >= 1.0 OR refractedDepth <= depth DO
  ASSERT albedo remains unchanged (refracted sample rejected)
END FOR
```

**Test Cases**:
1. **Sky Rejection**: Observe water surface reflection from shallow angle → verify sky is correctly preserved (no regression)
2. **Opaque Terrain Unchanged**: Observe rendering of non-water terrain blocks → verify no visual changes (refraction path not triggered)

---

### Bug 3 — Water Wave Animation

#### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate suppressed wave animation BEFORE implementing the fix. Confirm that most biome-tinted water surfaces are flat and motionless.

**Test Plan**: Load the shader pack with `WAVING_LEAVES = 1` enabled. Visit multiple biomes and observe water surfaces. Note which biome water displays wave animation and which is flat.

**Test Cases**:
1. **Forest Biome Water**: Observe greenish-tinted water → flat, no wave animation (will fail on unfixed code due to low blue channel)
2. **Plains Biome Water**: Observe default blue-tinted water → flat, no wave animation (will fail on unfixed code)
3. **Deep Ocean Biome Water**: Observe pure blue water → waves visible (may pass on unfixed code if colour guard succeeds)
4. **Wave Toggle Off**: Set `WAVING_LEAVES = 0`, recompile → flat water in all biomes (should pass on both unfixed and fixed code)

**Expected Counterexamples**:
- Wave animation suppressed in forest and plains biomes
- Possible causes: colour guard failing for biome-tinted water, incorrect blue channel threshold

#### Fix Checking

**Goal**: Verify that for all water vertices when `WAVING_LEAVES == 1`, the fixed code applies wave displacement unconditionally.

**Pseudocode:**
```
FOR ALL waterVertices WHERE WAVING_LEAVES == 1 DO
  result := position.y + sin(time + position.x * 2.0 + position.z * 2.0) * 0.05
  ASSERT position.y is displaced by sine wave
  ASSERT wave animation visible on screen for ALL biome water surfaces
END FOR
```

**Test Cases**:
1. Repeat all four exploratory test cases with the fixed shader code
2. Verify wave animation is uniformly visible in forest, plains, and deep ocean biomes
3. Compare side-by-side screenshots (unfixed vs fixed) for each biome

#### Preservation Checking

**Goal**: Verify that for all water vertices when `WAVING_LEAVES != 1`, the fixed code produces the same flat, static water as the original code.

**Pseudocode:**
```
FOR ALL waterVertices WHERE WAVING_LEAVES != 1 DO
  ASSERT position unchanged (entire wave block compiled out)
END FOR
```

**Test Cases**:
1. **Wave Toggle Disabled**: Set `WAVING_LEAVES = 0`, verify flat water in all biomes (no regression)
2. **Non-Water Geometry**: Observe rendering of terrain blocks, entities, particles → verify no visual changes (wave code only affects water vertices)
