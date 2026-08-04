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
- accepts only a versioned ABEDOME Supervisor test image;
- renders only the `dev` channel;
- accepts a RAUC download URL only from releases in this repository;
- regenerates the manifest from the current upstream `dev` manifest.

The public page contains technical release information only: upstream manifest
metadata, the approved ABEDOME Supervisor version, the HAOS version, and the
signed RAUC download URL. It must never contain user, device, network, or
installation data.

## RAUC signing secrets

Store `RAUC_CERTIFICATE` and `RAUC_PRIVATE_KEY` as the complete PEM files.
For compatibility, the build also accepts legacy secrets containing only the
PEM body. The workflow validates the certificate, private key, and their
matching public key before starting the expensive build; no secret material
is printed or uploaded.
## Required order

1. Create the production RAUC signing secrets in GitHub.
2. Build and validate a new signed OVA/RAUC test image.
3. Upload the immutable RAUC bundle to a GitHub Release in this repository.
4. Run the manual feed workflow with its exact version and URL.
5. Build a dedicated PVE update-test image that references this dev feed.
6. Test update and rollback in a new PVE VM before approving any wider use.

GitHub Actions artifacts are deliberately not used as the update URL: they
expire and are not a reliable public update endpoint.
