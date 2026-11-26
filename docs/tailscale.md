# Tailscale

Tailscale is a VPN built on WireGuard that connects your devices in a private tailnet. It can provide encrypted access to your devices and services without exposing them directly to the public internet. Install it on each device you want to connect, then authenticate them to the same tailnet.

## Install

On supported Linux hosts, select the `tailscale` bootstrap package:

```sh
./bootstrap.sh --dry-run --package tailscale
./bootstrap.sh --package tailscale
```

The package uses Tailscale's official installer if the `tailscale` command is missing. It does not sign in or connect the device. On Android, install the Tailscale app from [Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn) and follow its setup prompts; the Linux bootstrap package and CLI are not for Android.

## Useful commands

Start Tailscale and authenticate the device if needed:

```sh
sudo tailscale up
```

Check whether Tailscale is connected and see peer details:

```sh
sudo tailscale status
```

Disconnect this device from the tailnet without uninstalling Tailscale:

```sh
sudo tailscale down
```

Run `sudo tailscale up` again to reconnect. `tailscale down` affects this device's network connectivity through Tailscale; use it only when you intend to disconnect.
