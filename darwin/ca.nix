{
  config,
  lib,
  ...
}:
let
  cfg = config.retiolum.ca;
in
{
  options.retiolum.ca = {
    rootCA = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = builtins.readFile ../modules/ca/root-ca.crt;
      defaultText = "root-ca.crt";
    };
    intermediateCA = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = builtins.readFile ../modules/ca/intermediate-ca.crt;
      defaultText = "intermediate-ca.crt";
    };
    acmeURL = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "https://ca.r/acme/acme/directory";
      description = ''
        security.acme.certs.$name.server = config.retiolum.ca.acmeURL;
      '';
    };
    trustRoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        whether to trust the krebs root CA.
        This implies that krebs can forge a certificate for every domain
      '';
    };
    trustIntermediate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        whether to trust the krebs ACME CA.
        this only trusts the intermediate cert for .w and .r domains
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.trustRoot {
      security.pki.certificates = [ cfg.rootCA ];
    })
    (lib.mkIf cfg.trustIntermediate {
      security.pki.certificates = [ cfg.intermediateCA ];
    })
    # Firefox on macOS: Add certificates to system keychain and enable enterprise roots
    # This approach is proven to work and survives Firefox updates
    (lib.mkIf (cfg.trustRoot || cfg.trustIntermediate) {
      # Add certificates to macOS system keychain and configure Firefox
      system.activationScripts.firefoxCertPolicy.text = ''
        echo "Installing CA certificates..."

        # Write temporary certificate files
        TEMP_DIR=$(mktemp -d)

        ${lib.optionalString cfg.trustRoot ''
          cat > "$TEMP_DIR/krebs-root-ca.crt" <<'EOF'
          ${cfg.rootCA}
          EOF
          # Add to system keychain as trusted root
          security add-trusted-cert -d -r trustRoot -k "/Library/Keychains/System.keychain" "$TEMP_DIR/krebs-root-ca.crt" || true
        ''}

        ${lib.optionalString cfg.trustIntermediate ''
          cat > "$TEMP_DIR/krebs-intermediate-ca.crt" <<'EOF'
          ${cfg.intermediateCA}
          EOF
          # Add to system keychain
          security add-trusted-cert -d -r trustAsRoot -k "/Library/Keychains/System.keychain" "$TEMP_DIR/krebs-intermediate-ca.crt" || true
        ''}

        # Clean up temporary files
        rm -rf "$TEMP_DIR"

        # Configure Firefox to use system certificates
        # Must use sudo for system-wide preferences in /Library/Preferences
        echo "Configuring Firefox enterprise policies..."
        sudo defaults write /Library/Preferences/org.mozilla.firefox EnterprisePoliciesEnabled -bool TRUE
        sudo defaults write /Library/Preferences/org.mozilla.firefox Certificates__ImportEnterpriseRoots -bool TRUE
      '';
    })
  ];
}
