/*
 * Copyright (c) 2025 Caio Alonso da Costa
 * SPDX-License-Identifier: Apache-2.0
 */

module mux #(parameter int WIDTH = 4) (a, b, sel, dout);

  input logic [WIDTH-1:0] a;
  input logic [WIDTH-1:0] b;
  input logic sel;

  output logic [WIDTH-1:0] dout;

  logic [WIDTH-1:0] s_out;

  always_comb begin
    case (sel)
      1'b0 : s_out = a;
      1'b1 : s_out = b;
      default : s_out = '0;
    endcase
  end

  assign dout = s_out;

endmodule
