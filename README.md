# zoomUpstream

Upstream Zoom desktop client repackaged as a Nix flake. This package keeps Zoom’s own bundled Qt and runs the upstream binary with a minimal wrapper that’s aware of nix-ld. The wrapper is Wayland-first with X11 fallback.

This README explains:

- How to set up nix-ld (NixOS and non‑NixOS)
- How to launch Zoom (Wayland by default; X11 fallback)
- How to get Wayland screen sharing working (PipeWire + xdg-desktop-portal)
- Troubleshooting common issues
- Keeping the package updated

Note: Zoom is unfree software. You must allow unfree to build/run it.

## Overview

- Runs the upstream `.deb` with Zoom’s own bundled Qt, avoiding Qt version mismatches.
- Delegates runtime linking to nix-ld (recommended) instead of manual LD_LIBRARY_PATH or patchelf gymnastics.
- Wayland-first with:
  - `QT_QPA_PLATFORM="wayland;xcb"`
  - Chromium/CEF Ozone flags for PipeWire-based screen capture.
- Relies on host services for Wayland screen sharing:
  - PipeWire (with pulse compatibility)
  - xdg-desktop-portal + a portal backend (GTK or KDE)

## Prerequisites

- Nix with flakes enabled
- Allow unfree packages when building/running

Examples:

- One-shot: `NIXPKGS_ALLOW_UNFREE=1`
- NixOS configuration: `nixpkgs.config.allowUnfree = true;`

## Setup: nix-ld

nix-ld lets foreign (non-Nix) dynamically linked programs resolve shared libraries from the Nix store at runtime. This is the most robust way to run upstream binaries without hand-rolled LD_LIBRARY_PATH or patchelf.

### A) NixOS

Enable nix-ld and list libraries Zoom typically needs. Also ensure PipeWire and xdg-desktop-portal are enabled for Wayland screen sharing.

Add something like this to your `configuration.nix`:

```
{
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Core deps and graphics
      glib gtk3 gdk-pixbuf pango cairo freetype fontconfig
      libdrm libgbm libglvnd wayland libxkbcommon mesa

      # Audio/IPC
      alsa-lib pulseaudio pipewire dbus

      # Network/security/printing
      nspr nss krb5 cups

      # X11 + XCB utils (for Xwayland fallback and plugins)
      xorg.libX11 xorg.libxcb xorg.libXext xorg.libXrender
      xorg.libXcomposite xorg.libXcursor xorg.libXdamage xorg.libXfixes
      xorg.libXi xorg.libXrandr xorg.libXtst xorg.libXScrnSaver xorg.libxshmfence
      xorg.xcbutil xorg.xcbutilcursor xorg.xcbutilimage xorg.xcbutilwm
      xorg.xcbutilrenderutil xorg.xcbutilkeysyms

      # Misc runtime libs
      libuuid atk at-spi2-atk at-spi2-core expat udev systemd

      # GCC runtime (libstdc++, libatomic, etc.)
      stdenv.cc.cc
    ];
  };

  # Host runtime services for Wayland screen sharing
  services.pipewire = {
    enable = true;
    pulse.enable = true; # provides Pulseaudio socket via PipeWire
  };

  xdg.portal = {
    enable = true;
    # Pick one matching your desktop (gtk works broadly)
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };
}
```

Rebuild your system after adding the above.

### B) Non‑NixOS (or ad-hoc usage)

Use nix-ld in an ephemeral shell that sets `NIX_LD` and `NIX_LD_LIBRARY_PATH`:

```
nix shell nixpkgs#nix-ld
```

Then run Zoom via the wrapper inside that shell. Example:

```
NIXPKGS_ALLOW_UNFREE=1 nix run .#zoomUpstream --impure
```

If you prefer to launch the binary explicitly under the loader:

```
nix shell nixpkgs#nix-ld
"$NIX_LD" --library-path "$NIX_LD_LIBRARY_PATH" nix run .#zoomUpstream --impure
```

If you run into GPU issues on non‑NixOS, pair with nixGL:

```
nix run nixpkgs#nixgl.auto -- "$NIX_LD" --library-path "$NIX_LD_LIBRARY_PATH" nix run .#zoomUpstream --impure
```

## Usage

- Wayland-first:

  ```
  NIXPKGS_ALLOW_UNFREE=1 nix run .#zoomUpstream --impure
  ```

- X11 fallback (Xwayland):
  ```
  ZOOM_USE_WAYLAND=0 QT_QPA_PLATFORM=xcb \
  NIXPKGS_ALLOW_UNFREE=1 nix run .#zoomUpstream --impure
  ```

The wrapper will:

- Set Zoom’s Qt plugin and QML paths to the bundled Qt.
- Keep Wayland/Ozone flags enabled by default.
- If `NIX_LD` and `NIX_LD_LIBRARY_PATH` are set (e.g., by nix-ld), it will exec via the loader; otherwise it runs the binary directly.

## Wayland screen sharing

You must have the host services running:

- PipeWire with `pipewire-pulse` (for legacy Pulseaudio socket compatibility)
- xdg-desktop-portal plus a backend (GTK or KDE)

On NixOS, enable as shown above. On other distros, install and run your desktop’s portal backend (e.g., `xdg-desktop-portal-gtk`) and PipeWire.

You can check portal services with:

- `systemctl --user status xdg-desktop-portal*`
- `busctl --user list | grep portal` (on systems with `busctl`)

If portals are not running, Wayland screen sharing will fail.

## Troubleshooting

- error while loading shared libraries: libXYZ.so.N: cannot open shared object file
  - Ensure nix-ld is enabled and its libraries list includes the missing library.
  - On non‑NixOS, make sure you launched within `nix shell nixpkgs#nix-ld` (so `NIX_LD`/`NIX_LD_LIBRARY_PATH` are set).
  - Use `nix-index` or `nix-locate` to find which package contains a missing `.so`.

- Failed to create wl_display (No such file or directory) / Could not load the Qt platform plugin "wayland"
  - You’re not in a Wayland session or `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` aren’t available.
  - Use X11 fallback:
    ```
    ZOOM_USE_WAYLAND=0 QT_QPA_PLATFORM=xcb nix run .#zoomUpstream --impure
    ```

- ZoomWebviewHost finally launch state is false
  - Often indicates portal/DBus issues. Verify that PipeWire and xdg-desktop-portal (+ gtk/kde backend) are running on the host.

- can not find 'xdg-desktop-portal' command
  - Zoom probes for binaries in `/usr` paths. On NixOS, these may not exist, but the real requirement is that the portal DBus services are running. This message can be non-fatal if the service is available on the bus.

- No PulseAudio daemon running
  - Harmless if you’re using PipeWire with `pipewire-pulse` (it provides the PulseAudio socket).

- Black window / GPU issues
  - Try non‑NixOS with `nixGL`:
    ```
    nix run nixpkgs#nixgl.auto -- nix run .#zoomUpstream --impure
    ```
  - Or force X11 fallback as above.

## Keeping Zoom updated

This repository includes an `update.sh` script that:

- Fetches the latest upstream `.deb`
- Reads the version from the archive
- Computes the SHA256
- Updates `pkgs/zoomUpstream/version.nix`

Usage:

```
bash pkgs/zoomUpstream/update.sh
NIXPKGS_ALLOW_UNFREE=1 nix build .#zoomUpstream --impure
```

If you prefer upstreaming updates to nixpkgs itself, consider using `nixpkgs-update` in the nixpkgs repo to keep `zoom-us` current for everyone.

## Notes on sandbox flags

The wrapper includes Chromium/QtWebEngine flags like `--no-sandbox`, `--disable-setuid-sandbox`, etc., which are commonly required by upstream binaries in Nix environments due to namespace and sandbox constraints. If your environment supports the upstream sandboxing, you can experiment with removing them, but in many cases these flags are necessary for stability.

## License

Zoom is unfree software; you must enable unfree to build and run this package. This flake only repackages the upstream binary for convenience.
