extends GutTest
## Tests for d20 resolution.
##
## The natural results are the point of these tests. A natural twenty hitting
## regardless of armour class is what stops an opponent being unreachable, and a
## natural one missing regardless of bonus is what stops an attacker being
## certain; both override the arithmetic entirely, so both need asserting
## separately from the ordinary comparison.

const SEED := "test_checks"


func before_each() -> void:
	var bytes := PackedByteArray()
	bytes.resize(RngService.SEED_LENGTH)
	bytes.fill(0x11)
	RngService.begin_run_with_seed(bytes)


func test_a_natural_twenty_always_succeeds_and_is_critical() -> void:
	var outcome := Checks.Outcome.new(20, -5, 40)
	assert_true(outcome.succeeded, "a natural twenty hits whatever the armour class")
	assert_true(outcome.critical, "a natural twenty is a critical hit")


func test_a_natural_one_always_fails() -> void:
	var outcome := Checks.Outcome.new(1, 50, 2)
	assert_false(outcome.succeeded, "a natural one misses whatever the bonus")
	assert_true(outcome.fumbled)


func test_an_ordinary_roll_compares_against_the_target() -> void:
	assert_true(Checks.Outcome.new(10, 5, 15).succeeded, "15 meets a target of 15")
	assert_false(Checks.Outcome.new(10, 4, 15).succeeded, "14 does not meet a target of 15")


func test_advantage_and_disadvantage_cancel() -> void:
	# Not an approximation of the rule but the rule itself, and it matters here
	# for a second reason: the number of dice drawn from a stream must not
	# depend on how many sources of each a combatant happens to have.
	assert_eq(Checks.combine_bias(true, true), Checks.Bias.NONE)
	assert_eq(Checks.combine_bias(false, false), Checks.Bias.NONE)
	assert_eq(Checks.combine_bias(true, false), Checks.Bias.ADVANTAGE)
	assert_eq(Checks.combine_bias(false, true), Checks.Bias.DISADVANTAGE)


func test_advantage_keeps_the_better_of_two_dice() -> void:
	# Over many rolls the advantaged average must exceed the plain one. A single
	# roll proves nothing; the difference is a property of the distribution.
	var plain_total := 0
	var advantaged_total := 0
	for _attempt in range(400):
		plain_total += Checks.resolve(SEED, 0, 99).natural
		advantaged_total += Checks.resolve(SEED, 0, 99, Checks.Bias.ADVANTAGE).natural
	assert_gt(advantaged_total, plain_total, "advantage must do better than a single die")


func test_disadvantage_keeps_the_worse_of_two_dice() -> void:
	var plain_total := 0
	var disadvantaged_total := 0
	for _attempt in range(400):
		plain_total += Checks.resolve(SEED, 0, 99).natural
		disadvantaged_total += Checks.resolve(SEED, 0, 99, Checks.Bias.DISADVANTAGE).natural
	assert_lt(disadvantaged_total, plain_total, "disadvantage must do worse than a single die")


func test_every_roll_is_within_the_die() -> void:
	for _attempt in range(300):
		assert_between(Checks.resolve(SEED, 0, 10).natural, 1, Checks.DIE_SIDES)
