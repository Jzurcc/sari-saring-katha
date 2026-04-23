## GdUnit4 test suite for StoryManager story chapter advancement
## Tests: story_advanced flag prevents double-counting on the same customer exit
extends GdUnitTestSuite

class_name TestStoryManagerCooldown


## Minimal stub for _process_story_cooldown logic, isolated from Dialogic / SaveManager
class StoryProgressionStub extends Node:
	# Mirrors StoryManager's relevant state
	var character_story_states: Dictionary = {}
	var global_story_cooldown: int = 0
	var last_story_advancer_path: String = ""

	## Returns how many chapters a character has completed.
	func get_chapter(char_path: String) -> int:
		return character_story_states.get(char_path, 0)

	## Mirrors the core guard from StoryManager._process_story_cooldown():
	## chapter advances only if story_advanced == true AND not already processed.
	func process_story_cooldown(char_path: String, story_advanced: bool, already_processed: bool) -> void:
		if already_processed:
			return
		if not story_advanced:
			return
		var current = character_story_states.get(char_path, 0)
		character_story_states[char_path] = current + 1
		last_story_advancer_path = char_path


var _story: StoryProgressionStub


func before_test() -> void:
	_story = StoryProgressionStub.new()
	add_child(_story)


func after_test() -> void:
	remove_child(_story)
	_story.queue_free()
	_story = null


## [SM-01] Normal story advance: chapter increments by 1
func test_chapter_advances_once() -> void:
	_story.process_story_cooldown("res://kuyakap.tres", true, false)
	assert_int(_story.get_chapter("res://kuyakap.tres")).is_equal(1)


## [SM-02] story_advanced = false: chapter does NOT increment
func test_no_advance_when_story_not_advanced() -> void:
	_story.process_story_cooldown("res://kuyakap.tres", false, false)
	assert_int(_story.get_chapter("res://kuyakap.tres")).is_equal(0)


## [SM-03] Double call with already_processed = true: only increments once
## Directly tests the CRITICAL-3 guard: customer_satisfied + customer_dismissed
## both call _process_story_cooldown, second call must be swallowed.
func test_double_advance_rejected_by_already_processed() -> void:
	_story.process_story_cooldown("res://kuyakap.tres", true, false)  # first fire: OK
	_story.process_story_cooldown("res://kuyakap.tres", true, true)   # second fire: rejected
	assert_int(_story.get_chapter("res://kuyakap.tres")).is_equal(1)


## [SM-04] Multiple distinct characters each advance their own chapter independently
func test_multiple_characters_independent() -> void:
	_story.process_story_cooldown("res://kuyakap.tres", true, false)
	_story.process_story_cooldown("res://manangana.tres", true, false)
	_story.process_story_cooldown("res://kuyakap.tres", true, false)
	assert_int(_story.get_chapter("res://kuyakap.tres")).is_equal(2)
	assert_int(_story.get_chapter("res://manangana.tres")).is_equal(1)


## [SM-05] last_story_advancer_path is updated correctly
func test_last_advancer_path_updated() -> void:
	_story.process_story_cooldown("res://sarimanok.tres", true, false)
	assert_str(_story.last_story_advancer_path).is_equal("res://sarimanok.tres")


## [SM-06] last_story_advancer_path NOT updated when already_processed
func test_last_advancer_not_updated_when_rejected() -> void:
	_story.process_story_cooldown("res://sarimanok.tres", true, false)
	_story.process_story_cooldown("res://different.tres", true, true)  # rejected
	# Should still be sarimanok, not different
	assert_str(_story.last_story_advancer_path).is_equal("res://sarimanok.tres")
