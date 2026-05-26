# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# SoC-Linux specific makefile segment (level 2 child - child of iob_system_linux)

# Pass CACHE_DEMO flag to remote systems
UFLAGS+=CACHE_DEMO=$(CACHE_DEMO)

ifeq ($(CACHE_DEMO),1)
# Override default linux minicom script to run cache demo instead
MINICOM_SCRIPT=minicom_cache_demo.txt
endif

# include fpga build segment of (level 3) child systems
# child systems can add their own child3_fpga_build.mk without having to override this one.
ifneq ($(wildcard child3_fpga_build.mk),)
include child3_fpga_build.mk
endif
