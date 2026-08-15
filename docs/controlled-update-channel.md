# ABEDOME controlled update channel

## Purpose

ABEDOME follows Home Assistant upstream. This repository can optionally configure
a separate Supervisor manifest source for a deliberately approved ABEDOME test or
release channel.

The setting is enabled only by the ABEDOME OVA/qemux86-64 configuration.
Other board configurations that do not set it retain the unchanged upstream
update behaviour.

## Build-time configuration

`BR2_PACKAGE_HASSIO_SUPERVISOR_VERSION_URL` accepts an HTTPS URL template that
contains `{channel}`, for example:

```text
https://updates.example.invalid/{channel}.json
```

When configured, the URL and the approved Supervisor image repository are
persisted inside the data partition as `/mnt/data/supervisor/update-feed.json`.
The image repository is derived from the tagged
`BR2_PACKAGE_HASSIO_SUPERVISOR_IMAGE` value and must be available on GHCR.

`BR2_PACKAGE_HASSIO_CORE_IMAGE` optionally selects an approved, tagged managed
Core image. When it is set, the build replaces the upstream landing-page
preload with that exact Core repository and version. It also writes the
matching `homeassistant.json` and cached updater state with
`override_image=false`. A fresh OVA can therefore start the managed ABEDOME
Core without first contacting either the update feed or a container registry.
The default is empty, which preserves the upstream landing-page bootstrap on
boards that do not opt in.

At boot, both values are required before the Supervisor is started with
`SUPERVISOR_VERSION_URL`. The preloaded image is tagged from that same
repository, so a first boot does not need to pull from a different registry.
It is set in the ABEDOME OVA configuration together with the matching tagged
Supervisor and Core images; these values must never be configured
independently. Only the OVA/qemux86-64 configuration enables this preload.

A missing, malformed, non-HTTPS, or incomplete configuration is ignored at
boot, leaving the standard upstream behaviour in place.

## Release gates before activation

Do not add a real feed URL to a distribution until all of these are true:

1. The manifest is versioned and its container tags are checked against
   explicitly approved digests immediately before publication.
2. The ABEDOME Supervisor and Core images and the matching OS artifact have
   completed CI and are published with unique development versions that are
   never republished.
3. The RAUC artifact is signed with the private production key; that key is not
   stored in this repository.
4. The update was installed in the Proxmox test VM and rollback was verified.
5. A human explicitly approved promotion from test to release.
6. The test OVA embeds the feed template and the matching tagged preloaded
   Supervisor and Core images.

The feed remains a development-only channel until the signed OVA, fresh install,
in-place update and rollback have all been validated on Proxmox.

## Dedicated Proxmox update-test build

The `OS build` workflow has an explicit `abedome_update_test` switch. It is
`false` by default and changes nothing in ordinary builds.

When enabled, the workflow accepts only this deliberately narrow manual scope:

- branch `abedome/develop`;
- board `ova` (x86-64);
- channel `dev`;
- `publish=false` and `run_tests=false`;
- target OS candidate `18.2.dev2` (the earlier `18.2.dev0` fresh-image
  candidate and failed `18.2.dev1` preload build remain immutable and are not
  rebuilt);
- installed upgrade source `17.3.dev1785881843` on a clone of the validated VM;
- preloaded Supervisor `ghcr.io/mauro2020/abedome-supervisor:2026.8.0.dev4`;
- preloaded managed Core `ghcr.io/mauro2020/abedome-core:2026.9.1.dev6`;
- feed template `https://mauro2020.github.io/abedome-os/updates/{channel}.json`.

Candidate CI verifies the Core tag against the approved OCI index and
linux/amd64 manifest digests before building. It then verifies the exact Core
archive incorporated into the data partition, the persisted Core/updater JSON,
and the absence of an upstream `qemux86-64-homeassistant` archive. This second
check prevents a tag move between the registry preflight and the image fetch
from entering an artifact unnoticed.

The resulting `18.2.dev2` OVA and RAUC bundle are disposable candidates for
controlled Proxmox validation. Use the OVA for a fresh-install test in a new VM;
apply the RAUC bundle separately to a clone of the existing
`17.3.dev1785881843` validation VM. They are not release artifacts and must not
be published to a stable or beta channel.

The manually generated dev manifest may replace the Supervisor version and
image repository, and replace only `homeassistant.qemux86-64` with the approved
ABEDOME Core version while setting `images.core` to the ABEDOME GHCR repository.
The upstream version keys for other machines remain inherited only for manifest
compatibility. Because `images.core` is global, the feed is supported
exclusively on the dedicated OVA/qemux86-64 test build and must not be configured
on ARM or another machine type. The publication workflow must prove that the
requested Supervisor and Core tags still resolve to their approved OCI digests
immediately before deploying the feed. It also requires the exact installed
Supervisor, Core and Operating System baselines, rejects a numeric version
regression in any candidate, and requires at least one candidate to advance.
This permits a signed `17.3.dev1785881843` to `18.2.dev2` OS-only migration
while Core and Supervisor remain fixed and digest-verified. Before deployment,
the workflow downloads the resolved OVA RAUC bundle and verifies its ABEDOME
signature, `haos-ova` compatibility and version.

The feed schema remains tag-based and cannot pin the client directly to an OCI
digest. ABEDOME therefore treats every approved Supervisor and Core version tag
as append-only: the tag must never be republished, and a changed image requires
a new version, digest, review, and manual feed deployment.

Create a new VM for the validation. Existing test VMs, snapshots, and normal
build inputs remain outside this workflow's scope.
