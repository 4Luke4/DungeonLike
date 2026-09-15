#!/usr/bin/env bash
#
# Downloads the pinned Godot editor, verifying it against the checksum published
# with the release before it is unpacked.
#
# The verification is the point. This script pulls a binary from the network into
# a build that then produces the artifact players install; taking that on trust
# would make the release pipeline only as trustworthy as the connection it ran
# over. The release's own SHA512-SUMS.txt is the authority.
#
# Export templates are deliberately NOT downloaded, and that is worth explaining
# because it looks like an omission. This project exports a game PACK only:
# Gradle builds the Android application and embeds the engine as a library, so
# the engine is never asked to package, sign or assemble anything. For a .pck
# path, Godot calls EditorExportPlatform::export_pack() directly and skips the
# can_export() validation that a normal project export performs; the Android
# platform overrides export_project() but not export_pack(), so the base
# implementation runs and it needs no templates, no Android SDK and no keystore.
# Downloading them would add roughly 1.3 GB to every cold run for nothing.
#
# If the engine is ever asked to produce an APK or AAB itself, templates become
# required and this script needs the download restored.
#
# The version comes from config/android/toolchain.properties so that the engine
# used to export the game pack is provably the same build as the engine library
# the application links against.
#
# Usage: tools/scripts/fetch_godot.sh <destination-directory>
#
# On success the destination contains an executable `godot`.

set -euo pipefail

destination="${1:?usage: fetch_godot.sh <destination-directory>}"
repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
toolchain="${repository_root}/config/android/toolchain.properties"

read_property() {
    # Trailing carriage returns would survive into a URL and produce a 404 that
    # is invisible in the log, so they are stripped explicitly.
    sed -n "s/^${1}=//p" "${toolchain}" | tr -d '\r'
}

version="$(read_property 'godot.version')"
release_tag="$(read_property 'godot.releaseTag')"

if [[ -z "${version}" || -z "${release_tag}" ]]; then
    echo "godot.version and godot.releaseTag must be set in ${toolchain}" >&2
    exit 1
fi

base_url="https://github.com/godotengine/godot-builds/releases/download/${release_tag}"
editor_archive="Godot_v${release_tag}_linux.x86_64.zip"

mkdir -p "${destination}"
cd "${destination}"

# A cache restore may already have placed a verified copy here.
if [[ -x "godot" ]]; then
    echo "Godot ${version} already present in ${destination}; skipping download."
    exit 0
fi

echo "Downloading Godot ${version}…"
curl --fail --location --silent --show-error --remote-name "${base_url}/${editor_archive}"
curl --fail --location --silent --show-error --remote-name "${base_url}/SHA512-SUMS.txt"

echo "Verifying the checksum…"
# The published sums file covers every asset of the release; --ignore-missing
# keeps the assets that were not downloaded from being reported as failures.
sha512sum --check --ignore-missing --strict SHA512-SUMS.txt

# --ignore-missing would also pass silently if the archive were absent from the
# sums file entirely, so confirm the name really was listed.
if ! grep --quiet --fixed-strings "${editor_archive}" SHA512-SUMS.txt; then
    echo "${editor_archive} is not listed in SHA512-SUMS.txt; refusing to use it." >&2
    exit 1
fi

echo "Unpacking the editor…"
unzip -q -o "${editor_archive}"
mv "Godot_v${release_tag}_linux.x86_64" godot
chmod +x godot

rm -f "${editor_archive}" SHA512-SUMS.txt

echo "Godot ${version} is ready in ${destination}."
