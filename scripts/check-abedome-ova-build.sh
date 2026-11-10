#!/usr/bin/env bash
set -euo pipefail

output_dir=$1
core_image=$2
core_archive_digest=$3
supervisor_image=$4
expected_channel=$5

core_repository=${core_image%:*}
core_version=${core_image##*:}
supervisor_repository=${supervisor_image%:*}
supervisor_version=${supervisor_image##*:}
package_dir="${output_dir}/build/hassio-1.0.0"
version_json="${package_dir}/version.json"
data_image="${output_dir}/images/data.ext4"
archive_name="${core_image//[:\/]/_}@${core_archive_digest//[:\/]/_}.tar"
core_archive="${package_dir}/images/${archive_name}"

test -f "${version_json}"
test -f "${data_image}"
test -f "${core_archive}"

jq -e \
	--arg repository "${core_repository}" \
	--arg version "${core_version}" \
	--arg supervisor_repository "${supervisor_repository}" \
	--arg supervisor_version "${supervisor_version}" \
	'.images.core == $repository and .core == $version and .images.supervisor == $supervisor_repository and .supervisor == $supervisor_version' \
	"${version_json}" > /dev/null

upstream_core_archive=$(
	find "${package_dir}/images" -maxdepth 1 -type f \
		-name 'ghcr.io_home-assistant_*homeassistant*.tar' -print -quit
)
if [ -n "${upstream_core_archive}" ]; then
	printf 'Unexpected upstream Core archive: %s\n' "${upstream_core_archive}" >&2
	exit 1
fi

debugfs_bin=$(command -v debugfs || true)
if [ -z "${debugfs_bin}" ]; then
	debugfs_bin="${output_dir}/host/sbin/debugfs"
fi
test -x "${debugfs_bin}"

if "${debugfs_bin}" -R 'stat /docker/.wipe-scheduled' "${data_image}" \
	> /dev/null 2>&1; then
	echo "The candidate data image unexpectedly schedules a Docker data reset." >&2
	exit 1
fi

homeassistant_state="$(
	"${debugfs_bin}" -R 'cat /supervisor/homeassistant.json' "${data_image}" 2> /dev/null
)"
updater_state="$(
	"${debugfs_bin}" -R 'cat /supervisor/updater.json' "${data_image}" 2> /dev/null
)"

jq -e \
	--arg repository "${core_repository}" \
	--arg version "${core_version}" \
	'.image == $repository and .version == $version and .override_image == false' \
	<<< "${homeassistant_state}" > /dev/null
jq -e \
	--arg repository "${core_repository}" \
	--arg version "${core_version}" \
	--arg channel "${expected_channel}" \
	'.channel == $channel and .homeassistant == $version and .image.homeassistant == $repository' \
	<<< "${updater_state}" > /dev/null
