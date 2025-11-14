/*
 * Copyright (c) 2025 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

module reg_bank #(
    parameter int REG_W = 8,
    parameter int ADDR_W = 8,
    parameter int NUM_CFG = 8,
    parameter int NUM_STATUS = 8
) (
    input  logic clk,
    input  logic rstb,
    input  logic ena,
    // application interface
    input  logic wr_rdn,
    input  logic [ADDR_W-1:0] addr,
    output logic [REG_W-1:0]  rdata,
    input  logic [REG_W-1:0]  wdata,
    input  logic we,
    output logic ack,
    output logic err,
    // registers
    output logic [NUM_CFG*REG_W-1:0] rw_regs,
    input  logic [NUM_STATUS*REG_W-1:0] ro_regs
);

  // Limitations
  //  - NUM_CFG must be power of two
  //  - NUM_STATUS must be equal to NUM_CFG

  // Iterator
  int i;

  // rw registers
  logic [REG_W-1:0] config_regs [NUM_CFG-1:0];
  logic [REG_W-1:0] status_regs [NUM_STATUS-1:0];

  // handshake
  assign ack = 1'b1;
  assign err = 1'b0;

  // Mux to select config registers or read only registers access
  assign rdata = (addr[ADDR_W-1] == 1'b0) ? config_regs[addr[ADDR_W-2:0]] : status_regs[addr[ADDR_W-2:0]];

  // Register write
  always_ff @(posedge clk or negedge rstb) begin
    if (!rstb) begin
      for (i = 0; i < NUM_CFG; i++) begin
        config_regs[i] <= '0;
      end
    end else begin
      if (ena) begin
        if (we) begin
          config_regs[addr[ADDR_W-2:0]] <= wdata;
        end
      end
    end
  end

  // Generate variable
  genvar x, y;
  // Convert to unpacked array
  generate for (x = 0; x < NUM_STATUS; x = x + 1) begin
    assign status_regs[x] = ro_regs[((x+1)*REG_W-1) : x*REG_W];
  end endgenerate
  // Convert to 1 dimension packed array
  generate for (y = 0; y < NUM_CFG; y = y + 1) begin
    assign rw_regs[((y+1)*REG_W-1) : y*REG_W] = config_regs[y];
  end endgenerate

  // List all unused inputs to prevent warnings
  logic _unused = &{wr_rdn, 1'b0};

endmodule
