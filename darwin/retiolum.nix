{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  netname = "retiolum";
  cfg = config.networking.retiolum;
  hosts = ../hosts;
  genipv6 = import ../modules/retiolum/genipv6.nix { inherit lib; };
in
{
  options = {
    networking.retiolum.ipv4 = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        own ipv4 address
      '';
    };
    networking.retiolum.ipv6 = mkOption {
      type = types.str;
      default =
        (genipv6 "retiolum" "external" {
          hostName = cfg.nodename;
        }).address;
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
    networking.retiolum.port = mkOption {
      type = types.int;
      default = 655;
      description = ''
        port tinc is listen
      '';
    };
  };

  config = {
    services.tinc.networks.${netname} = {
      name = cfg.nodename;
      extraConfig = ''
        Port = ${toString cfg.port}
        LocalDiscovery = yes

        ConnectTo = eva
        ConnectTo = eve
        ConnectTo = ni
        ConnectTo = prism
        AutoConnect = yes
      '';
    };

    environment.etc."hosts".text =
      if (cfg.ipv4 == null) then
        builtins.readFile ../etc.hosts-v6only
      else
        builtins.readFile ../etc.hosts;

    environment.systemPackages = [
      config.services.tinc.networks.${netname}.package
    ];

    # Darwin-specific implementation for installing host keys
    launchd.daemons."tinc.${netname}-host-keys" =
      let
        install-keys = pkgs.writeShellScript "install-keys" ''
          rm -rf /etc/tinc/${netname}/hosts.tmp
          mkdir -p /etc/tinc/${netname}/hosts.tmp
          cp -R ${hosts}/* /etc/tinc/${netname}/hosts.tmp
          chmod -R u+w /etc/tinc/${netname}/hosts.tmp

          rm -rf /etc/tinc/${netname}/hosts
          mv /etc/tinc/${netname}/hosts.tmp /etc/tinc/${netname}/hosts
        '';
      in
      {
        command = toString install-keys;
        serviceConfig = {
          Label = "org.tinc-vpn.${netname}.host-keys";
          RunAtLoad = true;
          StandardErrorPath = "/var/log/tinc.${netname}-host-keys.log";
          StandardOutPath = "/var/log/tinc.${netname}-host-keys.log";
        };
      };

    # Darwin doesn't have systemd-networkd, so we need to configure the network interface differently
    # This will need to be done via launchd and ifconfig
    launchd.daemons."tinc.${netname}-network" = 
      let
        tincConf = config.services.tinc.networks.${netname};
        # Get the Device from tinc configuration
        interface = tincConf.settings.Device;
      in
      {
        command = toString (
          pkgs.writeShellScript "tinc-network-setup" ''
            # Wait for the tinc interface to come up
            while ! ifconfig ${interface} >/dev/null 2>&1; do
              sleep 1
            done

            # Configure the interface
            ${optionalString (cfg.ipv4 != null) ''
              ifconfig ${interface} inet ${cfg.ipv4} netmask 255.240.0.0
            ''}
            ${optionalString (cfg.ipv6 != null) ''
              ifconfig ${interface} inet6 ${cfg.ipv6} prefixlen 16
            ''}

            # Set MTU
            ifconfig ${interface} mtu 1377
          ''
        );

      serviceConfig = {
        Label = "org.tinc-vpn.${netname}.network";
        RunAtLoad = true;
        KeepAlive = false;
        StandardErrorPath = "/var/log/tinc.${netname}-network.log";
        StandardOutPath = "/var/log/tinc.${netname}-network.log";
      };
    };

    warnings = lib.optional (cfg.ipv6 == null) ''
      `networking.retiolum.ipv6` is not set
    '';
  };
}
