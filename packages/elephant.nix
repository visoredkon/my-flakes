{
  lib,
  optimization,
  pkgs,
  release,
  ...
}:

assert release ? sourceSha256 && release.sourceSha256 != "";
assert release ? vendorHash && release.vendorHash != "";
assert release ? version && release.version != "";

let
  excludedProviders = [
    "archlinuxpkgs"
    "dnfpackages"
    "aptpackages"
  ];

  commonArgs = {
    src = pkgs.fetchFromGitHub {
      owner = "abenz1267";
      repo = "elephant";
      tag = "v${release.version}";
      hash = release.sourceSha256;
    };

    inherit (release) vendorHash version;
  };

  elephantBin = optimization.withGoOptimizations (
    commonArgs
    // {
      goBuilder = pkgs.buildGo125Module;
      pname = "elephant";

      subPackages = [ "cmd/elephant" ];

      buildInputs = [ pkgs.protobuf ];
      nativeBuildInputs = with pkgs; [
        makeWrapper
        protoc-gen-go
      ];

      postFixup = ''
        wrapProgram "$out/bin/elephant" \
          --prefix PATH : ${lib.makeBinPath [ pkgs.fd ]}
      '';
    }
  );

  elephantProviders = optimization.withGoOptimizations (
    commonArgs
    // {
      goBuilder = pkgs.buildGo125Module;
      pname = "elephant-providers";

      buildInputs = [ pkgs.wayland ];
      nativeBuildInputs = with pkgs; [
        protobuf
        protoc-gen-go
      ];

      buildPhase = ''
        runHook preBuild
        echo "Building elephant providers..."
        EXCLUDE_LIST="${lib.concatStringsSep " " excludedProviders}"
        is_excluded() {
          target="$1"
          for e in $EXCLUDE_LIST; do
            [ -z "$e" ] && continue
            if [ "$e" = "$target" ]; then
              return 0
            fi
          done
          return 1
        }
        if [ -d ./internal/providers ]; then
          for dir in ./internal/providers/*; do
            [ -d "$dir" ] || continue
            provider=$(basename "$dir")
            if is_excluded "$provider"; then
              echo "Skipping excluded provider: $provider"
              continue
            fi
            set -- "$dir"/*.go
            if [ -e "$1" ]; then
              echo "Building provider: $provider"
              if ! go build -buildmode=plugin -ldflags "-s -w" -o "$provider.so" ./internal/providers/"$provider"; then
                echo "Failed to build provider: $provider"
                exit 1
              fi
            else
              echo "Skipping $provider: no .go files found"
            fi
          done
        fi
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/lib/elephant/providers"
        for so_file in *.so; do
          if [[ -f "$so_file" ]]; then
            cp "$so_file" "$out/lib/elephant/providers/"
          fi
        done
        runHook postInstall
      '';
    }
  );
in
pkgs.runCommand "elephant-with-providers"
  {
    buildInputs = [ pkgs.makeWrapper ];
  }
  ''
    mkdir -p "$out/bin" "$out/lib/elephant"
    cp ${elephantBin}/bin/elephant "$out/bin/"
    cp -r ${elephantProviders}/lib/elephant/providers "$out/lib/elephant/"
    wrapProgram "$out/bin/elephant" \
      --prefix PATH : ${
        lib.makeBinPath (
          with pkgs;
          [
            bluez
            imagemagick
            libqalculate
            wl-clipboard
          ]
        )
      }
  ''
