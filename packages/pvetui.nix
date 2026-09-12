{
  optimization,
  pkgs,
  release,
  ...
}:

assert release ? rev && release.rev != "";
assert release ? sourceSha256 && release.sourceSha256 != "";
assert release ? vendorHash && release.vendorHash != "";
assert release ? version && release.version != "";

optimization.withGoOptimizations {
  goBuilder = pkgs.buildGo126Module;
  pname = "pvetui";
  inherit (release) vendorHash version;

  src = pkgs.fetchFromGitHub {
    owner = "devnullvoid";
    repo = "pvetui";
    inherit (release) rev;
    hash = release.sourceSha256;
  };

  subPackages = [ "cmd/pvetui" ];

  ldflags = [
    "-X github.com/devnullvoid/pvetui/internal/version.version=${release.rev}"
    "-X github.com/devnullvoid/pvetui/internal/version.commit=${release.rev}"
  ];

  meta.mainProgram = "pvetui";
}
