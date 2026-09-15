class_name Item
extends RefCounted
## One generated item.
##
## An item is a base, the affixes that landed on it, and the values those
## affixes rolled. The values are stored rather than re-rolled, so that the item
## a player is carrying is the same item after the game is closed and reopened.

const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_VERY_RARE := "very_rare"

## Ascending, so that two items can be compared by how good they look.
const RARITY_ORDER: PackedStringArray = [
	RARITY_COMMON,
	RARITY_UNCOMMON,
	RARITY_RARE,
	RARITY_VERY_RARE,
]

var base_id: String
var prefix_id := ""
var suffix_id := ""

## Set when the item is an authored unique rather than a generated one. A unique
## carries its own name and its own effects and ignores the affix machinery.
var unique_id := ""

var rarity := RARITY_COMMON
var item_level := 1

## Affix identifier to the value it rolled, for effects whose size varies.
var rolled_values: Dictionary = {}


func _init(base: String = "") -> void:
	base_id = base


func is_unique() -> bool:
	return not unique_id.is_empty()


## How good this item looks, for the run summary's "finest find".
func rarity_rank() -> int:
	return RARITY_ORDER.find(rarity)


func to_dict() -> Dictionary:
	return {
		"base_id": base_id,
		"prefix_id": prefix_id,
		"suffix_id": suffix_id,
		"unique_id": unique_id,
		"rarity": rarity,
		"item_level": item_level,
		"rolled_values": rolled_values,
	}


static func from_dict(stored: Dictionary) -> Item:
	var item := Item.new(String(stored.get("base_id", "")))
	item.prefix_id = String(stored.get("prefix_id", ""))
	item.suffix_id = String(stored.get("suffix_id", ""))
	item.unique_id = String(stored.get("unique_id", ""))
	item.rarity = String(stored.get("rarity", RARITY_COMMON))
	item.item_level = int(stored.get("item_level", 1))
	item.rolled_values = stored.get("rolled_values", {})
	return item
