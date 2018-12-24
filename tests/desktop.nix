import <nixpkgs/nixos/tests/make-test.nix> ({ pkgs, ...} : {
  name = "desktop";

  machine = { config, pkgs, ... }: {
    imports = [
      ../profiles/base.nix
      ../profiles/interactive.nix
      ../profiles/desktop/default.nix
      ../profiles/autologin.nix
    ];
    environment.systemPackages = with pkgs; [ awf termite ];
  };

  testScript =
    ''
      $machine->waitForX;
      $machine->waitForFile("/home/danielrf/.Xauthority");
      $machine->succeed("xauth merge ~danielrf/.Xauthority");
      $machine->waitForWindow(qr/i3bar/);
      $machine->sleep(5);
      $machine->screenshot("startup");

      $machine->succeed("su - danielrf -s /bin/sh -c 'DISPLAY=:0 termite -t Termite &'");
      $machine->waitForWindow(qr/Termite/);
      $machine->sleep(5);
      $machine->screenshot("terminal");
      $machine->succeed("su - danielrf -s /bin/sh -c 'kill `pgrep termite`'");

      $machine->succeed("su - danielrf -s /bin/sh -c 'DISPLAY=:0 termite -t Termite -e \"vim ${./desktop.nix}\" --hold &'");
      $machine->waitForWindow(qr/Termite/);
      $machine->sleep(5);
      $machine->screenshot("vim");
      $machine->succeed("su - danielrf -s /bin/sh -c 'kill `pgrep termite`'");

      $machine->succeed("su - danielrf -s /bin/sh -c 'DISPLAY=:0 awf-gtk2 &'");
      $machine->waitForWindow(qr/A widget factory.*Gtk2/);
      $machine->sleep(5);
      $machine->screenshot("gtk2widgets");
      $machine->succeed("su - danielrf -s /bin/sh -c 'kill `pgrep awf-gtk`'");

      $machine->succeed("su - danielrf -s /bin/sh -c 'DISPLAY=:0 awf-gtk3 &'");
      $machine->waitForWindow(qr/A widget factory.*Gtk3/);
      $machine->sleep(5);
      $machine->screenshot("gtk3widgets");
      $machine->succeed("su - danielrf -s /bin/sh -c 'kill `pgrep awf-gtk`'");
    '';
})
