# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params: dict):
    # Include CACHE and DMA peripherals for demonstration
    CACHE_DEMO = int(py_params.get("cache_demo", 0))

    # Attributes to pass to parent SoC (iob_system_linux), overriding inherited defaults.
    override_attributes = {}

    # Py2hwsw dictionary describing current core
    attributes_dict = {
        "version": "0.8.0",
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
            "system_attributes": override_attributes,
        },
        # Every attribute in this dictionary will override/append to the ones of the iob_system_linux parent core
        # The difference between these attributes and the ones passed as python parameter to "system_attributes" (via override_attributes) is that those ones are pre-processed by iob_system_linux scripts, while the ones bellow are just overrides without preproceessing.
        "board_list": [
            "iob_aes_ku040_db_g",
            "iob_cyclonev_gt_dk",
            "iob_zybo_z7",
            "iob_smart_zynq_sl",
            "iob_zcu104",
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
        "wires": [],
        "subblocks": [
            # NOTE: Add other component overrides here.
        ],
        "snippets": [],
    }

    #
    # Cache/DMA demo
    #
    if CACHE_DEMO:
        override_attributes["confs"] = [
            {  # Needed for software
                "name": "CACHE_DEMO",
                "descr": "Set SOC_LINUX_CACHE_DEMO software macro to enable demo in baremetal firmware.",
                "type": "M",
                "val": True,
            },
        ]
        override_attributes["wires"] = [
            {
                "name": "cache_axi",
                "descr": "AXI bus for cache peripheral",
                "signals": {
                    "type": "axi",
                    "prefix": "cache_",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                    "LOCK_W": "1",
                },
            },
            {
                "name": "cache_chain_io",
                "descr": "Cache invalidate and write-trough buffer IO chain",
                "signals": [
                    {
                        "name": "cache_invalidate_i",
                        "descr": "Invalidates all cache lines instantaneously if high.",
                        "width": 1,
                    },
                    {
                        "name": "cache_invalidate_o",
                        "descr": "This output is asserted high when the cache is invalidated via the cache controller or the direct 'invalidate_in' signal. The present 'invalidate_out' signal is useful for invalidating the next-level cache if there is one. If not, this output should be floated.",
                        "width": 1,
                    },
                    {
                        "name": "cache_wtb_empty_i",
                        "descr": "This input is driven by the next-level cache, if there is one, when its write-through buffer is empty. It should be tied high if there is no next-level cache. This signal is used to compute the overall empty status of a cache hierarchy, as explained for signal 'wtb_empty_out'.",
                        "width": 1,
                    },
                    {
                        "name": "cache_wtb_empty_o",
                        "descr": "This output is high if the cache's write-through buffer is empty and its 'wtb_empty_in' signal is high. This signal informs that all data written to the cache has been written to the destination memory module, and all caches on the way are empty.",
                        "width": 1,
                    },
                ],
            },
            {
                "name": "dma_axi",
                "descr": "AXI bus connecting DMA peripheral to cache",
                "signals": {
                    "type": "axi",
                    "prefix": "dma_",
                    "ID_W": "AXI_ID_W",
                    "ADDR_W": "AXI_ADDR_W",
                    "DATA_W": "AXI_DATA_W",
                    "LEN_W": "AXI_LEN_W",
                    "LOCK_W": "2",
                },
            },
            {
                "name": "dma_rst",
                "signals": [{"name": "dma_rst", "width": 1}],
            },
            {
                "name": "axis_loopback",
                "descr": "Loopback AXI Stream bus for DMA peripheral test",
                "signals": {
                    "type": "axis",
                    "prefix": "loopback_",
                },
            },
        ]
        override_attributes["subblocks"] = [
            {
                # Instantiate a cache peripheral core from: https://github.com/IObundle/iob-cache
                "core_name": "iob_cache",
                "instance_name": "CACHE0",
                "instance_description": "Cache peripheral",
                "is_peripheral": True,
                "parameters": {
                    "AXI_ID_W": "AXI_ID_W",
                    "AXI_LEN_W": "AXI_LEN_W",
                    "FE_ADDR_W": "AXI_ADDR_W",
                    "BE_ADDR_W": "AXI_ADDR_W",
                    "USE_CTRL_CNT": 1,
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    # Cbus connected automatically
                    "axi_s": "dma_axi",
                    "axi_m": "cache_axi",
                    "ie_io": "cache_chain_io",
                },
                "fe_if": "axi",
                "use_ctrl": True,
                "use_dedicated_ctrl_port": True,
            },
            {
                # Instantiate a DMA peripheral core from: https://github.com/IObundle/py2hwsw/tree/main/py2hwsw/lib/peripherals/iob_dma
                "core_name": "iob_dma",
                "instance_name": "DMA0",
                "instance_description": "DMA interface",
                "is_peripheral": True,
                "parameters": {
                    "AXI_ID_W": "AXI_ID_W",
                    "AXI_LEN_W": "AXI_LEN_W",
                    "AXI_ADDR_W": "AXI_ADDR_W",
                    "AXI_DATA_W": "AXI_DATA_W",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "rst_i": "dma_rst",
                    "axi_m": "dma_axi",
                    "dma_input_io": "axis_loopback",
                    "dma_output_io": "axis_loopback",
                },
            },
            # Override default iob_system xbar to add +1 subordinate port to connect to cache
            # This instance is hardcoded to only work with iob_system params: INTMEM=0 EXTMEM=1 BOOTROM=1 PERIPHERALS=1 ETHERNET=1
            {
                "core_name": "iob_axi_full_xbar",
                "name": "soc_linux_axi_full_xbar",
                "instance_name": "iob_axi_full_xbar",
                "instance_description": "AXI full xbar instance",
                "parameters": {
                    "ID_W": "AXI_ID_W",
                    "LEN_W": "AXI_LEN_W",
                },
                "connect": {
                    "clk_en_rst_s": "clk_en_rst_s",
                    "rst_i": "rst",
                    # Subordinate interfaces
                    "s0_axi_s": "cpu_ibus",
                    "s1_axi_s": "cpu_dbus",
                    "s2_axi_s": (
                        "eth_axi",
                        ["eth_axi_awlock[0]", "eth_axi_arlock[0]"],
                    ),
                    "s3_axi_s": (
                        "cache_axi",
                        # MSB bits unused. Cache/DMA only accesses lower address range (memory).
                        ["{6'b0, cache_axi_awaddr}", "{6'b0, cache_axi_araddr}"],
                    ),
                    # Manager interfaces
                    "m0_axi_m": (
                        "axi_m",
                        [
                            "{unused_m1_araddr_bits, axi_araddr_o}",
                            "{unused_m1_awaddr_bits, axi_awaddr_o}",
                        ],
                    ),
                    "m1_axi_m": (
                        "bootrom_cbus",
                        [
                            "{unused_m2_araddr_bits, bootrom_axi_araddr}",
                            "{unused_m2_awaddr_bits, bootrom_axi_awaddr}",
                        ],
                    ),
                    "m2_axi_m": (
                        "axi_periphs_cbus",
                        [
                            "{unused_m3_araddr_bits, periphs_axi_araddr}",
                            "{unused_m3_awaddr_bits, periphs_axi_awaddr}",
                            "periphs_axi_awlock[0]",
                            "periphs_axi_arlock[0]",
                        ],
                    ),
                },
                "addr_w": 32,
                "data_w": 32,
                "lock_w": 1,
                "num_subordinates": 3 + 1,  # 3 subordinates inherited + 1 for cache
                "num_managers": 3,  # 3 managers inherited
            },
        ]
        override_attributes["snippets"] = [
            {
                "verilog_code": f"""
   assign dma_rst = 1'b0;

   assign cache_invalidate_i = 1'b0; 
   assign cache_wtb_empty_i = 1'b1;
"""
            }
        ]

    return attributes_dict
