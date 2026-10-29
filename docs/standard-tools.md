# Standard tools

`jq` and `yq` are canonical bootstrap IDs for standard command-line utilities. They are installed from apt by the Bash-only registry in `scripts/package-registry.sh` and have no tracked configuration or shell initialization. Select jq with `./bootstrap.sh --package jq` (or select `yq` separately); the baseline is also installed.

The AWS CLI has canonical ID `aws-cli` and alias `aws`; it is installed from Snap with `--classic`, and its binary is `/snap/bin/aws`. Installer metadata is centralized in the registry while installation implementations remain in `scripts/setup-tools.sh`.

`wifi` is the single selectable bootstrap ID for networking tools in `scripts/package-registry.sh`, installed by `scripts/setup-tools.sh`. It installs `network-manager`, `net-tools`, `wpasupplicant`, and `wireless-regdb` together. NetworkManager provides `nmcli` and the terminal interface `nmtui`; `net-tools` provides diagnostics such as `ifconfig`, `route`, and `netstat`. The `wifi` package has no Stow configuration and is not part of the automatic baseline. Select it with `./bootstrap.sh --package wifi` instead of separate networking package IDs.

Wi-Fi also requires firmware for the host's adapter. Broadcom BCM4322 hosts using `b43` need the appropriate `firmware-b43-installer` firmware from Debian's `contrib` component while an internet connection is available. Bootstrap does not enable repository components or install hardware-specific firmware.

After the firmware and NetworkManager service are available, list nearby networks with `nmcli device wifi list`, then connect with `sudo nmcli --ask device wifi connect "SSID"` or use `sudo nmtui`. Enter the Wi-Fi password at the prompt; keep credentials out of this repository. NetworkManager saves a connection profile for later automatic reconnection. A saved profile and working firmware must be prepared before Ethernet is unavailable; installing `net-tools` alone does not provide Wi-Fi connectivity.

Bootstrap does not migrate existing networking configuration; installing the distribution package can start NetworkManager. On Debian, NetworkManager's default `ifupdown` configuration leaves interfaces listed in `/etc/network/interfaces` with their existing manager. Review interface ownership before changing a remote host's network configuration. See the [Debian NetworkManager defaults](https://sources.debian.org/src/network-manager/1.52.1-1/debian/NetworkManager.conf/) and [nmcli connection examples](https://networkmanager.dev/docs/api/latest/nmcli-examples.html).
