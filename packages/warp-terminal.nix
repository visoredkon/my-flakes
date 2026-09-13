{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "warp-terminal";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = ".";

  buildInputs = with pkgs; [
    alsa-lib
    curl
    fontconfig
    stdenv.cc.cc
    xz
    zlib
  ];

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
    makeWrapper
    zstd
  ];

  runtimeDependencies = with pkgs; [
    libglvnd
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    stdenv.cc.libc
    vulkan-loader
    wayland
    xdg-utils
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -r opt usr/* "$out"

    substituteInPlace "$out/bin/warp-terminal" \
      --replace-fail '#!/bin/bash' '#!${pkgs.bash}/bin/bash' \
      --replace-fail /opt/ "$out/opt/"

    runHook postInstall
  '';

  postFixup = ''
    patchelf \
      --add-needed libfontconfig.so.1 \
      "$out/opt/warpdotdev/warp-terminal/warp"
  '';
}
