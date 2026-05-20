{
  pkgs,
  release,
  ...
}:

assert release ? sha256 && release.sha256 != "";
assert release ? url && release.url != "";
assert release ? version && release.version != "";

pkgs.stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit (release) version;
  src = pkgs.fetchurl {
    inherit (release) sha256 url;
  };

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    stdenv.cc.cc.lib
  ];
  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 antigravity "$out/bin/agy"

    runHook postInstall
  '';
}
