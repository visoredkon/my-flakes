# My Flakes

Personal Nix Flake package collection.

## Usage

```bash
nix flake show                  # Show all packages and apps
nix run .#<app>                 # Run an app
nix run .#update-release        # Update all packages
nix flake check                 # Validate formatting
```

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

## Layout

```
packages/    - Package definitions
releases/    - Version & checksum files
apps/        - Utility applications
```
