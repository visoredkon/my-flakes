{
  nix-cachyos-kernel,
  system,
  ...
}:

let
  cachyosKernels = nix-cachyos-kernel.legacyPackages.${system};
  linuxPackages = cachyosKernels.linuxPackages-cachyos-bore-lto-x86_64-v3;
  linux = cachyosKernels.linux-cachyos-bore-lto-x86_64-v3;

  exportedKernels = {
    linux-cachyos-bore-lto-x86_64-v3 = linux;
    linuxPackages-cachyos-bore-lto-x86_64-v3 = linuxPackages;
  };
in
{
  cachyosPackages = exportedKernels;
}
