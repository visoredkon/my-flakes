{ lib, pkgs }:

{
  pname,
  release,
  urlTemplate,
  completions ? null,
  ...
}@args:

assert urlTemplate != "";

pkgs.stdenvNoCC.mkDerivation (
  (removeAttrs args [
    "pname"
    "release"
    "urlTemplate"
    "completions"
  ])
  // {
    inherit pname;
    inherit (release) version;
    src = pkgs.fetchurl {
      inherit (release) sha256;
      url = builtins.replaceStrings [ "{version}" ] [ release.version ] urlTemplate;
    };

    dontStrip = true;
    strictDeps = true;

    postFixup =
      lib.optionalString (completions != null) ''
        mkdir -p completions
        tar --extract --file "${completions.archive}" --directory completions \
          --strip-components=${toString completions.stripComponents} \
          "${completions.prefix}${completions.files.bash}" \
          "${completions.prefix}${completions.files.fish}" \
          "${completions.prefix}${completions.files.zsh}"
        installShellCompletion \
          --bash "completions/${completions.files.bash}" \
          --fish "completions/${completions.files.fish}" \
          --zsh "completions/${completions.files.zsh}"
      ''
      + (args.postFixup or "");
  }
)
