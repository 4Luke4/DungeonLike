# Third-party notices

This file is the complete inventory of third-party material incorporated into, or
distributed with, DungeonLike, together with the attribution statements required
by the applicable licenses.

DungeonLike itself is proprietary (see [`LICENSE.md`](LICENSE.md)). Nothing in
that license restricts your rights in the third-party material listed here.

**Maintenance rule:** whenever a shipped dependency or licensing obligation
changes, this file must be updated in the same pull request.
`scripts/validate_attribution.py` enforces in CI that the required System
Reference Document attribution is present for every supported locale.

---

## 1. System Reference Document 5.2.1

DungeonLike's rules, statistics, and reference data are derived from the System
Reference Document 5.2.1, published by Wizards of the Coast LLC under the
**Creative Commons Attribution 4.0 International License (CC-BY-4.0)**.

- License: <https://creativecommons.org/licenses/by/4.0/legalcode>
- Source: <https://www.dndbeyond.com/srd>

CC-BY-4.0 requires that the following attribution statement accompany the work.
It is reproduced below in each locale DungeonLike ships, using the official
wording published in the corresponding localized edition of the document.

> **Attribution — required.** These statements are a license obligation. They must
> be surfaced in the application's in-app legal/credits screen in the user's active
> locale, not only in this repository file. They must not be reworded, abridged, or
> machine-translated.

<!--
  markdownlint-disable MD034
  MD034 (no-bare-urls) is suppressed for the attribution statements below.
  The licence requires these statements to appear as published, so the URLs
  inside them must not be rewritten as Markdown links or wrapped in angle
  brackets. Satisfying a style rule is not a reason to alter a legal notice.
-->

### English (`en`, default)

> This work includes material from the System Reference Document 5.2.1
> (“SRD 5.2.1”) by Wizards of the Coast LLC, available at
> https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative
> Commons Attribution 4.0 International License, available at
> https://creativecommons.org/licenses/by/4.0/legalcode.

### Italiano (`it`)

> Quest'opera include materiale tratto dal System Reference Document 5.2.1
> ("SRD 5.2.1") di Wizards of the Coast LLC, disponibile all'indirizzo
> https://www.dndbeyond.com/srd. Il SRD 5.2.1 è concesso in licenza ai sensi della
> licenza di attribuzione 4.0 Internazionale di Creative Commons, disponibile
> all'indirizzo https://creativecommons.org/licenses/by/4.0/legalcode.

### Español (`es`)

> Esta obra incluye material procedente del documento de referencia del sistema
> 5.2.1 (“SRD 5.2.1”) de Wizards of the Coast LLC, disponible en
> https://www.dndbeyond.com/srd. La licencia sobre el SRD 5.2.1 se concede de
> acuerdo con la licencia internacional de atribución/reconocimiento 4.0 de
> Creative Commons, disponible en https://creativecommons.org/licenses/by/4.0/legalcode.

### Français (`fr`)

> Cette œuvre inclut du matériel issu du System Reference Document 5.2.1
> (« SRD 5.2.1 ») de Wizards of the Coast LLC, disponible à l'adresse
> https://www.dndbeyond.com/srd. Le SRD 5.2.1 est régi par la Licence Creative
> Commons Attribution 4.0 International, disponible à l'adresse
> https://creativecommons.org/licenses/by/4.0/legalcode.

### Deutsch (`de`)

> Dieses Werk enthält Material aus dem Systemreferenzdokument 5.2.1
> („SRD 5.2.1“) von Wizards of the Coast LLC, verfügbar unter
> https://www.dndbeyond.com/srd. Das SRD 5.2.1 ist lizenziert gemäß Creative
> Commons Namensnennung 4.0 International Public License (verfügbar unter
> https://creativecommons.org/licenses/by/4.0/legalcode.de).

<!-- markdownlint-enable MD034 -->

### Compliance constraints

The license terms attached to the document impose two further obligations that
are binding on this project:

1. **No additional attribution.** No attribution to the publisher, its parent, or
   its affiliates may be included beyond the statement above. Do not add
   "thanks to", logos, or similar references anywhere in the app or repository.
2. **Warranty and liability.** Section 5 of CC-BY-4.0 contains a disclaimer of
   warranties and a limitation of liability that applies to this material.

The source PDFs are intentionally excluded from version control (see
[`.gitignore`](.gitignore)); only extracted, reviewable game data is committed.
See [ADR 0004](docs/architecture/adr/0004-srd-content-pipeline-and-licensing.md).

---

## 2. Godot Engine

The game runs on the Godot Engine, licensed under the **MIT License**.

- Upstream: <https://github.com/godotengine/godot>
- License: <https://github.com/godotengine/godot/blob/master/LICENSE.txt>

Godot bundles a number of third-party components under their own permissive
licenses. Its full, authoritative notice file is `COPYRIGHT.txt` in the engine
repository.

> **Pending obligation.** The engine is not yet integrated (see
> [ADR 0002](docs/architecture/adr/0002-engine-and-ui-architecture.md)). When the
> engine and its export templates are first shipped, the applicable MIT notice and
> the relevant entries from Godot's `COPYRIGHT.txt` must be reproduced here **and**
> surfaced in the in-app legal screen, because they are distributed in the
> application binary.

---

## 3. Build-time and development tooling

Tooling that is used to build, lint, or verify the project but is **not**
distributed in the application binary does not create a notice obligation in the
shipped product. It is nonetheless recorded here for supply-chain transparency:

| Component | Role | License |
| --------- | ---- | ------- |
| Android Gradle plugin | Build system | Apache-2.0 |
| Gradle | Build system | Apache-2.0 |
| Kotlin | Host-layer language and compiler | Apache-2.0 |
| Android SDK, Build Tools, NDK, CMake | Android toolchain | Android SDK Terms of Service / per-component |
| GitHub Actions used in CI | Automation | see each action's repository |

Runtime dependencies are added to this table as they are introduced, because
those **do** ship to users.

---

## 4. Trademarks

All product names, logos, and brands referenced in this file are the property of
their respective owners. Their use is for identification only and does not imply
affiliation with, or endorsement by, those owners.
