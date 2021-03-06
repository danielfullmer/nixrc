# yubikey.nix: Inteded for hosts I could potentially insert the yubikey into.

{ config, pkgs, lib, ... }:
let
  u2f_key = "danielrf:-lTPHVrWKR1eizhqEq4U5cVF2ozG4o9T6jT1dFvmR1ERuz-lVc6UkOZc1mztVIfZxVuLlDDE2VOb4KJg2wihgg,04b2601eac5bdb1dea7882c10393e0e79c814c4bda2a2b5cb63395173f8c91af0c86e32a39d13c07fa61013985c0b4c81cec08bf72f2e9d456708a08fd4efec141";
  u2f_file = pkgs.writeText "u2f_mapping" u2f_key;
in
{
  services.udev.packages = with pkgs; [ yubikey-personalization ];

  # For smartcards
  services.pcscd.enable = true;

  # Use gpg-agent instead of system-wide ssh-agent
  programs.ssh.startAgent = false;
  programs.ssh.askPassword = "${pkgs.x11_ssh_askpass}/libexec/x11-ssh-askpass";
  programs.gnupg = {
    agent.enable = true;
    agent.enableSSHSupport = true;
    agent.enableExtraSocket = true;
    agent.enableBrowserSocket = true;
    dirmngr.enable = true;
  };

  # Central authorization mapping config from: https://developers.yubico.com/pam-u2f/
  # For single-user: append the output of pamu2fcfg to ~/.config/Yubico/u2f_keys
  security.pam.u2f = {
    enable = true;
    # XXX: Hack to allow me to pass in another parameter to pam module. I should just add origin support in nixpkgs.
    authFile = "${u2f_file} origin=pam://controlnet";
    cue = true;
  };
  security.pam.services."sshd".u2fAuth = false;
  security.pam.services."sudo".u2fAuth = false;

  environment.systemPackages = with pkgs; [
    yubico-piv-tool
    yubikey-personalization

    gnupg
    pass
    #(pass.withExtensions (p: with p; [ pass-audit])) # 2020-06-18: broken in nixpkgs
  ] ++ lib.optionals (config.services.xserver.enable) [
    yubioath-desktop
    yubikey-personalization-gui
  ];

  systemd.services.gpg-key-import = {
    description = "Import gpg keys";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "danielrf";
      Group = "danielrf";
    };
    script = ''
      ${lib.getBin pkgs.gnupg}/bin/gpg --import ${../keys/users/danielfullmer-yubikey.asc} ${../keys/users/danielfullmer-offlinekey.asc}
      ${lib.getBin pkgs.gnupg}/bin/gpg --import-ownertrust << EOF
      FA0ED54AE0DBF4CDC4B4FEADD1481BC2EF6B0CB0:6:
      7242A6FEF237A429E981576F6EDF0AEEA2D9FA5D:6:
      EOF
    '';
    # TODO: Maybe create a udev rule to run "gpg --card-status" when yubikey plugged in first time
  };
}
