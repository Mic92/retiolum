{ config, pkgs, lib, ... }:

with lib;

let
  netname = "retiolum";
  cfg = config.networking.retiolum;

in {
  options = {
    networking.retiolum.ipv4 = mkOption {
      type = types.str;
      description = ''
        own ipv4 address
      '';
    };
    networking.retiolum.ipv6 = mkOption {
      type = types.str;
      description = ''
        own ipv6 address
      '';
    };
    networking.retiolum.nodename = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = ''
        tinc network name
      '';
    };
  };

  config = {
    services.tinc.networks.${netname} = {
      name = cfg.nodename;
      extraConfig = ''
        LocalDiscovery = yes

        ConnectTo = gum
        ConnectTo = ni
        ConnectTo = prism
        ConnectTo = eve
        AutoConnect = yes
      '';
    };

    networking.extraHosts = builtins.readFile ../../etc.hosts;

    environment.systemPackages = [ config.services.tinc.networks.${netname}.package ];

    systemd.services."tinc.${netname}".preStart = ''
      rm -rf /etc/tinc/${netname}/hosts
      cp -R ${../../hosts} /etc/tinc/${netname}/hosts
    '';

    networking.firewall.allowedTCPPorts = [ 655 ];
    networking.firewall.allowedUDPPorts = [ 655 ];

    systemd.network.enable = true;
    systemd.network.networks."${netname}".extraConfig = ''
      [Match]
      Name = tinc.${netname}

      [Network]
      Address=${cfg.ipv4}/12
      Address=${cfg.ipv6}/16
    '';
  };
}
