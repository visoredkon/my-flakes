{
  description = "My personal Nix Flake package collection";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, self }:
    let
      claudeCode = pkgs.callPackage ./packages/claude-code.nix {
        inherit (packageMetadata."claude-code") release urlTemplate;
      };
      copilotCli = pkgs.callPackage ./packages/copilot-cli.nix {
        inherit (packageMetadata."copilot-cli") release urlTemplate;
      };
      forgecode = pkgs.callPackage ./packages/forgecode.nix {
        inherit (packageMetadata.forgecode) release urlTemplate;
      };
      formatTargets = "apps/*.nix packages/*.nix releases/*/release.nix flake.nix";
      gortex = pkgs.callPackage ./packages/gortex.nix {
        inherit (packageMetadata.gortex) release urlTemplate;
      };

      mkApp = program: {
        inherit program;
        type = "app";
      };

      packageMetadata = {
        "claude-code" = rec {
          baseUrl = "https://downloads.claude.ai/claude-code-releases";
          release = import ./releases/claude-code/release.nix;
          urlTemplate = "${baseUrl}/{version}/linux-x64/claude";
        };

        "copilot-cli" = rec {
          baseUrl = "https://github.com/github/copilot-cli/releases/download";
          release = import ./releases/copilot-cli/release.nix;
          urlTemplate = "${baseUrl}/v{version}/copilot-linux-x64.tar.gz";
        };

        forgecode = rec {
          baseUrl = "https://github.com/tailcallhq/forgecode/releases/download";
          release = import ./releases/forgecode/release.nix;
          urlTemplate = "${baseUrl}/v{version}/forge-x86_64-unknown-linux-gnu";
        };

        gortex = rec {
          baseUrl = "https://github.com/zzet/gortex/releases/download";
          release = import ./releases/gortex/release.nix;
          urlTemplate = "${baseUrl}/v{version}/gortex_linux_amd64.tar.gz";
        };
      };

      pkgs = import nixpkgs { inherit system; };
      system = "x86_64-linux";
      updateRelease = pkgs.callPackage ./apps/update-release.nix { inherit packageMetadata; };
    in
    {
      apps.${system} = {
        "claude-code" = mkApp "${claudeCode}/bin/claude";
        "copilot-cli" = mkApp "${copilotCli}/bin/copilot";
        forgecode = mkApp "${forgecode}/bin/forgecode";
        gortex = mkApp "${gortex}/bin/gortex";
        update-release = mkApp "${updateRelease}/bin/update-release";
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
        let
          packagesForSystem = self.packages.${prev.stdenv.hostPlatform.system};
        in
        {
          "claude-code" = packagesForSystem."claude-code";
          "copilot-cli" = packagesForSystem."copilot-cli";
          forgecode = packagesForSystem.forgecode;
          gortex = packagesForSystem.gortex;
        };

      packages.${system} = {
        "claude-code" = claudeCode;
        "copilot-cli" = copilotCli;
        default = gortex;
        forgecode = forgecode;
        gortex = gortex;
      };
    };
}
