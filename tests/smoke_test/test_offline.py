import logging
from time import sleep

import pytest
from labgrid.driver import ExecutionError

_LOGGER = logging.getLogger(__name__)


def _has_fancy_ping(shell):
    """Detect the fancy busybox ping applet (CONFIG_FEATURE_FANCY_PING).

    The minimal applet (HAOS <= 18.1) only understands `ping HOST`, sends a
    single probe and prints "HOST is alive!"; it rejects flags like -c. The
    fancy applet (enabled since HAOS 18.2) behaves like iputils ping: it keeps
    pinging until a count is given, so a bare `ping HOST` never returns.
    """
    try:
        shell.run_check("ping -c 1 -W 1 127.0.0.1")
        return True
    except ExecutionError:
        return False


def _check_connectivity(shell, *, connected):
    # Bound the run: the fancy applet needs an explicit count or it never
    # returns; the minimal one rejects -c and does a single probe anyway.
    ping = "ping -c 1 -W 2" if _has_fancy_ping(shell) else "ping"
    for target in ["home-assistant.io", "1.1.1.1"]:
        try:
            output = " ".join(shell.run_check(f"{ping} {target}"))
            # minimal applet: "HOST is alive!"; fancy applet: ping statistics
            if f"{target} is alive!" in output or " 0% packet loss" in output:
                if connected:
                    return True
                else:
                    raise AssertionError(f"expecting disconnected but {target} is alive")
        except ExecutionError as exc:
            if not connected:
                stdout = "\n".join(exc.stdout)
                assert ("Network is unreachable" in stdout
                        or "bad address" in stdout
                        or "No response" in stdout
                        or "100% packet loss" in stdout)

    if connected:
        raise AssertionError(f"expecting connected but all targets are down")


@pytest.mark.timeout(120)
@pytest.mark.usefixtures("without_internet")
def test_ha_runs_offline(shell):
    def check_container_running(container_name):
        out = shell.run_check(
            f"docker container inspect -f '{{{{.State.Status}}}}' {container_name} || true"
        )
        return "running" in out

    # wait for supervisor to create network
    while True:
        if check_container_running("hassio_supervisor"):
            nm_conns = shell.run_check('nmcli con show')
            if "Supervisor" in " ".join(nm_conns):
                break
        sleep(1)

    # To simulate situation where HAOS is not connected to internet, we need to add
    # default gateway to the supervisor connection. So we add a default route to
    # a non-existing IP address in the VM's subnet. Maybe there is a better way?
    shell.run_check('nmcli con modify "Supervisor enp0s3" ipv4.addresses "192.168.76.10/24" '
                    '&& nmcli con modify "Supervisor enp0s3" ipv4.gateway 192.168.76.1 '
                    '&& nmcli device reapply enp0s3')

    _check_connectivity(shell, connected=False)

    for _ in range(60):
        if check_container_running("homeassistant") and check_container_running("hassio_cli"):
            break
        sleep(1)
    else:
        shell.run_check("docker logs hassio_supervisor")
        raise AssertionError("homeassistant or hassio_cli not running after 60s")

    web_index = shell.run_check("curl http://localhost:8123")
    assert "</html>" in " ".join(web_index)

    configured_update_feed = "".join(
        shell.run_check(
            "jq -r '.url // empty' /mnt/data/supervisor/update-feed.json 2>/dev/null || true"
        )
    )
    if configured_update_feed == (
        "https://mauro2020.github.io/abedome-os/updates/{channel}.json"
    ):
        managed_core_repository = "".join(
            shell.run_check(
                "jq -r '.image // empty' /mnt/data/supervisor/homeassistant.json"
            )
        )
        assert managed_core_repository == "ghcr.io/mauro2020/abedome-core"
        managed_core_version = "".join(
            shell.run_check(
                "jq -r '.version // empty' /mnt/data/supervisor/homeassistant.json"
            )
        )
        running_core_image = "".join(
            shell.run_check("docker inspect --format '{{.Config.Image}}' homeassistant")
        )
        assert running_core_image == f"{managed_core_repository}:{managed_core_version}"
        assert "false" in shell.run_check(
            "jq -r '.override_image' /mnt/data/supervisor/homeassistant.json"
        )
        assert "absent" in shell.run_check(
            "docker image inspect ghcr.io/home-assistant/qemux86-64-homeassistant:landingpage "
            ">/dev/null 2>&1 && echo present || echo absent"
        )
