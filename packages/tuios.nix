{
  optimization,
  pkgs,
  release,
  ...
}:

optimization.withGoOptimizations {
  goBuilder = pkgs.buildGoModule;

  pname = "tuios";
  inherit (release) vendorHash;

  version = pkgs.lib.substring 0 7 release.rev;

  src = pkgs.fetchFromGitHub {
    owner = "Gaurav-Gosain";
    repo = "tuios";
    inherit (release) rev;
    hash = release.sourceSha256;
  };

  subPackages = [
    "cmd/tuios"
    "cmd/tuios-web"
  ];

  env = {
    GOTOOLCHAIN = "local";
  };

  postPatch = ''
    go work edit -dropuse=./e2e/tui
  '';

  modBuildPhase = ''
    runHook preBuild
    go work vendor
    runHook postBuild
  '';

  ldflags = [
    "-X main.version=dev-${pkgs.lib.substring 0 7 release.rev}"
    "-X main.builtBy=nix"
  ];

  nativeCheckInputs = [ pkgs.git ];

  meta.mainProgram = "tuios";
}
