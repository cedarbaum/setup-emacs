#!/usr/bin/env bash

# This is a cut-down version of https://github.com/cachix/install-nix-action/blob/master/lib/install-nix.sh
# Users should use install-nix-action if they want to customise how Nix is installed.

set -euo pipefail

emacs_ci_version=$1
[[ -n "$emacs_ci_version" ]]

# On self-hosted runners we don't need to install more than once
if [[ ! -d /nix/store ]]; then
    # Configure Nix
    add_config() {
        echo "$1" | sudo tee -a /tmp/nix.conf >/dev/null
    }
    # Set jobs to number of cores
    add_config "max-jobs = auto"
    # Allow binary caches for user
    add_config "trusted-users = root $USER"

    installer_options=(
        --daemon
        --daemon-user-count 4
        --no-channel-add
        --darwin-use-unencrypted-nix-store-volume
        --nix-extra-conf-file /tmp/nix.conf
    )

    sh <(curl --retry 5 --retry-connrefused -L https://nixos.org/nix/install) "${installer_options[@]}"
    if [[ $OSTYPE =~ darwin ]]; then
        # Disable spotlight indexing of /nix to speed up performance
        sudo mdutil -i off /nix

        # macOS needs certificates hints
        cert_file=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
        echo "NIX_SSL_CERT_FILE=$cert_file" >> "$GITHUB_ENV"
        export NIX_SSL_CERT_FILE=$cert_file
        sudo launchctl setenv NIX_SSL_CERT_FILE "$cert_file"
    fi

    # Set paths
    echo "/nix/var/nix/profiles/per-user/$USER/profile/bin" >> "$GITHUB_PATH"
    echo "/nix/var/nix/profiles/default/bin" >> "$GITHUB_PATH"

    PATH=/nix/var/nix/profiles/per-user/$USER/profile/bin:/nix/var/nix/profiles/default/bin:$PATH

    export NIX_PATH=nixpkgs=channel:nixpkgs-unstable
    echo "NIX_PATH=${NIX_PATH}" >> $GITHUB_ENV
fi

nix-env --quiet -j8 -iA cachix -f https://cachix.org/api/v1/install
cachix use emacs-ci

nix-env -i --arg emacsAttr "\"$emacs_ci_version\"" -f "https://github.com/cedarbaum/nix-emacs-ci/archive/build-libgit.tar.gz"

emacs -version
