{
  lib,
  makeWrapper,
  mkPrebuilt,
  nodejs,
  release,
  ripgrep,
  unzip,
  urlTemplate,
}:

mkPrebuilt {
  buildInputs = [
    nodejs
    ripgrep
  ];

  installPhase = ''
    runHook preInstall

    local bundleDir="$out/lib/gemini"

    mkdir -p "$bundleDir"
    cp -aT . "$bundleDir"

    makeWrapper "${lib.getExe nodejs}" "$out/bin/gemini" \
      --add-flags "--no-warnings=DEP0040" \
      --add-flags "$bundleDir/gemini.js"

    runHook postInstall
  '';

  nativeBuildInputs = [
    makeWrapper
    unzip
  ];

  patchPhase = ''
    runHook prePatch

    for chunk in ./chunk-*.js; do
      if grep -q 'enableAutoUpdate: {' "$chunk"; then
        sed -i '/enableAutoUpdate: {/,/}/ s/default: true/default: false/' "$chunk"
      fi

      if grep -q 'await resolveExistingRgPath();' "$chunk"; then
        substituteInPlace "$chunk" \
          --replace-fail 'const existingPath = await resolveExistingRgPath();' 'const existingPath = "${lib.getExe ripgrep}";'
      fi
    done

    runHook postPatch
  '';

  pname = "gemini-cli";
  inherit release;

  unpackPhase = ''
    unzip $src
  '';

  inherit urlTemplate;
}
