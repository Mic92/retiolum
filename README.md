# **Retiolum tinc keys and hosts**

## NixOS usage

If you are a flake user:

```nix
{
  inputs = {
    retiolum.url = "git+https://git.thalheim.io/Mic92/retiolum";
  };
  outputs = { retiolum, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        retiolum.nixosModules.retiolum
        # To add the retiolum ssl certificate:
        # retiolum.nixosModules.ca
        {
          # Configure retiolum
          networking.retiolum = {
            nodename = "myhost";       # Optional, defaults to hostname
            ipv4 = "10.243.29.123";   # Your assigned IPv4 (optional)
            ipv6 = "42:0:3c46:...";   # Your assigned IPv6 (or auto-generated)
            port = 655;               # Optional, defaults to 655
          };
        }
      ];
    };
  };
}
```

## Darwin (macOS) usage

For nix-darwin users:

```nix
{
  inputs = {
    retiolum.url = "git+https://git.thalheim.io/Mic92/retiolum";
    darwin.url = "github:LnL7/nix-darwin";
  };
  outputs = { retiolum, darwin, ... }: {
    darwinConfigurations.mymac = darwin.lib.darwinSystem {
      modules = [
        # Import both modules
        retiolum.darwinModules.tinc
        retiolum.darwinModules.retiolum
        {
          # Configure retiolum
          networking.retiolum = {
            nodename = "mymac";       # Optional, defaults to hostname
            ipv4 = "10.243.29.124";   # Your assigned IPv4 (optional)
            ipv6 = "42:0:3c46:...";   # Your assigned IPv6 (or auto-generated)
            port = 655;               # Optional, defaults to 655
          };
        }
      ];
    };
  };
}
```

## Features

The NixOS and Darwin modules will automatically:
- Install and configure tinc
- Set up the retiolum network interface
- Install host keys from the repository
- Configure /etc/hosts with all retiolum hosts
- Generate keys on first start if needed
- Set up systemd services (NixOS) or launchd daemons (Darwin)

First add your key to https://github.com/krebs/stockholm
Mic92's stockholm fork will than update this repository itself.


## VPN Setup
1. Install **tinc** (e.g. Ubuntu : `sudo apt install tinc`, MacOS: `brew install tinc --devel`)

2. Create the appropriate directory and perform the initial tinc startup 
```
    $ sudo mkdir /etc/tinc/retiolum
    $ sudo tincd -K -n retiolum
    $ sudo systemctl enable --now tinc@retiolum
```

3. Provide the key generated in the previous step along with **{your_name}** (unique name for the machine) to @Mic92.
   You will get your respective IP addresses in return.

4. Create the tinc-up executable in the **/etc/tinc/retiolum** folder
```
    $ echo '#!/usr/bin/env bash
    curl https://retiolum.thalheim.io/tinc-hosts.tar.bz2 | tar -xjvf - -C /etc/tinc/retiolum/ || true
    ip link set $INTERFACE up
    ip addr add "Provided_IPv4_from_Step_3"/12 dev $INTERFACE
    ip addr add "Provided_IPv6_from_Step_3"/16 dev $INTERFACE' > /etc/tinc/retiolum/tinc-up

    $ chmod +x /etc/tinc/retiolum/tinc-up
```

5. Create (if it does not exist) the tinc configuration file
```
    $ echo 'DeviceType = tun
    Interface = tinc.retiolum
    Name = {your_name_from_Step_3}
    LocalDiscovery = yes
    ConnectTo = gum
    ConnectTo = ni
    ConnectTo = prism
    ConnectTo = eve
    ConnectTo = eva
    AutoConnect = yes' > /etc/tinc/retiolum/tinc.conf
```

6. Restart the vpn service
```
    $ systemctl restart tinc@retiolum
```
You should retrieve hosts' information after the restart.
The hosts folder should appear in /etc/tinc/retiolum
The list of the hosts is also available here : https://retiolum.thalheim.io/etc.hosts

## Testing

Test configurations are included in the flake:
```bash
# Test NixOS configuration
nix build .#nixosConfigurations.example.config.system.build.toplevel

# Test Darwin configuration
nix build .#darwinConfigurations.example.system
```
