module Pc_Unit (
  input clk,
  input rst_n,

  // jmp sign ctrl
  input branch_taken,
  input is_jalr,

  // jmp sign addr
  input [31:0] branch_target,
  input [31:0] alu_result,

  // output
  output [31:0] pc,
  output [31:0] pc_plus_4
);

// pc reg
  reg [31:0] pc_reg;
  wire [31:0] pc_next;

// wire
  assign pc = pc_reg;
  assign pc_plus_4 = pc_reg + 4;

// next pc
  assign pc_next = is_jalr     ? (alu_result & 32'hffff_fffe)     :
                   branch_taken? branch_target  :
                                 pc_plus_4;

// rst pc
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      pc_reg <= 32'h00000000;
    end
    else begin
      pc_reg <= pc_next;
    end
  end
endmodule



