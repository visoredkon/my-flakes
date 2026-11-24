{
  pkgs,
  ...
}:

{
  pname,
  release,
  urlTemplate,
  installCommands,
  meta,
}:

let
  inherit (release) version;

  src = pkgs.fetchurl {
    inherit (release) sha256;
    url = builtins.replaceStrings [ "{version}" ] [ version ] urlTemplate;
  };

  appimageContents = pkgs.appimageTools.extract { inherit pname version src; };
in
pkgs.appimageTools.wrapType2 {
  inherit
    pname
    version
    src
    meta
    ;
  extraInstallCommands = installCommands appimageContents;
}
