# wedgeberry
Wedgeberry is an interactive script that converts a Raspberry Pi into a customizable Wifi access point with transparent proxying for TLS and other traffic inspection via [mitmproxy](https://mitmproxy.org/). 
Wedgeberry software differs from other similar software in that it supports flexiable traffic routing options such as VPN/tunneling, firewall enforcement. 

![wedge-diagram](/images/connectivity.png)

# Installation

From a Raspberry Pi:
```
wget https://raw.githubusercontent.com/haxrob/wedgeberry/main/build/wedge-conf.sh
chmod u+x wedge-config.sh
sudo ./wedge-config.sh
```
![wedge-config](/images/wedgemenu.png)

**Note**: There is a known bug with the custom network parameter configuration menu settings causing hostapd to not start. Select 'automatic' for the time being.
# Features

Currently the following is supported and can be setup via the interative menu: 

* WLAN AP parameters (SSID, BSSID, channel, password, public etc.) 
* Mitmproxy as an inline transparent proxy on the Pi 
* Mitmweb as a system service
* Routing WLAN traffic traffic via:
    * Direct wired / wlan interface
    * Wireguard VPN tunnel
    * TOR network (TCP+DNS) 
    * HTTP/S proxy (BurpSuite configured in transparent mode)
* Log/monitoring support: 
    * connected clients (wifi stations, dhcp clients) 
    * DNS logs
    * Raw traffic capture

`wedge-config.sh` will handle all the required package installs, `iptables` rules, `ip route` rules and `systemd` services for persistance (including mitmproxy).

Mitmproxy's web interface is configured as a `systemd` service and will automatically start on reboot.

The script was motivated by the Raspberry Pi `raspi-config` tool which provides an accessible way to configure a Pi. 

# Building
`wedge-config.sh` is build by merging multiple bash scripts from `/src/*`. It is not recommended to edit the `wedge-config.sh` script directly. 
To build `wedge-config.sh` from this repository, run:
```
make
```
`wedge-config.sh` is emitted to the `./build` subdirectory.

Run with `-d` flag to write bash verbose output to logfile `wedge-debug.log` within the current working directory.

## Notes
- `mitmproxy` is installed to `/opt/mitmproxy` with `mitmweb` running as a service as `mitmproxy` user via (`mitmweb.servce`)
- DNS requests from `dnsmasq` are logged to `/root/wedge-dns.log`
- Internal configuration file is written to `/root/.config/wedge.conf`
- Selecting 'Update' from the menu will fetch the latest version

# Compatibility

Two interfaces are required - All Pi models that support Wifi should work out of the box except the Pi W. Here an additional USB interface card is required to be connected.

It is recommended to use [latest Raspberry Pi images](https://www.raspberrypi.com/software/operating-systems/). This software has only been tested on the Rasperry Pi image `Debian GNU/Linux 12 (bookworm)`.

# Packages

The following packages are installed and configured:
- dnsmasq 
- hostapd
- dhcpcd
- tor
- wireguard / wireguard-tools
- resolvconf 
- iptables
- pipx
