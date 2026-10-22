{
  optimization,
  pkgs,
  release,
  ...
}:

optimization.withGoOptimizations {
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
