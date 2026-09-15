extends GutTest
## Tests for dice expressions.
##
## Content declares every damage, heal and count as a string, so this parser
## stands between a typo in a JSON file and a monster that silently deals no
## damage. Rejecting a malformed expression matters more than parsing a valid
## one, which is why most of these tests are about what it refuses.

const SEED := "test_dice"


func before_each() -> void:
	RngService.begin_run_with_seed(_fixed_seed())


func test_a_plain_expression_parses() -> void:
	var parsed := Dice.parse("2d6")
	assert_not_null(parsed, "2d6 is a valid expression")
	assert_eq(parsed.count, 2)
	assert_eq(parsed.sides, 6)
	assert_eq(parsed.modifier, 0)


func test_a_positive_modifier_parses() -> void:
	var parsed := Dice.parse("1d8+3")
	assert_eq(parsed.modifier, 3)


func test_a_negative_modifier_parses() -> void:
	var parsed := Dice.parse("1d8-2")
	assert_eq(parsed.modifier, -2)


func test_a_doubled_operator_is_rejected() -> void:
	# The case this parser exists for: a lenient reader would treat "2d6++2" as
	# zero damage and nothing would ever report it.
	assert_null(Dice.parse("2d6++2"), "a doubled operator is not a dice expression")


func test_nonsense_is_rejected() -> void:
	for expression in ["", "d6", "2d", "two_d_six", "2x6", "2d6+"]:
		assert_null(Dice.parse(expression), "'%s' must not parse" % expression)


func test_a_roll_stays_within_its_bounds() -> void:
	# Rolled many times because a bound that is wrong by one shows up rarely.
	for _attempt in range(200):
		var rolled := Dice.roll(SEED, "3d6+2")
		assert_between(rolled, 5, 20, "3d6+2 must land between 5 and 20")


func test_a_negative_total_is_floored_at_zero() -> void:
	# A large negative modifier must not heal the target it was meant to hurt.
	for _attempt in range(50):
		assert_gte(Dice.roll(SEED, "1d4-10"), 0, "damage can never be negative")


func test_a_critical_doubles_the_dice_but_not_the_modifier() -> void:
	# The lowest a critical 2d6+5 can roll is 2 dice doubled to 4, each showing
	# one, plus the modifier once: 9. If the modifier were doubled it would be
	# 14, and if the dice were not doubled it would be 7.
	for _attempt in range(200):
		var rolled := Dice.roll_critical(SEED, "2d6+5")
		assert_between(rolled, 9, 29, "a critical doubles the dice and not the modifier")


func test_the_same_seed_produces_the_same_roll() -> void:
	RngService.begin_run_with_seed(_fixed_seed())
	var first := Dice.roll(SEED, "4d8+1")
	RngService.begin_run_with_seed(_fixed_seed())
	var second := Dice.roll(SEED, "4d8+1")
	assert_eq(first, second, "a seed must reproduce its rolls exactly")


func _fixed_seed() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(RngService.SEED_LENGTH)
	bytes.fill(0x2a)
	return bytes
