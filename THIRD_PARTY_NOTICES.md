# Third-party notices

DungeonLike is proprietary software (see [`LICENSE.md`](LICENSE.md)), but it
depends on, and in some cases ships, third-party components that remain governed
by their own licences. This file records every such component together with the
attribution the component's licence requires.

Keep this file accurate: `CLAUDE.md` makes updating it mandatory whenever a
shipped dependency or a licensing obligation changes. The obligations listed
here must also be reproduced in the in-application credits and licences screen
before the first store release; `docs/release/READINESS.md` tracks that gate.

---

## Game rules and terminology — System Reference Document 5.2.1

DungeonLike's rules vocabulary, creature and item terminology and related game
concepts derive from the System Reference Document 5.2.1, which is published
under the [Creative Commons Attribution 4.0 International
licence](https://creativecommons.org/licenses/by/4.0/legalcode). That licence
requires the following attribution statement to be reproduced verbatim, and
requires that no attribution beyond it be added:

> This work includes material from the System Reference Document 5.2.1 ("SRD
> 5.2.1") by Wizards of the Coast LLC, available at
> https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative
> Commons Attribution 4.0 International License, available at
> https://creativecommons.org/licenses/by/4.0/legalcode.

Notes for contributors:

- The statement above is reproduced exactly as the licence requires. Do not
  reword it, and do not add any further attribution to the publisher.
- The source documents themselves are not redistributed in this repository; the
  `srd/` directory is untracked.
- The localised editions of the same document are the authoritative source for
  Italian, Spanish, French and German rules terminology. See
  [`docs/i18n/LOCALIZATION.md`](docs/i18n/LOCALIZATION.md).

---

## Godot Engine — Android library

`org.godotengine:godot` is embedded in the shipped application and is licensed
under the MIT licence:

```
Copyright (c) 2014-present Godot Engine contributors.
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

The Godot engine additionally bundles third-party libraries with their own
licences (mbedTLS, FreeType, Swappy and others). Their notices are produced by
the engine itself through `Engine.get_license_info()` and
`Engine.get_copyright_info()`, and the in-application licences screen renders
them directly from the running engine so the list can never drift from the
engine build that actually ships.

---

## AndroidX and Google Play libraries

The following components ship inside the application and are licensed under the
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0):

| Component | Purpose |
| --- | --- |
| `androidx.core:core-ktx` | Platform compatibility helpers |
| `androidx.appcompat:appcompat` | Compatibility application and activity base classes |
| `androidx.activity:activity-ktx` | Activity result and lifecycle APIs |
| `androidx.fragment:fragment-ktx` | Fragment host for the embedded engine |
| `androidx.core:core-splashscreen` | Compatible splash screen |
| `androidx.window:window` | Adaptive layout and window metrics |
| `com.google.android.gms:play-services-games-v2` | Play Games achievements |

The Apache License 2.0 requires that a copy of the licence and any `NOTICE`
content accompany distribution; the in-application licences screen carries both.

---

## Development-only tooling

The tools below are used to lint, test and build DungeonLike. They are **not**
shipped inside the application and impose no obligation on the distributed
binary. They are listed for completeness and provenance.

| Tool | Licence |
| --- | --- |
| Gradle | Apache License 2.0 |
| Android Gradle plugin | Apache License 2.0 |
| Kotlin | Apache License 2.0 |
| GUT (Godot Unit Test) | MIT |
| gdtoolkit (`gdlint`, `gdformat`) | MIT |
| JUnit 5 | Eclipse Public License 2.0 |
| GitHub Actions used by the workflows | See each action's repository |
