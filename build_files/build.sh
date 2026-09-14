#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

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
# Not in the default Fedora repos. They resolve on a running Bazzite system only
# because these COPRs are enabled there; the build container has no such thing.
# Enable, install, then disable so the repos do not ship enabled in the image.

dnf5 -y copr enable scottames/ghostty
dnf5 -y install ghostty
dnf5 -y copr disable scottames/ghostty

dnf5 -y copr enable atim/lazygit
dnf5 -y install lazygit
dnf5 -y copr disable atim/lazygit

### Nix package manager
#
# Fedora 44 packages Nix natively, so no curl|sh installer. Binaries land in
# /usr (immutable, versioned with the image); /nix comes from nix-filesystem and
# is made writable by nix.mount + tmpfiles.d/nix-store.conf in system_files/.
#
# All four packages must be named explicitly: this base sets
# install_weak_deps=False, so `dnf5 install -y nix` silently drops everything
# the metapackage merely Recommends.
#
#   nix-daemon   the systemd units. Without it the build itself dies on
#                `systemctl enable nix-daemon.service`.
#   busybox      Fedora's nix.conf hardcodes
#                  sandbox-paths = /bin/sh=/usr/bin/busybox
#                Without it nix looks healthy and substitution works, but every
#                sandboxed build fails on a missing /usr/bin/busybox.
#   nix-legacy   nix-env, nix-build, nix-shell as argv[0] symlinks.
#                home-manager activation calls nix-build and nix-env directly,
#                so `home-manager switch` fails without it -- long after nix
#                itself appears to be working.
#
# Credit: github.com/physarella/bazzite-nix, who found each of these the hard
# way, one failed build at a time.

dnf5 install -y nix nix-daemon nix-legacy busybox

# Let anyone in wheel drive the daemon (add substituters, use flakes) without
# sudo. Fedora already enables nix-command + flakes in this file.
cat >>/etc/nix/nix.conf <<'NIXCONF'

# --- added by image build ---
trusted-users = root @wheel
NIXCONF

systemctl enable nix.mount

# Run the daemon as a plain service, NOT socket-activated. nix-daemon.socket has
# PID 1 create the listening socket and SELinux denies it outright:
#
#   avc: denied { create } for pid=1 comm="systemd" name="socket"
#     scontext=init_t tcontext=default_t tclass=sock_file permissive=0
#
# Fedora ships nix with no SELinux policy, so /nix/... maps to default_t and
# init_t may not create a sock_file of that type. Upstream: NixOS/nix#4913,
# #2374. The service creates the socket itself from a domain that is permitted
# to. Disable the socket too, or it fails every boot and leaves
# `systemctl is-system-running` reporting "degraded" forever.
systemctl disable nix-daemon.socket
systemctl enable nix-daemon.service

# Not handled here: 1Password. It came from a downloaded RPM (`requested-local`
# in the deployment origin, pinned at 8.12.12) rather than a repo, so it needs
# 1Password's yum repo wired up separately.
# https://support.1password.com/install-linux/#red-hat-fedora
