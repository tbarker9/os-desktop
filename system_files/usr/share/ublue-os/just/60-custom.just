# Custom ujust recipes for this image. The stock justfile imports this slot
# with `import? "/usr/share/ublue-os/just/60-custom.just"`.

# Update Bazzite (ujust update), then user-level tools via nix-config/update.sh
[group("system")]
update-all:
    #!/usr/bin/bash
    set -uo pipefail
    # Stock recipe first: OS image, flatpak and brew via uupd. Not overridden,
    # so upstream fixes to `ujust update` keep flowing in.
    ujust update
    os_rc=$?

    # Then everything uupd cannot reach: nix/home-manager, npm, uv, nvim, ...
    # brew and flatpak are skipped because uupd just did them.
    script="${NIX_CONFIG_DIR:-$HOME/Projects/nix-config}/update.sh"
    if [ -x "$script" ]; then
        "$script" --skip brew,flatpak
        user_rc=$?
    else
        echo "No executable $script -- skipping user-level updates."
        user_rc=0
    fi

    exit $(( os_rc || user_rc ))
