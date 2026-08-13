#!/usr/bin/env bash
set -e

build_dir=$1
dst_dir=$2
channel=$3
docker_version=$4
supervisor_version_url=$5
preloaded_supervisor_image=$6
preloaded_supervisor_repository=""

# A controlled feed can only update the same approved image source that the
# build preloaded. This prevents an update from falling back to another registry.
if [ -n "${supervisor_version_url}" ]; then
    if [ -z "${preloaded_supervisor_image}" ] || [ "${preloaded_supervisor_image}" = "${preloaded_supervisor_image%:*}" ]; then
        echo "A controlled Supervisor update feed requires a tagged preloaded Supervisor image." >&2
        exit 1
    fi
    preloaded_supervisor_repository="${preloaded_supervisor_image%:*}"
    printf '%s\n' "${preloaded_supervisor_repository}" > "${build_dir}/supervisor-image-repository"
else
    rm -f "${build_dir}/supervisor-image-repository"
fi

data_img="${dst_dir}/data.ext4"
data_dir="${build_dir}/data"

APPARMOR_URL="https://version.home-assistant.io/apparmor_${channel}.txt"

# Make image
rm -f "${data_img}"
truncate --size="1280M" "${data_img}"
mkfs.ext4 -L "hassos-data" -E lazy_itable_init=0,lazy_journal_init=0 "${data_img}"

# Mount / init file structs
mkdir -p "${data_dir}"
sudo mount -o loop,discard "${data_img}" "${data_dir}"

trap 'docker rm -f ${container} > /dev/null; sudo umount ${data_dir} || true' ERR EXIT

# Use official Docker in Docker images
# We use the same version as Buildroot is using to ensure best compatibility
container=$(docker run --privileged -e DOCKER_TLS_CERTDIR="" \
    -v "${data_dir}":/mnt/data \
    -v "${build_dir}":/build \
    -d "docker:${docker_version}-dind" --feature containerd-snapshotter --data-root /mnt/data/docker)

docker exec "${container}" sh /build/dind-import-containers.sh

sudo bash -ex <<EOF
# Indicator for docker-prepare.service to use the containerd snapshotter
touch "${data_dir}/.docker-use-containerd-snapshotter"

# Setup AppArmor
mkdir -p "${data_dir}/supervisor/apparmor"
curl -fsL -o "${data_dir}/supervisor/apparmor/hassio-supervisor" "${APPARMOR_URL}"

# Persist build-time updater channel
jq -n --arg channel "${channel}" '{"channel": \$channel}' > "${data_dir}/supervisor/updater.json"

# An optional ABEDOME update feed is written only when explicitly configured.
# Empty remains the upstream default and does not create this file.
if [ -n "${supervisor_version_url}" ]; then
    jq -n --arg url "${supervisor_version_url}" --arg image "${preloaded_supervisor_repository}" '{"url": \$url, "image": \$image}' > "${data_dir}/supervisor/update-feed.json"
fi
EOF

# Tear down docker and unmount the data partition before shrinking
docker rm -f "${container}" > /dev/null
sudo umount "${data_dir}"
trap - ERR EXIT

# Shrink the filesystem to its minimum size
e2fsck -f -y "${data_img}"
resize2fs -M "${data_img}"

# Truncate image file to match the filesystem size
block_count=$(dumpe2fs -h "${data_img}" 2>/dev/null | awk '/^Block count:/{print $3}')
block_size=$(dumpe2fs -h "${data_img}" 2>/dev/null | awk '/^Block size:/{print $3}')
truncate --size="$((block_count * block_size))" "${data_img}"
