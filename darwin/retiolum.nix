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

    # Darwin-specific hosts file management with delimiters
    launchd.daemons."tinc.${netname}-hosts-update" =
      let
        updateHosts = pkgs.writeShellScript "update-hosts" ''
          # Retiolum hosts content
          if [ "${toString cfg.ipv4}" = "" ]; then
            hosts_content=$(cat ${../etc.hosts-v6only})
          else
            hosts_content=$(cat ${../etc.hosts})
          fi

          # Check if /private/etc/hosts exists
          if [ ! -f /private/etc/hosts ]; then
            echo "Error: /private/etc/hosts not found"
            exit 1
          fi

          # Create a temporary file in /private/etc/
          temp_file=$(mktemp /private/etc/hosts.XXXXXX)

          # Set proper permissions for the temp file
          chmod 644 "$temp_file"

          # Check if retiolum section exists
          if grep -q "^# BEGIN RETIOLUM HOSTS$" /private/etc/hosts; then
            # Update existing section
            awk '
              BEGIN { in_retiolum = 0 }
              /^# BEGIN RETIOLUM HOSTS$/ { in_retiolum = 1; next }
              /^# END RETIOLUM HOSTS$/ { in_retiolum = 0; next }
              !in_retiolum { print }
            ' /private/etc/hosts > "$temp_file"

            # Add the retiolum section
            echo "# BEGIN RETIOLUM HOSTS" >> "$temp_file"
            echo "$hosts_content" >> "$temp_file"
            echo "# END RETIOLUM HOSTS" >> "$temp_file"

            # Copy everything after the retiolum section
            awk '
              BEGIN { in_retiolum = 0; after_retiolum = 0 }
              /^# BEGIN RETIOLUM HOSTS$/ { in_retiolum = 1; next }
              /^# END RETIOLUM HOSTS$/ { in_retiolum = 0; after_retiolum = 1; next }
              after_retiolum && !in_retiolum { print }
            ' /private/etc/hosts >> "$temp_file"
          else
            # First time - append to existing hosts file
            cp /private/etc/hosts "$temp_file"
            echo "" >> "$temp_file"  # Ensure newline before our section
            echo "# BEGIN RETIOLUM HOSTS" >> "$temp_file"
            echo "$hosts_content" >> "$temp_file"
            echo "# END RETIOLUM HOSTS" >> "$temp_file"
          fi

          # Replace the hosts file (permissions already set on temp file)
          mv "$temp_file" /private/etc/hosts
        '';
      in
      {
        command = toString updateHosts;
        serviceConfig = {
          Label = "org.tinc-vpn.${netname}.hosts-update";
          RunAtLoad = true;
          StandardErrorPath = "/var/log/tinc.${netname}-hosts-update.log";
          StandardOutPath = "/var/log/tinc.${netname}-hosts-update.log";
        };
      };

    environment.systemPackages = [
      config.services.tinc.networks.${netname}.package
    ];

    # Darwin-specific implementation for installing host keys and tinc-up script
    launchd.daemons."tinc.${netname}-host-keys" =
      let
        tinc-up-script = pkgs.writeText "tinc-up" ''
          #!/bin/sh
          # Configure the interface
          ${optionalString (cfg.ipv4 != null) ''
            /sbin/ifconfig $INTERFACE inet ${cfg.ipv4} netmask 255.240.0.0
          ''}
          ${optionalString (cfg.ipv6 != null) ''
            /sbin/ifconfig $INTERFACE inet6 ${cfg.ipv6} prefixlen 16
          ''}

          # Set MTU
          /sbin/ifconfig $INTERFACE mtu 1377

          # Add route for retiolum IPv6 network (ignore error if already exists)
          /sbin/route -n add -inet6 42::/16 -interface $INTERFACE 2>/dev/null || true
        '';
        install-keys = pkgs.writeShellScript "install-keys" ''
          rm -rf /etc/tinc/${netname}/hosts.tmp
          mkdir -p /etc/tinc/${netname}/hosts.tmp
          cp -R ${hosts}/* /etc/tinc/${netname}/hosts.tmp
          chmod -R u+w /etc/tinc/${netname}/hosts.tmp

          rm -rf /etc/tinc/${netname}/hosts
          mv /etc/tinc/${netname}/hosts.tmp /etc/tinc/${netname}/hosts

          # Install tinc-up script
          cp ${tinc-up-script} /etc/tinc/${netname}/tinc-up
          chmod 755 /etc/tinc/${netname}/tinc-up
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

    warnings = lib.optional (cfg.ipv6 == null) ''
      `networking.retiolum.ipv6` is not set
    '';
  };
}
