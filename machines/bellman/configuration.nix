{ config, lib, pkgs, ... }:

{
  imports = [
    ../../profiles/base.nix
    ../../profiles/dns.nix
    ../../profiles/interactive.nix
    ../../profiles/extended.nix
    ../../profiles/oled.nix
    ../../profiles/zerotier.nix
    ../../profiles/kdeconnect.nix
    ../../profiles/yubikey.nix
    ../../profiles/syncthing.nix
    ../../profiles/desktop/default.nix
    ../../profiles/monitors-calibrate.nix
    ../../profiles/gaming.nix
    ../../profiles/academic.nix
    ../../profiles/postfix.nix
    ../../profiles/gdrive.nix
    ../../profiles/wireguard.nix
    ../../profiles/tor.nix
    ../../profiles/cuttlefish.nix
    ../../profiles/nextcloud.nix
    #../../profiles/backup.nix
    #../../xrdesktop-overlay
    #../../profiles/cameras.nix
    ../../profiles/fdm-printer.nix
    ../../profiles/rtlsdr.nix

    ./ap.nix
    ./vfio.nix
    ../../profiles/pxe-server.nix
  ];

  networking.hostName = "bellman"; # Define your hostname.
  networking.hostId = "f6bb12be";

  #networking.wireless.enable = true;
  #networking.networkmanager.enable = true;
  #networking.interfaces.enp68s0.useDHCP = true;

  networking.useDHCP = false;
  networking.interfaces.enp68s0.ipv4.addresses = [ { address = "192.168.1.200"; prefixLength = 24; } ];
  networking.defaultGateway = "192.168.1.1";

  networking.vlans.netboot = {
    id = 3;
    interface = "enp68s0";
  };


  services.acpid.enable = true;

  services.redshift.enable = true;

  # For serial interface to reflash x39 monitor firmware
  services.udev.packages = lib.singleton (pkgs.writeTextFile {
    name = "uart-udev-rules";
    destination = "/etc/udev/rules.d/51-uart-custom.rules";
    text = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{product}=="FT232R USB UART", TAG+="uaccess", SYMLINK+="arduino"
    '';
  });

  # For flashing android stuff
  programs.adb.enable = true;
  users.users.danielrf.extraGroups = [ "adbusers" ];

  services.nginx.enable = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.virtualHosts."daniel.fullmer.me" = {
    default = true;
    public = true;
    root = "/data/webroot";
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.hydra = {
    enable = true;
    listenHost = "localhost";
    port = 5001;
    hydraURL = "https://hydra.daniel.fullmer.me/";
    notificationSender = "cgibreak@gmail.com";
    smtpHost = "${config.networking.hostName}";
    useSubstitutes = true;
    #buildMachinesFiles = [ ../profiles/hydra-remote-machines ];
    # This is a deprecated option, but it's still used by NARInfo.pm
    extraConfig = "binary_cache_secret_key_file = ${config.sops.secrets.nix-key.path}";

    # Patch to allow builtins.fetchTarball
    package = pkgs.hydra-unstable.overrideAttrs (attrs: { patches = (if attrs ? patches then attrs.patches else []) ++ [ ../../pkgs/hydra/no-restrict-eval.patch ]; });
  };
  services.nginx.virtualHosts."hydra.daniel.fullmer.me" = {
    locations."/".proxyPass = "http://127.0.0.1:5001/";
  };

  boot.binfmt.emulatedSystems = [ "armv6l-linux" "armv7l-linux" "aarch64-linux" ];

    # TOOD: Parameterize
    # Used by hydra even if nix.distributedBuilds is false
  nix.buildMachines = [
    { hostName = "localhost";
      #sshUser = "nix";
      #sshKey = "/none";
      systems = [ "x86_64-linux" "i686-linux" "aarch64-linux" "armv7l-linux" ];
      maxJobs = 4;
      supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "benchmark" ];
    }
#    { hostName = "banach";
#      #sshUser = "nix";
#      #sshKey = "/none";
#      system = "aarch64-linux";
#      maxJobs = 2;
#      supportedFeatures = [ ];
#    }
  ];
#  nix.distributedBuilds = true;

  # Remote hosts often have better connection to cache than direct to this host
  nix.extraOptions = ''
    builders-use-substitutes = true
    secret-key-files = ${config.sops.secrets.nix-key.path}
    experimental-features = nix-command flakes
  '';
  sops.secrets.nix-key = {};

  nix.package = pkgs.nixFlakes;

  environment.systemPackages = with pkgs; [
    #bcachefs-tools
    keyboard-firmware
    signal-desktop
  ];

  #system.autoUpgrade.enable = true;

  #nix.package = import /home/danielrf/NixDroid/misc/nix.nix { inherit pkgs; };

  #virtualisation.anbox.enable = true;

  #services.playmaker.enable = true; # Port 5000 (customize in future)
  services.playmaker.device = "walleye"; # This is currently the only device in playmaker/googleplay-api device.properties file that is actually android 9 / API 28
  # Port 5000 has no access control--anyone who can connect can add/remove packages.
  # We'll rely on firewall to ensure only zerotier network can access port 5000,
  # and additionally pass through the fdroid repo it generates via nginx.
#  services.nginx.virtualHosts."playmaker.daniel.fullmer.me" = {
#    locations."/".proxyPass = "http://127.0.0.1:5000/";
#  };
#  services.nginx.virtualHosts."fdroid.daniel.fullmer.me" = {
#    locations."/".proxyPass = "http://127.0.0.1:5000/fdroid/"; # Fdroid client isn't working over SSL for some reason
#  };

  services.attestation-server = {
    enable = true;
    domain = "attestation.daniel.fullmer.me";

    # TODO: Extract from robotnix configuration
    device = "crosshatch";
    signatureFingerprint = "30E3A2C19024A208DF0D4FE0633AE3663B22AD4868F446B1AC36D526CA8E95FA";
    avbFingerprint = "F7B29168803BA73C31641D2770C2A84D4FF68C157F0B8BFE0BDC1958D4310491";

    email = {
      username = "cgibreak@gmail.com";
      passwordFile = config.sops.secrets.attestation-server-email-password.path;
      host = "smtp.gmail.com";
      port = 465;
    };

    disableAccountCreation = true;
    nginx.enableACME = true;
  };
  sops.secrets.attestation-server-email-password = {};

  # For testing xrdesktop
#  services.xserver.desktopManager.gnome3.enable = true;
#  services.xserver.desktopManager.plasma5.enable = true;

  programs.ccache.enable = true;
  programs.firejail.enable = true;

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.extraConfig = ''
    # Needed for virtio-fs
    memory_backing_dir = "/dev/shm/"
  '';


#  services.mosquitto = {
#    enable = true;
#    # Not enabling SSL--so be sure to only access it over zerotier/wireguard
#    host = "0.0.0.0";
#    checkPasswords = true;
#    users.pixel3xl.hashedPassword = "";
#  };

  #services.jellyfin.enable = true;
  #services.netdata.enable = true; # Monitoring stuff

#  virtualisation.docker.enable = true;
#  xdg.portal.enable = true;
#  services.flatpak.enable = true;
  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
    #abrmd.enable = true;
  };

#  services.fwupd.enable = true;

#  boot.loader.systemd-boot.counters = {
#    enable = true;
#    tries = 2;
#  };

  #services.grocy = {
  #  enable = true;
  #  hostName = "grocy.daniel.fullmer.me";
  #};
  #services.nginx.virtualHosts."${config.services.grocy.hostName}".public = true;

  # services.tvheadend.enable = true;
  # hardware.firmware = [ pkgs.openelec-dvb-firmware ];

  services.nginx.statusPage = true; # for nginx exporter

  services.grafana.enable = true;
  services.prometheus = {
    enable = true;
    retentionTime = "365d";
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [ { targets = [ "localhost:9100" ]; } ];
      }
#      {
#        job_name = "systemd";
#        static_configs = [ { targets = [ "localhost:9558" ]; } ];
#      }
      {
        job_name = "apcupsd";
        static_configs = [ { targets = [ "localhost:${builtins.toString config.services.prometheus.exporters.apcupsd.port}" ]; } ];
      }
    ];
    exporters = {
      node = {
        enable = true;
        enabledCollectors = [
          "logind"
          "wifi"
          #"perf"
        ];
        extraFlags = [
          "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files"
        ];
      };
      dnsmasq.enable = true;
      nginx.enable = true;
      #tor.enable = true;
      wireguard.enable = true;
      apcupsd.enable = true;
    };
  };

#  systemd.services.systemd-exporter = {
#    wantedBy = [ "multi-user.target" ];
#    serviceConfig.ExecStart = "${pkgs.systemd-exporter}/bin/systemd_exporter --web.listen-address=127.0.0.1:9558 --collector.enable-ip-accounting";
#  };

  systemd.tmpfiles.rules = [ "d /var/lib/prometheus-node-exporter-text-files 1755 root root 10d" ];

  system.activationScripts.node-exporter-system-version = ''
    (
      mkdir -p /var/lib/prometheus-node-exporter-text-files
      cd /var/lib/prometheus-node-exporter-text-files
      (
        echo -n "system_version ";
        readlink /nix/var/nix/profiles/system | cut -d- -f2
      ) > system-version.prom.next
      mv system-version.prom.next system-version.prom
    )
  '';

  systemd.services.prometheus-smartmon = let
    scripts = pkgs.fetchFromGitHub {
      owner = "prometheus-community";
      repo = "node-exporter-textfile-collector-scripts";
      rev = "57d05ce7ab752ec6795b452b1b660b736a32dcd5"; # 2020-08-04
      sha256 = "05pvi9kh35a2ixdm8i5bnkq992srd8b9ysb4cbxi684hl74q2444";
    };
  in {
    script = "${pkgs.python3}/bin/python ${scripts}/smartmon.py > /var/lib/prometheus-node-exporter-text-files/smartmon.prom";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ smartmontools ];
  };

  systemd.timers.prometheus-smartmon = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "prometheus-smartmon.service";
      OnCalendar = "*:0/5"; # Every 5 minutes
    };
  };

  systemd.services.prometheus-nvme = let
    scripts = pkgs.stdenv.mkDerivation {
      name = "node-exporter-textfile-collector-scripts";
      src = pkgs.fetchFromGitHub {
        owner = "prometheus-community";
        repo = "node-exporter-textfile-collector-scripts";
        rev = "57d05ce7ab752ec6795b452b1b660b736a32dcd5"; # 2020-08-04
        sha256 = "05pvi9kh35a2ixdm8i5bnkq992srd8b9ysb4cbxi684hl74q2444";
      };
      buildInputs = [ pkgs.python3 ];
      installPhase = "mkdir -p $out/bin; cp * $out/bin/";
    };
  in {
    script = "${scripts}/bin/nvme_metrics.sh > /var/lib/prometheus-node-exporter-text-files/nvme.prom";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ nvme-cli gawk jq ];
  };

  systemd.timers.prometheus-nvme = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "prometheus-nvme.service";
      OnCalendar = "*:0/5"; # Every 5 minutes
    };
  };

  #boot.kernelParams = [ "systemd.unified_cgroup_hierarchy=1" ];
  systemd.enableCgroupAccounting = true;

}
