#!/bin/sh
set -e

# Make sure we can talk to the Docker daemon
echo "Waiting for Docker daemon..."
while ! docker version 2> /dev/null > /dev/null; do
	sleep 1
done

# Install Supervisor, plug-ins and landing page
echo "Loading container images..."

# Make sure to order images by size (largest first)
# It seems docker load requires space during operation
# shellcheck disable=SC2045
for image in $(ls -S /build/images/*.tar); do
	docker load --input "${image}"
done

# Tag the Supervisor how the OS expects it to be tagged. A controlled feed,
# when explicitly configured at build time, uses the approved preloaded source.
supervisor=$(docker images --filter "label=io.hass.type=supervisor" --quiet)
arch=$(docker inspect --format '{{ index .Config.Labels "io.hass.arch" }}' "${supervisor}")
supervisor_image="ghcr.io/home-assistant/${arch}-hassio-supervisor"

if [ -f /build/supervisor-image-repository ]; then
	supervisor_image=$(cat /build/supervisor-image-repository)
fi

docker tag "${supervisor}" "${supervisor_image}:latest"

# A managed Core preload must be the exact tagged image selected by the board.
# Validate the imported archive before the data partition is finalized so an
# upstream landing page or mislabeled image cannot silently enter the OVA.
if [ -f /build/core-image-reference ]; then
	core_image=$(cat /build/core-image-reference)
	core_version=${core_image##*:}

	if ! docker image inspect "${core_image}" > /dev/null 2>&1; then
		echo "The approved preloaded Core image was not imported: ${core_image}" >&2
		exit 1
	fi

	core_type=$(docker inspect --format '{{ index .Config.Labels "io.hass.type" }}' "${core_image}")
	core_arch=$(docker inspect --format '{{ index .Config.Labels "io.hass.arch" }}' "${core_image}")
	core_label_version=$(docker inspect --format '{{ index .Config.Labels "io.hass.version" }}' "${core_image}")

	if [ "${core_type}" != "core" ] || [ "${core_arch}" != "amd64" ] || \
	   [ "${core_label_version}" != "${core_version}" ]; then
		echo "The preloaded Core labels do not match the approved amd64 Core version." >&2
		exit 1
	fi

	if docker images --format '{{.Repository}}' | grep -Eq '^ghcr\.io/home-assistant/.+-homeassistant$'; then
		echo "An upstream Home Assistant Core repository was imported with the managed ABEDOME Core." >&2
		exit 1
	fi
fi
