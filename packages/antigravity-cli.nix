{
  pkgs,
  release,
  ...
}:

pkgs.stdenvNoCC.mkDerivation {
  pname = "antigravity-cli";
  inherit (release) version;
  src = pkgs.fetchurl {
    inherit (release) sha256 url;
  };

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    gcc-unwrapped.lib
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
