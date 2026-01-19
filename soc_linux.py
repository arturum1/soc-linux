# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params: dict):
    # Py2hwsw dictionary describing current core
    attributes_dict = {
        "version": "0.8",
        "parent": {
            # SoC-Linux is a child core of iob_system_linux: https://github.com/IObundle/py2hwsw/tree/main/py2hwsw/lib/hardware/iob_system_linux
            # SoC-Linux will inherit all attributes/files from the iob_system_linux core.
            "core_name": "iob_system_linux",
            # Every parameter in the lines below will be passed to the iob_system_linux parent core.
            # Full list of parameters available here: https://github.com/IObundle/py2hwsw/blob/main/py2hwsw/lib/iob_system/iob_system_linux/iob_system_linux.py
            #
            # Select CPU to use. For a list of compatible CPUs and info about custom CPU integration
            # check the 'cpu' python parameter at: https://github.com/IObundle/py2hwsw/blob/main/py2hwsw/lib/iob_system/iob_system.py
            "cpu": "iob_vexriscv",
            #
            # Do not include Tester system to speed-up setup process
            "include_tester": False,
            #
            # NOTE: Place other iob_system_linux python parameters here
            # "some_iob_system_linux_param": "my_value",
            **py_params,
        },
        # Every attribute in this dictionary will override/append to the ones of the iob_system_linux parent core
        "board_list": [
            "iob_aes_ku040_db_g",
            "iob_cyclonev_gt_dk",
            "iob_zybo_z7",
        ],
        "ports": [
            {
                # Override rs232 port of uart (inherited from iob_system_linux)
                "name": "rs232_m",
                "descr": "soc_linux uart interface",
                "signals": {
                    "type": "rs232",
                },
            },
            # NOTE: Add other ports here.
            # {
            #     "name": "my_custom_interface_io",
            #     "descr": "Custom SoCLinux interface",
            #     "signals": [
            #         {"name": "my_input_port_i", "width": 32},
            #         {"name": "my_output_port_o", "width": 32},
            #     ],
            # },
        ],
        # NOTE: Add other component overrides here.
    }

    return attributes_dict
