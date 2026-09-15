extends GutTest
## Tests for the host bridge.
##
## These run headless with no Android host attached, which is exactly the case
## the bridge exists to handle: the project has to stay runnable in the editor
## and in continuous integration, where the plugin is absent.


func test_reports_the_host_as_unavailable_when_running_without_one() -> void:
	assert_false(HostBridge.is_available(), "no Android host exists in a headless run")


func test_platform_entropy_is_empty_rather_than_failing() -> void:
	# RngService treats an empty result as "this source contributed nothing"
	# and seeds the run from the engine generator alone. Throwing here would
	# make the project unusable outside a device.
	assert_eq(HostBridge.host_entropy(32).size(), 0)


func test_a_refresh_rate_is_always_reported() -> void:
	assert_gt(HostBridge.display_refresh_rate_hz(), 0, "a usable rate must always come back")


func test_at_least_one_selectable_refresh_rate_is_offered() -> void:
	assert_gt(HostBridge.supported_refresh_rates_hz().size(), 0)


func test_achievements_are_reported_as_unavailable() -> void:
	assert_false(HostBridge.achievements_available())


func test_achievement_calls_are_safe_without_a_backend() -> void:
	# Game code reports progress unconditionally; these must be no-ops.
	HostBridge.unlock_achievement("first_descent")
	HostBridge.increment_achievement("rooms_cleared", 1)
	pass_test("achievement calls completed without a host")
