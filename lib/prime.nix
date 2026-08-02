{ lib }:
let
  env = {
    __NV_PRIME_RENDER_OFFLOAD = "1";
    __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
  };
in
{
  inherit env;
  exports = lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=${v}") env);
  wrapperArgs = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "--set ${k} ${v}") env);
}
