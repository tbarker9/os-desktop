# os-desktop

Custom [Bazzite](https://bazzite.gg) image for my gaming + development desktop.
Built from [ublue-os/image-template](https://github.com/ublue-os/image-template).

Published to `ghcr.io/tbarker9/os-desktop`.

## What this adds to stock Bazzite

| Change | Where | Why |
|---|---|---|
| empty `/nix` directory | `Containerfile` | Bazzite's root is read-only (composefs), so Nix's installer cannot create the mountpoint at runtime. Shipping it in the image is the fix. |

That is the entire diff against stock Bazzite. Everything else here is plumbing:
the build workflow, Renovate, and the signing key.

Do not add kernel arguments that Bazzite already manages --
`/usr/libexec/bazzite-hardware-setup` runs on every boot and applies its own
(`bluetooth.disable_ertm=1`, and others gated on hardware ID). An image-supplied
karg cannot be cleanly removed on the machine, so duplicating one pins it past
any future upstream decision to drop it.

## Layout

```
Containerfile                             base image + /nix
build_files/build.sh                      packages (dnf5) — runs inside the build
                                          (no system_files/ tree yet -- see
                                          build.sh for how to restore it)
image-template.env                        image name, description, tags
```

## Switching this machine to it

First time:

```
sudo bootc switch ghcr.io/tbarker9/os-desktop:latest
systemctl reboot
```

Afterwards updates arrive automatically — `uupd.timer` runs daily at 04:00.
To pull one now:

```
sudo bootc upgrade --check     # is anything new?
sudo bootc upgrade --apply     # fetch, stage, reboot if changed
```

Rollback if a build is bad: pick the previous deployment at the boot menu, or
`sudo bootc rollback`.

## Installing Nix (after switching)

Only needed once. `/nix` exists but is read-only (it lives on `/`), so the
installer still bind-mounts real storage from `/var` onto it:

```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
  | sh -s -- install ostree --persistence=/var/lib/nix
```

`nix-directory.service` will skip (its `ConditionPathExists=!/nix` is false now)
and `nix.mount` does the real work.

Determinate Nix owns `/etc/nix/nix.conf` — put custom settings in
`/etc/nix/nix.custom.conf` instead.

Home directory config lives separately, in `nix-config`.

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

Also absent, and why: **docker** (the binary here was a brew client with no
daemon; podman covers it), **keybase** (no longer used), **calibre** (runs as a
flatpak). Flatpaks are not managed declaratively -- the list lives in
`nix-config`.
