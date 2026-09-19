{
  description = "My personal Nix Flake package collection";

  nixConfig = {
    extra-substituters = [
      "https://visoredkon.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "visoredkon.cachix.org-1:1Lxuvyp4PXtSm9TXxKrXjxmtdcxyoT6CaasoRAmHYRg="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
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
      mkProtonCachyos = pkgs.callPackage ./packages/mk-proton-cachyos.nix { };
      optimization = pkgs.callPackage ./packages/optimization.nix { };

      disabledPackages = [
        "kiro"
        "kiro-cli"
        "warp-terminal"
      ];

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
        "proton-cachyos-x86_64-v3" = rec {
          baseUrl = "https://github.com/CachyOS/proton-cachyos";
          urlTemplate = "${baseUrl}/releases/download/{version}/proton-{version}-x86_64_v3.tar.xz";
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

      activePackagesConfig = removeAttrs packagesConfig disabledPackages;

      goPackagesConfig = {
        "bootdev" = {
          repoOwner = "bootdotdev";
          repoName = "bootdev";
        };

        "pvetui" = {
          repoOwner = "devnullvoid";
          repoName = "pvetui";
        };

        "typescript" = {
          repoOwner = "microsoft";
          repoName = "TypeScript";
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
            inherit optimization;
          };
        }) goPackageNames
      );

      optimizedPlainNames = [
        "bat"
        "btop"
        "delta"
        "eza"
        "fastfetch"
        "fd"
        "fish"
        "grim"
        "kitty"
        "mako"
        "neovim-unwrapped"
        "rofi"
        "slurp"
        "starship"
        "swappy"
        "walker"
        "wayvnc"
        "wl-clipboard"
        "yazi"
        "zoxide"
      ];

      optimizedReleaseNames = [
        "elephant"
        "libfprint"
        "waybar"
      ];

      optimizedReleases = builtins.listToAttrs (
        map (name: {
          inherit name;
          value = import ./releases/${name}.nix;
        }) optimizedReleaseNames
      );

      obsPluginNames = [
        "obs-pipewire-audio-capture"
        "obs-vkcapture"
      ];

      obsPackages = pkgs.callPackage ./packages/obs-studio.nix { inherit optimization; };

      hyprPackages = pkgs.callPackage ./packages/hyprland-family.nix {
        inherit optimization;
        inherit (pkgs) libinput;
        inherit (optimizedPackages)
          grim
          slurp
          ;
      };

      optimizedPackages =
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = pkgs.callPackage ./packages/${name}.nix { inherit optimization; };
          }) optimizedPlainNames
        )
        // builtins.mapAttrs (
          name: release:
          pkgs.callPackage ./packages/${name}.nix {
            inherit optimization release;
          }
        ) optimizedReleases
        // {
          cliphist = pkgs.callPackage ./packages/cliphist.nix { };
          easyeffects = pkgs.callPackage ./packages/easyeffects.nix { inherit optimization; };
          espanso-wayland = pkgs.callPackage ./packages/espanso-wayland.nix {
            inherit (optimizedPackages) wl-clipboard;
          };
          fprintd = pkgs.callPackage ./packages/fprintd.nix {
            inherit optimization;
            inherit (optimizedPackages) libfprint;
          };
          hyprpolkitagent = pkgs.callPackage ./packages/hyprpolkitagent.nix {
            inherit (hyprPackages) hyprlang hyprutils;
          };
          inherit (hyprPackages)
            aquamarine
            hyprcursor
            hyprgraphics
            hypridle
            hyprland
            hyprlang
            hyprlock
            hyprpaper
            hyprtoolkit
            hyprutils
            hyprwire
            xdg-desktop-portal-hyprland
            ;
          inherit (obsPackages)
            obs-studio
            obs-pipewire-audio-capture
            obs-vkcapture
            ;
        };

      packageMetadata = builtins.mapAttrs (
        name: info:
        info
        // {
          release = import ./releases/${name}.nix;
        }
      ) activePackagesConfig;

      generatedPackages =
        (builtins.mapAttrs (
          name: meta:
          pkgs.callPackage ./packages/${name}.nix {
            inherit mkPrebuilt;
            inherit mkProtonCachyos;
            inherit (meta) release urlTemplate;
          }
        ) (removeAttrs packageMetadata goPackageNames))
        // goPackages;

      formatTargets = "apps/*.nix packages/*.nix releases/*.nix flake.nix";

      mkApp = program: {
        inherit program;
        type = "app";
      };

      branchSourcesConfig = {
        "elephant" = {
          owner = "abenz1267";
          repo = "elephant";
          branch = "dev";
        };

        "libfprint" = {
          owner = "visoredkon";
          repo = "libfprint-egis0576";
          branch = "master";
        };

        "waybar" = {
          owner = "Alexays";
          repo = "Waybar";
          branch = "master";
        };
      };

      updateRelease = pkgs.callPackage ./apps/update-release.nix {
        inherit packageMetadata;
        inherit goPackagesConfig;
        inherit branchSourcesConfig;
      };

    in
    {
      apps.${system} =
        (builtins.mapAttrs (name: meta: mkApp "${generatedPackages.${name}}/bin/${meta.binName}") (
          nixpkgs.lib.filterAttrs (_: meta: meta ? binName) packageMetadata
        ))
        // {
          "bootdev" = mkApp "${generatedPackages.bootdev}/bin/bootdev";
          "typescript" = mkApp "${generatedPackages.typescript}/bin/tsc";
          "update-release" = mkApp "${updateRelease}/bin/update-release";
        };

      checks.${system} =
        (builtins.mapAttrs (
          name: meta:
          if meta ? binName then
            pkgs.runCommand "check-${name}" {
              buildInputs = [ generatedPackages.${name} ];
            } "touch $out"
          else
            pkgs.runCommand "check-${name}" { } ''
              test -e ${generatedPackages.${name}}
              test -e ${generatedPackages.${name}.steamcompattool}
              touch $out
            ''
        ) packageMetadata)
        // (builtins.mapAttrs (
          name: _:
          pkgs.runCommand "check-${name}" {
            buildInputs = [ goPackages.${name} ];
          } "touch $out"
        ) goPackages)
        // (builtins.mapAttrs (
          name: _:
          pkgs.runCommand "check-${name}" {
            buildInputs = [ optimizedPackages.${name} ];
          } "touch $out"
        ) optimizedPackages)
        // {
          embedded-lint =
            pkgs.runCommand "check-embedded-lint"
              {
                nativeBuildInputs = [
                  pkgs.basedpyright
                  pkgs.python3
                  pkgs.ruff
                  pkgs.shellcheck
                ];
                src = self;
              }
              ''
                work=$(mktemp -d)
                cp -r $src/. "$work/"
                chmod -R u+w "$work"
                cd "$work"
                export HOME=$(mktemp -d)
                export RUFF_CACHE_DIR=$(mktemp -d)
                cat > script.py <<'PYEOF'
                import pathlib
                import re
                import subprocess
                import sys
                import textwrap

                names: str = (
                    "installPhase|buildPhase|unpackPhase|postFixup|postInstall|"
                    "postPatchelf|extraInstallCommands|extraBuildCommands|text"
                )
                quote: str = "'" + "'"
                escaped_dollar: str = quote + "$"
                pattern: re.Pattern[str] = re.compile(
                    "(" + names + ")\\s*=\\s*" + quote + "(.*?)" + quote + ";",
                    re.DOTALL,
                )
                failures: list[str] = []
                extracted: int = 0


                def stub_nix_interpolations(body: str) -> str:
                    stubbed: str = ""
                    index: int = 0
                    while index < len(body):
                        start: int = body.find("''${", index)
                        if start < 0 or body[max(0, start - 2) : start] == "'" + "'":
                            stubbed += body[index:]
                            break
                        stubbed += body[index:start] + "NIX_INTERPOLATION"
                        depth: int = 1
                        cursor: int = start + 2
                        while cursor < len(body) and depth > 0:
                            if body[cursor] == "{":
                                depth += 1
                            elif body[cursor] == "}":
                                depth -= 1
                            cursor += 1
                        index = cursor
                    return stubbed


                def run_check(command: list[str], label: str, script_text: str) -> None:
                    result: subprocess.CompletedProcess[str] = subprocess.run(
                        command,
                        input=script_text,
                        capture_output=True,
                        check=False,
                        text=True,
                    )
                    if result.returncode != 0:
                        failures.append(f"{label}\n{result.stdout}{result.stderr}")


                nix_files: list[pathlib.Path] = sorted(pathlib.Path(".").rglob("*.nix"))
                for path in nix_files:
                    text: str = path.read_text()
                    matches: list[re.Match[str]] = list(pattern.finditer(text))
                    for match in matches:
                        raw: str = textwrap.dedent(match.group(2))
                        body: str = stub_nix_interpolations(raw)
                        body = body.replace(escaped_dollar, "$")
                        script: str = "#!/usr/bin/env bash\n" + body
                        extracted += 1
                        label: str = f"{path}:{match.group(1)}"
                        run_check(["bash", "-n"], label, script)
                        run_check(
                            [
                                "shellcheck",
                                "-S",
                                "warning",
                                "-e",
                                "SC2154,SC1083,SC1009,SC1073,SC1036,SC1072,SC1065",
                                "-",
                            ],
                            label,
                            script,
                        )
                if extracted == 0:
                    print("no embedded scripts extracted from nix files")
                    sys.exit(1)
                if failures:
                    print("\n".join(failures))
                    sys.exit(1)
                PYEOF
                ruff check script.py
                ruff format --check script.py
                basedpyright script.py
                python3 script.py
                touch $out
              '';
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
          yamllint =
            pkgs.runCommand "check-yamllint"
              {
                nativeBuildInputs = [ pkgs.yamllint ];
                src = self;
              }
              ''
                cd $src
                yamllint -d '{extends: relaxed, rules: {line-length: {max: 120}}}' .
                touch $out
              '';
        };

      formatter.${system} = pkgs.callPackage ./apps/formatter.nix { inherit formatTargets; };

      overlays.default =
        _: prev:
        builtins.intersectAttrs (activePackagesConfig // optimizedPackages) (
          self.packages.${prev.stdenv.hostPlatform.system} or { }
        )
        // nixpkgs.lib.genAttrs goPackageNames (
          name: self.packages.${prev.stdenv.hostPlatform.system}.${name}
        )
        // {
          obs-studio-plugins =
            prev.obs-studio-plugins
            // nixpkgs.lib.genAttrs obsPluginNames (
              name: self.packages.${prev.stdenv.hostPlatform.system}.${name}
            );
        };

      packages.${system} = generatedPackages // optimizedPackages;
    };
}
