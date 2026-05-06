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

      codebaseMemoryMcp = pkgs.callPackage ./packages/codebase-memory-mcp.nix {
        inherit (packageMetadata."codebase-memory-mcp") release urlTemplate;
      };

      copilotCli = pkgs.callPackage ./packages/copilot-cli.nix {
        inherit (packageMetadata."copilot-cli") release urlTemplate;
      };

      forgecode = pkgs.callPackage ./packages/forgecode.nix {
        inherit (packageMetadata.forgecode) release urlTemplate;
      };

      formatTargets = "apps/*.nix packages/*.nix releases/*/release.nix flake.nix";

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

        "codebase-memory-mcp" = rec {
          baseUrl = "https://github.com/DeusData/codebase-memory-mcp/releases/download";
          release = import ./releases/codebase-memory-mcp/release.nix;
          urlTemplate = "${baseUrl}/v{version}/codebase-memory-mcp-ui-linux-amd64.tar.gz";
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
      };

      pkgs = import nixpkgs { inherit system; };
      system = "x86_64-linux";
      updateRelease = pkgs.callPackage ./apps/update-release.nix { inherit packageMetadata; };
    in
    {
      apps.${system} = {
        "claude-code" = mkApp "${claudeCode}/bin/claude";
        "codebase-memory-mcp" = mkApp "${codebaseMemoryMcp}/bin/codebase-memory-mcp";
        "copilot-cli" = mkApp "${copilotCli}/bin/copilot";
        forgecode = mkApp "${forgecode}/bin/forgecode";
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
          "codebase-memory-mcp" = packagesForSystem."codebase-memory-mcp";
          "copilot-cli" = packagesForSystem."copilot-cli";
          forgecode = packagesForSystem.forgecode;
        };

      packages.${system} = {
        "claude-code" = claudeCode;
        "codebase-memory-mcp" = codebaseMemoryMcp;
        "copilot-cli" = copilotCli;
        forgecode = forgecode;
      };
    };
}
