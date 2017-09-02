{ config, pkgs, lib, ... }:
{
  environment.systemPackages = (with pkgs; [
    nox
    nix-index

    emacs
    pandoc
    bitlbee
    weechat
    mutt
    taskwarrior
  ]);

  programs.fish = {
    enable = true;
    interactiveShellInit =
      let shellThemeScript = pkgs.writeScript "shellTheme"
        (import (../modules/theme/templates + "/shell.${config.theme.brightness}.nix") { colors=config.theme.colors; });
      in
      ''
        eval sh ${shellThemeScript}
      '';
  };

  # Use the channel set with nix-channel. Should automatically get the latest
  # tested nixpkgs and nixos-configuration from hydra
  system.autoUpgrade.enable = true;
}