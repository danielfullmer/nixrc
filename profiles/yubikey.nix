{ config, pkgs, lib, ... }:
{
  # udev rules
  services.udev.packages = with pkgs; [ libu2f-host yubikey-personalization ];

  # For smartcards
  services.pcscd.enable = true;

  # Use gpg-agent instead of system-wide ssh-agent
  programs.ssh.startAgent = false;
  programs.gnupg = {
    agent.enable = true;
    agent.enableSSHSupport = true;
    agent.enableExtraSocket = true;
    agent.enableBrowserSocket = true;
    dirmngr.enable = true;
  };

  # To use, append the output of pamu2fcfg to ~/.config/Yubico/u2f_keys
  security.pam.enableU2F = true;

  environment.systemPackages = (with pkgs; [
    yubico-piv-tool
    yubikey-personalization

    gnupg
    pass

    keybase
    kbfs
  ] ++ lib.optionals (config.services.xserver.enable) [
    yubioath-desktop
    yubikey-personalization-gui
    keybase-gui
  ]);

  #  services.xserver.desktopManager.extraSessionCommands = ''
  #    (yubioath-gui -t) &
  #    (keybase-gui) &
  #  '';

  systemd.services.gpg-key-import = {
    description = "Import gpg keys";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "danielrf";
      Group = "danielrf";
    };
    script = ''
      ${lib.getBin pkgs.gnupg}/bin/gpg --import ${./yubikey.asc} ${./offlinekey.asc}
      ${lib.getBin pkgs.gnupg}/bin/gpg --import-ownertrust << EOF
      FA0ED54AE0DBF4CDC4B4FEADD1481BC2EF6B0CB0:6:
      7242A6FEF237A429E981576F6EDF0AEEA2D9FA5D:6:
      EOF
    '';
    # TODO: Maybe create a udev rule to run "gpg --card-status" when yubikey plugged in first time
  };

  services.keybase.enable = true;
  services.kbfs.enable = true;
  services.kbfs.mountPoint = "/keybase";

  # TODO: See https://github.com/keybase/client/issues/3508
  # systemd.user.sockets.keybase = {
  #   description = "Keybase socket";
  #   after = [ "network.target" ];
  #   wantedBy = [ "sockets.target" ];
  #   socketConfig.ListenStream = "%t/keybase/keybased.sock";
  # };

  systemd.user.services.keybase = {
    after = [ "network.target" ];
    wantedBy = [ "default.target" ]; # TODO: Remove this when socket-activation works
  };

  systemd.user.services.kbfs = {
    after = [ "keybase.target" ];
    wantedBy = [ "default.target" ];
  };

  # TODO: Remove this hack when keybase becomes multi-user
  system.activationScripts.keybase = lib.stringAfter [ "users" "groups" ] ''
    # XXX: Can't just do [[ ! -d /keybase ]] since root can't even stat() this dir if mounted
    if ls -f / | grep -q keybase; then false;
    else
      mkdir /keybase
      chown danielrf:danielrf /keybase
    fi
  '';
}
