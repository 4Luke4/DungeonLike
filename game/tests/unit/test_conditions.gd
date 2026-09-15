extends GutTest
## Tests for conditions and their effects.
##
## A condition is read from three places — when its sufferer attacks, when
## something attacks its sufferer, and when its sufferer's turn ends. These
## tests pin all three, because a condition added later that was remembered in
## only two would be a silent half-implementation.

var _conditions: Conditions


func before_each() -> void:
	_conditions = Conditions.new()


func test_a_condition_applies_and_is_reported() -> void:
	_conditions.apply(Conditions.POISONED, 2)
	assert_true(_conditions.has(Conditions.POISONED))
	assert_has(Array(_conditions.active()), Conditions.POISONED)


func test_an_unknown_condition_is_refused() -> void:
	# Content could otherwise name a condition nothing implements, and it would
	# be a silent no-op rather than an error.
	#
	# The predicate is asserted rather than the refusal itself: apply() reports
	# an unknown name with push_error, which is what it should do, and GUT
	# treats an engine error raised during a test as a failure.
	assert_false(Conditions.is_known("bewildered"), "an invented name is not a condition")
	assert_true(Conditions.is_known(Conditions.POISONED), "a declared one is")


func test_a_second_application_extends_but_never_shortens() -> void:
	# A plain assignment would let a second, weaker dose of poison cut the first
	# one short, which reads in play as an effect wearing off early for no
	# reason.
	_conditions.apply(Conditions.POISONED, 5)
	_conditions.apply(Conditions.POISONED, 2)
	assert_eq(_conditions.to_dict()[Conditions.POISONED], 5, "the longer duration wins")


func test_a_condition_expires_after_its_rounds() -> void:
	_conditions.apply(Conditions.STUNNED, 2)
	assert_eq(_conditions.advance_round().size(), 0, "still in force after one round")
	assert_has(Array(_conditions.advance_round()), Conditions.STUNNED)
	assert_false(_conditions.has(Conditions.STUNNED))


func test_conditions_that_prevent_acting() -> void:
	for condition in Conditions.PREVENTS_ACTING:
		var subject := Conditions.new()
		subject.apply(condition, 1)
		assert_true(subject.prevents_acting(), "%s must stop its sufferer acting" % condition)


func test_poison_gives_its_sufferer_disadvantage() -> void:
	_conditions.apply(Conditions.POISONED, 1)
	assert_true(_conditions.gives_sufferer_disadvantage())


func test_prone_makes_its_sufferer_easier_to_hit() -> void:
	_conditions.apply(Conditions.PRONE, 1)
	assert_true(_conditions.gives_attackers_advantage())


func test_invisibility_makes_its_sufferer_harder_to_hit() -> void:
	_conditions.apply(Conditions.INVISIBLE, 1)
	assert_true(_conditions.gives_attackers_disadvantage())


func test_active_conditions_keep_a_stable_order() -> void:
	# The interface reads this every frame; an order that came from a dictionary
	# could change between frames and make the list flicker.
	_conditions.apply(Conditions.STUNNED, 1)
	_conditions.apply(Conditions.BLINDED, 1)
	assert_eq(Array(_conditions.active()), [Conditions.BLINDED, Conditions.STUNNED])


func test_a_round_trip_preserves_every_condition() -> void:
	_conditions.apply(Conditions.FRIGHTENED, 3)
	_conditions.apply(Conditions.RESTRAINED, 1)
	var restored := Conditions.new()
	restored.from_dict(_conditions.to_dict())
	assert_eq(Array(restored.active()), Array(_conditions.active()))


func test_every_condition_is_named() -> void:
	for condition in Conditions.ALL:
		var key := Conditions.name_key(condition)
		assert_ne(tr(key), key, "%s has no translation" % key)
