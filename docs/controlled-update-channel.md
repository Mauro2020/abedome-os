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

1. The manifest is immutable and its container and OS references are pinned.
2. The ABEDOME Supervisor image and the matching OS artifact have completed CI.
3. The RAUC artifact is signed with the private production key; that key is not
   stored in this repository.
4. The update was installed in the Proxmox test VM and rollback was verified.
5. A human explicitly approved promotion from test to release.
6. The test OVA embeds both the feed template and the matching tagged
   preloaded Supervisor image.

The first real feed must be enabled only in a dedicated test build, never by
changing the default OVA configuration.