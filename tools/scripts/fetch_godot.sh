#!/usr/bin/env bash
#
# Downloads the pinned Godot editor and export templates, verifying both against
# the checksums published with the release before anything is unpacked.
#
# The verification is the point. This script pulls roughly 1.3 GB from the
# network into a build that then produces the artifact players install; taking
# that on trust would make the release pipeline only as trustworthy as the
# connection it ran over. The release's own SHA512-SUMS.txt is the authority.
#
# The version comes from config/android/toolchain.properties so that the engine
# used to export the game pack is provably the same build as the engine library
# the application links against.
#
# Usage: tools/scripts/fetch_godot.sh <destination-directory>
#
# On success the destination contains:
#   godot                                  the editor binary, executable
#   templates/<version>/                   export templates, where the editor expects them

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
templates_archive="Godot_v${release_tag}_export_templates.tpz"

mkdir -p "${destination}"
cd "${destination}"

# A cache restore may have already placed a verified copy here. Re-downloading
# 1.3 GB to arrive at the same bytes is the single slowest thing this pipeline
# could do.
if [[ -x "godot" && -d "templates/${version}" ]]; then
    echo "Godot ${version} already present in ${destination}; skipping download."
    exit 0
fi

echo "Downloading Godot ${version} and its export templates…"
curl --fail --location --silent --show-error --remote-name "${base_url}/${editor_archive}"
curl --fail --location --silent --show-error --remote-name "${base_url}/${templates_archive}"
curl --fail --location --silent --show-error --remote-name "${base_url}/SHA512-SUMS.txt"

echo "Verifying checksums…"
# The published sums file covers every asset of the release; only the two files
# actually downloaded are checked, and --ignore-missing keeps the rest from
# being reported as failures.
sha512sum --check --ignore-missing --strict SHA512-SUMS.txt

# Both archives are named in the sums file, so a silent mismatch between "the
# file verified" and "the file downloaded" would be a real risk if the grep
# above found nothing. Confirm each name was actually present.
for archive in "${editor_archive}" "${templates_archive}"; do
    if ! grep --quiet --fixed-strings "${archive}" SHA512-SUMS.txt; then
        echo "${archive} is not listed in SHA512-SUMS.txt; refusing to use it." >&2
        exit 1
    fi
done

echo "Unpacking the editor…"
unzip -q -o "${editor_archive}"
mv "Godot_v${release_tag}_linux.x86_64" godot
chmod +x godot

echo "Unpacking the export templates…"
# The templates archive is a zip whose contents live under templates/; the
# editor looks for them in a directory named after the exact version.
#
# Extraction goes through a staging directory rather than unpacking in place.
# The version directory is named "4.7.2.stable", so a glob like templates/*.*
# would match the destination itself and the move would fail silently, leaving
# the editor with no templates and a build that fails much later with a far
# less obvious message.
rm -rf templates_staging
unzip -q -o "${templates_archive}" -d templates_staging
mkdir -p "templates/${version}"
mv templates_staging/templates/* "templates/${version}/"
rm -rf templates_staging

# An empty template directory would take the failure all the way to the export
# step, where the cause is no longer visible.
if [ -z "$(ls -A "templates/${version}")" ]; then
    echo "No export templates were extracted into templates/${version}." >&2
    exit 1
fi

rm -f "${editor_archive}" "${templates_archive}" SHA512-SUMS.txt

echo "Godot ${version} is ready in ${destination}."
