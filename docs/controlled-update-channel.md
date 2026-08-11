# ABEDOME controlled update channel

## Purpose

ABEDOME follows Home Assistant upstream. This repository can optionally configure
a separate Supervisor manifest source for a deliberately approved ABEDOME test or
release channel.

The setting is **off by default**. Builds that do not set it use the unchanged
Home Assistant update behaviour.

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

At boot, both values are required before the Supervisor is started with
`SUPERVISOR_VERSION_URL`. The preloaded image is tagged from that same
repository, so a first boot does not need to pull from a different registry.
It is not set in the OVA default configuration.

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
6. The test OVA embeds both the feed template and the matching tagged
   preloaded Supervisor image.

The first real feed must be enabled only in a dedicated test build, never by
changing the default OVA configuration.

## Dedicated Proxmox update-test build

The `OS build` workflow has an explicit `abedome_update_test` switch. It is
`false` by default and changes nothing in ordinary builds.

When enabled, the workflow accepts only this deliberately narrow manual scope:

- branch `abedome/develop`;
- board `ova` (x86-64);
- channel `dev`;
- `publish=false` and `run_tests=false`;
- baseline OS version `17.3.dev0`;
- preloaded Supervisor `ghcr.io/mauro2020/abedome-supervisor:2026.8.0.dev1`;
- feed template `https://mauro2020.github.io/abedome-os/updates/{channel}.json`.

The resulting OVA is a lower-version, disposable baseline for one controlled
Proxmox validation. It is not a release artifact, must not be attached to a
normal installation, and must not be published to a stable or beta channel.

The manually generated dev manifest may replace the Supervisor version and
image repository, and replace only `homeassistant.qemux86-64` with the approved
ABEDOME Core version while setting `images.core` to the ABEDOME GHCR repository.
The upstream version keys for other machines remain inherited only for manifest
compatibility. Because `images.core` is global, the feed is supported
exclusively on the dedicated OVA/qemux86-64 test build and must not be configured
on ARM or another machine type. The publication workflow must prove that the
requested Supervisor and Core tags still resolve to their approved OCI digests
immediately before deploying the feed. It also requires the exact installed
Supervisor and Core baselines and rejects either candidate unless its numeric
development version is strictly newer.

The feed schema remains tag-based and cannot pin the client directly to an OCI
digest. ABEDOME therefore treats every approved Supervisor and Core version tag
as append-only: the tag must never be republished, and a changed image requires
a new version, digest, review, and manual feed deployment.

Create a new VM for the validation. Existing test VMs, snapshots, and normal
build inputs remain outside this workflow's scope.
