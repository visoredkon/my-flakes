{
  nix-cachyos-kernel,
  pkgs,
  system,
  ...
}:

let
  cachyosUpstream = nix-cachyos-kernel.legacyPackages.${system};

  tunedCachyosKernel = cachyosUpstream.linux-cachyos-latest-lto-x86_64-v3.override {
    cpusched = "bore";
    tickrate = "idle";
    hugepage = "madvise";
  };

  tunedCachyosLinuxPackages =
    let
      cachyosHelpers = pkgs.callPackage "${nix-cachyos-kernel}/helpers.nix" { };
    in
    cachyosHelpers.kernelModuleLLVMOverride (pkgs.linuxKernel.packagesFor tunedCachyosKernel);

  cachyosPackages = {
    linux-cachyos-latest-lto-x86_64-v3 = tunedCachyosKernel;
  };
in
{
  inherit cachyosPackages;

  cachyosKernels = {
    inherit (cachyosPackages) linux-cachyos-latest-lto-x86_64-v3;
    linuxPackages-cachyos-latest-lto-x86_64-v3 = tunedCachyosLinuxPackages;
  };
}
