# wedgeberry
Wedgeberry is a single script that provides an interactive menu to configure a Raspberry Pi into a Wifi transparent proxy to support traffic inspection and tampering.

Currently the following can be configured via the `wedge-config` interactive menu:

- Wifi access point with DHCP 
- Mitmproxy as transparent proxy 
- Routing all outbound traffic via Wireguard VPN tunnel
- Forward TCP ports (and DNS) via the Tor network
- Forward TCP ports to external interception proxy (BurpSuite) 

The script was motivated by the Raspberry Pi `raspi-config` tool which provides an accessible way to configure a Pi. Here we provide an easy and quick way to configure a Pi into a Wifi access point that supports various traffic forwarding options along with common tooling for IoT / mobile device security research / testing.

![wedge-config](wedge.png)

# Installation

From a Raspberry Pi:
```
wget https://github.com/haxrob/wedgeberry/..
sudo ./wedge-config.sh
```

Note, to build `wedge-config.sh` from this repository, run `make` to generate `./wedge-config.sh`

Run with `-d` flag to write bash verbose output to logfile

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

**Tools** - Install, configure or run useful toolls
- **MITMProxy** - Installs MITM proxy as a systemd service
- **Termshark** - Install or run termshark.io (cli based wireshark clone)

**Healthcheck** - Checks status of configuration and software services 
**Update** - Check and update script to latest version
**Uninstall** - Reverts configurations applied and optionally uninstalls packages
