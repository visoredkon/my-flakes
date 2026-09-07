{
  lib,
  pkgs,
}:
{
  release,
  urlTemplate,
  variant ? null,
}:
let
  packageName = "proton-cachyos${lib.optionalString (variant != null) "-${variant}"}";
  displayName = "Proton CachyOS${lib.optionalString (variant != null) " ${variant}"}";
in
pkgs.stdenvNoCC.mkDerivation {
  pname = packageName;
  version = lib.removePrefix "cachyos-" release.version;

  src = pkgs.fetchurl {
    inherit (release) sha256;
    url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
  };

  nativeBuildInputs = [
    pkgs.libarchive
    pkgs.xz
  ];

  unpackPhase = ''
    runHook preUnpack
    bsdtar -xf $src
    runHook postUnpack
  '';

  outputs = [
    "out"
    "steamcompattool"
  ];

  installPhase = ''
    runHook preInstall

    echo "${packageName} is a Steam compatibility tool. Use programs.steam.extraCompatPackages instead." > "$out"

    mkdir -p "$steamcompattool"

    srcRoot=$(find . -maxdepth 2 -name "compatibilitytool.vdf" -type f -printf "%h" | head -n1)
    if [ -z "$srcRoot" ]; then
      srcRoot="."
    fi

    cp -rL "$srcRoot"/. "$steamcompattool/"
    rm -f "$steamcompattool/compatibilitytool.vdf"
    cp "$srcRoot/compatibilitytool.vdf" "$steamcompattool/compatibilitytool.vdf"

    sed -i -r "s|\"display_name\".*|\"display_name\" \"${displayName}\"|" \
      "$steamcompattool/compatibilitytool.vdf"
    sed -i -r 's|"proton-cachyos-[^"]*"(\s*// Internal name)|"${displayName}"\1|' \
      "$steamcompattool/compatibilitytool.vdf"

    runHook postInstall
  '';

  meta = {
    description = ''
      ${displayName} compatibility tool for Steam Play and umu-launcher based on Proton
      with experimental features and third-party tools.

      (This is intended for use in the `programs.steam.extraCompatPackages` option only.)
    '';
    homepage = "https://github.com/CachyOS/proton-cachyos";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
