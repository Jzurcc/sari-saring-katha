extends SceneTree

# Test the one-level-deep merge strategy in SaveManager
func _init():
	print("=== SaveManager Merge Behaviour Tests ===\n")
	
	var cache = {}
	
	# --- Helper mimicking the new save_game() merge ---
	var merge = func(target: Dictionary, source: Dictionary):
		for key in source:
			if source[key] is Dictionary and target.has(key) and target[key] is Dictionary:
				for sub_key in source[key]:
					target[key][sub_key] = source[key][sub_key]
			else:
				target[key] = source[key]
	
	# Test 1: Initial shelf save - two shelves
	merge.call(cache, { "shelves": { "shelf_A": ["itemA", "itemB"], "shelf_B": ["itemC"] } })
	assert(cache["shelves"]["shelf_A"][0] == "itemA", "T1 FAIL")
	assert(cache["shelves"]["shelf_B"][0] == "itemC", "T1 FAIL")
	print("PASS - Test 1: Both shelves stored correctly")
	
	# Test 2: ShelfSurface A clears itself (saves empty array for its own key only)
	merge.call(cache, { "shelves": { "shelf_A": ["", ""] } })
	# shelf_A should now be empty
	assert(cache["shelves"]["shelf_A"][0] == "", "T2 FAIL: shelf_A not cleared")
	# shelf_B should be PRESERVED (not wiped)
	assert(cache["shelves"]["shelf_B"][0] == "itemC", "T2 FAIL: shelf_B was wiped!")
	print("PASS - Test 2: Clearing shelf_A preserved shelf_B (ghost item fix confirmed)")
	
	# Test 3: Inventory save should NOT overwrite shelves
	merge.call(cache, { "inventory": { "stock": {"res://item.tres": 5} } })
	assert(cache.has("shelves"), "T3 FAIL: shelves wiped by inventory save!")
	assert(cache["shelves"]["shelf_B"][0] == "itemC", "T3 FAIL: shelf_B lost after inventory save")
	print("PASS - Test 3: inventory save preserved shelves key")
	
	# Test 4: StoryManager saves progression dict - should not affect shelves or inventory
	merge.call(cache, { "progression": { "current_tier": 2 } })
	assert(cache.has("shelves"), "T4 FAIL")
	assert(cache.has("inventory"), "T4 FAIL")
	assert(cache["progression"]["current_tier"] == 2, "T4 FAIL")
	print("PASS - Test 4: progression save is isolated from other keys")
	
	# Test 5: Updating progression should update sub-keys, not replace the whole dict
	merge.call(cache, { "progression": { "purchase_counter": 3 } })
	assert(cache["progression"]["current_tier"] == 2, "T5 FAIL: current_tier was wiped!")
	assert(cache["progression"]["purchase_counter"] == 3, "T5 FAIL")
	print("PASS - Test 5: partial progression update preserved existing sub-keys")
	
	print("\n=== ALL TESTS PASSED ===")
	quit()
