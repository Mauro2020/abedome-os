#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repository_root}"

core_image="ghcr.io/mauro2020/abedome-core:2026.9.1.dev7"
core_repository=${core_image%:*}
core_version=${core_image##*:}
core_index_digest="sha256:a8bd4a1e5cc06efa42098ef41c8f98ec8c09a8acd4aba74a3f0b6c292b9269e5"
core_amd64_digest="sha256:14fb530a1936b47e6e4e7fb4f6346aad3f267aa1f4af953a5c24e008896c6c7f"
supervisor_image="ghcr.io/mauro2020/abedome-supervisor:2026.8.0.dev4"

grep -Fxq "BR2_PACKAGE_HASSIO_CORE_IMAGE=\"${core_image}\"" \
	buildroot-external/configs/ova_defconfig

configured_boards=$(
	grep -Rl '^BR2_PACKAGE_HASSIO_CORE_IMAGE=' buildroot-external/configs/*_defconfig
)
test "${configured_boards}" = "buildroot-external/configs/ova_defconfig"

grep -Fxq "  ABEDOME_PRELOADED_CORE_IMAGE: ${core_image}" \
	.github/workflows/build.yaml
grep -Fxq "  ABEDOME_PRELOADED_CORE_DIGEST: ${core_index_digest}" \
	.github/workflows/build.yaml
grep -Fxq "  ABEDOME_PRELOADED_CORE_AMD64_DIGEST: ${core_amd64_digest}" \
	.github/workflows/build.yaml
grep -Fxq '          CANDIDATE_SUFFIX: dev3' .github/workflows/build.yaml
grep -Fxq 'data_image_size="1280M"' \
	buildroot-external/package/hassio/create-data-partition.sh
grep -Fxq '	data_image_size="6144M"' \
	buildroot-external/package/hassio/create-data-partition.sh
grep -Fxq '	minimum_free_mib=256' \
	buildroot-external/package/hassio/create-data-partition.sh

temporary_dir=$(mktemp -d)
trap 'rm -rf "${temporary_dir}"' EXIT

fixture='{"core":"upstream","supervisor":"upstream","images":{"core":"ghcr.io/home-assistant/{machine}-homeassistant","supervisor":"ghcr.io/home-assistant/{arch}-hassio-supervisor"}}'

printf '%s\n' "${fixture}" \
	| bash buildroot-external/package/hassio/configure-version.sh \
		"${supervisor_image}" "${core_image}" \
	> "${temporary_dir}/configured.json"
jq -e \
	--arg core_repository "${core_repository}" \
	--arg core_version "${core_version}" \
	--arg supervisor_repository "${supervisor_image%:*}" \
	--arg supervisor_version "${supervisor_image##*:}" \
	'.images.core == $core_repository and .core == $core_version and .images.supervisor == $supervisor_repository and .supervisor == $supervisor_version' \
	"${temporary_dir}/configured.json" > /dev/null

printf '%s\n' "${fixture}" \
	| bash buildroot-external/package/hassio/configure-version.sh "" "" \
	> "${temporary_dir}/upstream.json"
jq -e \
	'.core == "landingpage" and .images.core == "ghcr.io/home-assistant/{machine}-homeassistant" and .images.supervisor == "ghcr.io/home-assistant/{arch}-hassio-supervisor"' \
	"${temporary_dir}/upstream.json" > /dev/null

if printf '%s\n' "${fixture}" \
	| bash buildroot-external/package/hassio/configure-version.sh \
		"" "${core_repository}@sha256:deadbeef" > /dev/null 2>&1; then
	echo "A digest reference was accepted where a tagged Core image is required." >&2
	exit 1
fi

bash buildroot-external/package/hassio/write-supervisor-state.sh \
	"${temporary_dir}/data" \
	dev \
	'https://mauro2020.github.io/abedome-os/updates/{channel}.json' \
	"${supervisor_image%:*}" \
	"${core_repository}" \
	"${core_version}"

jq -e \
	--arg repository "${core_repository}" \
	--arg version "${core_version}" \
	'.image == $repository and .version == $version and .override_image == false' \
	"${temporary_dir}/data/supervisor/homeassistant.json" > /dev/null
jq -e \
	--arg repository "${core_repository}" \
	--arg version "${core_version}" \
	'.channel == "dev" and .homeassistant == $version and .image.homeassistant == $repository' \
	"${temporary_dir}/data/supervisor/updater.json" > /dev/null

bash buildroot-external/package/hassio/write-supervisor-state.sh \
	"${temporary_dir}/upstream-data" stable "" "" "" ""
jq -e \
	'. == {"channel": "stable"}' \
	"${temporary_dir}/upstream-data/supervisor/updater.json" > /dev/null
test ! -e "${temporary_dir}/upstream-data/supervisor/homeassistant.json"
test ! -e "${temporary_dir}/upstream-data/supervisor/update-feed.json"

# Exercise the post-build verifier with a minimal fake debugfs reader. The real
# candidate job uses host-e2fsprogs against the generated data.ext4 image.
fake_output="${temporary_dir}/output"
fake_package="${fake_output}/build/hassio-1.0.0"
fake_state="${temporary_dir}/data/supervisor"
fake_archive="${core_image//[:\/]/_}@${core_index_digest//[:\/]/_}.tar"
mkdir -p "${fake_package}/images" "${fake_output}/images" "${temporary_dir}/bin"
cp "${temporary_dir}/configured.json" "${fake_package}/version.json"
touch "${fake_package}/images/${fake_archive}" "${fake_output}/images/data.ext4"

# These strings must expand in the generated debugfs stub, not in this script.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/usr/bin/env bash' \
	'set -euo pipefail' \
	'case "$2" in' \
	'  *homeassistant.json) cat "${FAKE_SUPERVISOR_STATE_DIR}/homeassistant.json" ;;' \
	'  *updater.json) cat "${FAKE_SUPERVISOR_STATE_DIR}/updater.json" ;;' \
	'  *) exit 1 ;;' \
	'esac' \
	> "${temporary_dir}/bin/debugfs"
chmod +x "${temporary_dir}/bin/debugfs"

PATH="${temporary_dir}/bin:${PATH}" \
	FAKE_SUPERVISOR_STATE_DIR="${fake_state}" \
	bash scripts/check-abedome-ova-build.sh \
		"${fake_output}" "${core_image}" "${core_index_digest}"

touch "${fake_package}/images/ghcr.io_home-assistant_qemux86-64-homeassistant_landingpage.tar"
if PATH="${temporary_dir}/bin:${PATH}" \
	FAKE_SUPERVISOR_STATE_DIR="${fake_state}" \
	bash scripts/check-abedome-ova-build.sh \
		"${fake_output}" "${core_image}" "${core_index_digest}" \
		> /dev/null 2>&1; then
	echo "The post-build verifier accepted an upstream Core archive." >&2
	exit 1
fi
