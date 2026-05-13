{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
}:

mkPrebuilt {
  pname = "claude-code";
  inherit release urlTemplate;

  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/claude"

    wrapProgram "$out/bin/claude" \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set USE_BUILTIN_RIPGREP 0 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --prefix PATH : ${
        pkgs.lib.makeBinPath (
          with pkgs;
          [
            bubblewrap
            procps
            ripgrep
            socat
          ]
        )
      }

    runHook postInstall
  '';

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
  ];
}
