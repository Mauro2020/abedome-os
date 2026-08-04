#!/usr/bin/env bash
set -euo pipefail

certificate_path="${1:?certificate output path is required}"
private_key_path="${2:?private key output path is required}"

if [[ -z "${RAUC_CERTIFICATE:-}" || -z "${RAUC_PRIVATE_KEY:-}" ]]; then
  echo "Both RAUC_CERTIFICATE and RAUC_PRIVATE_KEY must be set." >&2
  exit 1
fi

write_pem() {
  local value="$1"
  local begin_marker="$2"
  local end_marker="$3"
  local destination="$4"

  # Full PEM is preferred. The unwrapped base64 body remains supported for
  # existing repository secrets.
  if [[ "$value" == *"-----BEGIN "* ]]; then
    printf '%s\n' "$value" > "$destination"
  else
    printf '%s\n%s\n%s\n' "$begin_marker" "$value" "$end_marker" > "$destination"
  fi
  chmod 600 "$destination"
}

write_pem "$RAUC_CERTIFICATE" \
  "-----BEGIN CERTIFICATE-----" \
  "-----END CERTIFICATE-----" \
  "$certificate_path"
write_pem "$RAUC_PRIVATE_KEY" \
  "-----BEGIN PRIVATE KEY-----" \
  "-----END PRIVATE KEY-----" \
  "$private_key_path"

openssl x509 -in "$certificate_path" -noout >/dev/null
openssl pkey -in "$private_key_path" -noout -check >/dev/null

certificate_public_key="$(openssl x509 -in "$certificate_path" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)"
private_key_public_key="$(openssl pkey -in "$private_key_path" -pubout -outform DER | openssl dgst -sha256)"

if [[ "$certificate_public_key" != "$private_key_public_key" ]]; then
  echo "The RAUC certificate and private key do not match." >&2
  exit 1
fi

echo "RAUC signing material is valid."
