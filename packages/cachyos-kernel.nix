{
  nix-cachyos-kernel,
  pkgs,
  system,
  ...
}:

let
  cachyosUpstream = nix-cachyos-kernel.legacyPackages.${system};

  off = pkgs.lib.mkForce (pkgs.lib.kernel.option pkgs.lib.kernel.no);

  disabledKernelOptions = [
    "AMD_IOMMU"
    "DEBUG_INFO_BTF_MODULES"
    "DRM_AMDGPU"
    "DRM_NOUVEAU"
    "DRM_RADEON"
    "FB_NVIDIA"
    "FB_RIVA"
    "INFINIBAND"
    "KVM_AMD"
    "MEDIA_ANALOG_TV_SUPPORT"
    "MEDIA_DIGITAL_TV_SUPPORT"
    "MEDIA_RADIO_SUPPORT"
    "NET_VENDOR_AQUANTIA"
    "NET_VENDOR_BROCADE"
    "NET_VENDOR_CAVIUM"
    "NET_VENDOR_CHELSIO"
    "NET_VENDOR_EMULEX"
    "NET_VENDOR_MARVELL"
    "NET_VENDOR_MELLANOX"
    "NET_VENDOR_QLOGIC"
    "SCSI_CHELSIO_FCOE"
    "SCSI_CXGB3_ISCSI"
    "SCSI_CXGB4_ISCSI"
    "STAGING"
    "WLAN_VENDOR_ADMTEK"
    "WLAN_VENDOR_ATH"
    "WLAN_VENDOR_ATMEL"
    "WLAN_VENDOR_BROADCOM"
    "WLAN_VENDOR_INTERSIL"
    "WLAN_VENDOR_MARVELL"
    "WLAN_VENDOR_MEDIATEK"
    "WLAN_VENDOR_MICROCHIP"
    "WLAN_VENDOR_PURELIFI"
    "WLAN_VENDOR_QUANTENNA"
    "WLAN_VENDOR_RALINK"
    "WLAN_VENDOR_REALTEK"
    "WLAN_VENDOR_RSI"
    "WLAN_VENDOR_SILABS"
    "WLAN_VENDOR_ST"
    "WLAN_VENDOR_TI"
    "WLAN_VENDOR_ZYDAS"
  ];

  tunedCachyosKernel = cachyosUpstream.linux-cachyos-latest-lto-x86_64-v3.override {
    cpusched = "bore";
    tickrate = "idle";
    hugepage = "madvise";
    structuredExtraConfig = pkgs.lib.genAttrs disabledKernelOptions (_: off);
  };

  tunedCachyosLinuxPackages =
    let
      cachyosHelpers = pkgs.callPackage "${nix-cachyos-kernel}/helpers.nix" { };
    in
    cachyosHelpers.kernelModuleLLVMOverride (pkgs.linuxKernel.packagesFor tunedCachyosKernel);

  cachyosPackages = {
    linux_cachyos_latest_lto_x86_64_v3 = tunedCachyosKernel;
    linuxPackages_cachyos_latest_lto_x86_64_v3 = tunedCachyosLinuxPackages;
  };
in
{
  inherit cachyosPackages disabledKernelOptions;
}
