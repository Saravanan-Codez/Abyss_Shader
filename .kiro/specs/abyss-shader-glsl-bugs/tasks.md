# Implementation Plan

## Bug 1 — TAA Camera Delta Inverted

- [ ] 1. Write bug condition exploration test for Bug 1 (TAA Camera Delta)
  - **Property 1: Bug Condition** - TAA Camera Movement Ghosting
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate ghosting/smearing during camera movement
  - **Manual Testing Approach**: Load shader pack in Minecraft with TAA enabled (`TAA_TOGGLE == 1`)
  - Test implementation details from Bug Condition: camera movement triggers inverted reprojection delta
  - The test assertions should match Expected Behavior: stable, ghost-free TAA
  - **Test Cases**:
    1. Horizontal Pan: Look left/right while stationary → document visible smearing on vertical edges (trees, walls) lagging behind movement
    2. Forward Sprint: Move forward rapidly through forest → document tree trunks doubling or smearing backwards
    3. Quick Rotation: Spin view 180° rapidly → document entire scene ghosting in rotation direction
    4. Stationary View (control): Stand still for 10 seconds → should show clean, stable image (passes even on unfixed code because camera delta = 0)
  - Run test on UNFIXED code (`deferred.fsh` line 42 still has `cameraPosition - previousCameraPosition`)
  - **EXPECTED OUTCOME**: Test FAILS - ghosting/smearing visible during all camera movement
  - Document counterexamples found: capture screenshots or video showing ghosting direction, intensity, and affected geometry types
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [ ] 2. Write preservation property tests for Bug 1 (BEFORE implementing fix)
  - **Property 2: Preservation** - TAA Stationary Camera Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for stationary camera (cameraPosition == previousCameraPosition)
  - Write manual test cases capturing observed TAA blending behavior
  - **Test Cases**:
    1. Stationary Blend: Stand still, observe that TAA blends history and current frame smoothly producing temporal smoothing
    2. TAA Disabled: Set `TAA_TOGGLE = 0` in `shaders.settings`, verify shader passes current-frame colour through unmodified
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (confirms baseline TAA behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2_

- [ ] 3. Fix Bug 1 — TAA Camera Delta Inverted in `deferred.fsh`

  - [ ] 3.1 Implement the fix
    - **File**: `shaders/deferred.fsh`
    - **Function**: `reprojectUV(vec2 uv, float depth)`
    - **Line**: 42 (the `vec3 prevPlayerPos` assignment)
    - **Specific Change**: Invert camera delta operand order
    - Replace: `vec3 prevPlayerPos = playerPos + (cameraPosition - previousCameraPosition);`
    - With: `vec3 prevPlayerPos = playerPos + (previousCameraPosition - cameraPosition);`
    - **Rationale**: Player space is world-relative and stationary, so the correction must undo the camera movement rather than amplify it
    - _Bug_Condition: isBugCondition_TAA(frame) where cameraPosition != previousCameraPosition_
    - _Expected_Behavior: prevPlayerPos correctly locates point in previous frame, producing stable TAA (Property 1 from design)_
    - _Preservation: Stationary camera TAA, TAA disabled mode (Property 4 from design)_
    - _Requirements: 1.1, 1.2, 2.1, 2.2, 3.1, 3.2_

  - [ ] 3.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - TAA Camera Movement Stable
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - Repeat all four test cases (horizontal pan, forward sprint, quick rotation, stationary view)
    - **EXPECTED OUTCOME**: Test PASSES - no ghosting/smearing during camera movement, edges remain sharp and stable
    - Compare side-by-side screenshots (unfixed vs fixed) for each movement pattern
    - _Requirements: 2.1, 2.2_

  - [ ] 3.3 Verify preservation tests still pass
    - **Property 2: Preservation** - TAA Stationary Camera Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run stationary blend and TAA disabled tests
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in stationary camera behavior or TAA toggle)

---

## Bug 2 — Water Refraction Depth Test Inverted

- [ ] 4. Write bug condition exploration test for Bug 2 (Water Refraction Depth)
  - **Property 1: Bug Condition** - Water Refraction Invalid Geometry
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate incorrect refraction geometry
  - **Manual Testing Approach**: Load shader pack, observe water surfaces from various angles
  - Test implementation details from Bug Condition: inverted depth comparison accepts geometry in front of water, rejects geometry behind water
  - The test assertions should match Expected Behavior: correct underwater terrain visible through water
  - **Test Cases**:
    1. Underwater Floor: Stand at water surface, look down at stone floor 2m below → document whether refracted view shows correct underwater terrain (will fail on unfixed code — floor rejected, fallback to unrefracted)
    2. Shoreline Geometry: Stand in shallow water, look at chest on bank → document whether chest incorrectly appears through water surface (will fail on unfixed code — chest accepted as valid underwater terrain)
    3. Sky Reflection (control): Look at water surface from above at shallow angle → should show sky reflection correctly (passes on both unfixed and fixed code via `< 1.0` guard)
  - Run test on UNFIXED code (`composite.fsh` line 128 still has `refractedDepth < depth`)
  - **EXPECTED OUTCOME**: Test FAILS - underwater terrain not visible, shoreline geometry bleeding through water
  - Document counterexamples found: capture screenshots showing which geometry types are incorrectly accepted/rejected
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.3, 1.4, 2.3, 2.4_

- [ ] 5. Write preservation property tests for Bug 2 (BEFORE implementing fix)
  - **Property 2: Preservation** - Water Refraction Non-Buggy Inputs
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for sky samples (refractedDepth = 1.0) and geometry in front of water
  - Write manual test cases capturing observed rejection behavior
  - **Test Cases**:
    1. Sky Rejection: Observe water surface reflection from shallow angle → verify sky is correctly preserved
    2. Opaque Terrain Unchanged: Observe rendering of non-water terrain blocks → verify no visual changes (refraction path not triggered)
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (confirms baseline sky rejection and opaque terrain rendering to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.3, 3.4_

- [ ] 6. Fix Bug 2 — Water Refraction Depth Test Inverted in `composite.fsh`

  - [ ] 6.1 Implement the fix
    - **File**: `shaders/composite.fsh`
    - **Block**: Water refraction guard inside `if (materialID > 0.5)`, line 128
    - **Specific Change**: Invert depth comparison operator
    - Replace: `if (refractedDepth < 1.0 && refractedDepth < depth) {`
    - With: `if (refractedDepth < 1.0 && refractedDepth > depth) {`
    - **Rationale**: Depth buffer values increase with distance, so valid underwater geometry always has a larger depth value than the water surface
    - _Bug_Condition: isBugCondition_Refraction(refractedDepth, depth) where refractedDepth > depth (valid underwater geometry)_
    - _Expected_Behavior: refraction guard accepts geometry behind water surface, rejects geometry in front (Property 2 from design)_
    - _Preservation: Sky rejection via `< 1.0` guard, opaque terrain unchanged (Property 5 from design)_
    - _Requirements: 1.3, 1.4, 2.3, 2.4, 3.3, 3.4_

  - [ ] 6.2 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Water Refraction Correct Geometry
    - **IMPORTANT**: Re-run the SAME test from task 4 - do NOT write a new test
    - Repeat all three test cases (underwater floor, shoreline geometry, sky reflection)
    - **EXPECTED OUTCOME**: Test PASSES - underwater terrain correctly visible and distorted by water waves, shoreline geometry no longer bleeds through
    - Compare side-by-side screenshots (unfixed vs fixed) for each viewing angle
    - _Requirements: 2.3, 2.4_

  - [ ] 6.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Water Refraction Non-Buggy Inputs
    - **IMPORTANT**: Re-run the SAME tests from task 5 - do NOT write new tests
    - Run sky rejection and opaque terrain tests
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in sky handling or opaque rendering)

---

## Bug 3 — Water Wave Guard Silently Fails (ALREADY FIXED)

- [ ] 7. Verify Bug 3 fix (Water Wave Guard) in `gbuffers_water.vsh`
  - **NOTE**: Bug 3 has already been fixed in `gbuffers_water.vsh` - the unreliable colour guard has been removed
  - **Current Code**: Lines 14-18 show unconditional wave displacement inside `#if WAVING_LEAVES == 1` block
  - **Manual Verification**: Load shader pack with `WAVING_LEAVES = 1`, visit multiple biomes
  - **Test Cases**:
    1. Forest Biome Water: Observe greenish-tinted water → verify wave animation is visible
    2. Plains Biome Water: Observe default blue-tinted water → verify wave animation is visible
    3. Deep Ocean Biome Water: Observe pure blue water → verify wave animation is visible
    4. Wave Toggle Off: Set `WAVING_LEAVES = 0`, recompile → verify flat water in all biomes (preservation check)
  - **EXPECTED OUTCOME**: Wave animation uniformly visible in all biomes when toggle is enabled, flat when disabled
  - Capture screenshots comparing multiple biomes to confirm uniform wave behavior
  - _Requirements: 1.5, 1.6, 2.5, 2.6, 3.5, 3.6_

---

## Cross-Bug Integration Testing

- [ ] 8. Checkpoint - Ensure all fixes work together
  - Load shader pack with all three fixes applied
  - Run comprehensive visual regression test across all rendering features:
    1. **TAA**: Move camera in all directions → verify stable, ghost-free anti-aliasing
    2. **Water Refraction**: Observe underwater terrain through water waves → verify correct geometry visible
    3. **Water Waves**: Visit multiple biomes → verify uniform wave animation when enabled
    4. **Bloom**: Verify bloom extraction and upsample still function correctly
    5. **Godrays**: Verify volumetric light shafts render correctly during camera movement
    6. **Fog**: Verify distance fog transitions correctly
    7. **Shadows**: Verify shadow projection and PCF still work correctly
  - Ensure all tests pass
  - If any issues arise, document them and ask the user for guidance before proceeding
