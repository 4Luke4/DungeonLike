extends GutTest
## Tests for how a target's defences change an amount of damage.
##
## The ordering rules are what these assert. Immunity beating vulnerability, and
## each defence applying exactly once, are decisions that would otherwise be
## easy to reimplement differently at a second call site.


func test_an_undefended_type_is_unchanged() -> void:
	var result := Damage.apply("fire", 10, [], [], [])
	assert_eq(result.amount, 10)
	assert_eq(result.applied, Damage.Applied.NORMAL)


func test_resistance_halves_and_rounds_down() -> void:
	# Rounding down means a single point of resisted damage becomes none, which
	# is the intended behaviour rather than an artefact.
	assert_eq(Damage.apply("cold", 7, ["cold"], [], []).amount, 3)
	assert_eq(Damage.apply("cold", 1, ["cold"], [], []).amount, 0)


func test_vulnerability_doubles() -> void:
	assert_eq(Damage.apply("radiant", 6, [], [], ["radiant"]).amount, 12)


func test_immunity_nullifies() -> void:
	assert_eq(Damage.apply("poison", 99, [], ["poison"], []).amount, 0)


func test_immunity_beats_vulnerability() -> void:
	# A creature immune to fire takes nothing from it however vulnerable it is
	# also declared to be. Checking immunity first is what decides this.
	var result := Damage.apply("fire", 10, [], ["fire"], ["fire"])
	assert_eq(result.amount, 0, "immunity wins outright")
	assert_eq(result.applied, Damage.Applied.IMMUNE)


func test_resistance_beats_vulnerability() -> void:
	var result := Damage.apply("fire", 10, ["fire"], [], ["fire"])
	assert_eq(result.amount, 5, "resistance is checked before vulnerability")


func test_one_type_does_not_affect_another() -> void:
	# The reason damage travels as a list of typed amounts: a weapon dealing
	# slashing and fire against something that resists fire should have only the
	# fire halved.
	assert_eq(Damage.apply("slashing", 8, ["fire"], [], []).amount, 8)


func test_every_declared_type_is_named() -> void:
	for damage_type in Damage.TYPES:
		var key := Damage.name_key(damage_type)
		assert_ne(tr(key), key, "%s has no translation" % key)
