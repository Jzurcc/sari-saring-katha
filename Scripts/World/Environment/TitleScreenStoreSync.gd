extends Node3D

## Mirrors the player's saved store upgrades and placed front-window props
## onto the Main Menu 3D diorama (TitleScreen3D) using a read-only save peek.
##
## Keeps TitleScreen3D completely decoupled from MainGame's gameplay systems
## (CustomerSpawner, Player, SaveManager autosaves, AudioManager, Sky3D clock)
## while keeping the title screen storefront visually in sync with your save.

const CALENDAR_SCENE: PackedScene = preload("res://Scenes/Calendar.tscn")

const TEX_TROPHY: Texture2D = preload("res://Assets/ui/trophy.png")
const TEX_STO_NINO: Texture2D = preload("res://Assets/ui/sto_nino2.png")
const TEX_CAT: Texture2D = preload("res://Assets/ui/cat.png")
const TEX_PERMIT_FRAME: Texture2D = preload("res://Assets/ui/picture_frame_stand.png")
const TEX_TRASH: Texture2D = preload("res://Assets/ui/trash.png")

const TEX_CANDY_MIX: Texture2D = preload("res://Assets/items/icons/21_candycontainer_mix.png")
const TEX_CANDY_CHUBS: Texture2D = preload("res://Assets/items/icons/20_candycontainer_chubs.png")
const TEX_CANDY_MENTOR: Texture2D = preload("res://Assets/items/icons/18_candycontainer_mentor.png")
const TEX_CANDY_POCHA: Texture2D = preload("res://Assets/items/icons/19_candycontainer_pocha.png")

const TEX_SACHET_ARYEL: Texture2D = preload("res://Assets/items/icons/8_sachet_ariel.png")
const TEX_SACHET_KOPIMO: Texture2D = preload("res://Assets/items/icons/9_sachet_kopimo.png")
const TEX_SACHET_KNEESTOES: Texture2D = preload("res://Assets/items/icons/7_sachet_knees_toes.png")

const BENCH_TRANSFORM := Transform3D(
	Vector3(0.01134886, -1.0147491e-09, 0.00014403024),
	Vector3(-0.0001959394, 2.7609381e-09, 0.015439039),
	Vector3(-1.4154468e-09, -0.015440853, 2.7432987e-09),
	Vector3(-6.7510996, 0.7693781, -3.6162493)
)

const CALENDAR_TRANSFORM := Transform3D(
	Vector3(0.033346135, -1.0132097, 3.4778733e-09),
	Vector3(-3.3714652e-08, -3.76951e-09, -0.7749143),
	Vector3(0.77449477, 0.02548969, -3.382039e-08),
	Vector3(-1.886975, 3.6841087, -4.6021547)
)

var _props_root: Node3D = null
var _sto_nino_sprite: Sprite3D = null
var _sto_nino_upgraded: bool = false
var _pulse_time: float = 0.0


func _ready() -> void:
	_props_root = Node3D.new()
	_props_root.name = "SyncedStoreProps"
	add_child(_props_root)
	refresh_from_save()


func _process(delta: float) -> void:
	if _sto_nino_upgraded and is_instance_valid(_sto_nino_sprite):
		_pulse_time += delta * 2.2
		var glow := 0.5 + 0.5 * sin(_pulse_time)
		_sto_nino_sprite.modulate = Color(1.0, 0.95 + glow * 0.05, 0.86 + glow * 0.14, 1.0)


func refresh_from_save() -> void:
	if not is_instance_valid(_props_root):
		return
	for child in _props_root.get_children():
		child.queue_free()
	_sto_nino_sprite = null
	_sto_nino_upgraded = false

	var save: Dictionary = SaveManager.peek_save()
	var story: Dictionary = {}
	if save.has("StoryManager") and save["StoryManager"] is Dictionary:
		story = save["StoryManager"]
	elif save.has("progression") and save["progression"] is Dictionary:
		story = save["progression"]

	var current_tier: int = int(story.get("current_tier", 1))
	var bench_level: int = int(story.get("bench_upgrade_level", 0))
	var cat_level: int = int(story.get("cat_upgrade_level", 0))
	var permit_level: int = int(story.get("permit_upgrade_level", 0))
	var sto_nino_level: int = int(story.get("sto_nino_upgrade_level", 0))
	var has_trash_can: bool = bool(story.get("has_trash_can", false))

	var placed_set: Dictionary = {}
	var raw_placed = story.get("placed_containers", [])
	if raw_placed is Array:
		for p in raw_placed:
			placed_set[str(p)] = true

	# --- Permanent store props (match MainGame 1:1) ---
	_spawn_calendar()
	_spawn_sprite_prop(
		"Trophy",
		TEX_TROPHY,
		Transform3D(
			Vector3(-8.742278e-09, 0.0, -0.2),
			Vector3(0.0, 0.2, 0.0),
			Vector3(0.2, 0.0, -8.742278e-09),
			Vector3(4.3776584, 5.060807, -0.8048922)
		),
		BaseMaterial3D.BILLBOARD_FIXED_Y,
		SpriteBase3D.ALPHA_CUT_DISCARD
	)
	_sto_nino_sprite = _spawn_sprite_prop(
		"StoNino",
		TEX_STO_NINO,
		Transform3D(
			Vector3(-1.2988269e-08, 1.8073546e-09, -0.29999998),
			Vector3(0.041347455, 0.297137, 0.0),
			Vector3(0.297137, -0.041347455, -1.3113415e-08),
			Vector3(4.3776584, 5.22742, -0.11046374)
		),
		BaseMaterial3D.BILLBOARD_FIXED_Y,
		SpriteBase3D.ALPHA_CUT_DISCARD
	)
	_sto_nino_upgraded = sto_nino_level >= 1

	# --- Store Upgrade Props ---
	if bench_level >= 1:
		_spawn_bench()

	if cat_level >= 1:
		_spawn_sprite_prop(
			"Cat",
			TEX_CAT,
			Transform3D(
				Vector3(-1.0927847e-08, 0.0, -0.25),
				Vector3(0.0, 0.25, 0.0),
				Vector3(0.25, 0.0, -1.0927847e-08),
				Vector3(4.1500525, 4.8488646, 0.9894613)
			),
			BaseMaterial3D.BILLBOARD_FIXED_Y,
			SpriteBase3D.ALPHA_CUT_DISCARD
		)

	if permit_level >= 1:
		_spawn_sprite_prop(
			"PermitFrame",
			TEX_PERMIT_FRAME,
			Transform3D(
				Vector3(-7.616596e-09, -1.3833861e-09, -0.18),
				Vector3(-0.032190587, 0.17709818, 1.0418866e-12),
				Vector3(0.17709818, 0.032190587, -7.741208e-09),
				Vector3(4.3776584, 4.9098506, 2.1249723)
			),
			BaseMaterial3D.BILLBOARD_FIXED_Y,
			SpriteBase3D.ALPHA_CUT_DISCARD
		)

	if has_trash_can:
		_spawn_sprite_prop(
			"TrashCan",
			TEX_TRASH,
			Transform3D(
				Basis.from_scale(Vector3(0.3, 0.3, 0.3)),
				Vector3(-3.3081064, 1.4242652, -3.8005772)
			),
			BaseMaterial3D.BILLBOARD_ENABLED,
			SpriteBase3D.ALPHA_CUT_DISABLED
		)

	# --- Placed Front-Window Candy & Sachet Dispensers ---
	if current_tier >= 2 and current_tier < 10 and placed_set.has("res://Resources/items/candycontainer/Mix.tres"):
		_spawn_dispenser_sprite(
			"CandyContainer_Mix",
			TEX_CANDY_MIX,
			Transform3D(Vector3(-1.0927847e-08, 0, -0.25), Vector3(0, 0.25, 0), Vector3(0.25, 0, -1.0927847e-08), Vector3(-4.399547, 3.4277682, -2.334823)),
			Transform3D(Basis.IDENTITY, Vector3(0, 0, 2.1296196)),
			BaseMaterial3D.BILLBOARD_ENABLED,
			SpriteBase3D.ALPHA_CUT_DISCARD
		)

	if current_tier >= 6 and placed_set.has("res://Resources/items/candycontainer/Chubs.tres"):
		_spawn_dispenser_sprite(
			"CandyContainer_Chubs",
			TEX_CANDY_CHUBS,
			Transform3D(Vector3(-1.0927847e-08, 0, -0.25), Vector3(0, 0.25, 0), Vector3(0.25, 0, -1.0927847e-08), Vector3(-4.224358, 3.4277682, 1.9787197)),
			Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.5334625)),
			BaseMaterial3D.BILLBOARD_ENABLED,
			SpriteBase3D.ALPHA_CUT_DISCARD
		)

	if current_tier >= 10 and placed_set.has("res://Resources/items/candycontainer/Mentor.tres"):
		_spawn_dispenser_sprite(
			"CandyContainer_Mentor",
			TEX_CANDY_MENTOR,
			Transform3D(Vector3(-8.742278e-09, 0, -0.2), Vector3(0, 0.2, 0), Vector3(0.2, 0, -8.742278e-09), Vector3(-4.328629, 3.3153253, -1.7661636)),
			Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.07231903)),
			BaseMaterial3D.BILLBOARD_ENABLED,
			SpriteBase3D.ALPHA_CUT_DISCARD
		)

	if current_tier >= 10 and placed_set.has("res://Resources/items/candycontainer/Pocha.tres"):
		_spawn_dispenser_sprite(
			"CandyContainer_Pocha",
			TEX_CANDY_POCHA,
			Transform3D(Vector3(-8.742278e-09, 0, -0.2), Vector3(0, 0.2, 0), Vector3(0.2, 0, -8.742278e-09), Vector3(-4.4829006, 3.3153253, -1.3061287)),
			Transform3D(Basis.IDENTITY, Vector3(0, 0, 2.6620235)),
			BaseMaterial3D.BILLBOARD_ENABLED,
			SpriteBase3D.ALPHA_CUT_DISCARD
		)

	if placed_set.has("res://Resources/items/sachetcontainers/Aryel.tres"):
		_spawn_dispenser_sprite(
			"SachetContainer_Aryel",
			TEX_SACHET_ARYEL,
			Transform3D(Vector3(-4.371139e-08, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, -4.371139e-08), Vector3(-4.1811247, 4.4237165, -1.8683959)),
			Transform3D(Vector3(0.27473214, -0.012134387, -1.1707078e-11), Vector3(0.012134387, 0.27473214, 5.304109e-10), Vector3(-1.1708728e-11, -5.304109e-10, 0.275), Vector3(-0.091359615, -0.024161339, 0)),
			BaseMaterial3D.BILLBOARD_FIXED_Y,
			SpriteBase3D.ALPHA_CUT_DISABLED
		)

	if placed_set.has("res://Resources/items/sachetcontainers/Kopimo.tres"):
		_spawn_dispenser_sprite(
			"SachetContainer_Kopimo",
			TEX_SACHET_KOPIMO,
			Transform3D(Vector3(-4.371139e-08, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, -4.371139e-08), Vector3(-4.1645947, 4.518205, 2.447767)),
			Transform3D(Vector3(0.27473214, -0.012134387, -1.1707078e-11), Vector3(0.012134387, 0.27473214, 5.304109e-10), Vector3(-1.1708728e-11, -5.304109e-10, 0.275), Vector3(-0.091359615, -0.024161339, 0)),
			BaseMaterial3D.BILLBOARD_FIXED_Y,
			SpriteBase3D.ALPHA_CUT_DISABLED
		)

	if placed_set.has("res://Resources/items/sachetcontainers/KneesToes.tres"):
		_spawn_dispenser_sprite(
			"SachetContainer_KneesToes",
			TEX_SACHET_KNEESTOES,
			Transform3D(Basis.IDENTITY, Vector3(-4.0922375, 4.516964, -2.462047)),
			Transform3D(Vector3(0.20480031, -0.009045633, -8.727241e-12), Vector3(0.009045633, 0.20480031, 3.9539713e-10), Vector3(-8.728173e-12, -3.9539713e-10, 0.205), Vector3(-0.0731678, 0.08774614, 0)),
			BaseMaterial3D.BILLBOARD_FIXED_Y,
			SpriteBase3D.ALPHA_CUT_DISABLED
		)


func _spawn_bench() -> void:
	var store_models := get_node_or_null("3DModels")
	if not store_models:
		return
	var source_bench := store_models.get_node_or_null("Bench") as MeshInstance3D
	if not source_bench or not source_bench.mesh:
		return
	var bench := MeshInstance3D.new()
	bench.name = "Bench"
	bench.mesh = source_bench.mesh
	bench.transform = BENCH_TRANSFORM
	_props_root.add_child(bench)


func _spawn_calendar() -> void:
	if not CALENDAR_SCENE:
		return
	var cal := CALENDAR_SCENE.instantiate() as Node3D
	if not cal:
		return
	cal.name = "Calendar"
	cal.transform = CALENDAR_TRANSFORM
	_props_root.add_child(cal)


func _spawn_sprite_prop(
	prop_name: String,
	tex: Texture2D,
	xform: Transform3D,
	billboard_mode: BaseMaterial3D.BillboardMode,
	alpha_cut_mode: SpriteBase3D.AlphaCutMode
) -> Sprite3D:
	var spr := Sprite3D.new()
	spr.name = prop_name
	spr.texture = tex
	spr.transform = xform
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.billboard = billboard_mode
	spr.shaded = true
	spr.alpha_cut = alpha_cut_mode
	_props_root.add_child(spr)
	return spr


func _spawn_dispenser_sprite(
	prop_name: String,
	tex: Texture2D,
	parent_xform: Transform3D,
	child_xform: Transform3D,
	billboard_mode: BaseMaterial3D.BillboardMode,
	alpha_cut_mode: SpriteBase3D.AlphaCutMode
) -> void:
	var holder := Node3D.new()
	holder.name = prop_name
	holder.transform = parent_xform
	_props_root.add_child(holder)

	var spr := Sprite3D.new()
	spr.name = "Sprite3D"
	spr.texture = tex
	spr.transform = child_xform
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.billboard = billboard_mode
	spr.shaded = true
	spr.alpha_cut = alpha_cut_mode
	holder.add_child(spr)
