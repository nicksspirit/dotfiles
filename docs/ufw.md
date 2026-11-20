# UFW

Select `--package ufw` to install from apt through `scripts/setup-tools.sh`. Bootstrap prints a manual setup reminder; it does not enable UFW or write rules. If the host already has a firewall manager, use it instead of layering UFW on top without a migration plan.

## Configure remote access

1. Inspect existing rules (`sudo ufw status verbose` and `sudo ufw show added`). Identify the actual SSH port, management interface, and allowed client IP or subnet. A subnet rule tolerates DHCP changes but lets more clients reach the login screen. Keep an existing SSH session open and have a recovery path before changing access.
2. Allow SSH **before** enabling UFW or tightening an active policy. Example for a LAN interface `enp3s0`, SSH on `22`, and management subnet `192.168.0.0/24`; substitute the values for this host:

   ```sh
   sudo ufw allow in on enp3s0 from 192.168.0.0/24 to any port 22 proto tcp
   ```

   For each approved service, reuse that rule shape with its listening port and intended client network. For [Cockpit](cockpit.md), allow `443/tcp` through Caddy, `9090/tcp` for direct access, or neither for an SSH tunnel. Use only the branch you selected.
3. For a fresh UFW setup, set the policy and enable it:

   ```sh
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw enable
   sudo ufw status verbose
   ```

4. Verify a **new** SSH login and each intended service from a client before closing the original session. If a fresh activation blocks new SSH sessions, use the original session or console to run `sudo ufw disable` and correct the rules before re-enabling. On an existing firewall, restore the previous access rule rather than disabling protection. To remove an obsolete allow, use `sudo ufw delete` followed by the original `allow …` rule, then inspect the live rules again.

Docker-published ports can bypass ordinary UFW incoming rules; review their bindings and access separately.
