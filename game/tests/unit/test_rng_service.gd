extends GutTest
## Tests for the random number service.
##
## Two things are checked here that ordinary gameplay tests would not catch.
##
## The known-answer vectors are shared with the Kotlin suite in
## `host-core/src/test/kotlin/.../SeedDerivationTest.kt`. Both sides derive run
## seeds, and if either implementation drifts a recorded seed stops replaying
## the run it came from — which would quietly invalidate every bug report and
## every seeded test in the project.
##
## The distribution checks exist because a biased generator still passes every
## functional test: dice land in range, loot tables return items, nothing
## crashes. Bias only shows up in aggregate.

## Seed derived from platform entropy 0x11 x32 and engine entropy 0x22 x32.
const VECTOR_SEED_HEX := "885f2e0818c469fdf70db469c23591acac8cd34a1a6ed318f59a3fce6fed66d9"

## Seed derived from the engine source alone, as happens in the editor.
const VECTOR_ENGINE_ONLY_SEED_HEX := "e7d45c80c9427057a62ae89cf5dc1d877c8f525e8e04a954f8f08dcaf31d957f"

## First sixteen bytes of each stream derived from VECTOR_SEED_HEX.
const VECTOR_STREAM_PREFIXES := {
	"map": "bbae17cfdaa9fedcfa7c9b921ea3425e",
	"encounter": "a0e40c6dcb478be520603a94f901051a",
	"loot": "f494f7a27a3c9e65313a811aa820f55a",
	"cosmetic": "41a3cc896c94e48ec59bc518621f85f0",
}

## First ten twenty-sided results drawn from the map stream of VECTOR_SEED_HEX.
const VECTOR_MAP_D20 := [11, 8, 10, 9, 4, 17, 8, 13, 0, 16]


func _seed_bytes(hex: String) -> PackedByteArray:
	return PackedByteArray(Array(hex.hex_decode()))


func before_each() -> void:
	RngService.begin_run_with_seed(_seed_bytes(VECTOR_SEED_HEX))


func test_seed_derivation_matches_shared_vectors() -> void:
	var derived: PackedByteArray = RngService._derive_run_seed(
		_repeated(0x11, 32), _repeated(0x22, 32)
	)
	assert_eq(
		derived.hex_encode(),
		VECTOR_SEED_HEX,
		"run seed derivation must agree with the Kotlin implementation"
	)


func test_seed_derivation_without_platform_entropy_matches_shared_vector() -> void:
	var derived: PackedByteArray = RngService._derive_run_seed(PackedByteArray(), _repeated(0x7f, 32))
	assert_eq(derived.hex_encode(), VECTOR_ENGINE_ONLY_SEED_HEX)


func test_streams_match_shared_vectors() -> void:
	for stream: String in VECTOR_STREAM_PREFIXES:
		var bytes := RngService.next_bytes(stream, 16)
		assert_eq(
			bytes.hex_encode(),
			VECTOR_STREAM_PREFIXES[stream],
			"stream '%s' produced an unexpected sequence" % stream
		)


func test_same_seed_replays_the_same_sequence() -> void:
	var first := RngService.roll_each(RngService.STREAM_MAP, 10, 20)

	RngService.begin_run_with_seed(_seed_bytes(VECTOR_SEED_HEX))
	var second := RngService.roll_each(RngService.STREAM_MAP, 10, 20)

	assert_eq(first, second, "a seed must replay its run exactly")


func test_map_stream_matches_shared_dice_vector() -> void:
	var drawn: Array[int] = []
	for _index in range(VECTOR_MAP_D20.size()):
		drawn.append(RngService.next_below(RngService.STREAM_MAP, 20))

	assert_eq(drawn, VECTOR_MAP_D20)


func test_streams_are_independent() -> void:
	# Drawing heavily from one stream must not disturb another. This is the
	# property that lets a new system be added without changing the dungeons
	# every existing seed generates.
	for _index in range(500):
		RngService.next_below(RngService.STREAM_ENCOUNTER, 100)
	var loot_after_encounters := RngService.next_bytes(RngService.STREAM_LOOT, 16).hex_encode()

	RngService.begin_run_with_seed(_seed_bytes(VECTOR_SEED_HEX))
	var loot_alone := RngService.next_bytes(RngService.STREAM_LOOT, 16).hex_encode()

	assert_eq(loot_after_encounters, loot_alone)


func test_different_seeds_produce_different_runs() -> void:
	var first := RngService.next_bytes(RngService.STREAM_MAP, 32).hex_encode()

	RngService.begin_run_with_seed(_seed_bytes(VECTOR_ENGINE_ONLY_SEED_HEX))
	var second := RngService.next_bytes(RngService.STREAM_MAP, 32).hex_encode()

	assert_ne(first, second)


func test_next_below_stays_in_range() -> void:
	for _index in range(1000):
		var value := RngService.next_below(RngService.STREAM_MAP, 7)
		assert_between(value, 0, 6)


func test_next_below_one_is_always_zero() -> void:
	assert_eq(RngService.next_below(RngService.STREAM_MAP, 1), 0)


func test_next_in_range_is_inclusive_at_both_ends() -> void:
	var seen := {}
	for _index in range(400):
		var value := RngService.next_in_range(RngService.STREAM_MAP, 3, 5)
		assert_between(value, 3, 5)
		seen[value] = true

	assert_eq(seen.size(), 3, "every value in the range must be reachable")


func test_next_float_is_within_the_unit_interval() -> void:
	for _index in range(500):
		var value := RngService.next_float(RngService.STREAM_MAP)
		assert_true(value >= 0.0 and value < 1.0, "float %f left [0, 1)" % value)


func test_dice_rolls_are_bounded_and_summed() -> void:
	var each := RngService.roll_each(RngService.STREAM_ENCOUNTER, 3, 6)
	assert_eq(each.size(), 3)
	for die: int in each:
		assert_between(die, 1, 6)

	RngService.begin_run_with_seed(_seed_bytes(VECTOR_SEED_HEX))
	var total := RngService.roll(RngService.STREAM_ENCOUNTER, 3, 6)
	assert_between(total, 3, 18)


func test_sampling_is_not_measurably_biased() -> void:
	# Rejection sampling, rather than the modulo of a random word, is what keeps
	# low values from being marginally more likely. With 24000 draws over 6
	# buckets the expected count is 4000; a modulo bias on a range this size
	# would be far too small to show here, so the bound is deliberately loose
	# and this test is a smoke check for a gross defect, not a proof.
	var counts := [0, 0, 0, 0, 0, 0]
	for _index in range(24000):
		counts[RngService.next_below(RngService.STREAM_LOOT, 6)] += 1

	for count: int in counts:
		assert_between(count, 3600, 4400, "bucket counts should cluster near 4000")


func test_shuffle_preserves_contents_and_leaves_the_original_alone() -> void:
	var original := [1, 2, 3, 4, 5, 6, 7, 8]
	var shuffled := RngService.shuffled(RngService.STREAM_COSMETIC, original)

	assert_eq(original, [1, 2, 3, 4, 5, 6, 7, 8], "the input array must not be modified")
	assert_eq(shuffled.size(), original.size())
	var sorted_copy := shuffled.duplicate()
	sorted_copy.sort()
	assert_eq(sorted_copy, original, "a shuffle must not add, drop or alter elements")


func test_pick_returns_a_member_of_the_collection() -> void:
	var items := ["a", "b", "c"]
	for _index in range(50):
		assert_has(items, RngService.pick(RngService.STREAM_LOOT, items))


func test_run_seed_is_reported_in_the_form_the_player_sees() -> void:
	assert_eq(RngService.run_seed_hex(), VECTOR_SEED_HEX)


func _repeated(value: int, count: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(count)
	bytes.fill(value)
	return bytes
