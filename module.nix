{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.eden;
in
{
  options.programs.eden = {
    enable = lib.mkEnableOption "Eden Nintendo Switch Emulator";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.eden;
      defaultText = lib.literalExpression "pkgs.eden";
      description = "The Eden package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    # udev rules for controller (gamepad) hotplug access.
    services.udev.packages = [ cfg.package ];
  };
}
