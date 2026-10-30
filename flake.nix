{
  description = "My personal Nix Flake package collection";

  nixConfig = {
    extra-substituters = [
      "https://cache.lantian.pub/lantian"
      "https://visoredkon.cachix.org"
      "https://cache.nixos.org"
    ];
    extra-trusted-public-keys = [
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
      "visoredkon.cachix.org-1:1Lxuvyp4PXtSm9TXxKrXjxmtdcxyoT6CaasoRAmHYRg="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
    };
  };

  outputs =
    {
      nixpkgs,
      nix-cachyos-kernel,
      self,
    }:
    let
      system = "x86_64-linux";
      inherit (nixpkgs) lib;

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "antigravity"
            "antigravity-cli"
            "kiro"
            "warp-terminal"
            "zcode"
          ];
      };

      mkPrebuilt = pkgs.callPackage ./packages/mk-prebuilt.nix { };
      mkProtonCachyos = pkgs.callPackage ./packages/mk-proton-cachyos.nix { };
      optimization = pkgs.callPackage ./packages/optimization.nix { };

      disabledPackages = [
        "antigravity-cli"
        "antigravity"
        "claude-code"
        "bootdev"
        "codebase-memory-mcp"
        "copilot-cli"
        "kiro"
        "kiro-cli"
        "libfprint"
        "warp-terminal"
      ];

      enabledNames = names: builtins.filter (name: !(builtins.elem name disabledPackages)) names;

      packagesConfig = {
        "antigravity" = {
          baseUrl = "https://antigravity-auto-updater-974169037036.us-central1.run.app";
          binName = "antigravity";
          needsVscodeVersion = true;
          releaseFields = [
            "sha256"
            "url"
            "version"
            "vscodeVersion"
          ];
          urlTemplate = "";
        };
        "antigravity-cli" = {
          baseUrl = "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app";
          binName = "agy";
          releaseFields = [
            "sha256"
            "url"
            "version"
          ];
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
          needsVscodeVersion = true;
          releaseFields = [
            "sha256"
            "version"
            "vscodeVersion"
          ];
          urlTemplate = "${baseUrl}/releases/stable/linux-x64/signed/{version}/tar/kiro-ide-{version}-stable-linux-x64.tar.gz";
          vscodeProductPath = "Kiro/resources/app/product.json";
        };
        "kiro-cli" = rec {
          baseUrl = "https://prod.download.cli.kiro.dev/stable";
          binName = "kiro-cli";
          urlTemplate = "${baseUrl}/{version}/kirocli-x86_64-linux.zip";
        };
        "mise" = rec {
          baseUrl = "https://github.com/jdx/mise/releases/download";
          binName = "mise";
          releaseFields = [
            "sha256"
            "sourceSha256"
            "version"
          ];
          urlTemplate = "${baseUrl}/v{version}/mise-v{version}-linux-x64.tar.gz";
        };
        "ntn" = rec {
          baseUrl = "https://ntn.dev";
          binName = "ntn";
          urlTemplate = "${baseUrl}/releases/v{version}/ntn-x86_64-unknown-linux-musl.tar.gz";
        };
        "openchamber-desktop" = rec {
          baseUrl = "https://github.com/openchamber/openchamber/releases/download";
          binName = "openchamber-desktop";
          urlTemplate = "${baseUrl}/v{version}/OpenChamber-{version}-linux-x86_64.AppImage";
        };
        "opencode" = rec {
          baseUrl = "https://registry.npmjs.org/@opencode/cli-linux-x64";
          binName = "opencode";
          npmTag = "latest";
          urlTemplate = "${baseUrl}/-/cli-linux-x64-{version}.tgz";
        };
        "proton-cachyos-x86_64-v3" = rec {
          baseUrl = "https://github.com/CachyOS/proton-cachyos";
          urlTemplate = "${baseUrl}/releases/download/{version}/proton-{version}-x86_64_v3.tar.xz";
        };
        "strata" = rec {
          baseUrl = "https://github.com/lgse/strata/releases/download";
          binName = "strata";
          urlTemplate = "${baseUrl}/v{version}/strata-{version}-x86_64-unknown-linux-gnu.tar.gz";
        };
        "tinymist" = rec {
          baseUrl = "https://github.com/Myriad-Dreamin/tinymist/releases/download";
          binName = "tinymist";
          releaseFields = [
            "completionsSha256"
            "sha256"
            "version"
          ];
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
        "zcode" = rec {
          baseUrl = "https://cdn-zcode.z.ai/zcode/electron/releases";
          binName = "zcode";
          urlTemplate = "${baseUrl}/{version}/linux-x64/ZCode-{version}-linux-x64.AppImage";
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

      activeGoPackagesConfig = removeAttrs goPackagesConfig disabledPackages;

      goPackageNames = builtins.attrNames activeGoPackagesConfig;

      loadRelease = name: import ./releases/${name}.nix;

      loadReleases =
        names:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value = loadRelease name;
          }) names
        );

      goPackageReleases = loadReleases goPackageNames;

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
        "cliphist"
        "delta"
        "easyeffects"
        "eza"
        "fastfetch"
        "fd"
        "fish"
        "grim"
        "kitty"
        "mako"
        "neovim-unwrapped"
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

      optimizedReleases = loadReleases optimizedReleaseNames;

      obsPluginNames = [
        "obs-pipewire-audio-capture"
        "obs-vkcapture"
      ];

      obsPackages = pkgs.callPackage ./packages/obs-studio.nix { inherit optimization; };

      hyprPackages = pkgs.callPackage ./packages/hyprland-family.nix {
        inherit optimization;
        inherit (pkgs) libinput;
        inherit (optimizedPackagesAll)
          grim
          slurp
          ;
      };

      optimizedPackagesAll =
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
          espanso-wayland = pkgs.callPackage ./packages/espanso-wayland.nix {
            inherit optimization;
            inherit (optimizedPackagesAll) wl-clipboard;
          };
          fprintd = pkgs.callPackage ./packages/fprintd.nix {
            inherit optimization;
            inherit (optimizedPackagesAll) libfprint;
          };
          rofi = pkgs.callPackage ./packages/rofi.nix { inherit optimization; };
          inherit (hyprPackages)
            aquamarine
            hyprcursor
            hyprgraphics
            hypridle
            hyprland
            hyprlang
            hyprlock
            hyprpaper
            hyprpolkitagent
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

      optimizedPackages = removeAttrs optimizedPackagesAll disabledPackages;

      packageMetadata = builtins.mapAttrs (
        name: info:
        info
        // {
          release = loadRelease name;
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
        ) packageMetadata)
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

      activeBranchSourcesConfig = removeAttrs branchSourcesConfig disabledPackages;

      updateRelease = pkgs.callPackage ./apps/update-release.nix {
        inherit packageMetadata;
        goPackagesConfig = activeGoPackagesConfig;
        branchSourcesConfig = activeBranchSourcesConfig;
      };

      cachyos = pkgs.callPackage ./packages/cachyos-kernel.nix {
        inherit nix-cachyos-kernel system;
      };

      inherit (cachyos) cachyosPackages;

    in
    {
      apps.${system} = removeAttrs (
        (builtins.mapAttrs (name: meta: mkApp "${generatedPackages.${name}}/bin/${meta.binName}") (
          lib.filterAttrs (_: meta: meta ? binName) packageMetadata
        ))
        // {
          "bootdev" = mkApp "${generatedPackages.bootdev}/bin/bootdev";
          "typescript" = mkApp "${generatedPackages.typescript}/bin/tsc";
          "update-release" = mkApp "${updateRelease}/bin/update-release";
        }
      ) disabledPackages;

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
                nativeBuildInputs = [
                  pkgs.deadnix
                  pkgs.statix
                ];
                src = self;
              }
              ''
                cd $src
                statix check .
                deadnix --fail .
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
          linux_cachyos_bore_lto_x86_64_v3 = pkgs.runCommand "check-linux-cachyos-bore-lto-x86_64-v3" {
            buildInputs = [ cachyosPackages.linux-cachyos-bore-lto-x86_64-v3 ];
          } "touch $out";
          linux_cachyos_bore_lto_x86_64_v3_config =
            pkgs.runCommand "check-linux-cachyos-bore-lto-x86_64-v3-config"
              {
                config = cachyosPackages.linux-cachyos-bore-lto-x86_64-v3.configfile;
              }
              ''
                grep -q '^CONFIG_SCHED_BORE=y' "$config"
                grep -q '^CONFIG_X86_64_VERSION=3' "$config"
                grep -q '^CONFIG_LTO_CLANG_THIN=y' "$config"
                touch $out
              '';
        };

      formatter.${system} = pkgs.callPackage ./apps/formatter.nix { inherit formatTargets; };

      overlays.default =
        _: prev:
        builtins.intersectAttrs (activePackagesConfig // optimizedPackages) (
          self.packages.${prev.stdenv.hostPlatform.system} or { }
        )
        // lib.genAttrs goPackageNames (name: self.packages.${prev.stdenv.hostPlatform.system}.${name})
        // {
          cachyosKernels = cachyosPackages;
          obs-studio-plugins =
            prev.obs-studio-plugins
            // lib.genAttrs (enabledNames obsPluginNames) (
              name: self.packages.${prev.stdenv.hostPlatform.system}.${name}
            );
          python314Packages = prev.python314Packages // {
            pyrate-limiter = prev.python314Packages.pyrate-limiter.overrideAttrs (_: {
              doCheck = false;
            });
          };
          aggregateModules =
            modules:
            (prev.aggregateModules modules).overrideAttrs (old: {
              postBuild =
                let
                  upstreamCertMerge = lib.concatStringsSep "\n" [
                    "cp --no-preserve=mode,ownership --remove-destination \\"
                    "      -- \"$(readlink -f modules.cer)\" modules.cer"
                    "    sed \"1,$(wc -l < modules.order)d; s/\\.ko.*/.ko.cer/\" modules.dep \\"
                    "        | xargs -d'\\n' cat >> modules.cer"
                  ];
                  conditionalCertMerge = lib.concatStringsSep "\n" [
                    "if test -e \"$(readlink -f modules.cer 2>/dev/null)\"; then"
                    "  cp --no-preserve=mode,ownership --remove-destination \\"
                    "    -- \"$(readlink -f modules.cer)\" modules.cer"
                    "  sed \"1,$(wc -l < modules.order)d; s/\\.ko.*/.ko.cer/\" modules.dep \\"
                    "      | while IFS= read -r cer; do test -f \"$cer\" && cat \"$cer\" >> modules.cer || true; done"
                    "fi"
                  ];
                  patchedPostBuild =
                    builtins.replaceStrings [ upstreamCertMerge ] [ conditionalCertMerge ]
                      old.postBuild;
                in
                if patchedPostBuild == old.postBuild then
                  throw "aggregateModules cert-merge block not found; update or remove this workaround (xddxdd/nix-cachyos-kernel#111)"
                else
                  patchedPostBuild;
            });
        };

      packages.${system} = removeAttrs (
        generatedPackages
        // optimizedPackages
        // {
          inherit (cachyosPackages) linux-cachyos-bore-lto-x86_64-v3;
        }
      ) disabledPackages;

      legacyPackages.${system} = cachyosPackages;
    };
}
