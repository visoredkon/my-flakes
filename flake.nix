{
  description = "My personal Nix Flake package collection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, self }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "antigravity"
            "antigravity-cli"
            "kiro"
            "warp-terminal"
          ];
      };

      mkPrebuilt = pkgs.callPackage ./packages/mk-prebuilt.nix { };

      packagesConfig = {
        "antigravity" = {
          baseUrl = "https://antigravity-auto-updater-974169037036.us-central1.run.app";
          binName = "antigravity";
          urlTemplate = "";
        };
        "antigravity-cli" = {
          baseUrl = "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app";
          binName = "agy";
          urlTemplate = "";
        };
        "bun" = rec {
          baseUrl = "https://github.com/oven-sh/bun/releases/download";
          binName = "bun";
          urlTemplate = "${baseUrl}/bun-v{version}/bun-linux-x64.zip";
        };
        "claude-code" = rec {
          baseUrl = "https://downloads.claude.ai/claude-code-releases";
          binName = "claude";
          urlTemplate = "${baseUrl}/{version}/linux-x64/claude";
        };
        "codebase-memory-mcp" = rec {
          baseUrl = "https://github.com/DeusData/codebase-memory-mcp/releases/download";
          binName = "codebase-memory-mcp";
          urlTemplate = "${baseUrl}/v{version}/codebase-memory-mcp-ui-linux-amd64.tar.gz";
        };
        "copilot-cli" = rec {
          baseUrl = "https://github.com/github/copilot-cli/releases/download";
          binName = "copilot";
          urlTemplate = "${baseUrl}/v{version}/copilot-linux-x64.tar.gz";
        };
        "kiro" = rec {
          baseUrl = "https://prod.download.desktop.kiro.dev";
          binName = "kiro";
          urlTemplate = "${baseUrl}/releases/stable/linux-x64/signed/{version}/tar/kiro-ide-{version}-stable-linux-x64.tar.gz";
        };
        "kiro-cli" = rec {
          baseUrl = "https://prod.download.cli.kiro.dev/stable";
          binName = "kiro-cli";
          urlTemplate = "${baseUrl}/{version}/kirocli-x86_64-linux.zip";
        };
        "mise" = rec {
          baseUrl = "https://github.com/jdx/mise/releases/download";
          binName = "mise";
          urlTemplate = "${baseUrl}/v{version}/mise-v{version}-linux-x64.tar.gz";
        };
        "opencode" = rec {
          baseUrl = "https://github.com/anomalyco/opencode/releases/download";
          binName = "opencode";
          urlTemplate = "${baseUrl}/v{version}/opencode-linux-x64.tar.gz";
        };
        "typescript-language-server" = rec {
          baseUrl = "https://registry.npmjs.org/typescript-language-server/-/typescript-language-server";
          binName = "typescript-language-server";
          urlTemplate = "${baseUrl}-{version}.tgz";
        };
        "tinymist" = rec {
          baseUrl = "https://github.com/Myriad-Dreamin/tinymist/releases/download";
          binName = "tinymist";
          urlTemplate = "${baseUrl}/v{version}/tinymist-x86_64-unknown-linux-gnu.tar.gz";
        };
        "typst" = rec {
          baseUrl = "https://github.com/typst/typst/releases/download";
          binName = "typst";
          urlTemplate = "${baseUrl}/v{version}/typst-x86_64-unknown-linux-musl.tar.xz";
        };
        "warp-terminal" = rec {
          baseUrl = "https://releases.warp.dev/stable";
          binName = "warp-terminal";
          urlTemplate = "${baseUrl}/v{version}/warp-terminal-v{version}-1-x86_64.pkg.tar.zst";
        };
      };

      goPackagesConfig = {
        "bootdev" = {
          repoOwner = "bootdotdev";
          repoName = "bootdev";
        };
      };

      goPackageNames = builtins.attrNames goPackagesConfig;

      goPackageReleases = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = import ./releases/${name}.nix;
        }) goPackageNames
      );

      goPackages = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = pkgs.callPackage ./packages/${name}.nix {
            release = goPackageReleases.${name};
          };
        }) goPackageNames
      );

      packageMetadata = builtins.mapAttrs (
        name: info:
        info
        // {
          release = import ./releases/${name}.nix;
        }
      ) packagesConfig;

      generatedPackages =
        (builtins.mapAttrs (
          name: meta:
          pkgs.callPackage ./packages/${name}.nix {
            inherit mkPrebuilt;
            inherit (meta) release urlTemplate;
          }
        ) (builtins.removeAttrs packageMetadata goPackageNames))
        // goPackages;

      formatTargets = "apps/*.nix packages/*.nix releases/*.nix flake.nix";

      mkApp = program: {
        inherit program;
        type = "app";
      };

      updateRelease = pkgs.callPackage ./apps/update-release.nix {
        inherit packageMetadata;
        inherit goPackagesConfig;
      };
    in
    {
      apps.${system} =
        (builtins.mapAttrs (
          name: meta: mkApp "${generatedPackages.${name}}/bin/${meta.binName}"
        ) packageMetadata)
        // {
          "bootdev" = mkApp "${generatedPackages.bootdev}/bin/bootdev";
          "update-release" = mkApp "${updateRelease}/bin/update-release";
        };

      checks.${system} =
        (builtins.mapAttrs (
          name: _:
          pkgs.runCommand "check-${name}" {
            buildInputs = [ generatedPackages.${name} ];
          } "touch $out"
        ) packageMetadata)
        // {
          "bootdev" = pkgs.runCommand "check-bootdev" {
            buildInputs = [ generatedPackages.bootdev ];
          } "touch $out";
          format =
            pkgs.runCommand "check-format"
              {
                nativeBuildInputs = [ pkgs.nixfmt ];
                src = self;
              }
              ''
                cd $src
                nixfmt --check ${formatTargets}
                touch $out
              '';
          linter =
            pkgs.runCommand "check-linter"
              {
                nativeBuildInputs = [ pkgs.statix ];
                src = self;
              }
              ''
                cd $src
                statix check .
                touch $out
              '';
        };

      formatter.${system} = pkgs.callPackage ./apps/formatter.nix { inherit formatTargets; };

      overlays.default =
        _: prev:
        builtins.intersectAttrs packagesConfig (self.packages.${prev.stdenv.hostPlatform.system} or { })
        // nixpkgs.lib.genAttrs goPackageNames (
          name: self.packages.${prev.stdenv.hostPlatform.system}.${name}
        );

      packages.${system} = generatedPackages;
    };
}
