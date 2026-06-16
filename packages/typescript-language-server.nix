{
  mkPrebuilt,
  pkgs,
  release,
  urlTemplate,
  ...
}:

mkPrebuilt {
  pname = "typescript-language-server";
  inherit release urlTemplate;

  dontBuild = true;
  sourceRoot = "package";

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/typescript-language-server"
    cp -r lib package.json "$out/lib/node_modules/typescript-language-server"

    ln -s ${pkgs.typescript}/lib/node_modules/typescript "$out/lib/node_modules/typescript"

    makeWrapper "${pkgs.nodejs}/bin/node" "$out/bin/typescript-language-server" \
      --add-flags "$out/lib/node_modules/typescript-language-server/lib/cli.mjs"

    runHook postInstall
  '';
}
