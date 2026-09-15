class_name LootGenerator
extends RefCounted
## Generates the items a run drops.
##
## The catalogue is not a list of finished items. A base is drawn, a rarity buys
## an affix budget, and affixes are drawn until the budget is spent — so the
## number of distinct items is the number of legal combinations rather than the
## number of records anybody wrote. The authored unique items sit outside that
## machinery on their own depth-gated table, which is what keeps one of them
## feeling like an event rather than a tier.
##
## The order of the draws below is fixed and is part of what a seed reproduces.
## Inserting a draw in the middle of it would change every item every existing
## seed generates, so a new decision goes on the end.

## Rarity to the affix budget it buys and how many affixes it may carry.
const RARITY_RULES := {
	Item.RARITY_COMMON: {"budget": 0, "affixes": 0, "weight": 46},
	Item.RARITY_UNCOMMON: {"budget": 30, "affixes": 1, "weight": 32},
	Item.RARITY_RARE: {"budget": 65, "affixes": 2, "weight": 17},
	Item.RARITY_VERY_RARE: {"budget": 110, "affixes": 3, "weight": 5},
}

## Chance in a hundred that an authored unique is drawn instead of a generated
## item, once the depth allows any.
const UNIQUE_CHANCE_PERCENT := 7

## How far above the dungeon depth an item may roll.
const LEVEL_BONUS := 1


## Generates the item found at [param node], or null if it holds nothing.
##
## [param depth] is the dungeon depth, which sets both what may roll and how
## good it is allowed to be.
static func generate(content: ContentDatabase, node: MapNode, depth: int) -> Item:
	var stream := RngService.stream_for(RngService.STREAM_LOOT, node.id)
	var item_level := depth + LEVEL_BONUS

	var unique := _draw_unique(content, stream, depth)
	if unique != null:
		return unique

	var bases := content.filtered(
		"item_bases",
		func(record: Dictionary) -> bool: return int(record.get("item_level", 1)) <= item_level
	)
	if bases.is_empty():
		return null

	var base: Dictionary = bases[RngService.next_below(stream, bases.size())]
	var item := Item.new(String(base.get("id", "")))
	item.item_level = item_level
	item.rarity = _draw_rarity(stream)

	var rules: Dictionary = RARITY_RULES[item.rarity]
	_roll_affixes(content, stream, item, base, rules)
	return item


## Draws an authored unique, or null if none is drawn.
##
## Rolled before anything else so that a unique never consumes the draws a
## generated item would have used; that keeps the two paths independent.
static func _draw_unique(content: ContentDatabase, stream: String, depth: int) -> Item:
	var eligible := content.filtered(
		"uniques", func(record: Dictionary) -> bool: return int(record.get("min_depth", 1)) <= depth
	)
	if eligible.is_empty():
		return null
	if RngService.next_below(stream, 100) >= UNIQUE_CHANCE_PERCENT:
		return null

	var chosen := WeightedPick.record(stream, eligible)
	if chosen.is_empty():
		return null

	var item := Item.new(String(chosen.get("base", "")))
	item.unique_id = String(chosen.get("id", ""))
	item.rarity = String(chosen.get("rarity", Item.RARITY_RARE))
	item.item_level = depth
	return item


static func _draw_rarity(stream: String) -> String:
	var names := PackedStringArray()
	var weights := PackedInt32Array()
	# Walked in the order Item declares rather than the dictionary's, so the
	# draw cannot depend on hash ordering.
	for rarity in Item.RARITY_ORDER:
		names.append(rarity)
		weights.append(int(RARITY_RULES[rarity]["weight"]))
	var chosen := WeightedPick.index(stream, weights)
	return names[chosen] if chosen >= 0 else Item.RARITY_COMMON


## Fills [param item] with affixes until its budget or its count runs out.
##
## At most one prefix and one suffix, because those are the two the name is
## built from and an item with two prefixes could not be named. The budget is
## what stops a cheap affix being taken three times over.
static func _roll_affixes(
	content: ContentDatabase, stream: String, item: Item, base: Dictionary, rules: Dictionary
) -> void:
	var wanted := int(rules["affixes"])
	var budget := int(rules["budget"])
	if wanted <= 0:
		return

	var groups: Array = base.get("affix_groups", [])
	var used_exclusive := PackedStringArray()
	var roles_taken := PackedStringArray()

	for _attempt in range(wanted):
		var candidates := content.filtered(
			"affixes",
			func(record: Dictionary) -> bool:
				return _is_eligible(
					record, groups, item.item_level, budget, used_exclusive, roles_taken
				)
		)
		if candidates.is_empty():
			return

		var affix := WeightedPick.record(stream, candidates)
		if affix.is_empty():
			return

		var affix_id := String(affix.get("id", ""))
		var role := String(affix.get("role", "prefix"))
		budget -= int(affix.get("budget_cost", 0))
		used_exclusive.append(String(affix.get("exclusive_group", "")))
		roles_taken.append(role)
		if role == "prefix":
			item.prefix_id = affix_id
		else:
			item.suffix_id = affix_id

		_roll_effect_values(stream, item, affix)


## Whether one affix may land on this item right now.
static func _is_eligible(
	record: Dictionary,
	groups: Array,
	item_level: int,
	budget: int,
	used_exclusive: PackedStringArray,
	roles_taken: PackedStringArray
) -> bool:
	if int(record.get("min_item_level", 1)) > item_level:
		return false
	if int(record.get("budget_cost", 0)) > budget:
		return false
	if String(record.get("exclusive_group", "")) in used_exclusive:
		return false
	if String(record.get("role", "prefix")) in roles_taken:
		return false
	for group: Variant in record.get("affix_groups", []):
		if String(group) in groups:
			return true
	return false


## Rolls the size of any effect whose magnitude varies, and stores it.
##
## Stored rather than re-rolled so that an item keeps the same numbers for its
## whole life, including across a save and a reload.
static func _roll_effect_values(stream: String, item: Item, affix: Dictionary) -> void:
	var effects: Array = affix.get("effects", [])
	for index in range(effects.size()):
		var effect: Dictionary = effects[index]
		if not effect.has("roll"):
			continue
		var key := "%s:%d" % [String(affix.get("id", "")), index]
		item.rolled_values[key] = Dice.roll(stream, String(effect["roll"]))
