# SPDX-FileCopyrightText: 2026 IObundle
#
# SPDX-License-Identifier: MIT

# SoC-Linux specific makefile segment (level 2 child - child of iob_system_linux)

# Pass CACHE_DEMO flag to remote systems
UFLAGS+=CACHE_DEMO=$(CACHE_DEMO)

ifeq ($(CACHE_DEMO),1)
# Override default linux minicom script to run cache demo instead
MINICOM_SCRIPT=minicom_cache_demo.txt
endif

# Pass UART_DEMO flag to remote systems
UFLAGS+=UART_DEMO=$(UART_DEMO)

ifeq ($(UART_DEMO),1)
# Override default linux minicom script to run cache demo instead
MINICOM_SCRIPT=minicom_uart_demo.txt
endif

# Pass ETH_DEMO flag to remote systems
UFLAGS+=ETH_DEMO=$(ETH_DEMO)

ifeq ($(ETH_DEMO),1)
GRAB_TIMEOUT= 1300
MINICOM_SCRIPT=minicom_eth_demo.txt
CONSOLE_CMD += && ( cd ../../software/tests/iob_eth && ./validate_eth.sh -S root -p root -s 192.168.74.2 -i $(ETH_IF) )
# # Override CONSOLE_CMD: skip minicom (appended by child_fpga_build.mk) and run eth test instead
# # Use = (deferred expansion) to preserve variable references for later expansion
# CONSOLE_CMD = $(IOB_CONSOLE_PYTHON_ENV) $(PYTHON_DIR)/console_ethernet.py -s $(BOARD_SERIAL_PORT) -c $(PYTHON_DIR)/console.py -m "$(RMAC_ADDR)" -i "$(ETH_IF)" && ( cd ../../software/tests/iob_eth && ./validate_eth.sh -S root -p root -s 192.168.74.2 -i $(ETH_IF) )
endif

# include fpga build segment of (level 3) child systems
# child systems can add their own child3_fpga_build.mk without having to override this one.
ifneq ($(wildcard child3_fpga_build.mk),)
include child3_fpga_build.mk
endif
