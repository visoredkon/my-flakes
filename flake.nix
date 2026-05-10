{
  description = "My personal Nix Flake package collection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, self }:
    let
      formatTargets = "apps/*.nix packages/*.nix releases/*.nix flake.nix";

      generatedPackages = builtins.mapAttrs (
        name: meta:
        pkgs.callPackage ./packages/${name}.nix {
          inherit mkPrebuilt;
          inherit (meta) release urlTemplate;
        }
      ) packageMetadata;

      mkApp = program: {
        inherit program;
        type = "app";
      };

      mkPrebuilt = pkgs.callPackage ./packages/mk-prebuilt.nix { };

      packageMetadata = builtins.mapAttrs (
        name: info:
        info
        // {
          release = import ./releases/${name}.nix;
        }
      ) packagesConfig;

      packagesConfig = {
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
        "forgecode" = rec {
          baseUrl = "https://github.com/tailcallhq/forgecode/releases/download";
          binName = "forgecode";
          urlTemplate = "${baseUrl}/v{version}/forge-x86_64-unknown-linux-gnu";
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
      };

      pkgs = import nixpkgs { inherit system; };

      system = "x86_64-linux";

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

      checks.${system}.format =
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

      formatter.${system} = pkgs.callPackage ./apps/formatter.nix { inherit formatTargets; };

      overlays.default =
        _: prev:
        builtins.intersectAttrs packagesConfig (self.packages.${prev.stdenv.hostPlatform.system} or { });

      packages.${system} = generatedPackages;
    };
}
