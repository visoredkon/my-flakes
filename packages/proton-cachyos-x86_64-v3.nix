{
  mkProtonCachyos,
  release,
  urlTemplate,
  ...
}:

mkProtonCachyos {
  inherit release urlTemplate;
  variant = "x86_64-v3";
}
