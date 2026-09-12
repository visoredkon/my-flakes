{
  lib,
  optimization,
  pkgs,
  release,
  ...
}:

optimization.withGoOptimizations {
  pname = "bootdev";
  inherit (release) vendorHash version;

  src = pkgs.fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${release.version}";
    hash = release.sourceSha256;
  };

  subPackages = [ "." ];

  nativeBuildInputs = [
    pkgs.installShellFiles
    pkgs.writableTmpDirAsHomeHook
  ];

  postInstall = lib.optionalString (pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform) ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd bootdev --"$shell" <($out/bin/bootdev completion "$shell")
    done
  '';
}
