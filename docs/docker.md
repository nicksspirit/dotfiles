# Docker Engine

Select `--package docker` to install Docker Engine, containerd, Buildx, and the Compose plugin from Docker's Debian repository. `scripts/setup-tools.sh` supports Debian 13 (trixie) on amd64 for this unit. It enables and starts Docker and containerd, checks the service, and checks Compose.

Setup adds the current user to the `docker` group. Log out completely and reconnect, then run `docker run --rm hello-world` without sudo. Membership in the `docker` group grants root-level access; do not make the Docker socket world-writable with `chmod 666`.

Preview with `./bootstrap.sh --dry-run --package docker`. Validate bootstrap selection with `bash tests/test_bootstrap.sh`.
