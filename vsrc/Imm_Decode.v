`include "RV32i_def.vh"
module Imm_Decode (
  input [31:0] inst,
  input [2:0] imm_fmt,
  output reg [31:0] imm
);
// Imm type def
  // I type imm
    wire [31:0] I_imm;
    assign I_imm = {{20{inst[31]}}, inst[31:20]};

  // U type imm
    wire [31:0] U_imm;
    assign U_imm = {inst[31:12], 12'd0};

  // S type imm
    wire [31:0] S_imm;
    assign S_imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};

  // B type imm
    wire [31:0] B_imm;
    assign B_imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};

  // J type imm
    wire [31:0] J_imm;
    assign J_imm = {{11{inst[31]}}, inst[31],inst[19:12], inst[20], inst[30:21], 1'b0};

// Decode imm impl
  always @(*) begin
    case (imm_fmt)

      `RV32I_IMM_FMT_I : imm = I_imm;
      `RV32I_IMM_FMT_S : imm = S_imm;
      `RV32I_IMM_FMT_B : imm = B_imm;
      `RV32I_IMM_FMT_U : imm = U_imm;
      `RV32I_IMM_FMT_J : imm = J_imm;

      default: imm = 32'd0;
    endcase
  end

endmodule

