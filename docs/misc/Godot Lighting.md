# Godot 4 Lighting Guide

Based on the official comprehensive Godot 4 lighting tutorials, here is a structured summary of everything you need to know about lighting in Godot 4:

## 1. Introduction to Lighting

Lighting is a powerful tool to define the aesthetic of a game. A simple scene can be made captivating with good lighting, and the artistic direction (like day vs. night) lives or dies by its light setup.

## 2. Basic Scene Setup

By default, the Godot editor uses a preview sun and environment. To light a scene from scratch and have full control:

1. **Disable Preview Sun and Environment**: Click the sun and environment icons in the top bar of the 3D viewport.
2. **Add a WorldEnvironment Node**:
   - Set the `Background Mode` to `Custom Color` and choose black.
   - Disable default settings like `Glow` to ensure the scene starts completely pitch dark.

## 3. Light Nodes in Godot

Godot provides three primary physical 3D light nodes:

- **DirectionalLight3D**: Shines light onto the entire scene from a specific direction. It's infinite and uniform. Often used as a Sun or Moon.
  - *Setting*: Use `Max Distance` under Directional Shadow to optimize how far away shadows are cast and save performance.
- **OmniLight3D**: Emits light outwards from a specific point in a radius (e.g., a light bulb, a floating orb).
  - *Settings*: Has `Range` and `Attenuation` (how fast the light falls off/fades). An attenuation of 2 is physically accurate.
- **SpotLight3D**: Emits a cone of light in the direction it's pointing (e.g., a flashlight, window beam).
  - *Settings*: Has `Angle` (width of the cone) and `Angle Attenuation`.
  - *Trick*: You can place a Texture in the `Projector` slot of a spotlight to cast silhouettes (e.g., projecting a window-pane shadow onto a wall).

**Common Settings across lights:**

- **Shadows**: Toggle on/off to cast shadows. (For soft/fuzzy shadows, go to `Project > Project Settings > Advanced Settings > Lights and Shadows` and increase `Soft Shadow Filter Quality`).
- **Energy**: The intensity or brightness of the light.
- **Size**: Increasing the size simulates a larger light source (like a fluorescent tube instead of a tiny LED). This softens shadows and enlarges the light visible in reflections. *Note: this has a performance cost.*

## 4. Environment Lighting

The `WorldEnvironment` node contributes light globally.

- **Ambient Light**: A constant amount of base light added to the scene globally. You can adjust its source (e.g., grabbing light heavily from a Sky texture) and energy independently.
- **Reflected Light**: Sky textures and ambient environment light globally affect reflective objects.
- *Note*: Environment light affects all geometry across the whole scene. If you want specific areas to remain pitch black (like a dungeon beneath a sunny overworld), rely on other methods or Reflection Probes set to `Interior`.

## 5. Lighting as an Art Form

Placement and shadows drastically affect the mood:

- **Drama and Shadows**: Harsh shadows, strong contrast, and uneven lighting create an atmosphere of mystery or tension (e.g., action thrillers, horror). Soft lighting with minimal shadows feels open and inviting (e.g., romantic comedies, peaceful villages).
- **Three-Point Lighting**:
    1. **Key Light**: The main light illuminating the subject (e.g., the Sun outdoors, or a heavy lamp indoors).
    2. **Fill Light**: A less powerful light that softens contrast by brightening the darkest shadowed areas. Environment ambient light often acts as a fill.
    3. **Rim Light (Backlight)**: Shines from behind the subject to define shapes and separate the subject from the background. Often uses a contrasting cool/warm color.

## 6. Emissive Materials & Glow

To make an object look like a light source (like lava, neon signs, or light bulb glass):

1. **StandardMaterial3D**: In the material, enable `Emission`, pick a color multiplier, and increase the energy.
2. **Glow Effect (Post-Processing)**: Emissive surfaces won't physically "glow" with a halo unless you use post-processing.
    - In the `WorldEnvironment` node, enable `Glow`.
    - Change the `Blend Mode` from Softlight to `Screen`.
    - Adjust the unscaled/scaled levels to control halo bloom sizes.
    - Use the `HDR Threshold` slider so only *very bright* spots glow, leaving average brightness spots alone.
3. *Note:* Emissive materials typically do not cast real-time light onto their surroundings unless you are using Global Illumination (GI). Without GI, you need to place a hidden `OmniLight3D` nearby to sell the effect.

## 7. Fog

Fog softens transitions, blends distant geometry with the sky backdrop, and sells atmospheric scale.

- **Standard Fog**: Found under `WorldEnvironment > Fog`. Highly performant. Used to fade distant objects into a solid color based on depth or height (e.g., hiding render limits, creating a dark claustrophobic void).
- **Volumetric Fog**: Scatters light dynamically through volumes. Very realistic but more expensive. Lights shining through the fog (like a green dungeon light) will illuminate the mist in full 3D, creating god rays.

## 8. Global Illumination (GI)

GI simulates realistic indirect bounce lighting, where light hits an object, adopts its color, and bounces off to brighten shadows naturally. Godot provides several methods, ranging from cheap fakes to accurate physical renders:

### Faking GI (Cheap & Fast)

- **Environment Light**: Simplest real-time fake. Brightens all shadows uniformly.

- **Reflection Probes**: Localized fake. Renders a 360-degree cubemap of its surroundings to apply appropriate ambient light and reflections *only* within its defined box. Crucial for indoor rooms. Highly performant.

### True GI Solutions

Decide beforehand if meshes in your scene are `Static` (don't move) or `Dynamic`.

#### 1. SDFGI (Signed Distance Field GI)

- **Pros**: Truly "plug-and-play." Takes one click to turn on. Requires absolutely no baking. Handles reflections automatically. Updates correctly as the camera moves.

- **Cons**: Very prone to light leaking (light spilling through walls) and visible cascade popping as the camera shifts. Heavy on the GPU at runtime. Dynamic objects can receive GI but cannot contribute to it.
- **Best For**: Open-world or highly textured outdoor scenes where leaks and artifacts are hidden. Fast prototyping.

#### 2. VoxelGI

- **Pros**: highly dynamic. Bounces respond instantly to light changes (e.g., swinging a torch or changing a light color). Supports quality adjustment via subdivision settings. Allows you to tweak the baked data manually.

- **Cons**: Requires an initial bake. Heavily prone to light leaking (e.g., thin walls). Moderate-to-high runtime performance cost.
- **Best For**: Medium-sized dynamic scenes, modular outdoor environments.

#### 3. LightmapGI

- **Pros**: Flawless performance—baking the light removes almost all runtime cost for static lights. Delivers the absolute best-looking, smoothest, most physically realistic shadow bounces. Generating Probes allows moving actors (Dynamic) to smoothly sample the baked environment lighting.

- **Cons**: The longest prep and baking process. Completely static—if you move a wall or a baked light, you must completely re-bake. Requires UV2 unwrapping.
- **Workflow Tips**:
  - All baked meshes require a dedicated second UV layer map. (Select Mesh -> `Unwrap UV2 for Lightmap`, or use Import settings -> `Static Lightmaps`).
  - Use `Super Sampling` for final bakes to vastly reduce noise/artifacts at the cost of bake time (but 0 extra runtime cost).
  - If you have a blinking/flickering light, bake the surrounding static lamps, but omit the flickering light from baking so it stays real-time.

## 9. Screen Space Effects

Enable these cleanly in `WorldEnvironment` for final polish:

- **SSAO (Screen Space Ambient Occlusion)**: Adds dark, heavy shadowing where geometry intersects, grounding objects instead of letting them look floaty.
- **SSIL (Screen Space Indirect Lighting)**: Enhances small-scale bright bounce lighting details. Pairs well as a booster to a GI solution.
- **SSR (Screen Space Reflections)**: Computes accurate micro-reflections for surfaces actively visible on the screen (great for wet floors and puddles).
