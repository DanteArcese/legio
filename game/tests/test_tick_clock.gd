extends "res://tests/test_case.gd"

const TickClock := preload("res://scripts/sim/tick_clock.gd")


func test_defaults_to_osrs_like_tick_length() -> void:
	check_eq(TickClock.new().tick_length, 0.6, "default tick length")


func test_leftover_time_carries_over() -> void:
	var clock := TickClock.new()
	check_eq(clock.advance(0.5), 0, "0.5 s")
	check_eq(clock.advance(0.2), 1, "0.7 s total")
	check_eq(clock.advance(0.5), 1, "1.2 s total")


func test_many_ticks_in_one_frame_are_counted() -> void:
	var clock := TickClock.new()
	check_eq(clock.advance(1.85), 3, "1.85 s")


func test_long_stall_is_capped() -> void:
	var clock := TickClock.new()
	check_eq(clock.advance(60.0), TickClock.MAX_CATCH_UP_TICKS, "60 s stall")
	check_eq(clock.advance(0.1), 0, "no backlog after stall")


func test_shorter_tick_length_applies_immediately() -> void:
	var clock := TickClock.new()
	clock.advance(0.55)
	clock.tick_length = 0.4
	check_eq(clock.advance(0.0), 1, "carried time beyond new length runs at once")
	check_eq(clock.advance(0.39), 0, "then normal spacing")
	check_eq(clock.advance(0.01), 1, "next tick at 0.4 s")


func test_progress_reports_fraction_to_next_tick() -> void:
	var clock := TickClock.new()
	clock.advance(0.3)
	check(is_equal_approx(clock.progress(), 0.5), "progress %s" % clock.progress())
