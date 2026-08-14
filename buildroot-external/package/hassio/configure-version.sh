#!/usr/bin/env bash
set -euo pipefail

supervisor_image=${1:-}
core_image=${2:-}

# Keep the upstream landing-page bootstrap unless a managed Core image is
# explicitly pinned by the board configuration. Tagged references are split
# into the repository stored under images.* and the matching version field.
jq -e \
	--arg supervisor_image "${supervisor_image}" \
	--arg core_image "${core_image}" \
	'
		if $core_image == "" then
			.core = "landingpage"
		else
			($core_image | capture("^(?<name>[^@]+):(?<tag>[^:/@]+)$")) as $core_reference
			| .images.core = $core_reference.name
			| .core = $core_reference.tag
		end
		| if $supervisor_image == "" then
			.
		else
			($supervisor_image | capture("^(?<name>[^@]+):(?<tag>[^:/@]+)$")) as $supervisor_reference
			| .images.supervisor = $supervisor_reference.name
			| .supervisor = $supervisor_reference.tag
		end
	'
