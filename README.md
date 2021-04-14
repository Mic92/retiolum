# **Retiolum tinc keys and hosts**

## Contents
1. [VPN Setup](#VPN-Setup)
2. [SSH Setup](#SSH-Setup)

## VPN Setup
1. Install **tinc** (e.g. Ubuntu : sudo apt install tinc)

2. Create the appropriate directory and perform the initial tinc startup 
```
    $ sudo mkdir /etc/tinc/retiolum
    $ sudo tincd -K -n retiolum
    $ sudo systemctl enable --now tinc@retiolum
```

3. Provide the key generated in the previous step along with **{your_name}** to @Mic92 .
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

## SSH Setup
1. Generate an ssh key-pair or provide an already existing public ssh key to one of the authorised users.
2. One of the authorised users should add/modify the user's information in **/modules/users.nix** (https://github.com/Mic92/doctor-cluster-config)
3. Push the change to the repository
4. Log in to **rose**, pull the update(s) (if it's not done in the machine itelf)
5. Get in **/etc/nixos/** directory and run the script **./update-all.sh**
```
    $ cd /etc/nixos
    $ ./update-all.sh
```
