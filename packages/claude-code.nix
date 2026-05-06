{
  autoPatchelfHook,
  bubblewrap,
  fetchurl,
  lib,
  makeWrapper,
  procps,
  release,
  ripgrep,
  socat,
  stdenvNoCC,
  urlTemplate,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "claude-code";
  version = release.version;

  src = fetchurl {
    sha256 = release.sha256;
    url = builtins.replaceStrings [ "{version}" ] [ finalAttrs.version ] urlTemplate;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  dontBuild = true;
  dontStrip = true;
  dontUnpack = true;
  strictDeps = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/claude"

    wrapProgram "$out/bin/claude" \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          procps
          ripgrep
          socat
        ]
      }

    runHook postInstall
  '';
})
