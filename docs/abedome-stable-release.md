# ABEDOME stable release gate

ABEDOME OS 18.4 is based on Home Assistant OS 18.4 while preserving the
upstream compatibility identifiers (`haos`, `haos-ova`, `homeassistant` and the
`haos_ova-*` artifact names). The supported first stable target is OVA,
`qemux86-64`, `linux/amd64` on Proxmox VE.

The release gate is closed with independently verified immutable pins for Core
2026.11.1 and Supervisor 2026.11.0. `ABEDOME_RELEASE_PINS_READY` is `true`, and
the workflow records both the OCI index and `linux/amd64` manifest digest for
each image. Candidate and release builds must keep all four digests unchanged
unless a separately approved immutable component release replaces them.

## Candidate

Run `OS build` manually from `abedome/develop` with:

- `boards=ova`
- `publish=false`
- `run_tests=false`
- `hassio_channel=stable`
- `abedome_stable_candidate=true`
- `abedome_update_test=false`

This produces `18.4.dev0` artifacts but does not publish a feed or upload to
R2. The workflow requires the persistent ABEDOME RAUC certificate, verifies
both managed OCI images and their platform manifests, checks that the embedded
updater channel is `stable`, rejects an upstream Core archive and rejects a
data image carrying `/docker/.wipe-scheduled`. It also signs the merged image
checksums with Sigstore and stores `SHA256SUMS` and
`SHA256SUMS.sigstore.json` in the
`abedome-stable-candidate-18.4.dev0-digests` Actions artifact.

## Validation

1. Verify `xz -t`, `qemu-img check`, SHA256SUMS, Sigstore bundle and the RAUC
   signature/compatibility/version.
2. Boot a fresh VM offline and verify Core 2026.11.1, Supervisor 2026.11.0,
   onboarding, branding and at least 256 MiB of guarded preload space.
3. Snapshot the update-test VM, record `/data` sentinels and its `mobile_app`
   webhook/push registration, then install through a staged manifest.
4. Verify the slot switch, account/session state, `/data`, Matter, app pairing
   and a real iOS notification after reboot.
5. Boot the previous slot, verify rollback, then repeat the forward update.

The GitHub QEMU smoke suite deliberately skips its upstream live-feed update on
the ABEDOME fork. A candidate cannot be tested using `stable.json` before that
candidate has passed the PVE gate; doing so would be circular. Fresh/offline
smoke tests still run, while the signed in-place update and rollback are the PVE
release gate.

## Publication

After the stable `18.4` release artifacts have passed the same checks, run
`Publish ABEDOME stable update feed`. The protected `abedome-stable-feed`
environment is the final human approval. The workflow re-verifies both OCI
index and `linux/amd64` digests, downloads and verifies the signed RAUC bundle,
renders only `updates/stable.json`, and preserves the existing `updates/dev.json`
in the same GitHub Pages deployment. The development workflow performs the
inverse preservation. Both use one concurrency group to prevent lost updates.

The stable feed is always the last release action.
