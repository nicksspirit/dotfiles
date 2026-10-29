# Linux laptop servers

Use the optional `linux-laptop` bootstrap unit to keep a laptop server awake
when you close its lid. For example, use it on `mbp2010` with Debian 13.

## Requirements

- Linux with a running systemd manager.
- Sudo access to apply changes.
- A laptop that must stay awake. Setup does not detect the hardware type.

The unit runs `scripts/setup-linux-laptop.sh` outside GNU Stow. It installs no packages.

## Run setup

With bootstrap, preview the changes first:

```bash
./bootstrap.sh --dry-run --package linux-laptop
```

Then apply the changes:

```bash
./bootstrap.sh --package linux-laptop
```

On an already configured host, use the script directly. Preview first, then apply:

```bash
bash scripts/setup-linux-laptop.sh --dry-run
bash scripts/setup-linux-laptop.sh
```

- Dry runs work on other operating systems without invoking sudo.
- Unknown options cause setup to fail without applying the policy.
- Reboot when convenient to load the lid and idle settings. Setup does not restart logind or reboot the host.

## Settings

The script manages `/etc/systemd/logind.conf.d/90-dotfiles-linux-laptop.conf`.
It sets these [systemd-logind settings](https://www.freedesktop.org/software/systemd/man/latest/logind.conf.html):

- `HandleLidSwitch=ignore`: ignore lid closure on battery.
- `HandleLidSwitchExternalPower=ignore`: ignore lid closure on external power.
- `HandleLidSwitchDocked=ignore`: ignore lid closure when docked.
- `IdleAction=ignore`: take no action when the system is idle.

Setup also applies a persistent
[systemd mask](https://www.freedesktop.org/software/systemd/man/latest/systemctl.html#mask%20UNIT%E2%80%A6)
to each sleep target:

- `sleep.target`
- `suspend.target`
- `hibernate.target`
- `hybrid-sleep.target`
- `suspend-then-hibernate.target`

Masks take effect immediately and block activation, including manual suspend
and hibernation. Setup checks that each target's loaded state is `masked`.

## Existing files and failures

- Setup leaves an identical configuration file in place.
- Setup refuses to replace a different file, a symbolic link, or a target that is not a regular file.
- If masking fails, setup reports failure. It leaves the installed configuration and completed masks in place.
- Correct the error, then run setup again.

## Check the result

1. After reboot, inspect the configuration for later settings that override this policy:

   ```bash
   systemd-analyze cat-config systemd/logind.conf
   ```

2. Run this command in an SSH session:

   ```bash
   watch -n 2 uptime
   ```

3. Close the lid. Confirm that the uptime display continues to update.

## Limits and precautions

- This setup targets headless servers that use systemd sleep targets.
- Desktop power managers can control lid actions. They need their own policy.
- This setup does not prevent firmware shutdowns or direct kernel sleep requests.
- Keep ventilation clear. Monitor temperatures with the lid closed.
- The `mbp2010` investigation recorded GPU temperature spikes to 90 °C. Disabling sleep does not fix this problem.
- The policy stays active on battery. A server disconnected from external power can fully discharge its battery.

## Undo setup

1. Remove only `/etc/systemd/logind.conf.d/90-dotfiles-linux-laptop.conf`.
2. Run `sudo systemctl unmask` with only the targets newly masked by this setup.
3. Reboot.

Leave previously masked targets masked. Setup does not record their previous state.

## Validate repository changes

Run both test scripts:

```bash
bash tests/test_bootstrap.sh
bash tests/test_linux_laptop.sh
```

The laptop tests isolate privileged paths and commands. They do not test
hardware sleep or temperature behavior.
