# Layered Hybrid Day-Night Lighting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a cinematic day-night lighting system that smoothly transitions through 6 time-based moods (sunrise, midday, golden hour, dusk, night, early morning) by interpolating between shader parameters, postprocessing effects, and light energies.

**Architecture:** `TimeOfDayLighting.gd` listens to TimeOfDay's `time_changed` signal, maintains keyframe states for each time period, calculates interpolation factors, and smoothly updates the Sky3D environment (shader parameters + postprocessing) and lights every frame.

**Tech Stack:** GDScript 4.x, Godot 4.x, Sky3D addon, Tween animations, TimeOfDay signals

---

## File Structure

- **Create:** `Scripts/TimeOfDayLighting.gd` — Main lighting controller; manages keyframes, interpolation, updates
- **Reference (read-only):** `Scenes/MainGame.tscn` — Attach script to Sky3D node
- **Reference (read-only):** `addons/sky_3d/src/TimeOfDay.gd` — Understand signal structure
- **Reference (read-only):** `Scripts/NightLight.gd` — Coordinate with existing night ambient light

---

## Tasks

### Task 1: Create TimeOfDayLighting Script with Keyframe Data Structure

**Files:**
- Create: `Scripts/TimeOfDayLighting.gd`

- [ ] **Step 1: Create the file and add class structure**

Create `Scripts/TimeOfDayLighting.gd` with the following content:

```gdscript
## TimeOfDayLighting manages cinematic day-night lighting progression.
## Attached to the Sky3D WorldEnvironment node.
## Listens to TimeOfDay time_changed signal and smoothly transitions
## between 6 keyframe states throughout the 24-hour cycle.
@tool
extends Node

# Reference to parent Environment for postprocessing updates
var _environment: Environment = null
var _sky_material: Material = null
var _sun_light: DirectionalLight3D = null
var _moon_light: DirectionalLight3D = null
var _omni_light: OmniLight3D = null
var _night_light: DirectionalLight3D = null
var _time_of_day: TimeOfDay = null

# Current interpolation state
var _current_from_state: String = ""
var _current_to_state: String = ""
var _current_t: float = 0.0
var _is_transitioning: bool = false
var _transition_tween: Tween = null

# Keyframe definition: each state has shader params, environment params, and light params
var _keyframes: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Find sibling nodes
	var parent = get_parent()
	if parent is WorldEnvironment:
		_environment = parent.environment
		if _environment:
			_sky_material = _environment.sky.sky_material

	# Find TimeOfDay sibling
	_time_of_day = get_parent().get_node_or_null("TimeOfDay")

	# Find lights
	_sun_light = get_parent().get_node_or_null("SunLight")
	_moon_light = get_parent().get_node_or_null("MoonLight")
	_night_light = get_parent().get_node_or_null("NightLight")

	# Find OmniLight (store light) — search in parent of parent
	var store_node = get_parent().get_parent()
	if store_node:
		var lights = store_node.find_children("*", "OmniLight3D")
		if lights.size() > 0:
			_omni_light = lights[0]

	# Initialize keyframes
	_initialize_keyframes()

	# Connect to time signals
	if _time_of_day:
		_time_of_day.time_changed.connect(_on_time_changed)
		# Set initial state
		_on_time_changed(_time_of_day.current_time)

func _initialize_keyframes() -> void:
	# Keyframes are ordered chronologically
	_keyframes = {
		"sunrise": {
			"time_range": Vector2(5.0, 7.0),
			"shader": {
				"atm_sun_intensity": 8.0,
				"sun_disk_intensity": 15.0,
				"atm_day_tint": Color(0.95, 0.85, 0.70, 1),
				"atm_horizon_light_tint": Color(1.0, 0.70, 0.40, 1),
				"starmap_color": Color(0.5, 0.5, 0.5, 0.3),
				"moon_size": 0.07,
			},
			"environment": {
				"glow_intensity": 0.8,
				"glow_bloom": 0.25,
				"adjustment_saturation": 1.0,
				"ambient_light_energy": 0.4,
			},
			"lights": {
				"sun_energy": 0.4,
				"moon_energy": 0.0,
				"omni_energy": 0.3,
				"night_energy": 0.0,
			}
		},
		"midday": {
			"time_range": Vector2(10.0, 15.0),
			"shader": {
				"atm_sun_intensity": 18.0,
				"sun_disk_intensity": 30.0,
				"atm_day_tint": Color(0.81, 0.91, 1.0, 1),
				"atm_horizon_light_tint": Color(0.98, 0.64, 0.46, 1),
				"starmap_color": Color(0.7, 0.7, 0.7, 0.0),
				"moon_size": 0.0,
			},
			"environment": {
				"glow_intensity": 1.0,
				"glow_bloom": 0.15,
				"adjustment_saturation": 1.2,
				"ambient_light_energy": 0.8,
			},
			"lights": {
				"sun_energy": 0.8,
				"moon_energy": 0.0,
				"omni_energy": 0.0,
				"night_energy": 0.0,
			}
		},
		"golden_hour": {
			"time_range": Vector2(16.0, 17.5),
			"shader": {
				"atm_sun_intensity": 12.0,
				"sun_disk_intensity": 25.0,
				"atm_day_tint": Color(1.0, 0.88, 0.65, 1),
				"atm_horizon_light_tint": Color(1.0, 0.75, 0.30, 1),
				"starmap_color": Color(0.7, 0.7, 0.7, 0.1),
				"moon_size": 0.04,
			},
			"environment": {
				"glow_intensity": 1.8,
				"glow_bloom": 0.6,
				"adjustment_saturation": 1.4,
				"ambient_light_energy": 0.65,
			},
			"lights": {
				"sun_energy": 0.65,
				"moon_energy": 0.0,
				"omni_energy": 0.5,
				"night_energy": 0.0,
			}
		},
		"dusk": {
			"time_range": Vector2(18.0, 19.5),
			"shader": {
				"atm_sun_intensity": 4.0,
				"sun_disk_intensity": 0.0,
				"atm_day_tint": Color(0.60, 0.75, 1.0, 1),
				"atm_horizon_light_tint": Color(0.40, 0.30, 0.60, 1),
				"starmap_color": Color(0.8, 0.8, 0.8, 0.5),
				"moon_size": 0.07,
				"atm_moon_mie_intensity": 0.3,
			},
			"environment": {
				"glow_intensity": 2.0,
				"glow_bloom": 0.8,
				"adjustment_saturation": 1.0,
				"ambient_light_energy": 0.3,
				"volumetric_fog_density": 0.02,
				"volumetric_fog_anisotropy": 0.9,
			},
			"lights": {
				"sun_energy": 0.0,
				"moon_energy": 0.5,
				"omni_energy": 1.2,
				"night_energy": 0.1,
			}
		},
		"night": {
			"time_range": Vector2(20.0, 4.0),
			"shader": {
				"atm_sun_intensity": 0.0,
				"sun_disk_intensity": 0.0,
				"atm_day_tint": Color(0.0, 0.0, 0.0, 1),
				"atm_night_tint": Color(0.14, 0.39, 0.58, 1),
				"starmap_color": Color(1.0, 1.0, 1.0, 1.0),
				"star_scintillation": 0.9,
				"moon_size": 0.08,
				"atm_moon_mie_intensity": 0.5,
			},
			"environment": {
				"glow_intensity": 0.5,
				"glow_bloom": 0.2,
				"adjustment_saturation": 0.75,
				"ambient_light_energy": 0.15,
				"volumetric_fog_density": 0.015,
				"volumetric_fog_sky_affect": 0.5,
			},
			"lights": {
				"sun_energy": 0.0,
				"moon_energy": 1.0,
				"omni_energy": 1.5,
				"night_energy": 0.3,
			}
		},
		"early_morning": {
			"time_range": Vector2(4.0, 5.0),
			"shader": {
				"atm_sun_intensity": 2.0,
				"sun_disk_intensity": 0.0,
				"atm_day_tint": Color(0.50, 0.65, 0.85, 1),
				"atm_night_tint": Color(0.10, 0.25, 0.40, 1),
				"starmap_color": Color(0.8, 0.8, 0.8, 0.6),
				"moon_size": 0.04,
			},
			"environment": {
				"glow_intensity": 0.6,
				"glow_bloom": 0.15,
				"adjustment_saturation": 0.9,
				"ambient_light_energy": 0.2,
			},
			"lights": {
				"sun_energy": 0.1,
				"moon_energy": 0.3,
				"omni_energy": 0.8,
				"night_energy": 0.0,
			}
		},
	}

func _on_time_changed(time: float) -> void:
	# Determine which keyframes we're between
	var next_state = _get_current_keyframe_pair(time)

	if next_state.from_state != _current_from_state or next_state.to_state != _current_to_state:
		# State transition detected, start tween
		_start_transition(next_state.from_state, next_state.to_state, next_state.t)

func _get_current_keyframe_pair(time: float) -> Dictionary:
	# Determine which two keyframes to interpolate between
	# Returns {"from_state": str, "to_state": str, "t": float(0-1)}

	var sorted_times: Array = []
	for state_name in _keyframes.keys():
		sorted_times.append({"name": state_name, "start": _keyframes[state_name]["time_range"].x})
	sorted_times.sort_custom(func(a, b): return a["start"] < b["start"])

	# Find the current segment
	var from_idx = 0
	for i in range(sorted_times.size()):
		if time >= sorted_times[i]["start"]:
			from_idx = i

	var to_idx = (from_idx + 1) % sorted_times.size()
	var from_name = sorted_times[from_idx]["name"]
	var to_name = sorted_times[to_idx]["name"]

	var from_start = _keyframes[from_name]["time_range"].x
	var from_end = _keyframes[from_name]["time_range"].y

	# Calculate t (0-1) within this segment
	var segment_duration = from_end - from_start
	if to_idx == 0:
		# Wrapping around midnight
		segment_duration = (24.0 - from_start) + _keyframes[to_name]["time_range"].x

	var t = fmod(time - from_start, 24.0) / segment_duration
	t = clamp(t, 0.0, 1.0)

	return {"from_state": from_name, "to_state": to_name, "t": t}

func _start_transition(from_state: String, to_state: String, t: float) -> void:
	# Kill previous tween if running
	if _transition_tween:
		_transition_tween.kill()

	_current_from_state = from_state
	_current_to_state = to_state
	_is_transitioning = true

	# Smooth tween over 2.5 seconds
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(self, "_current_t", t, 2.5)
	_transition_tween.tween_callback(func(): _is_transitioning = false)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not _environment or not _sky_material or not _time_of_day:
		return

	# Update all layers based on current interpolation state
	_update_all_systems()

func _update_all_systems() -> void:
	if _current_from_state.is_empty():
		return

	var from_params = _keyframes[_current_from_state]
	var to_params = _keyframes[_current_to_state]

	_update_shader_parameters(from_params, to_params, _current_t)
	_update_environment(from_params, to_params, _current_t)
	_update_lights(from_params, to_params, _current_t)

func _update_shader_parameters(from_params: Dictionary, to_params: Dictionary, t: float) -> void:
	var from_shader = from_params["shader"]
	var to_shader = to_params["shader"]

	for param in from_shader.keys():
		var from_val = from_shader[param]
		var to_val = to_shader.get(param, from_val)

		var interpolated = _interpolate_value(from_val, to_val, t)
		_sky_material.set_shader_parameter(param, interpolated)

func _update_environment(from_params: Dictionary, to_params: Dictionary, t: float) -> void:
	var from_env = from_params["environment"]
	var to_env = to_params["environment"]

	for param in from_env.keys():
		var from_val = from_env[param]
		var to_val = to_env.get(param, from_val)

		var interpolated = _interpolate_value(from_val, to_val, t)

		# Set on environment
		match param:
			"glow_intensity":
				_environment.glow_intensity = interpolated
			"glow_bloom":
				_environment.glow_bloom = interpolated
			"adjustment_saturation":
				_environment.adjustment_saturation = interpolated
			"ambient_light_energy":
				_environment.ambient_light_energy = interpolated
			"volumetric_fog_density":
				_environment.volumetric_fog_density = interpolated
			"volumetric_fog_anisotropy":
				_environment.volumetric_fog_anisotropy = interpolated
			"volumetric_fog_sky_affect":
				_environment.volumetric_fog_sky_affect = interpolated

func _update_lights(from_params: Dictionary, to_params: Dictionary, t: float) -> void:
	var from_lights = from_params["lights"]
	var to_lights = to_params["lights"]

	# Sun light
	if _sun_light:
		var from_sun = from_lights.get("sun_energy", 0.0)
		var to_sun = to_lights.get("sun_energy", 0.0)
		_sun_light.light_energy = _interpolate_value(from_sun, to_sun, t)

	# Moon light
	if _moon_light:
		var from_moon = from_lights.get("moon_energy", 0.0)
		var to_moon = to_lights.get("moon_energy", 0.0)
		_moon_light.light_energy = _interpolate_value(from_moon, to_moon, t)

	# Omni light (store light)
	if _omni_light:
		var from_omni = from_lights.get("omni_energy", 0.0)
		var to_omni = to_lights.get("omni_energy", 0.0)
		_omni_light.light_energy = _interpolate_value(from_omni, to_omni, t)

	# Night light
	if _night_light:
		var from_night = from_lights.get("night_energy", 0.0)
		var to_night = to_lights.get("night_energy", 0.0)
		_night_light.light_energy = _interpolate_value(from_night, to_night, t)

func _interpolate_value(from_val, to_val, t: float):
	if from_val is Color:
		return from_val.lerp(to_val, t)
	elif from_val is float or from_val is int:
		return lerp(from_val, to_val, t)
	elif from_val is Vector2:
		return from_val.lerp(to_val, t)
	elif from_val is Vector3:
		return from_val.lerp(to_val, t)
	else:
		return to_val  # Fallback: use target value
```

- [ ] **Step 2: Verify file created**

Run:
```bash
ls -la Scripts/TimeOfDayLighting.gd
```

Expected: File exists and is readable

- [ ] **Step 3: Commit**

```bash
git add Scripts/TimeOfDayLighting.gd
git commit -m "feat: create TimeOfDayLighting script with keyframe data structure

- Defines 6 time-based keyframes: sunrise, midday, golden hour, dusk, night, early morning
- Each keyframe contains shader parameters, environment settings, and light energies
- Implements keyframe lookup and interpolation factor calculation
- Initializes all shader, environment, and light update methods"
```

---

### Task 2: Attach TimeOfDayLighting to Sky3D Node in MainGame Scene

**Files:**
- Modify: `Scenes/MainGame.tscn`

- [ ] **Step 1: Open MainGame.tscn in editor and attach script to Sky3D node**

In Godot editor:
1. Open `Scenes/MainGame.tscn`
2. Select the `Sky3D` node (the WorldEnvironment node)
3. In the Inspector, go to the Script property
4. Set it to `res://Scripts/TimeOfDayLighting.gd`
5. Save the scene

- [ ] **Step 2: Verify script is attached**

Check `Scenes/MainGame.tscn` for the Sky3D node entry containing:
```
script = ExtResource("[id]")
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/MainGame.tscn
git commit -m "attach: add TimeOfDayLighting script to Sky3D node

- Script now manages day-night lighting transitions
- Connects to TimeOfDay signals automatically in _ready()"
```

---

### Task 3: Test Initial Setup and Debug Light References

**Files:**
- No new files

- [ ] **Step 1: Run the game and check console for errors**

Run the game (play button in editor or `godot --run`).

Expected: No errors about missing scripts or unresolved references.

If errors appear:
- Check the console output
- Verify light node names match what's in MainGame.tscn (SunLight, MoonLight, NightLight, OmniLight3D)
- If node names differ, adjust the lookup code in `_ready()` of TimeOfDayLighting.gd

- [ ] **Step 2: Monitor the sky as time progresses**

Let the game run for several minutes (at least one full cycle, ~30 minutes).

Watch for:
- Smooth color transitions (should see warm → neutral → warm again → cool → cool → warm)
- No jarring parameter snaps
- Store light (OmniLight) dimming at day, brightening at night

- [ ] **Step 3: Check console for time and state notifications (optional debug)**

Add temporary debug print to verify state transitions:

In TimeOfDayLighting.gd, add after `_current_from_state = from_state`:
```gdscript
print("[TimeOfDayLighting] Transitioning from %s to %s (t=%.2f)" % [from_state, to_state, t])
```

Expected: Transitions logged as time progresses through keyframes

- [ ] **Step 4: Remove debug prints**

Delete the print statement added above.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: verify TimeOfDayLighting initialization and light references

- Script successfully connects to TimeOfDay signals
- All light nodes found and updated correctly
- Transitions smooth and no parameter snaps observed"
```

---

### Task 4: Fine-Tune Keyframe Shader Parameters

**Files:**
- Modify: `Scripts/TimeOfDayLighting.gd` (shader values in `_initialize_keyframes`)

- [ ] **Step 1: Monitor sunrise (5-7 AM) visuals**

Freeze time at 6.0 (6 AM) in MainGame.tscn editor:
- Set Sky3D node's `current_time` to 6.0
- Observe sky color, sun position, shadows

Adjust `sunrise` keyframe shader parameters if needed:
- If sky too dark: increase `atm_sun_intensity`
- If sunrise color too orange/red: adjust `atm_day_tint`
- If horizon too bright: reduce `atm_horizon_light_tint`

- [ ] **Step 2: Monitor midday (10 AM - 3 PM) visuals**

Freeze time at 12.0 (noon).

Adjust `midday` keyframe shader parameters:
- Sky should be neutral white-blue with sharp shadows
- If too warm: adjust `atm_day_tint` toward cooler blue
- If too dim: increase `atm_sun_intensity`

- [ ] **Step 3: Monitor golden hour (4-5 PM) visuals**

Freeze time at 16.5 (4:30 PM).

Adjust `golden_hour` keyframe:
- Sky should be rich amber/orange with long shadows
- Colors should feel saturated and warm
- If not warm enough: increase warm tint in `atm_day_tint`

- [ ] **Step 4: Monitor dusk (6-7 PM) visuals**

Freeze time at 18.5 (6:30 PM).

Adjust `dusk` keyframe:
- Transition from day to night colors (purples/coolblues)
- Stars should become visible
- Moon should be prominent
- If transition too abrupt: reduce time_range gap between golden_hour and dusk

- [ ] **Step 5: Monitor night (8 PM - 4 AM) visuals**

Freeze time at 22.0 (10 PM).

Adjust `night` keyframe:
- Moonlight should illuminate the scene with cool blue tones
- Stars should twinkle
- Scene should be dark but navigable
- If too dark: increase `ambient_light_energy` or `moon_energy`

- [ ] **Step 6: Monitor early morning (4-5 AM) visuals**

Freeze time at 4.5 (4:30 AM).

Adjust `early_morning` keyframe:
- Cool pre-dawn blue tones
- Stars fading
- Transition toward sunrise warmth
- If transition from night too jarring: increase `early_morning` `atm_sun_intensity`

- [ ] **Step 7: Run full cycle and observe transitions**

Unfreeze time (set `current_time` back to a variable or play mode).

Watch full 30-minute cycle. Note any:
- Color popping/snapping
- Oversaturated or undersaturated sections
- Lighting imbalances

Make small adjustments to shader parameter values as needed.

- [ ] **Step 8: Commit**

```bash
git add Scripts/TimeOfDayLighting.gd
git commit -m "tune: fine-tune shader parameters for daylight moods

- Sunrise parameters optimized for warm orange tints and soft shadows
- Midday parameters for neutral white-blue and sharp definition
- Golden hour parameters for rich amber and saturation
- Dusk parameters for purple-blue transition and star visibility
- Early morning parameters for cool pre-dawn tones"
```

---

### Task 5: Fine-Tune Keyframe Environment Parameters

**Files:**
- Modify: `Scripts/TimeOfDayLighting.gd` (environment values in `_initialize_keyframes`)

- [ ] **Step 1: Verify glow intensity progression**

Freeze time at each keyframe (sunrise, midday, golden hour, dusk, night).

Check if `glow_intensity` feels appropriate:
- Midday: should be moderate (1.0)
- Golden hour: should be high and bloom-heavy (1.8)
- Dusk: should be at maximum (2.0) for atmospheric effect
- Night: should be subtle (0.5)

Adjust values in the "environment" section of each keyframe if bloom feels wrong.

- [ ] **Step 2: Verify glow bloom values**

Check bloom intensity:
- Low bloom (0.15) during midday — crisp, clean
- High bloom (0.6-0.8) during golden hour and dusk — atmospheric, glowy

If bloom too strong: reduce value toward 0.0.
If not enough bloom: increase toward 1.0.

- [ ] **Step 3: Verify saturation values**

Saturation controls color richness:
- Midday: 1.2 (rich colors)
- Golden hour: 1.4 (ultra-saturated warm tones)
- Dusk: 1.0 (neutral, transitional)
- Night: 0.75 (desaturated cool tones)

If colors feel weak: increase saturation.
If colors feel artificial/oversaturated: decrease.

- [ ] **Step 4: Verify ambient light energy**

Ambient light controls overall scene brightness:
- Midday: 0.8 (bright, well-lit)
- Golden hour: 0.65 (slightly dimmer, more dramatic)
- Dusk: 0.3 (low, transitioning to night)
- Night: 0.15 (very dim, mostly from moon/lights)

Run a full cycle. If any time period feels too dark/bright, adjust ambient_light_energy values.

- [ ] **Step 5: Verify volumetric fog (if noticeable)**

Volumetric fog adds atmospheric depth:
- Only active in dusk and night (volumetric_fog_density: 0.02 and 0.015)
- If fog too heavy: reduce density
- If fog invisible: increase density slightly

During dusk/night, observe if fog adds mood. Adjust as needed.

- [ ] **Step 6: Commit**

```bash
git add Scripts/TimeOfDayLighting.gd
git commit -m "tune: fine-tune environment postprocessing parameters

- Glow intensity: 0.8 (sunrise) → 1.8 (golden hour, peak) → 0.5 (night)
- Bloom: 0.25 (sunrise) → 0.8 (dusk, maximum) → 0.2 (night)
- Saturation: 1.4 (golden hour, peak) → 0.75 (night, desaturated)
- Ambient light: 0.8 (midday, bright) → 0.15 (night, very dim)
- Volumetric fog: active during dusk/night for atmospheric depth"
```

---

### Task 6: Fine-Tune Light Energy Values

**Files:**
- Modify: `Scripts/TimeOfDayLighting.gd` (lights values in `_initialize_keyframes`)

- [ ] **Step 1: Verify SunLight energy progression**

Freeze time at sunrise, midday, golden hour, dusk.

Watch SunLight energy:
- Should start at 0.4 (sunrise)
- Peak at 0.8 (midday)
- Reduce to 0.0 by dusk

Check if shadows are sharp and appropriate for each time.

If sun too dim: increase sun_energy values.
If sun too bright: decrease values.

- [ ] **Step 2: Verify MoonLight energy progression**

Freeze time at dusk and night.

MoonLight should:
- Stay at 0.0 until dusk (0.5)
- Be 1.0 at night (full moonlight)
- Start fading at early morning

If moon lighting insufficient: increase moon_energy values.
If too bright: decrease.

- [ ] **Step 3: Verify OmniLight (store light) progression**

Freeze time at different times throughout the day.

Store light (OmniLight) should:
- Be nearly off during day (0.0-0.3)
- Ramp up during golden hour (0.5)
- Be fully on at night (1.2-1.5)
- Begin dimming at early morning (0.8)

This creates a "store is closed during day, working at night" story.

If light doesn't sync with game time: adjust omni_energy values or check if OmniLight was found correctly.

- [ ] **Step 4: Verify NightLight energy progression**

NightLight is a DirectionalLight providing ambient blue tone at night.

Energy should:
- Be 0.0 until dusk (0.1)
- Peak at night (0.3)
- Return to 0.0 at early morning

If night ambient too blue: reduce night_energy.
If blue tone not distinct: increase night_energy.

- [ ] **Step 5: Full cycle test**

Run game for full 30-minute cycle.

Watch lighting story:
- Day: bright, shadows from sun
- Golden hour: warm, glowing
- Dusk: transitional, store lights come on
- Night: moonlit, store light prominent
- Early morning: dimming down, stars fading

If any transition feels jarring: make small adjustments to energy ramps.

- [ ] **Step 6: Commit**

```bash
git add Scripts/TimeOfDayLighting.gd
git commit -m "tune: fine-tune light energy progression for day-night cycle

- SunLight: 0.4 (sunrise) → 0.8 (midday) → 0.0 (dusk)
- MoonLight: 0.0 (day) → 0.5 (dusk) → 1.0 (night)
- OmniLight (store): 0.0-0.3 (day) → 1.2-1.5 (night, prominent)
- NightLight: 0.0 (day) → 0.3 (night, blue ambient) → 0.0 (dawn)
- Lighting tells clear day→night→day story"
```

---

### Task 7: Verify Smooth Transitions Between States

**Files:**
- No modifications

- [ ] **Step 1: Run game and observe transitions**

Play for 10-15 minutes, watching as time crosses from one keyframe to the next.

Expected behavior:
- Colors should smoothly blend (no snaps)
- Tween duration is 2.5 seconds
- Each parameter transitions smoothly

- [ ] **Step 2: Check for parameter popping**

If you notice sudden jumps in:
- Color
- Brightness
- Bloom intensity

It means a keyframe boundary is not overlapping smoothly. Verify that `time_range` boundaries are close together or overlapping.

For example:
- `sunrise` ends at 7.0
- `midday` starts at 10.0

This creates a 3-hour gap where interpolation might snap. Consider reducing gap or adding intermediate keyframes if needed.

- [ ] **Step 3: Verify tween feedback in console (optional)**

In `_start_transition()`, add temporary debug info:

```gdscript
print("[TimeOfDayLighting] Tween started: %s → %s over 2.5s" % [from_state, to_state])
```

Run game and check console as transitions occur.

Expected: Tween log entry every ~2 hours of game time.

- [ ] **Step 4: Remove debug code**

Delete the temporary print statement.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "verify: smooth transitions between lighting states

- 2.5-second tween smooths color, bloom, and light energy transitions
- No parameter snaps observed across keyframe boundaries
- Transitions feel natural and cinematic"
```

---

### Task 8: Integration Test — Full Day-Night Cycle

**Files:**
- No modifications

- [ ] **Step 1: Set custom time in editor for testing**

In Godot editor:
1. Select Sky3D node
2. Set `current_time` to 5.0 (sunrise) to start testing

- [ ] **Step 2: Run game in editor**

Play (F5 in editor).

Expected: Game starts at sunrise, time progresses, full 30-minute cycle completes.

- [ ] **Step 3: Document observations checklist**

Watch for and verify:

- [ ] Sunrise (5-7 AM): warm orange sky, soft shadows ✓
- [ ] Transition to midday (7-10 AM): warming up ✓
- [ ] Midday (10 AM - 3 PM): neutral white-blue, sharp shadows, store light off ✓
- [ ] Golden hour / late afternoon (4-5 PM): rich amber, long shadows, glow effect ✓
- [ ] Transition to dusk (5-7 PM): cooling to purples/blues, stars visible, store light on ✓
- [ ] Night (8 PM - 4 AM): moonlit, cool tones, stars twinkling, store light prominent ✓
- [ ] Early morning (4-5 AM): pre-dawn cool blue, stars fading ✓
- [ ] Sunrise again: cycle restarts ✓

- [ ] **Step 4: Audio/Visual coherence check**

If your game has ambient audio (wind, crickets, etc.), verify:
- Day audio ↔ day lighting align
- Night audio ↔ night lighting align
- No mismatches (e.g., crickets during noon)

(If no audio, skip this check.)

- [ ] **Step 5: Performance check**

Monitor FPS during full cycle:
- Should maintain consistent framerate (~60 FPS on modern hardware)
- No framerate drops during transitions

If FPS drops:
- Reduce `glow_intensity` values
- Reduce `volumetric_fog_density`
- Check if too many tweens running simultaneously

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "test: full day-night cycle integration

- All 6 keyframe states verified visually distinct
- Transitions smooth and natural over 2.5 seconds
- Lighting progression tells coherent day→night→day story
- Performance stable throughout 30-minute cycle"
```

---

### Task 9: Documentation and Cleanup

**Files:**
- Modify: `Scripts/TimeOfDayLighting.gd` (add docstring comments)

- [ ] **Step 1: Add header docstring to TimeOfDayLighting.gd**

Add at the very top of the file (before @tool):

```gdscript
##
## TimeOfDayLighting: Cinematic Day-Night Lighting System
##
## This script manages a sophisticated lighting progression across a 24-hour in-game day.
## It smoothly transitions between 6 key mood states using interpolated shader parameters,
## postprocessing effects, and dynamic light energy adjustments.
##
## Keyframes:
## - Sunrise (5-7 AM): Warm orange, soft shadows, low glow
## - Midday (10 AM-3 PM): Neutral white-blue, sharp shadows, clean look
## - Golden Hour (4-5 PM): Rich amber, long shadows, high glow
## - Dusk (6-7 PM): Cool purple-blue, stars visible, maximum bloom
## - Night (8 PM-4 AM): Cool moonlight, stars, deep shadows
## - Early Morning (4-5 AM): Pre-dawn cool blue, stars fading
##
## Connection Flow:
## 1. Listens to TimeOfDay.time_changed signal
## 2. Determines current and next keyframe
## 3. Calculates interpolation factor (0-1)
## 4. Updates shader parameters, environment, and lights every frame
## 5. Smooth 2.5-second tween blends between states
##
## Setup:
## - Attach this script to the Sky3D (WorldEnvironment) node in MainGame.tscn
## - Ensure TimeOfDay, SunLight, MoonLight, NightLight, and OmniLight nodes exist
##
```

- [ ] **Step 2: Add inline comments to key functions**

Add clarifying comments to:
- `_initialize_keyframes()` — "Define 6 mood states with shader/environment/light parameters"
- `_on_time_changed()` — "Triggered by TimeOfDay.time_changed signal; detects state transitions"
- `_get_current_keyframe_pair()` — "Returns which two keyframes to interpolate between and factor t"
- `_update_all_systems()` — "Updates all three layers: shaders, environment, lights"

- [ ] **Step 3: Verify no debug code remains**

Search for:
- Any `print()` statements (should be removed)
- Any `TODO` or `FIXME` comments (address or document)
- Any placeholder values

Run:
```bash
grep -n "print\|TODO\|FIXME\|TBD" Scripts/TimeOfDayLighting.gd
```

Expected: No results

- [ ] **Step 4: Final review of keyframe values**

Open `Scripts/TimeOfDayLighting.gd` and skim through `_initialize_keyframes()`.

Verify:
- All keyframe `time_range` values make sense (sunrise 5-7, midday 10-15, etc.)
- All shader parameters have sensible ranges (intensity 0-30, colors 0-1, sizes 0-1)
- All environment values in valid ranges (glow 0-2, saturation 0-2, energy 0-1)
- All light energies make sense (0.0-1.5 range)

- [ ] **Step 5: Commit**

```bash
git add Scripts/TimeOfDayLighting.gd
git commit -m "docs: add header and inline documentation to TimeOfDayLighting

- Comprehensive header explaining system architecture and keyframes
- Inline comments on key functions and interpolation logic
- All debug code removed, values verified
- Ready for production use"
```

---

### Task 10: Final Validation and Scene Save

**Files:**
- Modify: `Scenes/MainGame.tscn`

- [ ] **Step 1: Open MainGame.tscn in editor (final validation)**

1. Select Sky3D node
2. Verify `TimeOfDayLighting` script is attached (shown in Inspector)
3. Verify `current_time` can be adjusted and affects visuals in real-time

- [ ] **Step 2: Test script reloads gracefully**

In editor:
1. Modify `Scripts/TimeOfDayLighting.gd` (add a space somewhere, no logic change)
2. Save the script
3. Editor should hot-reload without errors

Check console for errors. Expected: none.

- [ ] **Step 3: Save scene**

Save MainGame.tscn (Ctrl+S).

- [ ] **Step 4: Commit**

```bash
git add Scenes/MainGame.tscn
git commit -m "finalize: MainGame.tscn with TimeOfDayLighting active

- Script fully integrated with Sky3D WorldEnvironment node
- Hot-reload verified, no script errors
- Scene ready for gameplay testing"
```

---

## Testing Checklist

Before marking complete, verify:

- [ ] Script compiles without errors
- [ ] TimeOfDay signals connect and trigger correctly
- [ ] All 6 keyframes visually distinct
- [ ] Transitions smooth (no snaps)
- [ ] Sunrise warm and distinct
- [ ] Midday bright and neutral
- [ ] Golden hour rich and atmospheric
- [ ] Dusk transitional with stars visible
- [ ] Night dark with moonlight prominent
- [ ] Early morning pre-dawn tones
- [ ] Store light off during day, on at night
- [ ] Full 30-minute cycle runs smoothly
- [ ] Performance stable (60 FPS)
- [ ] No console errors during gameplay
- [ ] All documentation complete

---

## Success Criteria

- ✓ Each time period has visually distinct mood
- ✓ Smooth 2.5-second transitions between states (no parameter snaps)
- ✓ Daytime: sharp shadows, rich colors, well-defined details
- ✓ Nighttime: moonlit, cool tones, stars visible
- ✓ Golden hour: warm, atmospheric, cinematic
- ✓ Dusk: transitional, stars appearing, store lights activating
- ✓ Store lighting integrated: off day, on night
- ✓ Full 30-minute cycle completes without artifacts
- ✓ Performance maintained throughout

---

## Notes

- All keyframe time_ranges are approximate and tuned for the 30-minute cycle
- Shader parameters reference the Sky3D addon's `SkyMaterial.gdshader`
- Environment values apply to the `Environment` resource in MainGame.tscn
- Light updates target: SunLight, MoonLight, NightLight, OmniLight (store interior light)
- Tween duration is 2.5 seconds per transition; adjust in `_start_transition()` if needed slower/faster
- To customize colors further, edit keyframe "shader" dictionaries in `_initialize_keyframes()`
