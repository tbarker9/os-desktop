# os-desktop

Custom [Bazzite](https://bazzite.gg) image for my gaming + development desktop.
Built from [ublue-os/image-template](https://github.com/ublue-os/image-template).

Published to `ghcr.io/tbarker9/os-desktop`.

## What this adds to stock Bazzite

| Change | Where | Why |
|---|---|---|
| empty `/nix` directory | `Containerfile` | Bazzite's root is read-only (composefs), so Nix's installer cannot create the mountpoint at runtime. Shipping it in the image is the fix. |
| `bluetooth.disable_ertm=1` | `system_files/usr/lib/bootc/kargs.d/` | Xbox controller pairing. Was set by hand on the machine and recorded nowhere. |

## Layout

```
Containerfile                             base image + /nix
build_files/build.sh                      packages (dnf5) — runs inside the build
system_files/                             copied verbatim onto / in the image
  usr/lib/bootc/kargs.d/10-bluetooth.toml kernel arguments
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
