#!/bin/bash

set -ouex pipefail

### Packages
#
# These were previously layered with `rpm-ostree install`. A bootc image does not
# carry layered packages across a switch, so anything relied on has to be baked
# in here -- including zsh, which is the login shell in /etc/passwd. Without it
# the user's session cannot start and the greeter loops forever.
#
# Names taken verbatim from the deployment origin's `requested=` list, so they
# are known to resolve.

dnf5 install -y \
    adb \
    fd-find \
    ghostty \
    git \
    gnome-boxes \
    lazygit \
    m4 \
    neovim \
    ripgrep \
    zsh

# Not handled here: 1Password. It was installed from a downloaded RPM
# (`requested-local` in the deployment origin, pinned at 8.12.12) rather than a
# repo, so it needs 1Password's yum repo added before it can be installed. See
# https://support.1password.com/install-linux/#red-hat-fedora
