#!/usr/bin/env python3
"""Verify the Android toolchain source of truth and its consumers.

``config/android/toolchain.properties`` is the only authoritative declaration of
the Android SDK, build tools, NDK, CMake, ABI and Java requirements. The value of
a single source of truth is lost the moment a consumer restates one of its
values: the copy then drifts, and the drift is invisible until a build breaks in
a confusing way.

Enforced invariants:

1. Every required key is present, and each value matches its expected shape.
2. Product invariants hold: minSdk is 34, and arm64-v8a is the only ABI.
3. compileSdk is not lower than targetSdk, and both are at least minSdk.
4. ``gradle/libs.versions.toml`` agrees with the AGP and Kotlin versions declared
   here, so the catalogue and the toolchain cannot diverge.
5. No workflow hardcodes a value this file owns.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

TOOLCHAIN_PATH = Path("config/android/toolchain.properties")
CATALOG_PATH = Path("gradle/libs.versions.toml")
WORKFLOW_DIR = Path(".github/workflows")

# key -> (regex the value must match, human-readable description)
REQUIRED_KEYS: dict[str, tuple[str, str]] = {
    "sdk.min": (r"^\d+$", "integer API level"),
    "sdk.compile": (r"^\d+$", "integer API level"),
    "sdk.compile.minor": (r"^\d+$", "integer minor SDK version"),
    "sdk.target": (r"^\d+$", "integer API level"),
    "sdk.target.minor": (r"^\d+$", "integer minor SDK version"),
    "sdk.extension": (r"^\d+$", "integer SDK extension level"),
    "build.tools": (r"^\d+\.\d+\.\d+$", "build-tools revision, e.g. 37.0.0"),
    "ndk": (r"^\d+\.\d+\.\d+$", "NDK revision, e.g. 29.0.14206865"),
    "cmake": (r"^\d+\.\d+\.\d+$", "CMake version, e.g. 4.1.2"),
    "abi.filters": (r"^[a-z0-9\-]+(,[a-z0-9\-]+)*$", "comma-separated ABI list"),
    "java.version": (r"^\d+$", "major Java version"),
    "gradle.version": (r"^\d+\.\d+(\.\d+)?$", "Gradle version"),
    "agp.version": (r"^\d+\.\d+\.\d+$", "Android Gradle plugin version"),
    "kotlin.version": (r"^\d+\.\d+\.\d+$", "Kotlin version"),
    "godot.version": (r"^\d+\.\d+(\.\d+)?$", "Godot version"),
    "godot.channel": (r"^[a-z]+$", "Godot release channel"),
}

# Product invariants that a toolchain edit must not silently violate.
REQUIRED_MIN_SDK = 34
REQUIRED_ABIS = {"arm64-v8a"}


def load_properties(path: Path) -> dict[str, str]:
    """Parse a java.util.Properties-style file (key=value, '#' comments)."""
    values: dict[str, str] = {}
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith(("#", "!")):
            continue
        if "=" not in line:
            raise ValueError(f"{path}:{number}: expected 'key=value', found {raw!r}")
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    return values


def check_catalog(root: Path, properties: dict[str, str]) -> list[str]:
    """Assert the Gradle version catalogue mirrors the toolchain versions."""
    errors: list[str] = []
    catalog_file = root / CATALOG_PATH
    if not catalog_file.is_file():
        return [f"{CATALOG_PATH} is missing"]

    catalog = catalog_file.read_text(encoding="utf-8")
    for catalog_key, property_key in (("agp", "agp.version"), ("kotlin", "kotlin.version")):
        expected = properties.get(property_key)
        if expected is None:
            continue
        match = re.search(
            rf'^{re.escape(catalog_key)}\s*=\s*"([^"]+)"', catalog, re.MULTILINE
        )
        if match is None:
            errors.append(f"{CATALOG_PATH} does not declare a '{catalog_key}' version")
        elif match.group(1) != expected:
            errors.append(
                f"{CATALOG_PATH} declares {catalog_key} = {match.group(1)!r} but "
                f"{TOOLCHAIN_PATH} declares {property_key} = {expected!r}"
            )
    return errors


def check_workflows(root: Path, properties: dict[str, str]) -> list[str]:
    """Fail if a workflow restates a value owned by the toolchain file.

    Only values distinctive enough to be unambiguous are checked. Bare integers
    such as the API level are excluded: they collide with unrelated numbers like
    action versions and timeouts, and would produce false positives.
    """
    errors: list[str] = []
    workflow_dir = root / WORKFLOW_DIR
    if not workflow_dir.is_dir():
        return errors

    guarded = {
        key: properties[key]
        for key in ("build.tools", "ndk", "cmake", "agp.version", "kotlin.version")
        if key in properties and len(properties[key]) >= 5
    }

    for workflow in sorted(workflow_dir.glob("*.yml")):
        for number, raw in enumerate(
            workflow.read_text(encoding="utf-8").splitlines(), start=1
        ):
            # A line that names the source of truth is reading from it, not
            # duplicating it.
            if TOOLCHAIN_PATH.as_posix() in raw:
                continue
            line = raw.split("#", 1)[0]
            for key, value in guarded.items():
                if re.search(rf"(?<![\w.-]){re.escape(value)}(?![\w.-])", line):
                    errors.append(
                        f"{WORKFLOW_DIR / workflow.name}:{number}: hardcodes {value!r}, "
                        f"which is owned by {TOOLCHAIN_PATH} ({key}). Read it from "
                        "the source of truth instead."
                    )
    return errors


def check(root: Path) -> list[str]:
    errors: list[str] = []
    toolchain_file = root / TOOLCHAIN_PATH

    if not toolchain_file.is_file():
        return [f"{TOOLCHAIN_PATH} is missing"]

    try:
        properties = load_properties(toolchain_file)
    except ValueError as exc:
        return [str(exc)]

    for key, (pattern, description) in REQUIRED_KEYS.items():
        if key not in properties:
            errors.append(f"{TOOLCHAIN_PATH}: required key '{key}' is missing")
        elif not re.match(pattern, properties[key]):
            errors.append(
                f"{TOOLCHAIN_PATH}: '{key}' = {properties[key]!r} is not a valid {description}"
            )

    if errors:
        return errors

    min_sdk = int(properties["sdk.min"])
    compile_sdk = int(properties["sdk.compile"])
    target_sdk = int(properties["sdk.target"])

    if min_sdk != REQUIRED_MIN_SDK:
        errors.append(
            f"{TOOLCHAIN_PATH}: sdk.min must be {REQUIRED_MIN_SDK} (Android 14), found {min_sdk}"
        )
    if compile_sdk < target_sdk:
        errors.append(
            f"{TOOLCHAIN_PATH}: sdk.compile ({compile_sdk}) must not be lower than "
            f"sdk.target ({target_sdk})"
        )
    if target_sdk < min_sdk:
        errors.append(
            f"{TOOLCHAIN_PATH}: sdk.target ({target_sdk}) must not be lower than "
            f"sdk.min ({min_sdk})"
        )

    abis = {abi.strip() for abi in properties["abi.filters"].split(",") if abi.strip()}
    if abis != REQUIRED_ABIS:
        errors.append(
            f"{TOOLCHAIN_PATH}: abi.filters must be exactly "
            f"{','.join(sorted(REQUIRED_ABIS))} (64-bit only), found "
            f"{','.join(sorted(abis))}"
        )

    errors.extend(check_catalog(root, properties))
    errors.extend(check_workflows(root, properties))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--root",
        type=Path,
        default=REPO_ROOT,
        help="Repository root to validate (default: the repository containing this script)",
    )
    args = parser.parse_args()

    errors = check(args.root)
    if errors:
        print("Toolchain validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print("Toolchain validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
