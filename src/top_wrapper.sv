/*
 * Copyright (c) 2025 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

module top_wrapper #(parameter int NUM_CFG = 8, parameter int NUM_STATUS = 8, parameter int REG_WIDTH = 8) (rstb, clk, ena, mode, spi_cs_n, spi_clk, spi_mosi, spi_miso, spi_miso_oe, i2c_sda_o, i2c_sda_oe, i2c_sda_i, i2c_scl, sel, rw_regs, ro_regs);

  input  logic rstb;
  input  logic clk;
  input  logic ena;
  // spi peripheral
  input  logic [1:0] mode;
  input  logic spi_cs_n;
  input  logic spi_clk;
  input  logic spi_mosi;
  output logic spi_miso;
  output logic spi_miso_oe;
  // i2c peripheral
  output logic i2c_sda_o;
  output logic i2c_sda_oe;
  input  logic i2c_sda_i;
  input  logic i2c_scl;
  // Peripheral selector
  input  logic sel;
  // RW and RO registers
  output logic [NUM_CFG*REG_WIDTH-1:0] rw_regs;
  input  logic [NUM_STATUS*REG_WIDTH-1:0] ro_regs;

  // Auxiliar variables for spi peripheral
  logic spi_wr_rdn;
  logic [REG_WIDTH-1:0] spi_addr;
  logic [REG_WIDTH-1:0] spi_rdata, spi_wdata;
  logic spi_we;

  // Auxiliar variables for i2c peripheral
  logic i2c_wr_rdn;
  logic [REG_WIDTH-1:0] i2c_addr;
  logic [REG_WIDTH-1:0] i2c_rdata, i2c_wdata;
  logic i2c_we;

  // Auxiliar variables for interface register bank
  logic wr_rdn;
  logic [REG_WIDTH-1:0] addr;
  logic [REG_WIDTH-1:0] rdata, wdata;
  logic we;
  logic ack;
  logic err;

  // Auxiliar params
  localparam int NUM_REGS = NUM_CFG+NUM_STATUS;
  localparam int ADDR_REG_BANK_W = $clog2(NUM_REGS);
  logic [ADDR_REG_BANK_W-1:0] addr_reg_bank;

  // Tied extra bit off as SPI peripheral only provides 7 address bits
  assign spi_addr[REG_WIDTH-1] = 1'b0;

  // SPI peripheral
  spi_peripheral #(
    .REG_W(REG_WIDTH)
  ) spi_peripheral_i (
    .clk(clk),
    .rstb(rstb),
    .ena(ena),
    .mode(mode),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_miso_oe(spi_miso_oe),
    .spi_clk(spi_clk),
    .spi_cs_n(spi_cs_n),
    .wr_rdn(spi_wr_rdn),
    .addr(spi_addr[REG_WIDTH-2:0]),
    .rdata(spi_rdata),
    .wdata(spi_wdata),
    .we(spi_we),
    .status('0)
  );

  // i2c peripheral
  i2c_peripheral #(
    .SLAVE_ADDR (7'b1110000)
  ) i2c_peripheral_i (
    .clk(clk),
    .rst_n(rstb),
    .ena(ena),
    .sda_o(i2c_sda_o),
    .sda_oe(i2c_sda_oe),
    .sda_i(i2c_sda_i),
    .scl(i2c_scl),
    .wr_rdn(i2c_wr_rdn),
    .addr(i2c_addr),
    .rdata(i2c_rdata),
    .wdata(i2c_wdata),
    .we(i2c_we),
    .status('0)
  );

  // Select peripheral
  mux #(
    .WIDTH(1+REG_WIDTH+REG_WIDTH+1)
  ) mux_addr_i (
    .a({spi_wr_rdn, spi_addr, spi_wdata, spi_we}),
    .b({i2c_wr_rdn, i2c_addr, i2c_wdata, i2c_we}),
    .sel(sel),
    .dout({wr_rdn, addr,  wdata, we})
  );

  // Use only the address bits required for NUM_CFG+NUM_STATUS registers
  assign addr_reg_bank = addr[ADDR_REG_BANK_W-1:0];

  // Register bank
  reg_bank #(
    .REG_W(REG_WIDTH),
    .ADDR_W(ADDR_REG_BANK_W),
    .NUM_CFG(NUM_CFG),
    .NUM_STATUS(NUM_STATUS)
  ) reg_bank_i (
    .clk(clk),
    .rstb(rstb),
    .ena(ena),
    .wr_rdn(wr_rdn),
    .addr(addr_reg_bank),
    .rdata(rdata),
    .wdata(wdata),
    .we(we),
    .ack(ack),
    .err(err),
    .rw_regs(rw_regs),
    .ro_regs(ro_regs)
  );

  // Provide read data to both peripherals
  assign spi_rdata = rdata;
  assign i2c_rdata = rdata;

  // List all unused inputs to prevent warnings
  logic _unused = &{spi_addr[REG_WIDTH-1:ADDR_REG_BANK_W], addr[REG_WIDTH-1:ADDR_REG_BANK_W], ack, err, 1'b0};

endmodule
