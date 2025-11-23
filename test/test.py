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
    # Pull down inputs
    dut.ui_in = 0
    # Pull up all bidirection inputs
    dut.uio_in_ext.value = 255
    # Pull up SCL and SDA
    dut.i2c_scl.value = 1
    dut.i2c_sda_i.value = 1
    # Hold in reset
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    # Relase reset
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

    # Test data pattern
    test_data = b'\xca\x10\xde\xad'
    # Write Address 0 + 4 bytes for test data pattern
    await i2c_master.write(0x70, b'\x00' + test_data)
    # Sendo stop bit
    await i2c_master.send_stop()

    # Wait for some time
    await ClockCycles(dut.clk, 50)

    # Write Address 0
    await i2c_master.write(0x70, b'\x00')
    # Read 4 bytes from Address 0
    data = await i2c_master.read(0x70, 4)
    # Sendo stop bit
    await i2c_master.send_stop()

    # Assert data read is same as written
    assert test_data == data

    # Wait for some time
    await ClockCycles(dut.clk, 100)
