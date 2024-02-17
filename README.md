# wedgeberry
Wedgeberry is an interactive script that converts a Raspberry Pi into a customizable Wifi access point with transparent proxying for TLS and other traffic inspection via [mitmproxy](https://mitmproxy.org/). 
Wedgeberry software differs from other similar software in that it supports flexiable traffic routing options such as VPN/tunneling, firewall enforcement. 

![wedge-diagram](/images/connectivity.png)

Currently the following is supported and can be setup via the interative menu: 

* WLAN AP parameters (SSID, BSSID, channel etc) 
* Mitmproxy as an inline transparent proxy for traffic inspection
* Routing WLAN traffic traffic via:
    * Direct
    * Wireguard VPN tunnel
    * TOR network (TCP+DNS) 
    * HTTP/S proxy (BurpSuite configured in transparent mode)

`wedge-config.sh` will handle all the required package installs, `iptables` rules, `ip route` rules and `systemd` services for persistance (including mitmproxy).

Mitmproxy's web interface is configured as a `systemd` service and will automatically start on reboot.

The script was motivated by the Raspberry Pi `raspi-config` tool which provides an accessible way to configure a Pi. 

![wedge-config](/images/wedgemenu.png)

# Installation

From a Raspberry Pi:
```
wget https://raw.githubusercontent.com/haxrob/wedgeberry/main/build/wedge-conf.sh
sudo ./wedge-config.sh
```

__Note__: `wedge-config.sh` is build by merging multiple bash scripts. Do not edit it directly. 

To build `wedge-config.sh` from this repository, run:
```
make
```
`wedge-config.sh` is emitted to the `./build` subdirectory.

Run with `-d` flag to write bash verbose output to logfile `wedge-debug.log` within the current working directory.

## Notes
- `mitmproxy` is installed to `/opt/mitmproxy` with `mitmweb` running as a service as `mitmproxy` user via (`/etc/systemd/system/mitmweb.servce`)
- DNS requests from `dnsmasq` are logged to `/root/wedge-dns.log`
- Internal configuration file is written to `/root/.config/wedge.conf`

# Compatibility

Two interfaces are required - All Pi models that support Wifi should work out of the box except the Pi W. Here an additional USB interface card is required to be connected.

It is recommended to use [latest Raspberry Pi images](https://www.raspberrypi.com/software/operating-systems/). This software has only been tested on the Rasperry Pi image `Debian GNU/Linux 12 (bookworm)`.

# Packages

The following packages are installed and/or managed by wedgeberry:
- dnsmasq 
- hostapd
- dhcpcd
- tor
- wireguard / wireguard-tools
- resolvconf 
- iptables
- pipx