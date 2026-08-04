# ABEDOME update manifest tooling

This directory does **not** publish an update feed.

The manual GitHub Actions workflow `Generate ABEDOME test update manifest`
downloads an upstream channel manifest, applies the explicitly supplied approved
ABEDOME Supervisor image and signed HAOS version, validates the result, and
uploads it only as a seven-day GitHub Actions artifact.

The artifact must not be hosted or referenced by an ABEDOME image until all
release gates in [controlled-update-channel.md](../docs/controlled-update-channel.md)
have been completed.

`fixtures/upstream-dev.json` is a structural fixture used only by CI. The
`example.invalid` domain is intentionally non-resolvable and cannot be used
as an update endpoint.