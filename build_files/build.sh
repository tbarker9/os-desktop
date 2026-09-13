#!/bin/bash

set -ouex pipefail

### Packages
#
# These were previously layered with `rpm-ostree install`. A bootc image does not
# carry layered packages across a switch, so anything relied on has to be baked
# in here -- including zsh, which /etc/passwd names as the login shell. Without
# it the session cannot start and the greeter loops forever.

dnf5 install -y \
    adb \
    fd-find \
    git \
    gnome-boxes \
    m4 \
    neovim \
    ripgrep \
    zsh

### COPR packages
#
# ghostty and lazygit are not in the default Fedora repos. They resolve on the
# running system only because these COPRs are enabled there; the build container
# has no such thing. Enable, install, then disable so the repo does not stay
# enabled in the shipped image.

dnf5 -y copr enable scottames/ghostty
dnf5 -y install ghostty
dnf5 -y copr disable scottames/ghostty

dnf5 -y copr enable atim/lazygit
dnf5 -y install lazygit
dnf5 -y copr disable atim/lazygit

# Not handled here: 1Password. It came from a downloaded RPM (`requested-local`
# in the deployment origin, pinned at 8.12.12) rather than a repo, so it needs
# 1Password's yum repo wired up separately.
# https://support.1password.com/install-linux/#red-hat-fedora
