# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

CORE := soc_linux

SIMULATOR ?= icarus
SYNTHESIZER ?= yosys
LINTER ?= spyglass
BOARD ?= iob_cyclonev_gt_dk

BUILD_DIR ?= $(shell nix-shell --run "py2hwsw $(CORE) print_build_dir")

# Soc-linux uses memory with 26 address bits and 4 bytes per word, for a total of 256 MiB.
# We typically have to use the external FPGA board's DDR memory in order to fit the entire memory.
USE_INTMEM ?= 0
USE_EXTMEM ?= 1

INIT_MEM ?= 1

VERSION ?=$(shell cat $(CORE).py | grep version | cut -d '"' -f 4)

ifneq ($(DEBUG),)
EXTRA_ARGS +=--debug_level $(DEBUG)
endif

# System parameters
ifneq ($(INIT_MEM),)
PY_PARAMS:=$(PY_PARAMS):init_mem=$(INIT_MEM)
endif
ifneq ($(USE_INTMEM),)
PY_PARAMS:=$(PY_PARAMS):use_intmem=$(USE_INTMEM)
endif
ifneq ($(USE_EXTMEM),)
PY_PARAMS:=$(PY_PARAMS):use_extmem=$(USE_EXTMEM)
endif
ifneq ($(USE_ETHERNET),)
PY_PARAMS:=$(PY_PARAMS):use_ethernet=$(USE_ETHERNET)
endif
ifneq ($(CPU),)
PY_PARAMS:=$(PY_PARAMS):cpu=$(CPU)
endif
# Remove first char (:) from PY_PARAMS
PY_PARAMS:=$(shell echo $(PY_PARAMS) | cut -c2-)


setup:
	nix-shell --run "py2hwsw $(CORE) setup --no_verilog_lint --py_params '$(PY_PARAMS)' $(EXTRA_ARGS)"

pc-emul-run: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ pc-emul-run"

pc-emul-test:
	make pc-emul-run

sim-run: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ sim-run SIMULATOR=$(SIMULATOR)"

sim-test:
	make sim-run CPU=iob_vexriscv SIMULATOR=verilator

fpga-build: clean
	make setup INIT_MEM=0
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ fpga-sw-build BOARD=$(BOARD)"
	make -C ../$(CORE)_V$(VERSION)/ fpga-build BOARD=$(BOARD)

fpga-run:
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ fpga-sw-build BOARD=$(BOARD)"
	make -C ../$(CORE)_V$(VERSION)/ fpga-run BOARD=$(BOARD)

fpga-test:
	make fpga-build fpga-run BOARD=iob_cyclonev_gt_dk USE_INTMEM=0 USE_EXTMEM=1
	make fpga-build fpga-run BOARD=iob_aes_ku040_db_g USE_INTMEM=0 USE_EXTMEM=1

syn-build: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ syn-build SYNTHESIZER=$(SYNTHESIZER)"

lint-run: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ lint-run LINTER=$(LINTER)"

doc-build: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ doc-build"

doc-test: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/ doc-test"


test-all: pc-emul-test sim-test fpga-test syn-build lint-run doc-build doc-test



# Install board server and client
board_server_install:
	make -C lib board_server_install

board_server_uninstall:
	make -C lib board_server_uninstall

board_server_status:
	systemctl status board_server

.PHONY: setup pc-emul-run pc-emul-test sim-run sim-test fpga-build fpga-run fpga-test syn-build lint-run doc-build doc-test test-all board_server_install board_server_uninstall board_server_status


clean:
	nix-shell --run "py2hwsw $(CORE) clean --build_dir '$(BUILD_DIR)'"
	@rm -rf ../*.summary ../*.rpt
	@find . -name \*~ -delete

# Remove all __pycache__ folders with python bytecode
python-cache-clean:
	find . -name "*__pycache__" -exec rm -rf {} \; -prune

.PHONY: clean python-cache-clean

# Tester

tester-sim-run: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/tester/ sim-run SIMULATOR=$(SIMULATOR)"

tester-fpga-run: clean setup
	nix-shell --run "make -C ../$(CORE)_V$(VERSION)/tester/ fpga-sw-build BOARD=$(BOARD)"
	make -C ../$(CORE)_V$(VERSION)/tester/ fpga-run BOARD=$(BOARD)

.PHONY: tester-sim-run tester-fpga-run

# Release Artifacts

release-artifacts:
	nix-shell --run "make clean setup USE_INTMEM=1 USE_EXTMEM=0 INIT_MEM=1"
	tar -czf $(CORE)_V$(VERSION)_INTMEM1_EXTMEM0_INITMEM1.tar.gz ../$(CORE)_V$(VERSION)
	nix-shell --run "make clean setup USE_INTMEM=1 USE_EXTMEM=0 INIT_MEM=0"
	tar -czf $(CORE)_V$(VERSION)_INTMEM1_EXTMEM0_INITMEM0.tar.gz ../$(CORE)_V$(VERSION)
	nix-shell --run "make clean setup USE_INTMEM=1 USE_EXTMEM=1 INIT_MEM=0"
	tar -czf $(CORE)_V$(VERSION)_INTMEM1_EXTMEM1_INITMEM0.tar.gz ../$(CORE)_V$(VERSION)
	nix-shell --run "make clean setup USE_INTMEM=0 USE_EXTMEM=1 INIT_MEM=0"
	tar -czf $(CORE)_V$(VERSION)_INTMEM0_EXTMEM1_INITMEM0.tar.gz ../$(CORE)_V$(VERSION)

.PHONY: release-artifacts

SOC_LINUX_BUILD_DIR:=$(BUILD_DIR)
include linux_targets.mk
