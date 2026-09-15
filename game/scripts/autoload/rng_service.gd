extends Node
## All randomness in DungeonLike.
##
## Nothing else in the project may call [method @GlobalScope.randi],
## [method @GlobalScope.randf], [method Array.shuffle] or construct a
## [RandomNumberGenerator]; continuous integration fails the build on any such
## call. The reasoning is in `docs/rng/RNG_DESIGN.md`, and it comes down to
## three properties this service provides and ad-hoc calls do not:
##
## [b]Unpredictability.[/b] A run is seeded from real entropy drawn from two
## independent sources — the Android platform generator and the engine's own
## [Crypto] — so nobody can precompute what a run will contain.
##
## [b]Reproducibility.[/b] Expansion from that seed is deterministic, using
## HMAC_DRBG with SHA-256 as specified in NIST SP 800-90A over the engine's
## native [HMACContext]. The same seed always replays the same run, which is
## what makes a bug report actionable and a test possible.
##
## [b]Independence.[/b] Each subsystem draws from its own named stream, derived
## from the run seed with HKDF. Adding a system, or changing how many numbers
## one system draws, cannot shift another system's sequence.

## Emitted once a run has been seeded, carrying the seed in the same
## hexadecimal form the player sees.
signal run_seeded(seed_hex: String)

## Length of a run seed, in bytes.
const SEED_LENGTH := 32

## SHA-256 output length, in bytes.
const HASH_LENGTH := 32

## Domain separator for seed derivation. Versioned so a future change to the
## scheme cannot silently reinterpret seeds recorded under the old one. Must
## match `SeedDerivation.SALT` on the Kotlin side.
const SEED_SALT := "DungeonLike/run-seed/v1"

## Label bound into the seed's expand step. Must match `SeedDerivation.INFO`.
const SEED_INFO := "run-seed"

## Prefix that separates one subsystem's stream from another.
const STREAM_INFO_PREFIX := "DungeonLike/stream/v1:"

## Streams the game draws from. Pick the one that matches what is being
## decided; drawing from the wrong stream couples two systems together.
const STREAM_MAP := "map"
const STREAM_ENCOUNTER := "encounter"
const STREAM_LOOT := "loot"
const STREAM_COSMETIC := "cosmetic"

var _run_seed := PackedByteArray()
var _streams := {}

## Whether the platform contributed entropy to the current run. False means the
## run was seeded by the engine generator alone, which is what happens in the
## editor and on desktop builds.
var _platform_entropy_used := false


## Seeds a fresh run from real entropy and returns the seed.
##
## Both sources are consulted: whichever is available contributes, and at least
## one always is, because the engine's generator is always present.
func begin_run() -> PackedByteArray:
	var crypto := Crypto.new()
	var engine_entropy := crypto.generate_random_bytes(SEED_LENGTH)
	var platform_entropy := HostBridge.host_entropy(SEED_LENGTH)

	_platform_entropy_used = not platform_entropy.is_empty()
	var seed_bytes := derive_run_seed(platform_entropy, engine_entropy)
	_adopt_seed(seed_bytes)
	return seed_bytes


## Replays a previously recorded run.
##
## Used by the "replay this seed" flow, by bug reports and by tests. The run
## unfolds identically to the one the seed came from.
func begin_run_with_seed(seed_bytes: PackedByteArray) -> void:
	assert(seed_bytes.size() == SEED_LENGTH, "a run seed must be %d bytes" % SEED_LENGTH)
	_platform_entropy_used = false
	_adopt_seed(seed_bytes)


## The current run's seed, in the hexadecimal form shown to the player.
func run_seed_hex() -> String:
	return _run_seed.hex_encode()


## Whether the current run drew on platform entropy as well as the engine's.
func used_platform_entropy() -> bool:
	return _platform_entropy_used


## Returns [param count] bytes from [param stream].
func next_bytes(stream: String, count: int) -> PackedByteArray:
	assert(count > 0, "byte count must be positive")
	return _generate(stream, count)


## Returns a uniformly distributed integer in [code][0, bound)[/code].
##
## Rejection sampling is used rather than the modulo of a random word. Modulo
## would make the lowest values marginally more likely whenever [param bound]
## does not divide the word range — a bias small enough to be invisible in play
## and large enough to be real in a game whose loot tables are drawn thousands
## of times per run.
func next_below(stream: String, bound: int) -> int:
	assert(bound > 0, "bound must be positive")
	if bound == 1:
		return 0

	# Largest multiple of `bound` that fits in 32 bits. Draws at or above it are
	# discarded, which is what removes the bias.
	var word_range := 1 << 32
	var limit := word_range - (word_range % bound)

	while true:
		var word := _next_uint32(stream)
		if word < limit:
			return word % bound

	# Unreachable: the loop only exits by returning. GDScript still requires a
	# terminal return for a typed function.
	return 0


## Returns a uniformly distributed integer in [code][low, high][/code],
## inclusive at both ends.
func next_in_range(stream: String, low: int, high: int) -> int:
	assert(low <= high, "range is inverted: %d > %d" % [low, high])
	return low + next_below(stream, high - low + 1)


## Returns a float in [code][0, 1)[/code] with 53 bits of resolution, the most a
## double can represent without rounding to exactly 1.0.
func next_float(stream: String) -> float:
	var bytes := _generate(stream, 8)
	var value := 0
	for index in range(7):
		value = (value << 8) | bytes[index]
	# 56 bits gathered, shifted down to 53 so the result can never round to 1.0.
	value = value >> 3
	return float(value) / float(1 << 53)


## Rolls [param count] dice of [param sides] and returns the total.
func roll(stream: String, count: int, sides: int) -> int:
	var total := 0
	for die in roll_each(stream, count, sides):
		total += die
	return total


## Rolls [param count] dice of [param sides] and returns each result.
##
## Individual results are what the interface shows the player, and what a
## combat log needs in order to explain an outcome.
func roll_each(stream: String, count: int, sides: int) -> Array[int]:
	assert(count > 0, "a roll needs at least one die")
	assert(sides > 1, "a die needs at least two faces")

	var results: Array[int] = []
	for _index in range(count):
		results.append(1 + next_below(stream, sides))
	return results


## Returns a uniformly chosen element of [param items].
func pick(stream: String, items: Array) -> Variant:
	assert(not items.is_empty(), "cannot pick from an empty collection")
	return items[next_below(stream, items.size())]


## Returns a shuffled copy of [param items], leaving the original untouched.
##
## Uses the Fisher-Yates shuffle, which produces every ordering with equal
## probability given an unbiased index source.
func shuffled(stream: String, items: Array) -> Array:
	var result := items.duplicate()
	var index := result.size() - 1
	while index > 0:
		var swap_with := next_below(stream, index + 1)
		var held: Variant = result[index]
		result[index] = result[swap_with]
		result[swap_with] = held
		index -= 1
	return result


## Combines entropy from two sources into a run seed.
##
## Public because it is a meaningful operation in its own right and because the
## test suite pins it against vectors shared with the Kotlin implementation.
## Mirrors `SeedDerivation.deriveRunSeed` exactly; the two must not drift.
func derive_run_seed(
	platform_entropy: PackedByteArray, engine_entropy: PackedByteArray
) -> PackedByteArray:
	# Both inputs are length-prefixed before concatenation. Without the prefix
	# a longer draw from one source could impersonate a split across both.
	var material := PackedByteArray()
	material.append_array(_length_prefixed(platform_entropy))
	material.append_array(_length_prefixed(engine_entropy))

	var prk := _hmac(SEED_SALT.to_utf8_buffer(), material)
	return _hkdf_expand(prk, SEED_INFO.to_utf8_buffer(), SEED_LENGTH)


# --- Internals ---------------------------------------------------------------


func _adopt_seed(seed_bytes: PackedByteArray) -> void:
	_run_seed = seed_bytes
	# Streams are rebuilt from the new seed; keeping old state would leak one
	# run's sequence into the next.
	_streams.clear()
	run_seeded.emit(run_seed_hex())


func _length_prefixed(bytes: PackedByteArray) -> PackedByteArray:
	var size := bytes.size()
	var prefixed := PackedByteArray()
	prefixed.append((size >> 24) & 0xFF)
	prefixed.append((size >> 16) & 0xFF)
	prefixed.append((size >> 8) & 0xFF)
	prefixed.append(size & 0xFF)
	prefixed.append_array(bytes)
	return prefixed


## Lazily instantiates a subsystem's generator.
##
## Each stream is a separate HMAC_DRBG instance seeded with material derived
## from the run seed under its own label, which is what makes the streams
## independent of one another.
func _stream_state(stream: String) -> Dictionary:
	if _streams.has(stream):
		return _streams[stream]

	assert(not _run_seed.is_empty(), "no run has been seeded yet")

	var info := (STREAM_INFO_PREFIX + stream).to_utf8_buffer()
	var seed_material := _hkdf_expand(
		_hmac(SEED_SALT.to_utf8_buffer(), _run_seed), info, SEED_LENGTH
	)
	var state := _drbg_instantiate(seed_material)
	_streams[stream] = state
	return state


## HMAC_DRBG instantiation, NIST SP 800-90A section 10.1.2.3.
func _drbg_instantiate(seed_material: PackedByteArray) -> Dictionary:
	var key := PackedByteArray()
	var value := PackedByteArray()
	key.resize(HASH_LENGTH)
	value.resize(HASH_LENGTH)
	key.fill(0x00)
	value.fill(0x01)

	var state := {"key": key, "value": value}
	_drbg_update(state, seed_material)
	return state


## HMAC_DRBG update, NIST SP 800-90A section 10.1.2.2.
##
## The second half runs only when there is provided data; that asymmetry is what
## makes an update with no input distinct from one with input, and it is part of
## the specification rather than an optimisation.
func _drbg_update(state: Dictionary, provided_data: PackedByteArray) -> void:
	var key: PackedByteArray = state["key"]
	var value: PackedByteArray = state["value"]

	var material := PackedByteArray()
	material.append_array(value)
	material.append(0x00)
	material.append_array(provided_data)
	key = _hmac(key, material)
	value = _hmac(key, value)

	if not provided_data.is_empty():
		material = PackedByteArray()
		material.append_array(value)
		material.append(0x01)
		material.append_array(provided_data)
		key = _hmac(key, material)
		value = _hmac(key, value)

	state["key"] = key
	state["value"] = value


## HMAC_DRBG generate, NIST SP 800-90A section 10.1.2.5.
func _generate(stream: String, count: int) -> PackedByteArray:
	var state := _stream_state(stream)
	var key: PackedByteArray = state["key"]
	var value: PackedByteArray = state["value"]

	var output := PackedByteArray()
	while output.size() < count:
		value = _hmac(key, value)
		output.append_array(value)

	state["value"] = value
	# Reseeding after every request gives backtracking resistance: recovering
	# the state later does not reveal the numbers already produced.
	_drbg_update(state, PackedByteArray())

	return output.slice(0, count)


func _next_uint32(stream: String) -> int:
	var bytes := _generate(stream, 4)
	return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]


## HKDF expand, RFC 5869 section 2.3.
func _hkdf_expand(
	pseudo_random_key: PackedByteArray, info: PackedByteArray, length: int
) -> PackedByteArray:
	var output := PackedByteArray()
	var block := PackedByteArray()
	var counter := 1

	while output.size() < length:
		var material := PackedByteArray()
		material.append_array(block)
		material.append_array(info)
		material.append(counter)
		block = _hmac(pseudo_random_key, material)
		output.append_array(block)
		counter += 1

	return output.slice(0, length)


## HMAC-SHA256 over the engine's native implementation. No cryptographic
## primitive is written by hand in this project.
func _hmac(key: PackedByteArray, message: PackedByteArray) -> PackedByteArray:
	var context := HMACContext.new()
	var started := context.start(HashingContext.HASH_SHA256, key)
	assert(started == OK, "failed to start HMAC context")
	var updated := context.update(message)
	assert(updated == OK, "failed to update HMAC context")
	return context.finish()
