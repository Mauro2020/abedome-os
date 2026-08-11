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
- accepts only a versioned ABEDOME Supervisor test image that is newer than the
  exact version installed on the validation VM;
- verifies that the Supervisor tag resolves to the explicitly approved OCI
  digest;
- accepts only a published, versioned ABEDOME Core development image;
- rejects a Core candidate that is not newer than the exact installed baseline;
- verifies that the Core tag resolves to the explicitly approved OCI digest;
- supports only the dedicated OVA/qemux86-64 (`linux/amd64`) validation build;
- renders only the `dev` channel;
- accepts a RAUC download URL only from releases in this repository;
- regenerates the manifest from the current upstream `dev` manifest.

The public page contains technical release information only: upstream manifest
metadata, the approved ABEDOME Supervisor version, the HAOS version, and the
approved ABEDOME Core version and repository, plus the signed RAUC download
URL. Both approved image digests and both installed baselines are checked by the
workflow and recorded in its summary because the upstream feed schema itself is
tag-based. The page must never contain user, device, network, or installation
data.

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
2. Publish unique ABEDOME Supervisor and Core development versions, record the
   installed baselines, verify the approved digests, and never republish those
   tags.
3. Build and validate a new signed OVA/RAUC test image.
4. Upload the signed, versioned RAUC bundle to a GitHub Release in this repository.
5. Run the manual feed workflow with the exact image versions and RAUC URL.
6. Build a dedicated PVE update-test image that references this dev feed.
7. Test update and rollback in a new PVE VM before approving any wider use.

GitHub Actions artifacts are deliberately not used as the update URL: they
expire and are not a reliable public update endpoint.
