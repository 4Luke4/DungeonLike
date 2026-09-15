extends GutTest
## Tests for the frame rate and power policy.


func after_each() -> void:
	FramePacingService.set_idle(false)
	FramePacingService.apply_preferred_cap(HostBridge.display_refresh_rate_hz())


func test_the_frame_rate_is_capped_rather_than_left_unlimited() -> void:
	# Zero means uncapped in the engine. On a 120 Hz panel that renders frames
	# the display never shows, which is the battery drain this policy exists to
	# avoid.
	assert_gt(Engine.max_fps, 0, "the frame rate must always be capped")


func test_a_requested_cap_is_applied() -> void:
	FramePacingService.apply_preferred_cap(60)
	assert_eq(FramePacingService.current_cap(), 60)
	assert_eq(Engine.max_fps, 60)


func test_a_cap_above_what_the_panel_supports_is_clamped() -> void:
	var supported := FramePacingService.available_caps()
	var highest: int = supported[supported.size() - 1]

	FramePacingService.apply_preferred_cap(highest + 240)

	assert_eq(FramePacingService.current_cap(), highest)


func test_idling_lowers_the_cap_and_enables_low_processor_mode() -> void:
	FramePacingService.apply_preferred_cap(120)
	FramePacingService.set_idle(true)

	assert_eq(FramePacingService.current_cap(), FramePacingService.IDLE_FPS)
	assert_true(OS.low_processor_usage_mode, "a static screen should idle the process")


func test_leaving_idle_restores_the_preferred_cap() -> void:
	FramePacingService.apply_preferred_cap(90)
	FramePacingService.set_idle(true)
	FramePacingService.set_idle(false)

	assert_eq(FramePacingService.current_cap(), 90)
	assert_false(OS.low_processor_usage_mode)
