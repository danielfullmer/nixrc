{ config, pkgs, lib, ... }:

let
  # Allow localhost, zerotier, and wireguard hosts
  denyInternet = ''
    allow 127.0.0.1;
    allow ::1;
    allow 30.0.0.0/24;
    allow 10.200.0.0/24;
    deny all;
  '';
in
{
  # Stuff for streaming cameras?
  # Currently unencrypted. Maybe fix in the future?
  # https://github.com/arut/nginx-rtmp-module/wiki/Directives#hls
  # TODO: Need to mkdir and chown in startup
  services.nginx.appendConfig = ''
    rtmp {
      server {
        listen 1935;
        chunk_size 4096;

        application live {
          live on;
          record off;
          hls on;
          hls_path /tmp/hls;
          hls_fragment 2s;
          hls_playlist_length 10s;
        }
      }
    }
  '';
  services.nginx.virtualHosts."daniel.fullmer.me" = {
    locations."/cameras".extraConfig = denyInternet;
    locations."/cameras/hls/" = {
      alias = "/tmp/hls/";
      extraConfig = ''
        types {
          application/vnd.apple.mpegurl m3u8;
          video/mp2t ts;
        }
        add_header Cache-Control no-cache;
      '';
    };
  };

  services.zoneminder = {
    enable = true;
    database = {
      createLocally = true;
      username = "zoneminder";
    };
    hostname = "zoneminder.daniel.fullmer.me";
  };
  services.nginx.virtualHosts."${config.services.zoneminder.hostname}" = {
    default = lib.mkForce false; # Override some defaults set in nixos module
    listen = [
      { addr = "0.0.0.0"; port = 80; ssl = false; }
      { addr = "0.0.0.0"; port = 443; ssl = true; }
    ];
    forceSSL = true;
    enableACME = true;
    extraConfig = denyInternet;
  };
}