/*
 * Copyright (c) 2025 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module sunrise_digital_top (
    input  wire  clk,            // clock
    input  wire  rst_n,          // reset_n - low to reset
    input  wire  ena,            // always 1 when the design is powered, so you can ignore it

    input  wire  protocol_sel_i, // Select protocol for peripheral, spi = 0, i2c = 1

    input  wire  spi_cpol_i,     // SPI clock polarity configuration
    input  wire  spi_cpha_i,     // SPI clock phase configuration
    input  wire  spi_cs_n_i,     // SPI chip select
    input  wire  spi_clk_i,      // SPI clock
    input  wire  spi_mosi_i,     // SPI data line, manager output, peripheral input
    output wire  spi_miso_o,     // SPI data line, manager input, peripheral output
    output wire  spi_miso_oe,    // SPI data line, manager input, peripheral output enable output enable (tri-state control), 0 = HiZ, 1 = drive spi_miso

    input  wire  i2c_addr0_i,    // i2c address bit 0 input
    input  wire  i2c_addr1_i,    // i2c address bit 1 input
    input  wire  i2c_addr2_i,    // i2c address bit 2 input
    input  wire  i2c_scl_i,      // i2c serial clock input
    input  wire  i2c_sda_i,      // i2c serial data input
    output wire  i2c_sda_o,      // i2c serial data output
    output wire  i2c_sda_oe,     // i2c serial data output enable (tri-state control), 0 = HiZ, 1 = drive i2c_data_o

    output wire [7:0] d7seg_o    // 7 segments display
);

  // Number of stages in each synchronizer
  localparam int SYNC_STAGES = 2;
  localparam int SYNC_WIDTH = 1;

  // Number of CFG Regs and Status Regs
  // Limitation: NUM_CFG must be equal to NUM_STATUS
  localparam int NUM_CFG = 8;
  localparam int NUM_STATUS = NUM_CFG;
  // Size of Regs
  localparam int REG_WIDTH = 8;

  // Config Regs and Status Regs
  wire [NUM_CFG*REG_WIDTH-1:0] rw_regs;
  wire [NUM_STATUS*REG_WIDTH-1:0] ro_regs;
  wire [7:0] d7seg;

  // Sync'ed
  wire protrocol_sel_sync;
  wire cpol_sync;
  wire cpha_sync;
  wire spi_cs_n_sync;
  wire spi_clk_sync;
  wire spi_mosi_sync;

  // Synchronizers for protocol selector
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH))
  sync_input_prot_sel (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(protocol_sel_i), .data_out(protrocol_sel_sync));
  // Synchronizers for spi inputs
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH))
  sync_input_spi_cpol (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_cpol_i), .data_out(cpol_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH))
  sync_input_spi_cpha (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_cpha_i), .data_out(cpha_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH))
  sync_input_spi_cs_n (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_cs_n_i), .data_out(spi_cs_n_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH))
  sync_input_spi_clk  (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_clk_i),  .data_out(spi_clk_sync));
  synchronizer #(.STAGES(SYNC_STAGES), .WIDTH(SYNC_WIDTH))
  sync_input_spi_mosi (.rstb(rst_n), .clk(clk), .ena(ena), .data_in(spi_mosi_i), .data_out(spi_mosi_sync));

  // Assign status
  assign ro_regs[7:0]   = 8'hCA;
  assign ro_regs[15:8]  = 8'h10;
  assign ro_regs[23:16] = 8'hAA;
  assign ro_regs[31:24] = 8'h55;
  assign ro_regs[39:32] = 8'hFF;
  assign ro_regs[47:40] = 8'h00;
  assign ro_regs[55:48] = 8'hA5;
  assign ro_regs[63:56] = 8'h5A;

  // top wrapper
  top_wrapper #(
    .NUM_CFG(NUM_CFG),
    .NUM_STATUS(NUM_STATUS),
    .REG_WIDTH(REG_WIDTH)
  ) top_wrapper_i (
    .rstb(rst_n),
    .clk(clk),
    .ena(ena),
    .mode({cpol_sync, cpha_sync}),
    .spi_cs_n(spi_cs_n_sync),
    .spi_clk(spi_clk_sync),
    .spi_mosi(spi_mosi_sync),
    .spi_miso(spi_miso_o),
    .spi_miso_oe(spi_miso_oe),
    .i2c_sda_o(i2c_sda_o),
    .i2c_sda_oe(i2c_sda_oe),
    .i2c_sda_i(i2c_sda_i),
    .i2c_scl(i2c_scl_i),
    .sel(protrocol_sel_sync),
    .rw_regs(rw_regs),
    .ro_regs(ro_regs)
  );

  // 7 segments display address 0
  assign d7seg = rw_regs[7:0];
  assign d7seg_o = d7seg;

endmodule