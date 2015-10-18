{ config, pkgs, lib, ... }:
{
  services.udev.extraRules = ''
    # From https://github.com/Yubico/libu2f-host/blob/master/70-u2f.rules
    ACTION!="add|change", GOTO="u2f_end"

    # Yubico YubiKey
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", ATTRS{idProduct}=="0113|0114|0115|0116|0120|0402|0403|0406|0407|0410", TAG+="uaccess"

    LABEL="u2f_end"
  '';

  # For smartcards
  services.pcscd.enable = true;

  environment.systemPackages = (with pkgs; [
    yubico-piv-tool
    yubikey-personalization
  ]);
}
