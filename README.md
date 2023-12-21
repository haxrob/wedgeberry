# wedgeberry
Wedgeberry is an interactive script that assists in repurposing a Raspberry Pi into a customizable Wifi access point with transparent proxying for TLS and other traffic inspection via [mitmproxy](https://mitmproxy.org/). Wedgeberry's primary goal is to automate setup steps while offering configuration options that supports the security tester's privacy. VPN/tunneling, firewall enforcement and Wifi parameter randomization (BSSID, SSID) are optional features to support this goal. Wedgeberry is intended to replace the need to setup a segmented LAN for IoT / mobile testing. 

![wedge-diagram](/images/connectivity.png)

Currently the following can be configured via the `wedge-config` interactive menu:

- Wifi access point with DHCP 
- Mitmproxy as transparent proxy 
- Routing all outbound traffic via Wireguard VPN tunnel
- Forward TCP ports (and DNS) via the Tor network
- Forward TCP ports to external intproxy (BurpSuite) 

`wedge-config.sh` will handle all the required package installs, `iptables` rules, `ip route` rules and systemd services for persistance (including mitmproxy).

The script was motivated by the Raspberry Pi `raspi-config` tool which provides an accessible way to configure a Pi. 

![wedge-config](/images/wedge.png)

# Installation

From a Raspberry Pi:
```
wget https://raw.githubusercontent.com/haxrob/wedgeberry/main/build/wedge-conf.sh
sudo ./wedge-config.sh
```

Note, `wedge-config.sh` is 'build' by merging multiple bash scripts. Do not edit it directly. To build `wedge-config.sh` from this repository, run
```
make clean
make
```
`wedge-config.sh` is emitted to the `./build` directory.

Run with `-d` flag to write bash verbose output to logfile `wedge-debug.log` within the current working directory.

## Notes
- `mitmproxy` is installed to `/opt/mitmproxy` with `mitmweb` running as a service as `mitmproxy` user
- DNS requests from `dnsmasq` are logged to `/root/wedge-dns.log`
- Internal configuration file is written to `$HOME/.config/wedge.conf`
## Services

# Menu items

**Setup** - Peforms initial configuration (hostap, dhcp)
- **Automatic** - Installs with defaults (SSID, channel, wifi password, DHCP subnet)
- **Custom** - Custom Wifi network parameters

**Clients** - Lists Wifi stations connected that have a DHCP assigned address

**Connectivity** - Select outbound traffic path
- **Direct** - Default route out of selected interface
- **Wireguard** - Route via Wireguard interface. Can specify custom wireguard configuration or interactivly configure via menu options
- **TOR** - Forward specific TCP ports via Tor network
- **BurpSuite / External proxy** - Forward specific TCP ports to BurpSuite proxy running on external host
- **MITMProxy** - Forward specific portst o MITMProxy transparent proxy running on Pi

**Mitmproxy** - Manage mitmproxy 
- **Port forwarding** - Specify TCP ports to forward to mitmproxy
- **Disable forwarding** - Removes related iptables rules
- **Install** - Installs mitmproxy (via pipx) and adds a systemd service to start mitmweb
- **Uninstall** - Removes mitmproxy and service file

**Healthcheck** - Checks status of configuration and software services 

**Update** - Check and update script to latest version

**Uninstall** - Removes all iptables rules, routes, configurations and optionally uninstalls packages

# Compatibility

Two interfaces are required - All Pi models that support Wifi should work out of the box except the Pi W. Here an additional interface card is required to be connected.

It is recommended to use [latest Raspberry Pi images](https://www.raspberrypi.com/software/operating-systems/). This software has only been tested on the Rasperry Pi image `Debian GNU/Linux 12 (bookworm)`.

# Packages

The following packages are installed and/or managed:
- dnsmasq 
- hostapd
- dhcpcd
- tor
- wireguard / wireguard-tools
- resolvconf 
- iptables
- pipx