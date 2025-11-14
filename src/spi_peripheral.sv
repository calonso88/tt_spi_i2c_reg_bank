/*
 * Copyright (c) 2024 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

module spi_peripheral #(
    parameter int REG_W = 8
) (
    input  logic clk,
    input  logic rstb,
    input  logic ena,

    // serial interface
    input  logic spi_mosi,
    output logic spi_miso,
    output logic spi_miso_oe,
    input  logic spi_clk,
    input  logic spi_cs_n,
    // CPOL and CPHA
    input  logic [1:0] mode,
    // first byte in frame
    input  logic [REG_W-1:0] status,

    // application interface
    output logic             wr_rdn,
    output logic [REG_W-2:0] addr,
    input  logic [REG_W-1:0] rdata,
    output logic [REG_W-1:0] wdata,
    output logic             we
);

  // Start of frame - negedge of spi_cs_n
  logic sof;
  // Pulse on start of frame
  falling_edge_detector falling_edge_detector_sof (.rstb(rstb), .clk(clk), .ena(ena), .data(spi_cs_n), .neg_edge(sof));
  // End of frame - posedge of spi_cs_n
  logic eof;
  // Pulse on end of frame
  rising_edge_detector rising_edge_detector_eof (.rstb(rstb), .clk(clk), .ena(ena), .data(spi_cs_n), .pos_edge(eof));

  // Pulses on rising and falling edge of spi_clk
  logic spi_clk_pos;
  logic spi_clk_neg;

  // Pulse on rising edge of spi_clk
  rising_edge_detector rising_edge_detector_spi_clk (.rstb(rstb), .clk(clk), .ena(ena), .data(spi_clk), .pos_edge(spi_clk_pos));
  // Pulse on falling edge of spi_clk
  falling_edge_detector falling_edge_detector_spi_clk (.rstb(rstb), .clk(clk), .ena(ena), .data(spi_clk), .neg_edge(spi_clk_neg));

  // Mask with spi_cs_n
  logic spi_clk_pos_gated;
  logic spi_clk_neg_gated;

  assign spi_clk_pos_gated = spi_clk_pos & ~spi_cs_n;
  assign spi_clk_neg_gated = spi_clk_neg & ~spi_cs_n;

  // Sample data
  logic spi_data_sample;
  // Change data
  logic spi_data_change;

  // Assert according to SPI Config
  always_comb begin
      case ( mode )
      2'b00 : begin
        spi_data_sample = spi_clk_pos_gated;
        spi_data_change = spi_clk_neg_gated;
      end
      2'b01 : begin
        spi_data_sample = spi_clk_neg_gated;
        spi_data_change = spi_clk_pos_gated;
      end
      2'b10 : begin
        spi_data_sample = spi_clk_neg_gated;
        spi_data_change = spi_clk_pos_gated;
      end
      2'b11 : begin
        spi_data_sample = spi_clk_pos_gated;
        spi_data_change = spi_clk_neg_gated;
      end
      default : begin
        spi_data_sample = spi_clk_neg_gated;
        spi_data_change = spi_clk_pos_gated;
      end
    endcase
  end

  // FSM states type
  typedef enum logic [2:0] {
    STATE_IDLE, STATE_ADDR, STATE_CMD, STATE_RX_DATA, STATE_TX_DATA
  } fsm_state;

  // FSM states
  fsm_state state, next_state;

  // Next state transition
  always_ff @(negedge(rstb) or posedge(clk)) begin
    if (!rstb) begin
      state <= STATE_IDLE;
    end else begin
      if (ena) begin
        state <= next_state;
      end
    end
  end

  // Sample addr and data
  logic tx_buffer_load;
  logic sample_addr;
  logic sample_data;

  // Next state logic
  always_comb begin
    // default assignments
    next_state = state;
    tx_buffer_load = 1'b0;
    sample_addr = 1'b0;
    sample_data = 1'b0;

    case (state)
      STATE_IDLE : begin
        if (sof) begin
          next_state = STATE_ADDR;
        end
      end
      STATE_ADDR : begin
        if (buffer_counter == REG_W) begin
          sample_addr = 1'b1;
          next_state = STATE_CMD;
        end else if (eof) begin
          next_state = STATE_IDLE;
        end
      end
      STATE_CMD : begin
        if (reg_rw == 1'b0) begin
          next_state = STATE_TX_DATA;
        end else if (reg_rw) begin
          next_state = STATE_RX_DATA;
        end else if (eof) begin
          next_state = STATE_IDLE;
        end
      end
      STATE_RX_DATA : begin
        if (buffer_counter == REG_W) begin
          sample_data = 1'b1;
          next_state = STATE_IDLE;
        end else if (eof) begin
          next_state = STATE_IDLE;
        end
      end
      STATE_TX_DATA : begin
        if (buffer_counter == '0) begin
          tx_buffer_load = 1'b1;
        end else if (buffer_counter == REG_W) begin
          next_state = STATE_IDLE;
        end else if (eof) begin
          next_state = STATE_IDLE;
        end
      end
      default : begin
        next_state = STATE_IDLE;
      end
    endcase
  end

  // RX Buffer
  logic [REG_W-1:0] rx_buffer;

  // RX Buffer
  always_ff @(negedge(rstb) or posedge(clk)) begin
    if (!rstb) begin
      rx_buffer <= '0;
    end else begin
      if (ena) begin
        if (spi_data_sample) begin
          rx_buffer <= {rx_buffer[REG_W-2:0], spi_mosi};
        end
      end
    end
  end

  // General counter
  logic [3:0] buffer_counter;

  // Buffer Counter
  always_ff @(negedge(rstb) or posedge(clk)) begin
    if (!rstb) begin
      buffer_counter <= '0;
    end else begin
      if (ena) begin
        if (buffer_counter == REG_W) begin
          buffer_counter <= '0;
        end else if (spi_data_sample) begin
          buffer_counter <= buffer_counter + 1'b1;
        end
      end
    end
  end

  // Addr and Read/Write Command register
  logic [REG_W-2:0] reg_addr;
  logic reg_rw;

  // Addr and Read/Write Command Registers
  always_ff @(negedge(rstb) or posedge(clk)) begin
    if (!rstb) begin
      reg_addr <= '0;
      reg_rw <= '0;
    end else begin
      if (ena) begin
        if (sample_addr) begin
          reg_addr <= rx_buffer[REG_W-2:0];
          reg_rw <= rx_buffer[REG_W-1];
        end
      end
    end
  end

  // Data register and data valid strobe
  logic [REG_W-1:0] reg_data;
  logic reg_we;

  // Data and write enable Registers
  always_ff @(negedge(rstb) or posedge(clk)) begin
    if (!rstb) begin
      reg_data <= '0;
      reg_we <= '0;
    end else begin
      if (ena) begin
        reg_we <= '0;
        if (sample_data) begin
          reg_data <= rx_buffer;
          reg_we <= reg_rw;
        end
      end
    end
  end

  // TX Buffer
  logic [REG_W-1:0] tx_buffer;

  // TX Buffer
  always_ff @(negedge(rstb) or posedge(clk)) begin
    if (!rstb) begin
      tx_buffer <= '0;
    end else begin
      if (ena) begin
        if (sof) begin
          tx_buffer <= status;
        end else if (tx_buffer_load) begin
          tx_buffer <= rdata;
        end else if (spi_data_change) begin
          tx_buffer <= {tx_buffer[REG_W-2:0], 1'b0};
        end
      end
    end
  end

  // Map to outputs
  assign wr_rdn = reg_rw;
  assign addr = reg_addr;
  assign wdata = reg_data;
  assign we = reg_we;
  assign spi_miso = tx_buffer[REG_W-1];
  assign spi_miso_oe = spi_cs_n;

endmodule
