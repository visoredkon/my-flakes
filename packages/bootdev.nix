{
  lib,
  buildGoModule,
  pkgs,
  release,
  ...
}:

(buildGoModule.override { stdenv = pkgs.llvmPackages.stdenv; }) {
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
    pkgs.mold
    pkgs.writableTmpDirAsHomeHook
  ];

  env = {
    GOAMD64 = "v3";
    GOFLAGS = "-trimpath";
    NIX_CFLAGS_LINK = "-fuse-ld=mold";
  };

  postInstall = lib.optionalString (pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform) ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd bootdev --"$shell" <($out/bin/bootdev completion "$shell")
    done
  '';
}
