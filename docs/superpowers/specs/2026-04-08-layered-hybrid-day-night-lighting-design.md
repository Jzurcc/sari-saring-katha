# Layered Hybrid Day-Night Lighting System Design

**Date:** 2026-04-08
**Scope:** Enhance Sky3D postprocessing and shader parameters for a cinematic, mood-driven day-night cycle
**Current Cycle:** 30 minutes per full 24-hour day
**Target:** Distinct visual atmospheres for sunrise, midday, golden hour, dusk, and night

---

## Architecture Overview

The lighting system consists of **3 coordinated layers** that update simultaneously based on the current in-game time:

1. **Sky Shader Layer** — Shader material parameters for atmospheric effects and sky appearance
2. **Postprocessing Layer** — Environment glow, bloom, saturation, exposure adjustments
3. **Supplementary Lighting Layer** — Store interior lights that activate/dim based on time

**Flow:** `TimeOfDay` script detects time change → `TimeOfDayLighting` interpolates between keyframe states → all 3 layers update smoothly over 2-3 seconds.

---

## Time Keyframes

Six distinct visual states corresponding to real times:

### **Sunrise (5-7 AM)**
- **Mood:** Warm, soft, transitioning from night
- **Shader Parameters:**
  - `atm_sun_intensity`: 8.0 (low, sun near horizon)
  - `sun_disk_intensity`: 15.0 (visible but soft)
  - `atm_day_tint`: Color(0.95, 0.85, 0.70, 1) — warm orange/amber
  - `atm_horizon_light_tint`: Color(1.0, 0.70, 0.40, 1) — deep orange horizon
  - `starmap_color`: Color(0.5, 0.5, 0.5, 0.3) — stars fading out
  - `moon_size`: 0.07 (still visible, fading)
- **Environment:**
  - `glow_intensity`: 0.8
  - `glow_bloom`: 0.25
  - `adjustment_saturation`: 1.0
  - `ambient_light_energy`: 0.4
- **Supplementary Lights:**
  - Flickering OmniLight: `energy = 0.3` (very dim, store light not needed yet)

### **Midday (10 AM - 3 PM)**
- **Mood:** Bright, neutral, sharp definition
- **Shader Parameters:**
  - `atm_sun_intensity`: 18.0 (current value, strong sunlight)
  - `sun_disk_intensity`: 30.0 (bright disk)
  - `atm_day_tint`: Color(0.81, 0.91, 1.0, 1) — neutral white-blue
  - `atm_horizon_light_tint`: Color(0.98, 0.64, 0.46, 1) — current value
  - `starmap_color`: Color(0.7, 0.7, 0.7, 0.0) — stars invisible
  - `moon_size`: 0.0 (hidden)
- **Environment:**
  - `glow_intensity`: 1.0
  - `glow_bloom`: 0.15 (minimal bloom)
  - `adjustment_saturation`: 1.2 (rich colors)
  - `ambient_light_energy`: 0.8
- **Supplementary Lights:**
  - Flickering OmniLight: `energy = 0.0` (off, not needed)

### **Golden Hour / Late Afternoon (4-5 PM)**
- **Mood:** Rich, warm, long shadows, dramatic
- **Shader Parameters:**
  - `atm_sun_intensity`: 12.0 (lower on horizon)
  - `sun_disk_intensity`: 25.0 (prominent)
  - `atm_day_tint`: Color(1.0, 0.88, 0.65, 1) — golden amber
  - `atm_horizon_light_tint`: Color(1.0, 0.75, 0.30, 1) — deep golden
  - `starmap_color`: Color(0.7, 0.7, 0.7, 0.1) — stars barely visible
  - `moon_size`: 0.04 (faint, rising)
- **Environment:**
  - `glow_intensity`: 1.8 (high bloom/glow)
  - `glow_bloom`: 0.6 (rich atmospheric glow)
  - `adjustment_saturation`: 1.4 (ultra-saturated colors)
  - `ambient_light_energy`: 0.65
- **Supplementary Lights:**
  - Flickering OmniLight: `energy = 0.5` (warming up as sun sets)

### **Dusk (6-7 PM)**
- **Mood:** Transitional, deep purples/blues, atmospheric
- **Shader Parameters:**
  - `atm_sun_intensity`: 4.0 (very low, below horizon)
  - `sun_disk_intensity`: 0.0 (sun gone)
  - `atm_day_tint`: Color(0.60, 0.75, 1.0, 1) — cool purple-blue
  - `atm_horizon_light_tint`: Color(0.40, 0.30, 0.60, 1) — deep purple horizon
  - `starmap_color`: Color(0.8, 0.8, 0.8, 0.5) — stars visible, getting brighter
  - `moon_size`: 0.07 (visible, bright)
  - `atm_moon_mie_intensity`: 0.3 (moon glow starts)
- **Environment:**
  - `glow_intensity`: 2.0 (maximum atmospheric glow)
  - `glow_bloom`: 0.8 (maximum bloom for mood)
  - `adjustment_saturation`: 1.0 (cooler, less saturated)
  - `ambient_light_energy`: 0.3
  - `volumetric_fog_density`: 0.02 (subtle fog)
  - `volumetric_fog_anisotropy`: 0.9 (pronounced light scattering)
- **Supplementary Lights:**
  - Flickering OmniLight: `energy = 1.2` (store light fully on, warm color)
  - Add secondary light: warm "interior glow" visible through windows

### **Night (8 PM - 4 AM)**
- **Mood:** Cool moonlight, stars, mysterious, subtle
- **Shader Parameters:**
  - `atm_sun_intensity`: 0.0 (no sunlight)
  - `sun_disk_intensity`: 0.0
  - `atm_day_tint`: Color(0.0, 0.0, 0.0, 1) — black
  - `atm_night_tint`: Color(0.14, 0.39, 0.58, 1) — cool blue moonlit tone
  - `starmap_color`: Color(1.0, 1.0, 1.0, 1.0) — full star visibility
  - `star_scintillation`: 0.9 (twinkling stars)
  - `moon_size`: 0.08 (prominent, bright)
  - `atm_moon_mie_intensity`: 0.5 (moonlight glow)
- **Environment:**
  - `glow_intensity`: 0.5 (subtle, cool glow)
  - `glow_bloom`: 0.2 (minimal bloom)
  - `adjustment_saturation`: 0.75 (desaturated, cool)
  - `ambient_light_energy`: 0.15 (very dim, mostly from moon/stars)
  - `volumetric_fog_density`: 0.015 (thin atmospheric haze)
  - `volumetric_fog_sky_affect`: 0.5 (fog lit by moonlight)
- **Supplementary Lights:**
  - Flickering OmniLight: `energy = 1.5` (store light dominant, warm amber)
  - SunLight: `energy = 0.0` (disabled)
  - MoonLight: `energy = 1.0` (enabled, casting shadows)
  - Optional: NightLight adds additional ambient blue tint

### **Early Morning (4-5 AM)**
- **Mood:** Pre-dawn, cool and quiet, stars fading
- **Shader Parameters:**
  - `atm_sun_intensity`: 2.0 (sun very low on horizon, not yet visible)
  - `sun_disk_intensity`: 0.0
  - `atm_day_tint`: Color(0.50, 0.65, 0.85, 1) — cool pre-dawn blue
  - `atm_night_tint`: Color(0.10, 0.25, 0.40, 1) — softer blue tone
  - `starmap_color`: Color(0.8, 0.8, 0.8, 0.6) — stars fading
  - `moon_size`: 0.04 (small, setting)
- **Environment:**
  - `glow_intensity`: 0.6
  - `glow_bloom`: 0.15
  - `adjustment_saturation`: 0.9
  - `ambient_light_energy`: 0.2
- **Supplementary Lights:**
  - Flickering OmniLight: `energy = 0.8` (winding down as sun rises)

---

## Implementation Components

### **1. TimeOfDayLighting Script**

File: `Scripts/TimeOfDayLighting.gd`

**Responsibilities:**
- Extend or integrate with existing `TimeOfDay.gd` script
- Store keyframe data as a dictionary with time ranges as keys
- Poll current time each frame and determine which two keyframes to interpolate between
- Calculate interpolation factor (0-1) based on time within current range
- Update Sky3D environment, shader parameters, and light energies
- Manage smooth tweens for transitions (2-3 second blends)

**Key Methods:**
- `_ready()` — initialize keyframe data
- `_process()` — detect time changes, trigger interpolation
- `_interpolate_state(from_state, to_state, t: float)` — blend between states
- `_update_sky_parameters(params: Dictionary)` — apply shader parameters
- `_update_environment(env_params: Dictionary)` — apply postprocessing
- `_update_lights(light_params: Dictionary)` — adjust OmniLight, SunLight, MoonLight

### **2. Keyframe Data Structure**

Dictionary format:
```gdscript
var keyframes = {
  "sunrise": {
    "time_range": Vector2(5.0, 7.0),
    "shader": { "atm_sun_intensity": 8.0, ... },
    "environment": { "glow_intensity": 0.8, ... },
    "lights": { "omni_energy": 0.3, ... }
  },
  // ... other keyframes
}
```

### **3. Smooth Transitions**

- As time crosses from one keyframe to the next, use a Tween to smoothly blend over 2-3 seconds
- Prevents jarring snaps, makes time progression cinematic
- Each parameter eases independently (shader, environment, lights)

### **4. Supplementary Lighting Considerations**

The existing flickering OmniLight should:
- Remain mostly off during day (energy 0-0.3)
- Ramp up during golden hour (0.5)
- Be fully active at night (1.2-1.5), creating warm contrast with cool moonlight
- Maintain its existing flicker script behavior but scaled by energy multiplier

---

## Integration Points

### **With Existing TimeOfDay.gd**
- Hook into the time change events/signals if available
- Or poll `current_time` each frame in `_process()`

### **With Sky3D WorldEnvironment**
- Access `environment` property to update `glow_intensity`, `glow_bloom`, `ambient_light_energy`, etc.
- Modify shader material parameters via `environment.sky.sky_material.set_shader_parameter()`

### **With Existing Lights**
- Modify `SunLight.light_energy`, `MoonLight.light_energy`, `MoonLight.light_color`
- Modify `OmniLight3D.light_energy` and optionally `light_color`
- Ensure `NightLight.gd` is aware of sky state for consistent blue ambient tone

---

## Testing & Iteration

**Phase 1: Parameter Baseline**
- Implement keyframe data and interpolation logic
- Test each keyframe in isolation (freeze time on each state, verify visuals)
- Adjust shader parameters until each mood is visually distinct

**Phase 2: Transition Smoothness**
- Enable full cycle, watch 30-minute progression
- Verify smooth blends between keyframes
- Adjust tween duration if transitions feel too fast/slow

**Phase 3: Polish**
- Fine-tune individual parameters based on in-engine appearance
- Ensure no extreme bloom/saturation spikes that look unnatural
- Verify store lights tell the right story (dim at day, prominent at night)

---

## Success Criteria

- ✓ Each time of day (sunrise, midday, golden hour, dusk, night) has visually distinct mood
- ✓ Transitions between states are smooth (no jarring snaps)
- ✓ Daytime has sharp definition, rich colors, dramatic shadows
- ✓ Nighttime emphasizes moonlight, stars, cool tones, deep shadows
- ✓ Golden hour and dusk feel warm, atmospheric, cinematic
- ✓ 30-minute cycle completes without artifacts or parameter popping
- ✓ Store lighting (OmniLight) tells narrative: off during day, on at night

---

## Risks & Mitigation

| Risk | Mitigation |
|------|-----------|
| Parameter values too extreme, visual artifacts | Test incrementally; use reference images from existing scenes |
| Transitions feel jarring if tween too fast | Start with 3-second tweens, reduce if needed |
| Bloom/glow values cause performance issues | Monitor FPS; reduce `glow_bloom` if needed |
| Shader parameters conflict (e.g., sun intensity vs. day tint) | Test in editor before committing to implementation |

---

## Files to Modify/Create

- **Create:** `Scripts/TimeOfDayLighting.gd` — main implementation
- **Reference:** `Scripts/TimeOfDay.gd` — for time polling
- **Reference:** `Scripts/NightLight.gd` — for night ambient lighting coordination
- **Reference:** `Scenes/MainGame.tscn` — environment and shader parameters (read-only for reference)

---

## Notes

- All shader parameters reference the existing `SkyMaterial.gdshader` from the Sky3D addon
- Postprocessing values are applied to the `Environment` resource already in use
- The system is designed to run every frame with minimal additional CPU cost (just tweens and parameter updates)
- Future enhancement: allow players to adjust cycle speed in-game settings
