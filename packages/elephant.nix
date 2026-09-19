{
  lib,
  optimization,
  pkgs,
  release,
  ...
}:

assert release ? rev && release.rev != "";
assert release ? sourceSha256 && release.sourceSha256 != "";
assert release ? vendorHash && release.vendorHash != "";

optimization.withGoOptimizations {
  goBuilder = pkgs.buildGo127Module;
  pname = "elephant";
  version = builtins.substring 0 7 release.rev;
  inherit (release) vendorHash;

  src = pkgs.fetchFromGitHub {
    owner = "abenz1267";
    repo = "elephant";
    inherit (release) rev;
    hash = release.sourceSha256;
  };

  subPackages = [ "cmd/elephant" ];

  buildInputs = with pkgs; [
    protobuf
    wayland
  ];

  nativeBuildInputs = with pkgs; [
    makeWrapper
    protoc-gen-go
  ];

  postBuild = ''
    mkdir -p "$out/lib/elephant/providers"
    for dir in internal/providers/*/; do
      provider=$(basename "$dir")
      case " archlinuxpkgs aptpackages dnfpackages " in
        *" $provider "*) continue ;;
      esac
      go build -buildmode=plugin -ldflags "-s -w" -o "$out/lib/elephant/providers/$provider.so" ./internal/providers/"$provider" || exit 1
    done
  '';

  postFixup = ''
    wrapProgram "$out/bin/elephant" \
      --prefix PATH : ${
        lib.makeBinPath (
          with pkgs;
          [
            bluez
            fd
            imagemagick
            libqalculate
            wl-clipboard
          ]
        )
      }
  '';
}
