# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from cocotbext.i2c import I2cMaster

@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    # Pull up i2c SDA and SCL
    dut.uio_in.value = (1 << 1) + (1 << 2)

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Wait for some time
    await ClockCycles(dut.clk, 100)

    # Select i2c peripheral
    dut.ui_in.value = 1 << 7

    # Wait for some time
    await ClockCycles(dut.clk, 100)

    # I2C Master component
    i2c_master = I2cMaster(dut.i2c_sda, dut.i2c_sda_i, dut.i2c_scl, dut.i2c_scl, 400)

    test_data = b'\xaa\xbb\xcc\xdd'
    await i2c_master.write(0x70, b'\x00' + test_data)
    await i2c_master.send_stop()

    # Wait for some time
    await ClockCycles(dut.clk, 10)
    await ClockCycles(dut.clk, 10)

    await i2c_master.write(0x70, b'\x00')
    data = await i2c_master.read(0x70, 4)
    await i2c_master.send_stop()

    assert test_data == data

    # Wait for some time
    await ClockCycles(dut.clk, 10)