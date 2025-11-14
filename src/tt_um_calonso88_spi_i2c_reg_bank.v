/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_calonso88_spi_i2c_reg_bank (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // Peripheral selector
  // 1'b0 - SPI can access reg bank
  // 1'b1 - i2c can access reg bank
  wire sel;

  // i2c Auxiliars
  wire i2c_sda_i;
  wire i2c_sda_o;
  wire i2c_sda_oe;
  wire i2c_scl;

  // SPI Auxiliars
  wire spi_cpol;
  wire spi_cpha;
  wire spi_cs_n;
  wire spi_clk;
  wire spi_miso;
  wire spi_mosi;

    // Input ports - SPI modes
  assign spi_cpol = ui_in[0];
  assign spi_cpha = ui_in[1];

  // Input ports - peripheral selector
  assign sel = ui_in[7];

  // Output ports (drive 7seg display) - Config Reg Address 0
  //assign uo_out[7:0] = rw_regs[7:0];
  assign uo_out[7:0] = '0;

  // Bi direction IOs [6:4] (cs_n, sclk, mosi) always as inputs
  assign uio_oe[6:4] = 3'b000;

  // Bi direction IOs [3] - (miso) is controlled by spi_cs_n_sync
  // input port when spi_cs_n_sync = 1'b1
  // output port when spi_cs_n_sync = 1'b0
  //assign uio_oe[3] = spi_cs_n_sync ? 1'b0 : 1'b1;
  assign uio_oe[3] = spi_cs_n ? 1'b0 : 1'b1;

  // Bi direction IOs [1] - Control of i2c SDA
  // Bi direction IOs [2] - i2c SCL, always input
  assign uio_oe[1] = i2c_sda_oe;
  assign uio_oe[2] = 1'b0;

  // Bi direction IOs [7] and [0] unused - set always as inputs
  assign uio_oe[7] = 1'b0;
  assign uio_oe[0] = 1'b0;

  // Bi-directional Input ports i2c
  assign i2c_sda_i = uio_in[1];
  assign i2c_scl   = uio_in[2];

  // Bi-directional Input ports SPI
  assign spi_cs_n  = uio_in[4];
  assign spi_clk   = uio_in[5];
  assign spi_mosi  = uio_in[6];

  // Bi-directional Output ports i2c
  assign uio_out[1] = i2c_sda_o;
  // Bi-directional Output ports SPI
  assign uio_out[3] = spi_miso;

  // Bi-directional ouputs unused needs to be assigned to 0.
  assign uio_out[0] = 1'b0;
  assign uio_out[2] = 1'b0;
  assign uio_out[7:4] = 4'b0000;

  // List all unused inputs to prevent warnings
  //wire _unused = &{ui_in[6:2], uio_in[7], uio_in[3], uio_in[0], rw_regs[NUM_CFG*REG_WIDTH-1:8], 1'b0};
  wire _unused = &{ui_in[6:2], uio_in[7], uio_in[3], uio_in[0], 1'b0};

  // Instantiate top
  sunrise_digital_top sunrise_digital_top_i (
    .rst_n          (rst_n),
    .clk            (clk),
    .ena            (ena),
    .protocol_sel_i (sel),       // Select protocol for peripheral, spi = 0, i2c = 1
    .spi_cpol_i     (spi_cpol),  // SPI clock polarity configuration
    .spi_cpha_i     (spi_cpha),  // SPI clock phase configuration
    .spi_cs_n_i     (spi_cs_n),  // SPI chip select
    .spi_clk_i      (spi_clk),   // SPI clock
    .spi_mosi_i     (spi_mosi),  // SPI data line, manager output, peripheral input
    .spi_miso_o     (spi_miso),  // SPI data line, manager input, peripheral output
    .spi_miso_oe    (),          // SPI data line, manager input, peripheral output enable output enable (tri-state control), 0 = HiZ, 1 = drive spi_miso

    .i2c_addr0_i    (1'b1),      // i2c address bit 0 input
    .i2c_addr1_i    (1'b1),      // i2c address bit 1 input
    .i2c_addr2_i    (1'b1),      // i2c address bit 2 input
    .i2c_scl_i      (i2c_scl),   // i2c serial clock input
    .i2c_sda_i      (i2c_sda_i), // i2c serial data input
    .i2c_sda_o      (i2c_sda_o), // i2c serial data output
    .i2c_sda_oe     (i2c_sda_oe) // i2c serial data output enable (tri-state control), 0 = HiZ, 1 = drive i2c_data_o
  );

endmodule
