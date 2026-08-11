#!/usr/bin/env python3
"""Render and validate an ABEDOME controlled update manifest.

The output is intentionally an artifact only. Publishing it as an update feed is
a separate, human-approved release action.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

ALLOWED_CHANNELS = {"stable", "beta", "dev"}
CORE_DEVELOPMENT_VERSION = re.compile(
    r"^(?P<year>[0-9]{4})\.(?P<month>[0-9]{1,2})\."
    r"(?P<patch>[0-9]+)\.dev(?P<build>[0-9]+)$"
)


def fail(message: str) -> None:
    print(f"Manifest validation error: {message}", file=sys.stderr)
    raise SystemExit(2)


def require_value(value: object, name: str) -> str:
    if not isinstance(value, str) or not value or value.strip() != value:
        fail(f"{name} must be a non-empty string without surrounding whitespace")
    if any(character.isspace() for character in value):
        fail(f"{name} must not contain whitespace")
    return value


def validate_https_template(value: object, name: str, placeholders: tuple[str, ...]) -> str:
    template = require_value(value, name)
    parsed = urlparse(template)
    if parsed.scheme != "https" or not parsed.netloc:
        fail(f"{name} must be an HTTPS URL")
    for placeholder in placeholders:
        if placeholder not in template:
            fail(f"{name} must contain {placeholder}")
    return template


def validate_image_repository(value: object, name: str) -> str:
    repository = require_value(value, name)
    if not repository.startswith("ghcr.io/") or repository.count("/") < 2:
        fail(f"{name} must be a GHCR repository path")
    if ":" in repository or "@" in repository:
        fail(f"{name} must be a repository without tag or digest")
    return repository


def parse_core_development_version(
    value: object,
    name: str,
) -> tuple[int, int, int, int]:
    version = require_value(value, name)
    match = CORE_DEVELOPMENT_VERSION.fullmatch(version)
    if match is None:
        fail(f"{name} must use the YYYY.M.P.devN development version format")
    return tuple(int(component) for component in match.groups())


def require_newer_core_version(candidate: object, baseline: object) -> None:
    candidate_version = require_value(candidate, "core version candidate")
    baseline_version = require_value(baseline, "installed Core version baseline")
    candidate_parts = parse_core_development_version(
        candidate_version,
        "core version candidate",
    )
    baseline_parts = parse_core_development_version(
        baseline_version,
        "installed Core version baseline",
    )
    if candidate_parts <= baseline_parts:
        fail(
            f"Core version candidate {candidate_version} must be newer than "
            f"installed baseline {baseline_version}"
        )


def require_newer_supervisor_version(candidate: object, baseline: object) -> None:
    candidate_version = require_value(candidate, "supervisor version candidate")
    baseline_version = require_value(
        baseline,
        "installed Supervisor version baseline",
    )
    candidate_parts = parse_core_development_version(
        candidate_version,
        "supervisor version candidate",
    )
    baseline_parts = parse_core_development_version(
        baseline_version,
        "installed Supervisor version baseline",
    )
    if candidate_parts <= baseline_parts:
        fail(
            f"Supervisor version candidate {candidate_version} must be newer than "
            f"installed baseline {baseline_version}"
        )


def load_manifest(path: Path) -> dict[str, object]:
    try:
        content = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as err:
        fail(f"cannot read source manifest: {err}")

    if not isinstance(content, dict):
        fail("source manifest must be a JSON object")
    return content


def validate_manifest(manifest: dict[str, object]) -> None:
    channel = require_value(manifest.get("channel"), "channel")
    if channel not in ALLOWED_CHANNELS:
        fail(f"channel must be one of: {', '.join(sorted(ALLOWED_CHANNELS))}")

    require_value(manifest.get("supervisor"), "supervisor")

    homeassistant = manifest.get("homeassistant")
    if not isinstance(homeassistant, dict):
        fail("homeassistant must be an object")
    require_value(homeassistant.get("default"), "homeassistant.default")
    require_value(
        homeassistant.get("qemux86-64"),
        "homeassistant.qemux86-64",
    )

    hassos = manifest.get("hassos")
    if not isinstance(hassos, dict):
        fail("hassos must be an object")
    require_value(hassos.get("ova"), "hassos.ova")

    validate_https_template(
        manifest.get("ota"),
        "ota",
        ("{version}", "{board}"),
    )

    images = manifest.get("images")
    if not isinstance(images, dict):
        fail("images must be an object")
    validate_image_repository(images.get("core"), "images.core")
    validate_image_repository(images.get("supervisor"), "images.supervisor")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--supervisor-version", required=True)
    parser.add_argument("--supervisor-version-baseline", required=True)
    parser.add_argument("--supervisor-image", required=True)
    parser.add_argument("--core-version", required=True)
    parser.add_argument("--core-version-baseline", required=True)
    parser.add_argument("--core-image", required=True)
    parser.add_argument("--hassos-ova-version", required=True)
    parser.add_argument("--ota-url-template", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_arguments()
    manifest = load_manifest(args.source)

    images = manifest.get("images")
    if not isinstance(images, dict):
        fail("source manifest images must be an object")
    hassos = manifest.get("hassos")
    if not isinstance(hassos, dict):
        fail("source manifest hassos must be an object")
    homeassistant = manifest.get("homeassistant")
    if not isinstance(homeassistant, dict):
        fail("source manifest homeassistant must be an object")

    require_newer_supervisor_version(
        args.supervisor_version,
        args.supervisor_version_baseline,
    )
    require_newer_core_version(args.core_version, args.core_version_baseline)

    manifest["supervisor"] = args.supervisor_version
    images["supervisor"] = args.supervisor_image
    images["core"] = args.core_image
    homeassistant["qemux86-64"] = args.core_version
    hassos["ova"] = args.hassos_ova_version
    manifest["ota"] = args.ota_url_template
    validate_manifest(manifest)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Validated test manifest written to {args.output}")


if __name__ == "__main__":
    main()
