# os-desktop

Custom [Bazzite](https://bazzite.gg) image for my gaming + development desktop.
Built from [ublue-os/image-template](https://github.com/ublue-os/image-template).

Published to `ghcr.io/tbarker9/os-desktop`.

## What this adds to stock Bazzite

| Change | Where | Why |
|---|---|---|
| Nix, working out of the box | `build_files/build.sh`, `system_files/` | Fedora 44 packages Nix natively. `/nix` comes from `nix-filesystem` and is made writable by a bind mount from `/var/lib/nix`. See [Nix](#nix) below -- it is the bulk of the diff. |
| Packages that were previously layered | `build_files/build.sh` | `adb`, `fd-find`, `git`, `gnome-boxes`, `m4`, `ripgrep`, `zsh`. A bootc image does not carry layered packages across a switch, so anything relied on has to be baked in. `zsh` especially: `/etc/passwd` names it as the login shell, and without it the greeter loops forever. |
| `ghostty`, `lazygit` | `build_files/build.sh` | Not in the default Fedora repos. Their COPRs are enabled, used, then disabled, so the image does not ship enabled COPRs. |
| 1Password + Brave repo definitions | `system_files/etc/yum.repos.d/` | The applications themselves are *not* installed -- see [Deliberately not in the image](#deliberately-not-in-the-image). Shipping the repo files and importing the signing keys means layering them later needs no setup. |

Everything else here is plumbing: the build workflow, Renovate, and the signing
key.

Do not add kernel arguments that Bazzite already manages --
`/usr/libexec/bazzite-hardware-setup` runs on every boot and applies its own
(`bluetooth.disable_ertm=1`, and others gated on hardware ID). An image-supplied
karg cannot be cleanly removed on the machine, so duplicating one pins it past
any future upstream decision to drop it.

## Layout

```
Containerfile                             base image, pinned by digest
build_files/build.sh                      packages (dnf5) + nix setup --
                                          runs inside the build
system_files/                             copied verbatim to / at build time
  etc/yum.repos.d/                        1Password + Brave repo definitions
  usr/lib/systemd/system/nix.mount        bind-mounts /var/lib/nix over /nix
  usr/lib/tmpfiles.d/nix-store.conf       creates the backing store dirs
image-template.env                        image name, description, tags
```

## Nix

Bazzite's root is read-only (composefs), so a writable `/nix` needs two pieces
that ship in `system_files/`:

- `tmpfiles.d/nix-store.conf` creates the real store under `/var/lib/nix`
  (persistent, per-machine).
- `nix.mount` bind-mounts that over `/nix` at boot.

Nix itself is installed from Fedora's RPMs, so the binaries live in `/usr` and
are versioned with the image. **There is no `curl | sh` installer step** -- the
Determinate Systems installer was used once, early on, and is no longer how this
works. `/etc/nix/nix.conf` is owned by the RPM; the build appends
`trusted-users = root @wheel` to it.

Four packages are named explicitly (`nix nix-daemon nix-legacy busybox`) because
this base sets `install_weak_deps=False`, which silently drops everything the
`nix` metapackage merely Recommends. `build.sh` documents what each one is for
and what breaks without it -- read that before trimming the list.

The daemon runs as a plain service, not socket-activated, because SELinux denies
PID 1 creating the socket. Again, see `build.sh`.

Verifying it works after a switch:

```
findmnt /nix                       # should be rw, source /var/lib/nix
systemctl is-active nix.mount nix-daemon.service
nix --version
```

Home directory config (packages, dotfiles, home-manager) is **not** here. It
lives in a separate private repo, `~/Projects/nix-config`.

## Switching this machine to it

First time:

```
sudo bootc switch ghcr.io/tbarker9/os-desktop:latest
systemctl reboot
```

Afterwards updates arrive automatically -- `uupd.timer` runs daily at 04:00.
To pull one now:

```
sudo bootc upgrade --check     # is anything new?
sudo bootc upgrade --apply     # fetch, stage, reboot if changed
```

Rollback if a build is bad: pick the previous deployment at the boot menu, or
`sudo bootc rollback`.

## Keeping the build alive

GitHub disables scheduled workflows after **60 days without repository
activity**. Workflow runs do not count -- only commits.

This is handled by Renovate (`.github/renovate.json5`). It watches the pinned
base digest and opens a PR each time Bazzite ships stable, roughly every 5 days.
Merging those PRs is the repository activity that keeps the schedule alive, and
it means OS changes land when I choose rather than silently.

Note the config automerges `pin`/`pinDigest` updates (the act of *adding* a pin)
but not `digest` updates (moving an existing pin), so base image bumps wait for
review.

Fallback if it ever does go dormant -- `uupd` warns after 30 days without an
update, which is 30 days of slack before the 60-day cutoff:

```
git commit --allow-empty -m "keepalive" && git push
gh workflow run build.yml     # push alone may not trigger; the push trigger is path-filtered
gh run watch
sudo bootc upgrade --apply
```

## Deliberately not in the image

**1Password and Brave** are layered on the running system, not baked in. Both
unpack into `/opt`, which is a symlink to `/var/opt` on this base -- and `/var`
is machine state that bootc seeds only on first boot, so an RPM installed there
during the build is discarded on deploy.

The fix used elsewhere is to replace `/opt` with a real directory. ostree
symlinks a whole family of writable FHS paths into `/var` (`/home`, `/opt`,
`/srv`, `/root`, `/usr/local`, `/mnt`) so their contents survive upgrades;
undoing one of them to accommodate two applications changes how the OS works
more than the problem warrants.

What the image *does* provide is their repo definitions and signing keys, so
installing them needs no setup. The commands live in `nix-config` as the
`os-layers` helper, since they are user-run scripts rather than OS content.

**neovim** is installed by home-manager instead, and `~/.config/nvim` is a
symlink into `nix-config`. Shipping it here too put two neovims on the box --
the Nix one always won on `PATH`, so the image's copy was dead weight that would
only drift. Letting Nix own the editor also makes it identical on the Mac and
the homeserver, which the image cannot reach. `vim-minimal` and `nano` remain,
so there is still an editor if Nix is ever broken.

Also absent, and why: **docker** (the binary here was a brew client with no
daemon; podman covers it), **keybase** (no longer used), **calibre** (runs as a
flatpak). Flatpaks are not managed declaratively -- the list lives in
`nix-config` as the `os-flatpaks` helper.
