# ABEDOME update manifest tooling

The manual GitHub Actions workflow `Generate ABEDOME test update manifest`
downloads an upstream channel manifest, applies the explicitly supplied approved
ABEDOME Supervisor and Core images plus the signed HAOS version, validates the
result, and uploads it only as a seven-day GitHub Actions artifact. The Core
version override is applied only to `homeassistant.qemux86-64`. The upstream
version keys for other machines remain in the manifest for structural
compatibility, but `images.core` is a global repository setting. This feed is
therefore supported **only** by the dedicated OVA/qemux86-64 test build and must
never be configured on ARM or another machine type. Before a manifest is
generated or published, the requested Core tag must resolve to its explicitly
approved OCI digest.

A separate manual workflow, `Publish ABEDOME dev test update feed`, may deploy
a validated **dev-only** manifest to GitHub Pages after all release gates in
[controlled-update-channel.md](../docs/controlled-update-channel.md) have been
completed. It accepts RAUC bundles only from GitHub Releases in this repository,
runs only from the protected `abedome/develop` branch, and never publishes
stable or beta channels.

The update schema is tag-based. Digest verification is a point-in-time release
gate, not a registry-enforced immutable reference: an approved version tag must
never be republished. Any change to that tag requires a new version, digest,
review, and feed deployment.

The public endpoint is technical release metadata only. It must never contain
user, device, network, or installation data. See
[github-pages-dev-test-feed.md](../docs/github-pages-dev-test-feed.md) for the
required signing, release, deployment, and PVE validation order.

`fixtures/upstream-dev.json` is a structural fixture used only by CI. The
`example.invalid` domain is intentionally non-resolvable and cannot be used as
an update endpoint.
