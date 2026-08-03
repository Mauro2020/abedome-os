# ABEDOME Supervisor PVE test integration

The x86-64 OVA test build preloads this approved Supervisor image:

```text
ghcr.io/mauro2020/abedome-supervisor:pve-e6a5f6fa3cc8
```

The Home Assistant OS build resolves the tag to an OCI digest before importing it into
the image. The reference is configured only in
`buildroot-external/configs/ova_defconfig`.

## Scope of this test

- The initial Supervisor container is ABEDOME's validated PVE test image.
- Home Assistant Core, add-ons, OS components, and the release manifest remain
  upstream Home Assistant components.
- The Supervisor has no configured ABEDOME update-feed URL, so it keeps its
  upstream update behaviour.
- This does not enable OTA publishing, custom update manifests, or production
  signing.

## Changing the image

A replacement reference must be introduced in a separate pull request and only
after its image has been built and validated by the
`Publish ABEDOME Supervisor PVE image` workflow. The reference must include a
tag and be anonymously readable by the OS build container.

## PVE validation

Build only the `ova` board with tests enabled, import the resulting QCOW2 into
a new Proxmox VM, and complete onboarding. Do not reuse the existing baseline VM
for this test.
