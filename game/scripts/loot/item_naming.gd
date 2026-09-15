class_name ItemNaming
extends RefCounted
## Builds the displayed name of a generated item, in the player's language.
##
## A generated name is a base noun with an adjective in front of it and a phrase
## after it, and the five shipped languages do not agree on where the adjective
## goes or on whether it changes shape. English and German put it before the
## noun; Italian, Spanish and French put it after. Italian, Spanish and French
## inflect it for the noun's gender; German inflects it for gender too, with a
## different set of endings; English does not inflect it at all.
##
## None of that is decided here. Three things in the translation tables decide
## it, so that a translator can fix a wrong name without a code change:
##
## [b]Word order[/b] is an ITEM_NAME_* row per language, written with positional
## placeholders. [code]%1$s[/code] is always the base noun, [code]%2$s[/code] the
## prefix, [code]%3$s[/code] the suffix.
##
## [b]Gender[/b] is a _GRAMMAR row beside each base noun, holding a tag such as
## [code]ms[/code] or [code]fs[/code]. It is a property of the translation, not
## of the item: a longsword is feminine in Italian and neuter in German.
##
## [b]Inflection[/b] is three rows per prefix adjective, one per gender form.
##
## Suffixes are complete noun phrases and never agree with anything, which is a
## constraint on the content rather than a limitation here: it is what keeps
## French elision and the Italian and Spanish article contractions in the hands
## of a translator instead of in a runtime grammar engine.

## Fallback when a base noun declares no gender. Neuter is the safest guess:
## in the two languages that have one it is a real form, and in the three that
## do not the neuter row repeats the masculine.
const DEFAULT_GRAMMAR := "ns"

# Every function here is static, and [method Object.tr] is an instance method,
# so lookups go through the translation singleton directly. It is the same
# table [method Object.tr] consults. Its result is a StringName, which has no
# format operator, so each lookup is converted before it is used or joined.


## The name to show for [param item].
static func display_name(item: Item, content: ContentDatabase) -> String:
	if item.is_unique():
		var unique := content.by_id(item.unique_id)
		return String(TranslationServer.translate(String(unique.get("name_key", ""))))

	var base := content.by_id(item.base_id)
	var base_key := String(base.get("name_key", ""))
	var base_name := String(TranslationServer.translate(base_key))
	var grammar := _grammar_of(base_key)

	var prefix := ""
	if not item.prefix_id.is_empty():
		var affix := content.by_id(item.prefix_id)
		prefix = _affix_name(affix, grammar)

	var suffix := ""
	if not item.suffix_id.is_empty():
		var affix := content.by_id(item.suffix_id)
		suffix = String(TranslationServer.translate(String(affix.get("name_key", ""))))

	var pattern := "ITEM_NAME_BASE"
	if not prefix.is_empty() and not suffix.is_empty():
		pattern = "ITEM_NAME_PREFIX_SUFFIX"
	elif not prefix.is_empty():
		pattern = "ITEM_NAME_PREFIX"
	elif not suffix.is_empty():
		pattern = "ITEM_NAME_SUFFIX"

	return String(TranslationServer.translate(pattern)).format([base_name, prefix, suffix])


## The gender tag of a base noun's translation in the current language.
##
## The tag is itself a translated row, so switching language switches the tag
## along with the noun. A missing or malformed row falls back rather than
## producing a name with a raw key in it.
static func _grammar_of(base_key: String) -> String:
	if base_key.is_empty():
		return DEFAULT_GRAMMAR
	var grammar_key := base_key + "_GRAMMAR"
	var tag := String(TranslationServer.translate(grammar_key))
	return DEFAULT_GRAMMAR if tag == grammar_key or tag.length() != 2 else tag


## The form of an adjective that agrees with [param grammar].
static func _affix_name(affix: Dictionary, grammar: String) -> String:
	var key := String(affix.get("name_key", ""))
	if key.is_empty():
		return ""
	if not bool(affix.get("inflected", false)):
		return String(TranslationServer.translate(key))
	return String(TranslationServer.translate("%s_%s" % [key, grammar.to_upper()]))
