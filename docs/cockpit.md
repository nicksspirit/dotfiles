# Cockpit access recipes

Choose one access path per host. Skip Cockpit entirely on hosts that do not need a web console. These recipes assume Debian with systemd and an existing SSH or local console session.

| Access path | Cockpit listener | Client-facing port |
| --- | --- | --- |
| [SSH tunnel](#ssh-tunnel) for occasional administration | `127.0.0.1:9090` | Existing SSH port only |
| [LAN HTTPS through Caddy](#lan-https-through-caddy) for regular browser access | `127.0.0.1:9090` | `443/tcp` on the intended network |
| [Direct HTTPS](#direct-https) when Cockpit supplies its own trusted TLS | Selected management IP on `9090` | `9090/tcp` on the intended network |

## Prepare the host

1. Record the server's stable management address, client subnet, interface, and actual SSH port. Inspect existing listeners and overrides with `ss -ltn` and `systemctl cat cockpit.socket`. Keep the current SSH session open and back up any existing Cockpit and Caddy configuration before editing.
2. Select only the bootstrap packages needed for this host. For Caddy **and** UFW, for example:

   ```sh
   ./bootstrap.sh --dry-run --package caddy --package ufw
   ./bootstrap.sh --package caddy --package ufw
   ```

   Omit either option when the host uses another proxy or firewall, or does not need that tool. Install Cockpit separately with `sudo apt-get install cockpit`; it is not a bootstrap unit. When installing on a shared network, have host ingress filtering in place first: the package's stock socket can listen on every interface. Configure [UFW](ufw.md) only if selected; otherwise use the host's existing access controls.
3. Set the socket for the chosen path. Run `sudo systemctl edit cockpit.socket` and use the following override for loopback, or substitute the chosen management IP for direct access:

   ```ini
   [Socket]
   ListenStream=
   ListenStream=127.0.0.1:9090
   ```

   Stop the service and socket together, then enable and start the socket. This can disconnect Cockpit sessions but does not restart SSH.

   ```sh
   sudo systemctl stop cockpit.service cockpit.socket
   sudo systemctl enable --now cockpit.socket
   ss -ltn 'sport = :9090'
   ```

   Proceed only when `ss` shows the intended address, not a wildcard listener. For migrations, review `/etc/cockpit/cockpit.conf` and remove stale settings owned by the previous access path.

## SSH tunnel

With Cockpit on loopback, run this on the client, substituting the SSH login and adding `-p` if needed:

```sh
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:9090:127.0.0.1:9090 user@server
```

Open `http://127.0.0.1:9090/` while the tunnel runs. Cockpit permits HTTP on loopback; SSH encrypts the network hop. Verify the login page loads and leave `9090` closed on the server firewall.

## LAN HTTPS through Caddy

This example uses `192.168.0.120`; substitute your management IP or use a private hostname your clients can resolve. Keep Cockpit on loopback.

1. In `/etc/cockpit/cockpit.conf`, merge into the existing `[WebService]` section:

   ```ini
   [WebService]
   Origins = https://192.168.0.120
   ProtocolHeader = X-Forwarded-Proto
   ```

   The origin must match the browser's HTTPS scheme and host (include the port if nonstandard). Caddy sets the forwarded protocol and proxies WebSockets. Leave `AllowUnencrypted` at its default; Cockpit already permits loopback HTTP.
2. Configure the site in `/etc/caddy/Caddyfile`:

   ```caddyfile
   https://192.168.0.120 {
       bind 192.168.0.120
       tls internal
       reverse_proxy 127.0.0.1:9090
   }
   ```

   For a `/console/` URL, add `UrlRoot = /console` under Cockpit's `[WebService]`, then replace the site's `reverse_proxy` line with these lines:

   ```caddyfile
   redir / /console/ 302
   redir /console /console/ 302
   reverse_proxy /console/* 127.0.0.1:9090
   ```

   Preserve the prefix when forwarding. `/cockpit/` and `/cockpit+` are reserved by Cockpit.
3. Run `sudo systemctl try-restart cockpit.service` to load the changes if Cockpit is running. Follow [Apply a Caddy site](caddy.md#apply-a-site). Allow `443/tcp` only from the intended client network using [UFW](ufw.md) or the host's existing firewall.
4. Follow [Trust the internal CA](caddy.md#trust-the-internal-ca-on-a-client). From a client, open `https://192.168.0.120/` **without `:9090`**. If using a prefix, confirm the redirect to `/console/`. Sign in and open a page to verify the proxied session, not just the initial HTML. Confirm Cockpit is still on loopback and remove any obsolete direct `9090` firewall allow after verifying access.

## Direct HTTPS

Bind Cockpit to the chosen management IP. If migrating from Caddy, remove proxy-specific `ProtocolHeader` and URL prefix settings and review `Origins`. Install a certificate valid for the address clients use, following `man cockpit-ws` for certificate files. Allow `9090/tcp` only from the management network. From that network, verify `https://SERVER:9090/` and sign in without bypassing certificate warnings. If you cannot provide trusted TLS, use the SSH tunnel or Caddy branch instead.
