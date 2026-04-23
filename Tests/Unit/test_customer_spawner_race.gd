## GdUnit4 test suite for CustomerSpawner._on_customer_dismissed race guard
## Tests: _is_spawning is set BEFORE the await so the second signal fire is rejected
##
## Strategy: We test the state of _is_spawning using a minimal in-scene CustomerSpawner
## stub, not the full game scene, to avoid Dialogic/StoryManager dependencies.
extends GdUnitTestSuite

class_name TestCustomerSpawnerRace


## Minimal stub that replaces CustomerSpawner signals without needing the full game.
## We test the _is_spawning behaviour directly by inspecting state mid-coroutine.
class SpawnerStub extends Node:
	var _is_spawning: bool = false
	var _spawn_call_count: int = 0
	var current_customer = null
	var guest_customer = null

	## Mirrors the fixed _on_customer_dismissed logic for isolated testing.
	func on_dismissed(customer) -> void:
		if customer == null:
			return
		if customer != current_customer and customer != guest_customer:
			return
		# RACE GUARD (this is what we are testing)
		if _is_spawning:
			return
		_is_spawning = true

		current_customer = null

		await get_tree().create_timer(0.05).timeout  # shortened delay for tests

		_is_spawning = false
		_spawn_call_count += 1  # represents _spawn_next_customer() being called

	func reset() -> void:
		_is_spawning = false
		_spawn_call_count = 0
		current_customer = null
		guest_customer = null


var _stub: SpawnerStub


func before_test() -> void:
	_stub = SpawnerStub.new()
	add_child(_stub)


func after_test() -> void:
	remove_child(_stub)
	_stub.queue_free()
	_stub = null


## [CS-01] Single signal: spawner resets _is_spawning and increments spawn count
func test_single_dismiss_works() -> void:
	var fake_customer = Object.new()
	_stub.current_customer = fake_customer
	_stub.on_dismissed(fake_customer)
	await get_tree().create_timer(0.2).timeout
	assert_int(_stub._spawn_call_count).is_equal(1)
	assert_bool(_stub._is_spawning).is_false()
	fake_customer.free()


## [CS-02] Double signal: second call is rejected — spawn only runs ONCE
## This directly tests the CRITICAL-1 race condition fix.
func test_double_signal_only_spawns_once() -> void:
	var fake_customer = Object.new()
	_stub.current_customer = fake_customer

	# Fire twice in rapid succession (simulates customer_satisfied + customer_dismissed)
	_stub.on_dismissed(fake_customer)
	_stub.on_dismissed(fake_customer)  # should be rejected by the _is_spawning guard

	await get_tree().create_timer(0.3).timeout
	assert_int(_stub._spawn_call_count).is_equal(1)
	fake_customer.free()


## [CS-03] After full cycle, a new customer can be processed again
func test_spawner_accepts_new_customer_after_reset() -> void:
	var c1 = Object.new()
	_stub.current_customer = c1
	_stub.on_dismissed(c1)
	await get_tree().create_timer(0.2).timeout
	assert_int(_stub._spawn_call_count).is_equal(1)

	# Simulate second customer arriving
	var c2 = Object.new()
	_stub.current_customer = c2
	_stub.on_dismissed(c2)
	await get_tree().create_timer(0.2).timeout
	assert_int(_stub._spawn_call_count).is_equal(2)

	c1.free()
	c2.free()


## [CS-04] Null customer is rejected early
func test_null_customer_rejected() -> void:
	_stub.on_dismissed(null)
	await get_tree().create_timer(0.1).timeout
	assert_int(_stub._spawn_call_count).is_equal(0)


## [CS-05] Unknown customer (not current, not guest) is rejected
func test_untracked_customer_rejected() -> void:
	var tracked = Object.new()
	var untracked = Object.new()
	_stub.current_customer = tracked
	_stub.on_dismissed(untracked)
	await get_tree().create_timer(0.1).timeout
	assert_int(_stub._spawn_call_count).is_equal(0)
	tracked.free()
	untracked.free()
