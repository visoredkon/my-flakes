{
  lib,
  buildGoModule,
  pkgs,
  release,
  ...
}:

buildGoModule {
  pname = "bootdev";
  inherit (release) version;

  src = pkgs.fetchFromGitHub {
    owner = "bootdotdev";
    repo = "bootdev";
    rev = "v${release.version}";
    hash = release.sourceSha256;
  };

  inherit (release) vendorHash;

  ldflags = [
    "-s"
    "-w"
  ];

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
