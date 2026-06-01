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
        "warp-terminal" = rec {
          baseUrl = "https://releases.warp.dev/stable";
          binName = "warp-terminal";
          urlTemplate = "${baseUrl}/v{version}/warp-terminal-v{version}-1-x86_64.pkg.tar.zst";
        };
      };

      packageMetadata = builtins.mapAttrs (
        name: info:
        info
        // {
          release = import ./releases/${name}.nix;
        }
      ) packagesConfig;

      generatedPackages = builtins.mapAttrs (
        name: meta:
        pkgs.callPackage ./packages/${name}.nix {
          inherit mkPrebuilt;
          inherit (meta) release urlTemplate;
        }
      ) packageMetadata;

      formatTargets = "apps/*.nix packages/*.nix releases/*.nix flake.nix";

      mkApp = program: {
        inherit program;
        type = "app";
      };

      updateRelease = pkgs.callPackage ./apps/update-release.nix { inherit packageMetadata; };
    in
    {
      apps.${system} =
        (builtins.mapAttrs (
          name: meta: mkApp "${generatedPackages.${name}}/bin/${meta.binName}"
        ) packageMetadata)
        // {
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
        };

      formatter.${system} = pkgs.callPackage ./apps/formatter.nix { inherit formatTargets; };

      overlays.default =
        _: prev:
        builtins.intersectAttrs packagesConfig (self.packages.${prev.stdenv.hostPlatform.system} or { });

      packages.${system} = generatedPackages;
    };
}
