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

if ! docker_directory="$(
	"${debugfs_bin}" -R 'ls -p /docker' "${data_image}" 2>&1
)"; then
	echo "Unable to inspect the candidate Docker data directory." >&2
	printf '%s\n' "${docker_directory}" >&2
	exit 1
fi

# The machine-readable debugfs listing is /inode/mode/uid/gid/name/size/.
# Require its dot entry and reject every unexpected line so lookup and partial
# read errors cannot be mistaken for an empty directory. awk exits 0 when the
# marker is present, 1 when it is safely absent, and 2 for ambiguous output.
docker_directory_status=0
awk -F/ '
	/^[[:space:]]*$/ { next }
	/^debugfs [^[:space:]]+ \([^)]*\)$/ { next }
	$1 == "" &&
	$2 ~ /^[0-9]+$/ &&
	$3 ~ /^[0-7]+$/ &&
	$4 ~ /^[0-9]+$/ &&
	$5 ~ /^[0-9]+$/ &&
	NF == 8 &&
	($7 == "" || $7 ~ /^[0-9]+$/) &&
	$8 == "" {
		if ($6 == ".") valid_directory = 1
		if ($6 == ".wipe-scheduled") marker_found = 1
		next
	}
	{ invalid_output = 1 }
	END {
		if (invalid_output || !valid_directory) exit 2
		if (marker_found) exit 0
		exit 1
	}
' <<< "${docker_directory}" || docker_directory_status=$?

case "${docker_directory_status}" in
	0)
		echo "The candidate data image unexpectedly schedules a Docker data reset." >&2
		exit 1
		;;
	1) ;;
	*)
		echo "Unable to verify the candidate Docker data directory." >&2
		printf '%s\n' "${docker_directory}" >&2
		exit 1
		;;
esac

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
