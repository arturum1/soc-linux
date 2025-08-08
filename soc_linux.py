# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    # Py2hwsw dictionary describing current core
    core_dict = {
        "version": "0.8",
        "parent": {
            # SoC-Linux is a child core of iob_system_linux: https://github.com/IObundle/py2hwsw/tree/main/py2hwsw/lib/hardware/iob_system_linux
            # SoC-Linux will inherit all attributes/files from the iob_system_linux core.
            "core_name": "iob_system_linux",
            # Every parameter in the lines below will be passed to the iob_system_linux parent core.
            # Full list of parameters availabe here: https://github.com/IObundle/py2hwsw/blob/main/py2hwsw/lib/iob_system_linux/iob_system_linux.py
            "cpu": "iob_vexriscv",
            # NOTE: Place other iob_system_linux python parameters here
            "system_attributes": {
                # Every attribute in this dictionary will override/append to the ones of the iob_system_linux parent core.
                "board_list": [
                    "iob_aes_ku040_db_g",
                    "iob_cyclonev_gt_dk",
                    "iob_zybo_z7",
                ],
                "ports": [
                    {
                        # Add new rs232 port for uart
                        "name": "rs232_m",
                        "descr": "iob-system uart interface",
                        "signals": {
                            "type": "rs232",
                        },
                    },
                    # NOTE: Add other ports here.
                ],
                "subblocks": [
                    {
                        # Instantiate a UART16550 core from: https://github.com/IObundle/iob-uart16550
                        "core_name": "iob_uart16550",
                        "instance_name": "UART0",  # Use same name as one inherited from iob_system to replace it
                        "instance_description": "UART peripheral",
                        "is_peripheral": True,
                        "parameters": {},
                        "connect": {
                            "clk_en_rst_s": "clk_en_rst_s",
                            # Cbus connected automatically
                            "rs232_m": "rs232_m",
                            "interrupt_o": "uart_interrupt",
                        },
                    },
                    # NOTE: Add other components/peripherals here.
                ],
            },
            **py_params_dict,
        },
    }

    return core_dict
