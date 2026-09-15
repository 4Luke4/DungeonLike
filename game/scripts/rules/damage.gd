class_name Damage
extends RefCounted
## Damage types, and what a target's resistances do to an amount of them.
##
## A creature that is immune to poison and vulnerable to fire needs both facts
## applied to the right part of a mixed attack, which is why damage travels as a
## list of typed amounts rather than as one number. A weapon that deals
## slashing and fire has the fire halved against something that resists fire,
## and the slashing untouched.


## Every damage type content may name. Kept in step with the vocabulary
## tools/scripts/check_content.py validates against.
const TYPES: PackedStringArray = [
	"acid",
	"bludgeoning",
	"cold",
	"fire",
	"force",
	"lightning",
	"necrotic",
	"piercing",
	"poison",
	"psychic",
	"radiant",
	"slashing",
	"thunder",
]

## How a defence changed an amount, so the combat log can say which applied.
enum Applied { NORMAL, RESISTED, IMMUNE, VULNERABLE }


## One typed amount of damage after a target's defences have been applied.
class Result:
	extends RefCounted

	var damage_type: String
	var amount: int
	var applied: int

	func _init(type_name: String, final_amount: int, how: int) -> void:
		damage_type = type_name
		amount = final_amount
		applied = how


## Applies one target's defences to [param amount] of [param damage_type].
##
## Immunity is checked first and wins outright; a creature immune to fire takes
## nothing from it however vulnerable it might also be. Resistance halves and
## vulnerability doubles, and each applies once — stacking either would make two
## sources of the same resistance better than one, which is not how they work.
##
## Halving rounds down, so a single point of resisted damage becomes none.
static func apply(
	damage_type: String,
	amount: int,
	resistances: PackedStringArray,
	immunities: PackedStringArray,
	vulnerabilities: PackedStringArray
) -> Result:
	if damage_type in immunities:
		return Result.new(damage_type, 0, Applied.IMMUNE)
	if damage_type in resistances:
		return Result.new(damage_type, amount / 2, Applied.RESISTED)
	if damage_type in vulnerabilities:
		return Result.new(damage_type, amount * 2, Applied.VULNERABLE)
	return Result.new(damage_type, amount, Applied.NORMAL)


## The localisation key naming [param damage_type] to the player.
static func name_key(damage_type: String) -> String:
	return "DAMAGE_" + damage_type.to_upper()
