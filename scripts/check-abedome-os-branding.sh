#!/bin/bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repository_root}"

# Product copy changes; compatibility identifiers do not.
# shellcheck disable=SC1091
source buildroot-external/meta
test "${HAOS_NAME}" = "ABEDOME OS"
test "${HAOS_ID}" = "haos"
os_version="${VERSION_MAJOR}.${VERSION_MINOR}"

grep -Fxq 'BR2_TARGET_GENERIC_HOSTNAME="homeassistant"' \
  buildroot-external/configs/ova_defconfig
grep -Fxq 'BR2_TARGET_GENERIC_ISSUE="Welcome to ABEDOME OS"' \
  buildroot-external/configs/ova_defconfig
grep -Fq 'Welcome to ' buildroot-external/rootfs-overlay/etc/motd
grep -Fq 'ABEDOME OS' buildroot-external/rootfs-overlay/etc/motd
grep -Fq 'ABEDOME system CLI' \
  buildroot-external/rootfs-overlay/usr/sbin/haos-cli
grep -Fxq 'Description=ABEDOME system CLI' \
  buildroot-external/rootfs-overlay/usr/lib/systemd/system/ha-cli@.service

if grep -ER '^Description=(HAOS|Home Assistant OS)' \
  buildroot-external/rootfs-overlay/usr/lib/systemd/system; then
  echo "Found an upstream OS product name in a visible systemd description."
  exit 1
fi

# shellcheck disable=SC1091
source buildroot-external/scripts/name.sh
export BOARD_ID=ova
export BINARIES_DIR=/tmp
export VERSION_SUFFIX=dev0
test "$(haos_rauc_compatible)" = "haos-ova"
test "$(haos_image_basename)" = "/tmp/haos_ova-${os_version}.dev0"

# The archive command must retain these variable references literally.
# shellcheck disable=SC2016
grep -Fxq \
  '    tar -C "${ova_data}" --owner=root --group=root -cf "${hdd_ova}" home-assistant.ovf home-assistant.vmdk home-assistant.mf' \
  buildroot-external/scripts/hdd-image.sh

OS_VERSION="${os_version}" python3 - <<'PY'
import json
import os
from pathlib import Path
import xml.etree.ElementTree as ET

upstream = json.loads(Path("UPSTREAM.json").read_text(encoding="utf-8"))
assert upstream["product"] == "ABEDOME OS"
assert upstream["upstream"] == "home-assistant/operating-system"
assert upstream["baseline_release"] == os.environ["OS_VERSION"]
assert upstream["auto_merge"] is False

ovf = "{http://schemas.dmtf.org/ovf/envelope/1}"
vbox = "{http://www.virtualbox.org/ovf/machine}"
vssd = "{http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData}"
root = ET.parse("buildroot-external/board/pc/ova/home-assistant.ovf").getroot()
file_reference = root.find(f"{ovf}References/{ovf}File")
assert file_reference is not None
assert file_reference.get(f"{ovf}id") == "file1"
assert file_reference.get(f"{ovf}href") == "home-assistant.vmdk"

disk = root.find(f"{ovf}DiskSection/{ovf}Disk")
assert disk is not None
assert disk.get(f"{ovf}fileRef") == "file1"

virtual_system = root.find(f"{ovf}VirtualSystem")
assert virtual_system is not None
assert virtual_system.get(f"{ovf}id") == "HomeAssistant"
assert virtual_system.findtext(f"{ovf}Name") == "ABEDOME OS"
assert virtual_system.findtext(f"{ovf}ProductSection/{ovf}Product") == "ABEDOME OS"
assert (
    virtual_system.findtext(f"{ovf}ProductSection/{ovf}ProductUrl")
    == "https://github.com/Mauro2020/abedome-os"
)
assert (
    virtual_system.findtext(
        f"{ovf}VirtualHardwareSection/{ovf}System/{vssd}VirtualSystemIdentifier"
    )
    == "ABEDOME OS"
)
machine = virtual_system.find(f"{vbox}Machine")
assert machine is not None
assert machine.get("name") == "ABEDOME OS"
PY
