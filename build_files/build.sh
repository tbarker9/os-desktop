#!/bin/bash

set -ouex pipefail

# No system_files/ tree in this repo yet. If you need to ship files onto / --
# a policy.json to enforce image signatures, a systemd unit -- recreate the
# directory, re-add `COPY system_files /system_files` to the Containerfile, and
# restore the copy below.
#
# cp -avf "/ctx/system_files"/. /

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
