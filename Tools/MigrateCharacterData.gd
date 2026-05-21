@tool
extends EditorScript

## MigrateCharacterData.gd — One-time migration tool
##
## Reads all hardcoded per-character category and visit-story data
## that was previously inside StoryManager._build_generic_transaction()
## and _build_transaction_context(), and writes it back into the
## corresponding CustomerData .tres resource files.
##
## HOW TO RUN:
##   1. Open this file in the Godot script editor.
##   2. Click File > Run (or press Ctrl+Shift+X).
##   3. The script will print a summary of what was written.
##   4. Save the project (Ctrl+S) to persist the .tres changes to disk.
##
## This script is SAFE to run multiple times — it only overwrites the
## new fields (chapter_categories, visit_story_chapters) and will not
## touch any other resource properties.

func _run() -> void:
	print("=== MigrateCharacterData: Starting migration ===")

	# ---------------------------------------------------------------------------
	# Source data — exact values from StoryManager's hardcoded logic
	# Key: resource path (relative to res://)
	# Value: { "categories": Array[String], "visit_chapters": Array[bool] }
	# ---------------------------------------------------------------------------
	var migration_data := {
		"res://Resources/customers/KuyaKap.tres": {
			# Chapters 0-6: cigarette, Chapter 7: bottle, Chapter 8+: candy
			# max_story_chapters is 9
			"categories": ["cigarette", "cigarette", "cigarette", "cigarette", "cigarette", "cigarette", "cigarette", "bottle", "candy"],
			"visit_chapters": []  # KuyaKap has no visit-only chapters
		},
		"res://Resources/customers/ManangAna.tres": {
			# Chapter 0: pack, 1: can, 2: bottle, 3: pack, 4: sachet, 5: sachet, 6: can, 7: visit, 8: pack
			"categories": ["pack", "can", "bottle", "pack", "sachet", "sachet", "can", "", "pack"],
			"visit_chapters": [false, false, false, false, false, false, false, true, false]
		},
		"res://Resources/customers/Danilo.tres": {
			# Danilo always snack for purchases; chapters 0-7 are visit-only, chapter 8 is purchase
			"categories": ["snack", "snack", "snack", "snack", "snack", "snack", "snack", "snack", "snack"],
			"visit_chapters": [true, true, true, true, true, true, true, true, false]
		},
		"res://Resources/customers/Buboy.tres": {
			# Chapter 0: visit, 1: can, 2: snack, 3: sachet, 4: snack, 5: pack, 6: bottle, 7: candy, 8: snack, 9: pack
			"categories": ["", "can", "snack", "sachet", "snack", "pack", "bottle", "candy", "snack", "pack"],
			"visit_chapters": [true, false, false, false, false, false, false, false, false, false]
		},
		"res://Resources/customers/TK.tres": {
			# 0: bottle, 1: snack, 2: pack, 3: bottle, 4: snack, 5: pack, 6: snack, 7: bottle, 8: pack
			"categories": ["bottle", "snack", "pack", "bottle", "snack", "pack", "snack", "bottle", "pack"],
			"visit_chapters": []
		},
		"res://Resources/customers/Rosalyn.tres": {
			# 0: visit, 1: visit, 2: bottle, 3: bottle, 4: visit, 5: visit, 6: candy, 7: visit, 8: visit
			"categories": ["", "", "bottle", "bottle", "", "", "candy", "", ""],
			"visit_chapters": [true, true, false, false, true, true, false, true, true]
		},
		"res://Resources/customers/Rodel.tres": {
			# 0: bottle, 1: snack, 2: bottle, 3: bottle, 4: snack, 5: bottle, 6: frozen, 7: bottle, 8: visit
			"categories": ["bottle", "snack", "bottle", "bottle", "snack", "bottle", "frozen", "bottle", ""],
			"visit_chapters": [false, false, false, false, false, false, false, false, true]
		},
		"res://Resources/customers/Brahim.tres": {
			# 0: frozen, 1: can, 2: pack, 3: frozen, 4: can, 5: pack, 6: frozen, 7: candy, 8: pack
			"categories": ["frozen", "can", "pack", "frozen", "can", "pack", "frozen", "candy", "pack"],
			"visit_chapters": []
		},
		"res://Resources/customers/Sarimanok.tres": {
			# Chapters 0-3: visit-only. 4: snack, 5: pack, 6: snack, 7: can, 8: can
			"categories": ["", "", "", "", "snack", "pack", "snack", "can", "can"],
			"visit_chapters": [true, true, true, true, false, false, false, false, false]
		},
		"res://Resources/customers/ReynaMayari.tres": {
			# 0: cigarette, 1: bottle, 2: cigarette, 3: candy, 4: cigarette, 5: bottle, 6: candy, 7: bottle, 8: sachet
			"categories": ["cigarette", "bottle", "cigarette", "candy", "cigarette", "bottle", "candy", "bottle", "sachet"],
			"visit_chapters": []
		},
	}

	var migrated_count := 0
	var failed_count := 0

	for path in migration_data.keys():
		var entry: Dictionary = migration_data[path]
		var result := _migrate_resource(path, entry.get("categories", []), entry.get("visit_chapters", []))
		if result:
			migrated_count += 1
		else:
			failed_count += 1

	print("")
	print("=== MigrateCharacterData: Complete ===")
	print("  Migrated: %d resources" % migrated_count)
	print("  Failed:   %d resources" % failed_count)
	print("")
	print("  Next step: Review changes in Inspector, then save all (Ctrl+S).")


func _migrate_resource(path: String, categories: Array, visit_chapters: Array) -> bool:
	if not ResourceLoader.exists(path):
		push_error("[MigrateCharacterData] Resource not found: %s" % path)
		return false

	var resource = load(path) as CustomerData
	if not resource:
		push_error("[MigrateCharacterData] Failed to load as CustomerData: %s" % path)
		return false

	var char_name := path.get_file().get_basename()

	# Write chapter_categories
	var typed_cats: Array[String] = []
	for cat in categories:
		typed_cats.append(str(cat))
	resource.chapter_categories = typed_cats

	# Write visit_story_chapters
	var typed_visits: Array[bool] = []
	for v in visit_chapters:
		typed_visits.append(bool(v))
	resource.visit_story_chapters = typed_visits

	# Save back to disk
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		push_error("[MigrateCharacterData] Failed to save %s: error %d" % [path, err])
		return false

	print("  [OK] %s — %d categories, %d visit chapters" % [char_name, typed_cats.size(), typed_visits.size()])
	return true
