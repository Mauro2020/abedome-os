# ABEDOME OVA integration for Proxmox

The x86-64 OVA validation build preloads the approved managed images:

```text
ghcr.io/mauro2020/abedome-supervisor:2026.8.0.dev4
ghcr.io/mauro2020/abedome-core:2026.9.1.dev6
```

It also persists the ABEDOME development feed template:

```text
https://mauro2020.github.io/abedome-os/updates/{channel}.json
```

These settings exist only in `buildroot-external/configs/ova_defconfig`. Other
boards keep the upstream landing-page and update-source behaviour.

## Fresh-boot contract

The build resolves and downloads the approved linux/amd64 Core image, imports
it into the data partition, and seeds the matching managed Core repository and
version with `override_image=false`. The first boot must therefore start the
ABEDOME Core directly, including when the update feed and registry are not yet
reachable. It must never preload or start
`ghcr.io/home-assistant/qemux86-64-homeassistant:landingpage`.

Candidate CI verifies the approved OCI index and platform digests before the
build and verifies the incorporated archive and persisted JSON after the
build. The Supervisor and Core version tags are append-only and must not be
republished.

## Changing an image

A replacement Supervisor or Core reference requires its own published,
immutable development version and reviewed digest. Update the OVA pin, its
workflow digest contract and the feed only through separate reviewed changes.
Do not point a validation OVA at a floating `latest` or `landingpage` alias.

## Proxmox validation

Import the QCOW2 into a new VM on `nvme_storage`. Validate the first boot once
with networking unavailable and once online. In both cases confirm the running
Core image and the persisted Core state, then restart the Supervisor and the
host. The logs must contain no pull, attach or fallback to the upstream
`qemux86-64-homeassistant` repository. Do not reuse or overwrite the validated
migration VM for this fresh-install test.
