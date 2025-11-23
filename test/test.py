# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.types import Logic

import random

from cocotbext.i2c import I2cMaster

def get_bit(value, bit_index):
  temp = value & (1 << bit_index)
  return temp

def spi_clk_invert(value):
  temp = ~Logic(value)
  return temp


async def spi_write_cpha0 (dut, address, data):

  dut.spi_cs_n_i.value = 1 # PULL CS high, if it wasn't already
  await ClockCycles(dut.clk, 10)

  # Pull CS low + Write command bit - bit 7 - MSBIT in first byte
  dut.spi_cs_n_i.value = 0
  dut.spi_mosi_i.value = 1
  await ClockCycles(dut.clk, 10)
  dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
  await ClockCycles(dut.clk, 10)

  iterator = 0
  while iterator < 3:
    # Don't care - bit 6, bit 5 and bit 4
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    dut.spi_mosi_i.value = 0
    await ClockCycles(dut.clk, 10)
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    await ClockCycles(dut.clk, 10)
    iterator += 1

  iterator = 3
  while iterator >= 0:
    # Address[iterator] - bit 3, bit 2, bit 1 and bit 0
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    address_bit = get_bit(address, iterator)
    if (address_bit == 0):
      dut.spi_mosi_i.value = 0
    else:
      dut.spi_mosi_i.value = 1
    await ClockCycles(dut.clk, 10)
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    await ClockCycles(dut.clk, 10)
    iterator -= 1

  iterator = 7
  while iterator >= 0:
    # Data[iterator]
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    data_bit = get_bit(data, iterator)
    if (data_bit == 0):
      dut.spi_mosi_i.value = 0
    else:
      dut.spi_mosi_i.value = 1
    await ClockCycles(dut.clk, 10)
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    await ClockCycles(dut.clk, 10)
    iterator -= 1

  dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
  await ClockCycles(dut.clk, 10)

  dut.spi_cs_n_i.value = 1 # PULL CS high
  await ClockCycles(dut.clk, 10)


async def spi_read_cpha0 (dut, address):

  dut.spi_cs_n_i.value = 1 # PULL CS high, if it wasn't already
  await ClockCycles(dut.clk, 10)

  # Pull CS low + Read command bit - bit 7 - MSBIT in first byte
  dut.spi_cs_n_i.value = 0 # PULL CS low to start transmission
  dut.spi_mosi_i.value = 0
  await ClockCycles(dut.clk, 10)
  dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
  await ClockCycles(dut.clk, 10)

  iterator = 0
  while iterator < 3:
    # Don't care - bit 6, bit 5 and bit 4
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    dut.spi_mosi_i.value = 0
    await ClockCycles(dut.clk, 10)
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    await ClockCycles(dut.clk, 10)
    iterator += 1

  iterator = 3
  while iterator >= 0:
    # Address[iterator] - bit 3, bit 2, bit 1 and bit 0
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    address_bit = get_bit(address, iterator)
    if (address_bit == 0):
      dut.spi_mosi_i.value = 0
    else:
      dut.spi_mosi_i.value = 1
    await ClockCycles(dut.clk, 10)
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    await ClockCycles(dut.clk, 10)
    iterator -= 1

  miso_byte = 0
  miso_bit = 0

  data = 0

  iterator = 7
  while iterator >= 0:
    # Data[iterator]
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    data_bit = get_bit(data, iterator)
    if (data_bit == 0):
      dut.spi_mosi_i.value = 0
    else:
      dut.spi_mosi_i.value = 1
    await ClockCycles(dut.clk, 10)
    miso_bit = int(dut.spi_miso_o.value)
    miso_byte = miso_byte | (miso_bit << iterator)
    dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
    await ClockCycles(dut.clk, 10)
    iterator -= 1

  dut.spi_clk_i.value = spi_clk_invert(dut.spi_clk_i.value)
  await ClockCycles(dut.clk, 10)

  dut.spi_cs_n_i.value = 1 # PULL CS high
  await ClockCycles(dut.clk, 10)

  return miso_byte


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
    dut.ui_in.value = 0
    # Pull up all bidirection inputs
    dut.uio_in_ext.value = 255
    # Pull up CS, CLK and MOSI
    dut.spi_cs_n_i.value = 1
    dut.spi_clk_i.value = 1
    dut.spi_mosi_i.value = 1
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

    # Select i2c peripheral and set address modifiers
    dut.ui_in.value = (1 << 7) + (1 << 4) + (1 << 3) + (0 << 2)


    # Wait for some time
    await ClockCycles(dut.clk, 100)

    # I2C Master component
    i2c_master = I2cMaster(dut.i2c_sda, dut.i2c_sda_i, dut.i2c_scl, dut.i2c_scl, 400)

    # Test data pattern
    test_data = b'\xca\x10\xde\xad'
    # Write Address 0 + 4 bytes for test data pattern
    await i2c_master.write(0x76, b'\x00' + test_data)
    # Sendo stop bit
    await i2c_master.send_stop()

    # Wait for some time
    await ClockCycles(dut.clk, 50)

    # Write Address 0
    await i2c_master.write(0x76, b'\x00')
    # Read 4 bytes from Address 0
    data = await i2c_master.read(0x76, 4)
    # Sendo stop bit
    await i2c_master.send_stop()

    # Assert data read is same as written
    assert test_data == data

    # Wait for some time
    await ClockCycles(dut.clk, 100)


    # Config CPOL and CPHA
    CPOL = 0
    CPHA = 0

    # Select SPI peripheral, config cpol and cpha as 0 and preserve i2c address modifiers
    dut.ui_in.value = (0 << 7) + (1 << 4) + (1 << 3) + (0 << 2) + (CPHA << 1) + (CPOL << 0)

    # Pull CS high
    dut.spi_cs_n_i.value = 1 # DRIVE CS HIGH
    await ClockCycles(dut.clk, 10)

    # CPOL = 0, SPI_CLK low in idle
    dut.spi_clk_i.value = 0

    # Wait for some time
    await ClockCycles(dut.clk, 10)
    await ClockCycles(dut.clk, 10)

    # ITERATIONS
    iterations = 0

    while iterations < 10:
        data0 = random.randint(0x00, 0xFF)
        data1 = random.randint(0x00, 0xFF)
        data2 = random.randint(0x00, 0xFF)
        data3 = random.randint(0x00, 0xFF)
        data4 = random.randint(0x00, 0xFF)
        data5 = random.randint(0x00, 0xFF)
        data6 = random.randint(0x00, 0xFF)
        data7 = random.randint(0x00, 0xFF)

        # Write reg[0] = 0xF0
        await spi_write_cpha0 (dut, 0, data0)
        # Write reg[1]
        await spi_write_cpha0 (dut, 1, data1)
        # Write reg[2]
        await spi_write_cpha0 (dut, 2, data2)
        # Write reg[3]
        await spi_write_cpha0 (dut, 3, data3)
        # Write reg[4]
        await spi_write_cpha0 (dut, 4, data4)
        # Write reg[5]
        await spi_write_cpha0 (dut, 5, data5)
        # Write reg[6]
        await spi_write_cpha0 (dut, 6, data6)
        # Write reg[7]
        await spi_write_cpha0 (dut, 7, data7)

        # Read reg[0]
        reg0 = await spi_read_cpha0 (dut, 0)
        # Read reg[1]
        reg1 = await spi_read_cpha0 (dut, 1)
        # Read reg[2]
        reg2 = await spi_read_cpha0 (dut, 2)
        # Read reg[3]
        reg3 = await spi_read_cpha0 (dut, 3)
        # Read reg[4]
        reg4 = await spi_read_cpha0 (dut, 4)
        # Read reg[5]
        reg5 = await spi_read_cpha0 (dut, 5)
        # Read reg[6]
        reg6 = await spi_read_cpha0 (dut, 6)
        # Read reg[7]
        reg7 = await spi_read_cpha0 (dut, 7)

        # Read status reg[0]
        s_reg0 = await spi_read_cpha0 (dut, 8)
        # Read status reg[1]
        s_reg1 = await spi_read_cpha0 (dut, 9)
        # Read status reg[2]
        s_reg2 = await spi_read_cpha0 (dut, 10)
        # Read status reg[3]
        s_reg3 = await spi_read_cpha0 (dut, 11)
        # Read status reg[4]
        s_reg4 = await spi_read_cpha0 (dut, 12)
        # Read status reg[5]
        s_reg5 = await spi_read_cpha0 (dut, 13)
        # Read status reg[6]
        s_reg6 = await spi_read_cpha0 (dut, 14)
        # Read status reg[7]
        s_reg7 = await spi_read_cpha0 (dut, 15)

        await ClockCycles(dut.clk, 10)
        await ClockCycles(dut.clk, 10)

        assert reg0 == data0
        assert reg1 == data1
        assert reg2 == data2
        assert reg3 == data3
        assert reg4 == data4
        assert reg5 == data5
        assert reg6 == data6
        assert reg7 == data7
        assert s_reg0 == 0xCA
        assert s_reg1 == 0x10
        assert s_reg2 == 0xAA
        assert s_reg3 == 0x55
        assert s_reg4 == 0xFF
        assert s_reg5 == 0x00
        assert s_reg6 == 0xA5
        assert s_reg7 == 0x5A

        iterations = iterations + 1


    # Wait for some time
    await ClockCycles(dut.clk, 10)
    await ClockCycles(dut.clk, 10)