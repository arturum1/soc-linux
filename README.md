<!--
SPDX-FileCopyrightText: 2025 IObundle

SPDX-License-Identifier: MIT
-->

# SoCLinux Project

[SoCLinux](https://nlnet.nl/project/SoCLinux/) is an open-source project that aims to configure and generate a Linux system for RISC-V processors, focusing on creating a robust and maintainable environment for designing and testing IP cores.
The project builds upon the existing open-source Py2HWSW framework powering the IOb-SoC platform, enhancing the functionality and portability of IP cores, by using as examples the key IOb-Cache, IOb-Eth, and IOb-UART16550 open-source cores.
By providing a Linux IP core testbed, SoCLinux enables developers to build and test Linux drivers for new IP cores quickly, accelerating the production of high-quality IP cores, open-source or otherwise. 
The project aims to establish a widely adopted and maintainable ecosystem for IP core development, benefiting the broader community of IP core providers and users.
SoCLinux will leverage the IP-XACT standard (IEEE 1685) for IP core packaging, and seamlessly exchange IP cores with FuseSoC, a well-known open-source IP core package manager.

## SoCLinux template

The SoCLinux template available in this repository is a derivative system of the [IOb-System-Linux](https://github.com/IObundle/py2hwsw/tree/main/py2hwsw/lib/iob_system/iob_system_linux) SoC located in the [Py2HWSW](https://github.com/IObundle/py2hwsw) framework's core library.

This repository serves as a template for creating Linux-compatible SoC designs, using the Py2HWSW framework.
For purely baremetal SoC designs, the [IOb-SoC](https://github.com/IObundle/iob-soc) template is recommended.

This template follows the same principles as the IOb-SoC template. It is recommended to read the [IOb-SoC documentation](https://github.com/IObundle/iob-soc/blob/main/README.md) to understand the design and usage of the template.

## Quick start

```Bash
# Clone the SoC-Linux repository:
git clone --recursive git@github.com:IObundle/soc-linux.git
cd soc-linux

# Start a Nix environment with dependencies installed (including latest Py2HWSW):
nix-shell

# Generate and run the `soc_linux` system in simulation with baremetal firmware:
make sim-run SIMULATOR=verilator

# Generate and run the `soc_linux` system in the AES-KU040-DB-G FPGA board with baremetal firmware:
# NOTE: FPGA design tools must be installed and FPGA board must be attached locally.
# Refer to: https://github.com/IObundle/iob-soc?tab=readme-ov-file#run-on-fpga-board
make fpga-build fpga-run BOARD=iob_aes_ku040_db_g

# Run the Linux OS on the FPGA board
make fpga-run BOARD=iob_aes_ku040_db_g RUN_LINUX=1
```

<!--
## Differences to IOb-SoC
This section outlines the distinctions between IOb-SoC and SoCLinux.

The bootloader in SoCLinux differs from that in IOb-SoC. In SoCLinux, the bootloader is directly loaded into internal RAM, whereas in IOb-SoC, the bootloader binary starts in ROM and is then copied to RAM.

The boot control unit in SoCLinux, unlike IOb-SoC, is a distinct module and exclusively manages the boot process state. On the software side, the SoCLinux bootloader initially loads a file named soc_linux_mem.config, which specifies the files and their respective memory addresses to be copied into external memory.

-->

## Ethernet

The SoCLinux template supports ethernet communication by default.
The bootloader and firmware provided use ethernet to speed up file transfers.

However, to setup the ethernet interfaces on the host machine, root privileges are required.
As an alternative, ethernet can be disabled by passing `USE_ETHERNET=0` to the make command.
This will cause SoCLinux to generate a system without ethernet support, and make all file transfers via serial communication.

## Ethernet simulation

The ethernet simulation requires dummy interfaces, named `eth-[SIMULATOR]`.

The SoCLinux template automatically creates Makefiles in the build directory to create these interfaces during the build process for simulation.
These interfaces require root privileges to be created, so the Makefile may request for sudo/root password during the build process for simulation.

Alternatively, to setup these dummy interfaces manually, run the following commands:
```bash
sudo modprobe dummy
sudo ip link add eth-icarus type dummy
sudo ifconfig eth-icarus up
sudo ip link add eth-verilator type dummy
sudo ifconfig eth-verilator up
```

#### Make dummy interfaces permanent:
1. Add `dummy` to `/etc/modules`
2. Create `/etc/network/if-pre-up.d/dummy-eth-interfaces` with:
```bash
#!/usr/bin/env bash

# Create eth-SIMULATOR dummy interfaces
ip link add eth-icarus type dummy
ifconfig eth-icarus up
ip link add eth-verilator type dummy
ifconfig eth-verilator up
```
3. Set script as executable:
```bash
# Set script as executable
sudo chmod +x /etc/network/if-pre-up.d/dummy-eth-interfaces
```

## Ethernet Receiver MAC Address
The current ethernet setup uses a fake receiver MAC address (RMAC_ADDR) common
for all simulators and boards. To receive ethernet packets for any destination
address, the interface connected to the board needs to be in premiscuous mode.
Check premiscuous mode with the command:
```bash
ip -d link
# check for promiscuity 1
```
Set promiscuity to 1 with the command:
```bash
sudo ip link set [interface] promisc on
```

## Ethernet RAW frame access
The system's Python scripts need RAW frame access for Ethernet communication.
To achieve this, the Python interpreter must have the CAP_NET_RAW capability.

The [iob-eth](https://github.com/IObundle/iob-eth/tree/master/scripts/pyRawWrapper) repository includes a wrapper for the Python binary that provides RAW frame access.
The iob-eth's scripts will copy this wrapper's Makefile and source files to the build directory under the folder `path/to/build/dir/scripts/pyRawWrapper/`.

The SoCLinux template will generate a Makefile in the build directory to automatically create the Python wrapper during the build process for simulation and FPGA.

Alternatively, to build the python wrapper manually, run:
```bash
make -C ../soc_linux_V*/scripts/pyRawWrapper
```

It is also possible to use a custom python wrapper located in a different path by setting the `IOB_CONSOLE_PYTHON_ENV` environment variable:
```bash
export IOB_CONSOLE_PYTHON_ENV=/path/to/custom/pyRawWrapper
```

## Common issues:

```bash
unable to set iab: Operation not permitted
```

This error usually appears when the pyRawWrapper does not have the linux 'CAP_NET_RAW' capability set.
Running the following command with root privileges will set the capability:
```bash
setcap cap_net_raw,cap_setpcap=p path/to/pyRawWrapperBinary
```

# Tutorial: Add New Device Driver
Checkout [this tutorial](document/device_driver_tutorial.md) for more details on
how to add a new device to be tested.

# Acknowledgement
This project is funded through [NGI Zero Core](https://nlnet.nl/core), a fund established by [NLnet](https://nlnet.nl) with financial support from the European Commission's [Next Generation Internet](https://ngi.eu) program. Learn more at the [NLnet project page](https://nlnet.nl/project/SoCLinux).

[<img src="https://nlnet.nl/logo/banner.png" alt="NLnet foundation logo" width="20%" />](https://nlnet.nl)
[<img src="https://nlnet.nl/image/logos/NGI0_tag.svg" alt="NGI Zero Logo" width="20%" />](https://nlnet.nl/core)
