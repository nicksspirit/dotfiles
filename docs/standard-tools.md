# Standard tools

`jq` and `yq` are canonical bootstrap IDs for standard command-line utilities. They are installed from apt by the Bash-only registry in `scripts/package-registry.sh` and have no tracked configuration or shell initialization. Select jq with `./bootstrap.sh --package jq` (or select `yq` separately); the baseline is also installed.

The AWS CLI has canonical ID `aws-cli` and alias `aws`; it is installed from Snap with `--classic`, and its binary is `/snap/bin/aws`. Installer metadata is centralized in the registry while installation implementations remain in `scripts/setup-tools.sh`.
