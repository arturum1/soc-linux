# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: GPL-3.0-only

# SoC-Linux specific makefile segment (level 2 child - child of iob_system_linux)

# Pass CACHE_DEMO flag to remote systems
UFLAGS+=CACHE_DEMO=$(CACHE_DEMO)

ifeq ($(CACHE_DEMO),1)
# Override default linux minicom script
MINICOM_SCRIPT=minicom_cache_demo.txt
endif

# Pass UART_DEMO flag to remote systems
UFLAGS+=UART_DEMO=$(UART_DEMO)

ifeq ($(UART_DEMO),1)
# Override default linux minicom script
MINICOM_SCRIPT=minicom_uart_demo.txt
endif

# Pass ETH_DEMO flag to remote systems
UFLAGS+=ETH_DEMO=$(ETH_DEMO)

ifeq ($(ETH_DEMO),1)
GRAB_TIMEOUT= 1500
MINICOM_SCRIPT=minicom_eth_demo.txt
CONSOLE_CMD += && ( cd ../../software/tests/iob_eth && ./validate_eth.sh -S root -p root -s 192.168.74.2 -i $(ETH_IF) )
endif

# Pass CPU_DEMO flag to remote systems
UFLAGS+=CPU_DEMO=$(CPU_DEMO)

ifeq ($(CPU_DEMO),1)
# Override default linux minicom script
MINICOM_SCRIPT=minicom_cpu_demo.txt
endif

# Pass VIDEO_DEMO flag to remote systems
UFLAGS+=VIDEO_DEMO=$(VIDEO_DEMO)

ifeq ($(VIDEO_DEMO),1)
MINICOM_SCRIPT=minicom_video_demo.txt
CONSOLE_CMD += && ( ./video_demo.sh )
endif


# include fpga build segment of (level 3) child systems
# child systems can add their own child3_fpga_build.mk without having to override this one.
ifneq ($(wildcard child3_fpga_build.mk),)
include child3_fpga_build.mk
endif
