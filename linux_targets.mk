# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

#
# Configuration variables
#

# Path of cloned iob-linux repository
LINUX_REPO_DIR ?=
# Name and build directory path of the linux-compatible peripheral core
CORE_BUILD_DIR ?=
# Build directory of pre-built linux system
SOC_LINUX_BUILD_DIR ?=
# Target FPGA board
BOARD ?= iob_cyclonev_gt_dk

$(info [linux_targets.mk]: LINUX_REPO_DIR: $(LINUX_REPO_DIR), CORE_BUILD_DIR: $(CORE_BUILD_DIR), SOC_LINUX_BUILD_DIR: $(SOC_LINUX_BUILD_DIR), BOARD: $(BOARD))


#
# Automatic variables
#
# Generate relative paths
ifneq ($(CORE_BUILD_DIR),)
REL_LINUX2BUILD :=`realpath $(CORE_BUILD_DIR) --relative-to=$(LINUX_REPO_DIR)`

CORE=$(shell grep '^NAME=' $(CORE_BUILD_DIR)/config_build.mk | cut -d '=' -f 2)
endif

# Find board directoy inside hardware/fpga
BOARD_DIR := $(shell find $(SOC_LINUX_BUILD_DIR)/hardware/fpga -name $(BOARD) -type d -print -quit)
# Include board.mk to set BOARD_USER, BOARD_SERVER, and BOARD_SERIAL_PORT
ifneq ($(BOARD_DIR),)
include $(BOARD_DIR)/board.mk
endif
# Configure ssh if running on remote machines
ifneq ($(BOARD_SERVER),)
SSH_START=ssh $(BOARD_USER)@$(BOARD_SERVER) '
SSH_END='
REMOTE_BUILD_DIR?=$(USER)/$(notdir $(SOC_LINUX_BUILD_DIR))
REMOTE_CORE_DIR?=$(USER)/$(notdir $(CORE_BUILD_DIR))
else
REMOTE_BUILD_DIR=$(SOC_LINUX_BUILD_DIR)
REMOTE_CORE_DIR?=$(CORE_BUILD_DIR)
endif
# Assume a serial port if not specified
ifeq ($(BOARD_SERIAL_PORT),)
BOARD_SERIAL_PORT=/dev/usb-uart
endif

#
# Targets
#

kernel-module-rebuild:
	# Compile userspace binaries
	nix-shell $(LINUX_REPO_DIR) --run 'make -C $(CORE_BUILD_DIR)/software/linux/user all'
	# Compile kernel driver
	nix-shell $(LINUX_REPO_DIR) --run 'make -C $(LINUX_REPO_DIR) build-linux-drivers MODULE_NAME=$(CORE) MODULE_DRIVER_DIR=$(REL_LINUX2BUILD)/software/linux/drivers ROOTFS_OVERLAY_DIR=$(REL_LINUX2BUILD)/software/linux/drivers'
ifneq ($(BOARD_SERVER),)
	# Rsync build dir to remote machine
	rsync $(BOARD_SYNC_FLAGS) -avz --force --delete --exclude 'software/tb' $(CORE_BUILD_DIR)/ $(BOARD_USER)@$(BOARD_SERVER):$(REMOTE_CORE_DIR)/
endif
	# 1) Upload kernel module and user space binaries to running linux instance using lrzsz
	# 2) Reload kernel module in running instance
	#
	# NOTE: These commands dont use board_client.py to grab the FPGA board. May cause conflicts with shared FPGAs.
	# They dont grab the board, since its meant to be used with an already grabbed fpga running a linux instance.
	$(SSH_START) cd $(REMOTE_CORE_DIR)/software/linux;\
	stty -F /dev/usb-uart 115200 raw -echo -crtscts;\
	echo "rz -o /drivers" > $(BOARD_SERIAL_PORT) && sz -y drivers/$(CORE).ko < $(BOARD_SERIAL_PORT) > $(BOARD_SERIAL_PORT);\
	`# Uncomment this for block to enable transfer of user-space binaries\
	for file in "$(CORE)_user_sysfs" "$(CORE)_user_dev" "$(CORE)_user_ioctl" "$(CORE)_tests_sysfs" "$(CORE)_tests_dev" "$(CORE)_tests_ioctl"; do\
		echo "rz -o /root" > $(BOARD_SERIAL_PORT) && sz -y user/$$file < $(BOARD_SERIAL_PORT) > $(BOARD_SERIAL_PORT);\
	done; `\
	echo "modprobe /drivers/$(CORE).ko" > $(BOARD_SERIAL_PORT) $(SSH_END)

.PHONY: kernel-module-rebuild

# Set TERM variable to linux-c-nc (needed to run in non-interactive mode https://stackoverflow.com/a/49077622)
TERM_STR:=TERM=linux-c-nc
# Set HOME to current (fpga) directory (needed because minicom always reads the '.minirc.*' config file from HOME)
HOME_STR:=HOME=$(REMOTE_BUILD_DIR)/hardware/fpga
SCRIPT_STR:=-S minicom_linux_script.txt
# Set a capture file and print its contents (to work around minicom clearing the screen)
LOG_STR:=-C minicom_out.log $(FAKE_STDOUT) || cat minicom_out.log
rerun-tests:
	$(SSH_START) cd $(REMOTE_BUILD_DIR)/hardware/fpga;\
	$(HOME_STR) $(TERM_STR) minicom iobundle.dfl $(SCRIPT_STR) $(LOG_STR) $(SSH_END)

.PHONY: rerun-tests
