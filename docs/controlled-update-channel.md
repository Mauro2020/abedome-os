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

When configured, the URL is persisted inside the data partition as
`/mnt/data/supervisor/update-feed.json` and passed to the Supervisor as
`SUPERVISOR_VERSION_URL`. It is not set in the OVA default configuration.

A missing, malformed, or non-HTTPS template is ignored at boot, leaving the
standard upstream behaviour in place.

## Release gates before activation

Do not add a real feed URL to a distribution until all of these are true:

1. The manifest is immutable and its container and OS references are pinned.
2. The ABEDOME Supervisor image and the matching OS artifact have completed CI.
3. The RAUC artifact is signed with the private production key; that key is not
   stored in this repository.
4. The update was installed in the Proxmox test VM and rollback was verified.
5. A human explicitly approved promotion from test to release.

The first real feed must be enabled only in a dedicated test build, never by
changing the default OVA configuration.