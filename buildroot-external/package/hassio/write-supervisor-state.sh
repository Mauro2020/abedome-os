#!/usr/bin/env bash
set -euo pipefail

data_dir=$1
channel=$2
supervisor_version_url=${3:-}
supervisor_repository=${4:-}
core_repository=${5:-}
core_version=${6:-}

mkdir -p "${data_dir}/supervisor"

if [ -n "${core_repository}" ] || [ -n "${core_version}" ]; then
	if [ -z "${core_repository}" ] || [ -z "${core_version}" ]; then
		echo "A preloaded Core repository and version must be configured together." >&2
		exit 1
	fi

	jq -n \
		--arg channel "${channel}" \
		--arg version "${core_version}" \
		--arg image "${core_repository}" \
		'{"channel": $channel, "homeassistant": $version, "image": {"homeassistant": $image}}' \
		> "${data_dir}/supervisor/updater.json"

	jq -n \
		--arg version "${core_version}" \
		--arg image "${core_repository}" \
		'{"version": $version, "image": $image, "override_image": false}' \
		> "${data_dir}/supervisor/homeassistant.json"
else
	jq -n --arg channel "${channel}" '{"channel": $channel}' \
		> "${data_dir}/supervisor/updater.json"
	rm -f "${data_dir}/supervisor/homeassistant.json"
fi

if [ -n "${supervisor_version_url}" ]; then
	if [ -z "${supervisor_repository}" ]; then
		echo "A controlled update feed requires a Supervisor repository." >&2
		exit 1
	fi
	jq -n \
		--arg url "${supervisor_version_url}" \
		--arg image "${supervisor_repository}" \
		'{"url": $url, "image": $image}' \
		> "${data_dir}/supervisor/update-feed.json"
else
	rm -f "${data_dir}/supervisor/update-feed.json"
fi
