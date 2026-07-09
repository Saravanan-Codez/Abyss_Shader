# Abyss Shader

Abyss Shader is a modular, high-performance, professional-grade Minecraft shader pack designed for modern rendering engines like **Iris / Sodium** and legacy **OptiFine** loaders. It is built using `#version 150 compatibility` to ensure maximum platform compatibility while maintaining robust rendering features.

---

## 🌟 Key Features

*   **Soft Shadows (PCF):** Dynamic shadow mapping generated from the sun/moon's perspective with 4-tap Percentage-Closer Filtering (PCF) to smooth out jagged pixelated edges.
*   **Vibrant Downsampled Bloom:** Fast, optimized neighborhood-sampled bloom in the final post-processing pass to make light sources and glowing blocks visually "pop".
*   **Water Fresnel Reflections:** Dynamically adjusts the water surface color based on the viewing angle (fresnel equation), simulating natural reflective characteristics.
*   **Smooth Atmospheric Color Grading:** A transition curve that smoothly shifts between warm golden tones during the day and cool blue tones at night/inside caves without abrupt lighting lines.
*   **Highly Optimized Baseline:** Strict execution of alpha culling (`discard`) and simple exposure multipliers instead of expensive `pow()` curves inside standard G-buffer shaders to preserve high FPS.
*   **Comprehensive Geometry Coverage:** Complete pipeline shaders for terrain, transparent water, player hand, entities (mobs/banners/signs), block entities (chests), and basic sky rendering.

---

## 📂 Directory Layout

```text
Abyss_Shader/
│
├── shaders/
│   ├── lang/
│   │   └── en_us.lang             # Translation and GUI config settings
│   ├── gbuffers_terrain.vsh/.fsh  # Opaque blocks, texture/lightmap mapping
│   ├── gbuffers_water.vsh/.fsh    # Translucent water pass + Fresnel reflection
│   ├── gbuffers_entities.vsh/.fsh # Mobs, signs, and banner shading
│   ├── gbuffers_hand.vsh/.fsh     # Player hand model shading
│   ├── gbuffers_block.vsh/.fsh    # Dynamic block entities (chests, etc.)
│   ├── gbuffers_skybasic.vsh/.fsh # Sky dome rendering
│   ├── shadow.vsh/.fsh            # Shadow depth map generation passes
│   ├── composite.vsh/.fsh         # 3D Depth reconstruction & PCF Shadow composite pass
│   ├── composite1.vsh/.fsh        # Secondary composite pass (translucent lighting)
│   ├── deferred.vsh/.fsh          # Post-processing staging pass
│   ├── final.vsh/.fsh             # Final screen pass + Bloom + Tonemapping
│   ├── shaders.settings           # Shader configuration parameters
│   └── shaders.txt                # Metadata options configuration
│
├── builds/                        # Compiled .zip build outputs
├── Build-ShaderPack.ps1           # Automation build/deploy PowerShell script
├── pack.mcmeta                    # Resource pack metadata for Minecraft
└── version.txt                    # Project version indicator
```

---

## ⚙️ Feature Toggles

To give you total control over the balance between performance and visual fidelity, key features can be toggled on/off using macros directly inside the shader files:

*   **Soft Shadows:** Toggle `#define SHADOW_BLUR_ON` inside [composite.fsh](file:///d:/Falkon_labs/Abyss_Shader/shaders/composite.fsh) to switch between soft PCF shadows and crisp binary hard shadows.
*   **Vibrant Bloom:** Toggle `#define BLOOM_ON` inside [final.fsh](file:///d:/Falkon_labs/Abyss_Shader/shaders/final.fsh) to toggle the bloom glow filter.

---

## 🛠️ Installation & Workflow Automation

This repository includes a utility script **`Build-ShaderPack.ps1`** to compile the shaders and automatically deploy them to your local Minecraft directory.

### Build and Package:
Open a PowerShell terminal at the root of the project folder and run:
```powershell
.\Build-ShaderPack.ps1
```
This generates a version-incremented `.zip` archive inside the `builds/` directory.

### Build & Auto-Deploy directly to Minecraft:
To bypass drag-and-dropping the file manually, run:
```powershell
.\Build-ShaderPack.ps1 -Deploy
```
This script will:
1. Compile the zip.
2. Scan your `%APPDATA%\.minecraft\shaderpacks` directory.
3. Automatically delete old iterations of `Abyss_Shader_*.zip`.
4. Copy the fresh build directly into your game files.
5. In Minecraft, press **F3 + R** to immediately reload the shaders and view your changes!
