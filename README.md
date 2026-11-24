# My Flakes

Personal Nix Flake package collection.

## Usage

```bash
nix flake show                  # Show all packages and apps
nix run .#<app>                 # Run an app
nix run .#update-release        # Update all packages
nix flake check                 # Validate formatting
```

## Ghost Downloader

`ghost-downloader` wraps the upstream Nuitka Linux tarball. Notes:

- The app is updated through this flake; its in-app self-updater is not available in the Nix store.
- FFmpeg, N_m3u8DL-RE, yt-dlp, and QuickJS (quickjs-ng) are bundled and detected automatically.
- yt-dlp is pinned to a release newer than the one in nixpkgs, because older builds fail YouTube's JavaScript challenges.
- Kelpie/eD2k is not bundled; install it from the app's setup if needed.
- The wrapper synchronizes feature packs and refreshes the desktop, autostart, D-Bus, and `ghd` launchers the app writes under `$HOME`.

## Binary Cache

Prebuilt packages are available from Cachix:

```nix
{
  nix.settings = {
    extra-substituters = [ "https://visoredkon.cachix.org" ];
    extra-trusted-public-keys = [
      "visoredkon.cachix.org-1:1Lxuvyp4PXtSm9TXxKrXjxmtdcxyoT6CaasoRAmHYRg="
    ];
  };
}
```

## Using via Overlay (NixOS)

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    my-flakes.url = "github:visoredkon/my-flakes";
  };

  outputs = { self, nixpkgs, my-flakes, ... }:
  {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          nixpkgs.overlays = [
            my-flakes.overlays.default
          ];
        }
      ];
    };
  };
}
```

Then use packages in your configuration:

```nix
environment.systemPackages = with pkgs; [
  # packages from my-flakes are now available
];
```

### Compatibility

This overlay is built against `nixos-unstable` (see `flake.lock`). Use the same `nixpkgs` in your system as in the example above. Mixing with stable `nixos-26.05` risks ABI mismatch, e.g. `programs.rofi.plugins` from 26.05 combined with an unstable `rofi-unwrapped`.

### Transitive substituters

`nix-cachyos-kernel` declares `https://attic.xuyh0120.win/lantian` as an `extra-substituter`. Timeouts there are non-fatal warnings. If unreachable from your network, do not enable `accept-flake-config` for transitive inputs, or set `substituters` explicitly without that host.

## Layout

```
packages/    - Package definitions
releases/    - Version & checksum files
apps/        - Utility applications
```
