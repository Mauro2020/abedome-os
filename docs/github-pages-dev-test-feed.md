# GitHub Pages dev test feed

ABEDOME uses GitHub Pages only as a public, static endpoint for a **manually
approved development test manifest**. It is not a production release channel.

The expected feed URL is:

```text
https://mauro2020.github.io/abedome-os/updates/dev.json
```

## One-time repository setup

In **Settings → Pages**, set **Source** to **GitHub Actions**. The deployment
workflow creates the `github-pages` environment; protect that environment so
only the protected `abedome/develop` branch can deploy.

## Publishing conditions

The `Publish ABEDOME dev test update feed` workflow is manual-only and:

- runs only from `abedome/develop`;
- accepts only a versioned ABEDOME Supervisor candidate that is not older than
  the exact version installed on the validation VM;
- verifies that the Supervisor tag resolves to the explicitly approved OCI
  digest;
- accepts only a published, versioned ABEDOME Core candidate that is not older
  than the exact installed baseline;
- verifies that the Core tag resolves to the explicitly approved OCI digest;
- accepts only an Operating System candidate that is not older than the exact
  installed baseline;
- requires at least one of Supervisor, Core or Operating System to advance, so
  unchanged components are allowed but a complete no-op is rejected;
- supports only the dedicated OVA/qemux86-64 (`linux/amd64`) validation build;
- renders only the `dev` channel;
- accepts a RAUC download URL only from releases in this repository and verifies
  the resolved bundle against the pinned ABEDOME certificate, `haos-ova`
  compatibility and the approved candidate version;
- regenerates the manifest from the current upstream `dev` manifest.

The public page contains technical release information only: upstream manifest
metadata, the approved ABEDOME Supervisor version, the HAOS version, and the
approved ABEDOME Core version and repository, plus the signed RAUC download
URL. Both approved image digests and all three installed baselines are checked
by the workflow and recorded in its summary because the upstream feed schema
itself is tag-based. The page must never contain user, device, network, or
installation data.

`images.core` applies globally inside the update schema. Although upstream
version keys for other machines remain present, this feed must never be
configured on ARM or any target other than the dedicated OVA/qemux86-64 test
build. Digest verification occurs immediately before deployment; the approved
Supervisor and Core version tags must never be republished.

## RAUC signing secrets

Store `RAUC_CERTIFICATE` and `RAUC_PRIVATE_KEY` as the complete PEM files.
For compatibility, the build also accepts legacy secrets containing only the
PEM body. The workflow validates the certificate, private key, and their
matching public key before starting the expensive build; no secret material
is printed or uploaded.
## Required order

1. Create the production RAUC signing secrets in GitHub.
2. Publish a unique development version for every component that advances,
   record all three installed baselines, verify both approved digests, and never
   republish those tags.
3. Build and validate the new signed OVA/RAUC candidate.
4. Fresh-boot its OVA in a new PVE VM without changing the validated source VM.
5. Upload the signed, versioned RAUC bundle to a GitHub Release in this repository.
6. Run the manual feed workflow with the exact candidate versions, all three
   installed baselines, both approved image digests, and the RAUC URL.
7. Clone the validated `17.3.dev1785881843` VM and test its in-place update to
   `18.2.dev3`, reboot and rollback before approving any wider use.

GitHub Actions artifacts are deliberately not used as the update URL: they
expire and are not a reliable public update endpoint.
