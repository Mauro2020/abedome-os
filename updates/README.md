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
generated or published, the requested Supervisor and Core tags must each
resolve to their explicitly approved OCI digests. Both workflows also require
the exact Supervisor, Core and Operating System versions currently installed on
the validation VM. The renderer compares numeric version components and refuses
to generate or publish a manifest if any candidate is older than its installed
baseline. Components may remain at their exact baselines, but at least one of
Supervisor, Core or Operating System must advance, so a complete no-op is also
refused. This permits an OS-only migration when Core and Supervisor remain at
their exact baselines, or a coordinated migration in which one or both managed
components also advance without regression.

Two separate manual workflows publish GitHub Pages manifests. `Publish ABEDOME
dev test update feed` remains the development-only path. `Publish ABEDOME
stable update feed` is additionally gated by the protected
`abedome-stable-feed` environment and accepts only stable Core, Supervisor and
OS versions. Both workflows accept RAUC bundles only from GitHub Releases in
this repository, verify the exact ABEDOME signature, compatibility and version,
and run only from `abedome/develop`. Each workflow preserves and validates the
other channel's existing manifest before deploying the replacement Pages
artifact, so publishing one channel cannot silently remove the other.

The stable feed is the final release action. It must not be approved until the
exact Core and Supervisor index plus `linux/amd64` digests have been recorded,
the signed OS bundle has passed fresh-install and in-place RAUC tests on PVE,
and rollback plus `/data` preservation have been verified. A candidate build
never publishes either feed.

The exact candidate inputs and PVE release gate are documented in
[abedome-stable-release.md](../docs/abedome-stable-release.md).

The update schema is tag-based. Digest verification is a point-in-time release
gate, not a registry-enforced immutable reference: approved Supervisor and Core
version tags must never be republished. Any change to either tag requires a new
version, digest, review, and feed deployment.

The public endpoint is technical release metadata only. It must never contain
user, device, network, or installation data. See
[github-pages-dev-test-feed.md](../docs/github-pages-dev-test-feed.md) for the
required signing, release, deployment, and PVE validation order.

`fixtures/upstream-dev.json` and `fixtures/upstream-stable.json` are structural
fixtures used only by CI. The `example.invalid` domain is intentionally
non-resolvable and cannot be used as an update endpoint.
