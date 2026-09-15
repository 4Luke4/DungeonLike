# Random number design

DungeonLike is a roguelike: the dungeon, the encounters and the loot of every
run are drawn at random, and the player has to be able to trust that. This
document records how randomness is produced, why it is built this way, and what
the design does and does not promise.

Implementations:

* `game/scripts/autoload/rng_service.gd` — the service everything draws from
* `host-core/src/main/kotlin/com/yuumi/dungeonlike/core/SeedDerivation.kt` and
  `Hkdf.kt` — the same seed derivation on the host side
* `app/src/main/kotlin/com/yuumi/dungeonlike/entropy/HostEntropySource.kt` —
  platform entropy

## The two properties that pull against each other

A run must be **unpredictable**: nobody, including a player who reads the
installed package, may be able to work out in advance what a run will contain.

A run must be **reproducible**: given the seed printed on the run summary, the
same run unfolds again, byte for byte. Without this a bug report that says "the
boss room had no exit" cannot be investigated, and no test can assert anything
about generated content.

Both are achieved by separating them. Entropy is drawn once, from a real source,
at the start of a run; everything afterwards is a deterministic function of that
seed.

## Seeding

```text
platform entropy (SecureRandom, 32 bytes)  ─┐
                                            ├─► HKDF-SHA256 ─► run seed (32 bytes)
engine entropy (Crypto, 32 bytes)          ─┘
```

Two independent sources are used, and both contribute, so that a weakness in
either one alone cannot make a run predictable. The platform half comes from
`java.security.SecureRandom` through the host bridge; the engine half from
`Crypto.generate_random_bytes()`.

The default `SecureRandom` constructor is used rather than
`getInstanceStrong()`, which can block for an unbounded time while the kernel
entropy pool fills — on a cold boot that would stall the first run of the game.

The two inputs are **length-prefixed** before being concatenated. Without the
prefix, a 64-byte draw from one source and a 32+32 split across both would hash
identically, which would let whichever source was larger decide the outcome on
its own.

In the editor and in desktop runs there is no Android host, so the platform half
is empty. The run is still seeded, and `RngService.used_platform_entropy()`
reports that it was seeded from one source only.

## Expansion

The run seed is expanded by **HMAC_DRBG with SHA-256**, as specified in NIST SP
800-90A, built on the engine's native `HMACContext`. No cryptographic primitive
is implemented by hand anywhere in this project.

The generator reseeds itself after every request, which gives backtracking
resistance: recovering the state later does not reveal the numbers already
produced.

## Streams

Each subsystem draws from its own named stream, derived from the run seed with
HKDF under its own label:

| Stream | Draws |
| --- | --- |
| `map` | Layout, room contents, connectivity |
| `encounter` | What appears, initiative, attack and damage rolls |
| `loot` | Drops, item generation, rarity |
| `cosmetic` | Anything with no effect on play |

This is not tidiness. With a single sequence, adding a system — or changing how
many numbers an existing one draws — shifts every later draw, so every recorded
seed would generate a different run after such a change and every seeded test
would need rewriting. With independent streams, a change to encounters leaves
the dungeons that existing seeds generate untouched.

## Unbiased sampling

`next_below(stream, bound)` uses **rejection sampling**, never the modulo of a
random word. Modulo makes the lowest values marginally more likely whenever the
bound does not divide the word range. The effect is invisible in any single
roll, and entirely real across the thousands of loot draws a run makes.

Everything else — `next_in_range`, `next_float`, `roll`, `roll_each`, `pick`,
`shuffled` — is built on that one primitive, so no gameplay code handles raw
bytes and no gameplay code can reintroduce the bias.

## Enforcement

`randi()`, `randf()`, `randi_range()`, `randf_range()`, `randomize()`,
`Array.shuffle()`, `Array.pick_random()` and `RandomNumberGenerator` are
forbidden outside `RngService`. `tools/scripts/check_rng_usage.py` fails the
build on any occurrence, and the failure names the replacement to use.

A stray call would not break anything visibly: the run still plays. It would
simply stop being reproducible, and nobody would notice until a seed failed to
reproduce a reported bug.

## Verified agreement between implementations

The seed derivation exists twice, in Kotlin and in GDScript, and they must
produce identical bytes. Both are pinned to the same known-answer vectors:

| Input | Run seed |
| --- | --- |
| platform `0x11`×32, engine `0x22`×32 | `885f2e08…6fed66d9` |
| platform empty, engine `0x7f`×32 | `e7d45c80…f31d957f` |

asserted in `SeedDerivationTest.kt` and in `game/tests/unit/test_rng_service.gd`.
The HKDF implementation is additionally checked against the published RFC 5869
test vectors. If either implementation drifts, a suite fails rather than runs
quietly replaying differently.

The GDScript suite also pins the first bytes of each stream and the first ten
twenty-sided results of the `map` stream, and includes a distribution check —
because a biased generator passes every functional test there is: dice land in
range, tables return items, nothing crashes.

## What this does not promise

**It is not anti-cheat.** The seed is shown to the player deliberately. A player
who edits the game's memory can change any outcome, and on their own device
that is their business — see the [threat model](../architecture/THREAT_MODEL.md).

**It is not a security boundary.** Nothing secret is protected by these numbers.
The construction is cryptographic because that is what guarantees the
statistical properties and the reproducibility fairness needs, not because an
attacker is being kept out.
