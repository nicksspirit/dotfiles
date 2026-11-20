# Caddy

Prefer Caddy as the reverse proxy for most web services. Terminate HTTPS at Caddy and keep same-host backends on loopback. Select `--package caddy` to install from apt through `scripts/setup-tools.sh`. Bootstrap does not write `/etc/caddy/Caddyfile` or change firewall rules.

## Choose HTTPS

- **Private IP or hostname:** Use `tls internal`. Give clients a stable IP or a hostname they can resolve. Trust Caddy's root on the clients that need it; no router port forwarding is needed.
- **Publicly trusted hostname:** Use a domain you control and omit `tls internal`. Plan certificate validation before deployment. Default HTTP/TLS challenges require public reachability on the corresponding port; a private deployment can use DNS validation with a compatible DNS provider module. Publicly trusted TLS does not require making the backend public.

See [Caddy's automatic HTTPS documentation](https://caddyserver.com/docs/automatic-https) for certificate requirements. For a working private-IP example with a loopback backend, use [Cockpit over LAN HTTPS](cockpit.md#lan-https-through-caddy).

## Apply a site

1. Inspect and back up `/etc/caddy/Caddyfile`. Replace the stock welcome site on a fresh install; preserve unrelated sites on an existing proxy. Check for port conflicts and keep the frontend reachable only from the intended network.
2. Validate, start the service if needed, and load the site:

   ```sh
   sudo -u caddy -H caddy validate --config /etc/caddy/Caddyfile &&
     sudo systemctl enable --now caddy &&
     sudo systemctl reload caddy
   ```

3. Check the HTTPS listener with `ss -ltn 'sport = :443'`. From an intended client, verify HTTPS without bypassing certificate checks and test the application. If a reload fails, inspect `sudo journalctl -u caddy -n 50 --no-pager`; restore the backed-up config before reloading again if necessary.

## Trust the internal CA on a client

On the server, export only the public root certificate from the packaged systemd service's data directory:

```sh
sudo openssl x509 \
  -in /var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt \
  -outform PEM > "$HOME/caddy-root.crt"
```

Copy `caddy-root.crt` to the client over authenticated SSH. Keep the CA private key on the server. Test with `curl --cacert ./caddy-root.crt https://YOUR_SITE/` before changing the client's trust store.

On macOS, trust the root for SSL only if you trust this server to act as a CA. Use Keychain Access or run:

```sh
sudo security add-trusted-cert -d -r trustRoot -p ssl \
  -k /Library/Keychains/System.keychain ./caddy-root.crt
```

Verify with `/usr/bin/curl https://YOUR_SITE/` without `--cacert` or `-k`, then test in the browser. A browser using its own trust store may need a separate import. See [Caddy's systemd guide](https://caddyserver.com/docs/running#local-https-with-systemd) for storage and trust details.
