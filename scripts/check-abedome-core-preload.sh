#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repository_root}"

core_image="ghcr.io/mauro2020/abedome-core:2026.11.1"
core_repository=${core_image%:*}
core_version=${core_image##*:}
core_index_digest="sha256:d311b61cbc1e4549b0a4919ce5e66ceb7693b3c89cf27d41def6bd5c4154c211"
core_amd64_digest="sha256:50cfccddde92f1975c01b0f05df99d5b7122e7c3694e3b487e15d034d6c80940"
supervisor_image="ghcr.io/mauro2020/abedome-supervisor:2026.11.0"
supervisor_index_digest="sha256:751e40e46ad35f890d07431d8cbfe96aa692d6508ad42d5c2081756347c8342b"
supervisor_amd64_digest="sha256:da8b1ce7b30415eddf6de3df6f4cfae9c8cd410d7be0fc8fe1b1f83db39c5ffb"

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
grep -Fxq "  ABEDOME_PRELOADED_SUPERVISOR_IMAGE: ${supervisor_image}" \
	.github/workflows/build.yaml
grep -Fxq "  ABEDOME_PRELOADED_SUPERVISOR_DIGEST: ${supervisor_index_digest}" \
	.github/workflows/build.yaml
grep -Fxq "  ABEDOME_PRELOADED_SUPERVISOR_AMD64_DIGEST: ${supervisor_amd64_digest}" \
	.github/workflows/build.yaml
grep -Fxq '  ABEDOME_RELEASE_PINS_READY: "true"' .github/workflows/build.yaml
grep -Fxq '          CANDIDATE_SUFFIX: dev0' .github/workflows/build.yaml

digest_condition="\${{ github.event_name == 'release' || needs.prepare.outputs.publish_build == 'true' || (github.event_name == 'workflow_dispatch' && inputs.abedome_stable_candidate) }}"
candidate_condition="\${{ github.event_name == 'workflow_dispatch' && inputs.abedome_stable_candidate }}"
publish_condition="\${{ github.event_name != 'release' && needs.prepare.outputs.publish_build == 'true' }}"
test "$(grep -Fxc "        if: ${digest_condition}" .github/workflows/build.yaml)" -eq 2

sign_job=$(sed -n '/^  sign:$/,/^  update_index:$/p' .github/workflows/build.yaml)
grep -Fxq "    if: ${digest_condition}" <<< "${sign_job}"
test "$(grep -Fxc "        if: ${publish_condition}" <<< "${sign_job}")" -eq 3
grep -Fq -- '- name: Upload signed digests to R2' <<< "${sign_job}"

candidate_artifact=$(sed -n '/- name: Upload signed candidate digests artifact/,/- name: Upload release assets/p' .github/workflows/build.yaml)
grep -Fxq "        if: ${candidate_condition}" <<< "${candidate_artifact}"
if grep -Fq '          archive: false' <<< "${candidate_artifact}"; then
	echo "The signed candidate digest artifact would expire instead of being retained." >&2
	exit 1
fi
# This GitHub expression must remain literal in the workflow contract.
# shellcheck disable=SC2016
grep -Fq '          name: abedome-stable-candidate-${{ needs.prepare.outputs.version_full }}-digests' <<< "${candidate_artifact}"
grep -Fq '            SHA256SUMS' <<< "${candidate_artifact}"
grep -Fq '            SHA256SUMS.sigstore.json' <<< "${candidate_artifact}"
grep -Fq '          if-no-files-found: error' <<< "${candidate_artifact}"

update_index_job=$(sed -n '/^  update_index:$/,/^  bump_version:$/p' .github/workflows/build.yaml)
grep -Fxq "    if: ${publish_condition}" <<< "${update_index_job}"

core_platform_check=$(sed -n '/- name: Verify configured ABEDOME Core platform image/,/- name: Verify configured ABEDOME Supervisor platform image/p' .github/workflows/build.yaml)
supervisor_platform_check=$(sed -n '/- name: Verify configured ABEDOME Supervisor platform image/,/- name: Override release channel/p' .github/workflows/build.yaml)
# These GitHub expressions must remain literal in the workflow contract.
# shellcheck disable=SC2016
core_index_pin='expected_index_digest="${{ env.ABEDOME_PRELOADED_CORE_DIGEST }}"'
# shellcheck disable=SC2016
core_platform_pin='expected_platform_digest="${{ env.ABEDOME_PRELOADED_CORE_AMD64_DIGEST }}"'
# shellcheck disable=SC2016
supervisor_index_pin='expected_index_digest="${{ env.ABEDOME_PRELOADED_SUPERVISOR_DIGEST }}"'
# shellcheck disable=SC2016
supervisor_platform_pin='expected_platform_digest="${{ env.ABEDOME_PRELOADED_SUPERVISOR_AMD64_DIGEST }}"'
# shellcheck disable=SC2016
index_digest_extract='actual_index_digest="$(jq -r ".Digest" <<< "${inspect}")"'
# shellcheck disable=SC2016
index_digest_compare='if [ "${actual_index_digest}" != "${expected_index_digest}" ]; then'
# shellcheck disable=SC2016
core_raw_index='raw_index="$(skopeo inspect --raw "docker://${core_image}")"'
# shellcheck disable=SC2016
supervisor_raw_index='raw_index="$(skopeo inspect --raw "docker://${supervisor_image}")"'
# shellcheck disable=SC2016
platform_membership='any(.manifests[]?; .digest == \$digest and .platform.os == \"linux\" and .platform.architecture == \"amd64\")'
grep -Fq "${core_index_pin}" <<< "${core_platform_check}"
grep -Fq "${core_platform_pin}" <<< "${core_platform_check}"
grep -Fq "${index_digest_extract}" <<< "${core_platform_check}"
grep -Fq "${index_digest_compare}" <<< "${core_platform_check}"
grep -Fq "${core_raw_index}" <<< "${core_platform_check}"
grep -Fq "${platform_membership}" <<< "${core_platform_check}"
grep -Fq "${supervisor_index_pin}" <<< "${supervisor_platform_check}"
grep -Fq "${supervisor_platform_pin}" <<< "${supervisor_platform_check}"
grep -Fq "${index_digest_extract}" <<< "${supervisor_platform_check}"
grep -Fq "${index_digest_compare}" <<< "${supervisor_platform_check}"
grep -Fq "${supervisor_raw_index}" <<< "${supervisor_platform_check}"
grep -Fq "${platform_membership}" <<< "${supervisor_platform_check}"

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
	'printf "debugfs 1.47.3 (14-May-2025)\\n" >&2' \
	'case "$2" in' \
	'  *homeassistant.json) cat "${FAKE_SUPERVISOR_STATE_DIR}/homeassistant.json" ;;' \
	'  *updater.json) cat "${FAKE_SUPERVISOR_STATE_DIR}/updater.json" ;;' \
	'  "ls -p /docker")' \
	'    case "${FAKE_WIPE_MARKER_STATE:-absent}" in' \
	'      absent)' \
	'        printf "/42/040755/0/0/.//\\n"' \
	'        printf "/2/040755/0/0/..//\\n"' \
	'        ;;' \
	'      present)' \
	'        printf "/42/040755/0/0/.//\\n"' \
	'        printf "/2/040755/0/0/..//\\n"' \
	'        printf "/43/100600/0/0/.wipe-scheduled/0/\\n"' \
	'        ;;' \
	'      ambiguous)' \
	'        printf "/42/040755/0/0/.//\\n"' \
	'        printf "/2/040755/0/0/..//\\n"' \
	'        printf "debugfs: simulated partial directory read\\n" >&2' \
	'        ;;' \
	'      failed) printf "debugfs: simulated command failure\\n" >&2; exit 1 ;;' \
	'      *) exit 2 ;;' \
	'    esac' \
	'    ;;' \
	'  *) exit 1 ;;' \
	'esac' \
	> "${temporary_dir}/bin/debugfs"
chmod +x "${temporary_dir}/bin/debugfs"

PATH="${temporary_dir}/bin:${PATH}" \
	FAKE_SUPERVISOR_STATE_DIR="${fake_state}" \
	bash scripts/check-abedome-ova-build.sh \
		"${fake_output}" "${core_image}" "${core_index_digest}" \
		"${supervisor_image}" dev

for marker_state in present ambiguous failed; do
	if PATH="${temporary_dir}/bin:${PATH}" \
		FAKE_SUPERVISOR_STATE_DIR="${fake_state}" \
		FAKE_WIPE_MARKER_STATE="${marker_state}" \
		bash scripts/check-abedome-ova-build.sh \
			"${fake_output}" "${core_image}" "${core_index_digest}" \
			"${supervisor_image}" dev > /dev/null 2>&1; then
		echo "The post-build verifier accepted Docker reset marker state ${marker_state}." >&2
		exit 1
	fi
done

if PATH="${temporary_dir}/bin:${PATH}" \
	FAKE_SUPERVISOR_STATE_DIR="${fake_state}" \
	bash scripts/check-abedome-ova-build.sh \
		"${fake_output}" "${core_image}" "${core_index_digest}" \
		"${supervisor_image}" stable > /dev/null 2>&1; then
	echo "The post-build verifier accepted a dev updater state as stable." >&2
	exit 1
fi

touch "${fake_package}/images/ghcr.io_home-assistant_qemux86-64-homeassistant_landingpage.tar"
if PATH="${temporary_dir}/bin:${PATH}" \
	FAKE_SUPERVISOR_STATE_DIR="${fake_state}" \
	bash scripts/check-abedome-ova-build.sh \
		"${fake_output}" "${core_image}" "${core_index_digest}" \
		"${supervisor_image}" dev \
		> /dev/null 2>&1; then
	echo "The post-build verifier accepted an upstream Core archive." >&2
	exit 1
fi
