#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Packages
#
# These are currently layered imperatively with `rpm-ostree install`, which means
# they are re-applied on every OS update (slow) and are lost on reinstall.
# Uncomment to bake them into the image instead.
#
# Deliberately left off for the first build so that a failure points at one
# change (/nix) rather than several.
#
# dnf5 install -y \
#     adb \
#     fd-find \
#     ghostty \
#     gnome-boxes \
#     lazygit \
#     m4 \
#     neovim \
#     ripgrep \
#     zsh
