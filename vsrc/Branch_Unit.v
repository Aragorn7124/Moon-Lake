module Branch_Unit(
  input [31:0] rs1_data,
  input [31:0] rs2_data,
  input [31:0] pc,
  input [31:0] imm,
  input [2:0] funct3,
  input is_branch,
  input is_jal,

  output reg branch_taken,
  output [31:0] branch_target
);

// target addr
  assign branch_target = pc + imm;

// branch taken check (JAL>branch)
  always @(*) begin
    branch_taken = 1'b0;
    if(is_jal) begin
      branch_taken = 1'b1;
    end
    else if(is_branch) begin
      case (funct3)
        3'b000: branch_taken = (rs1_data == rs2_data);// BEQ
        3'b001: branch_taken = (rs1_data != rs2_data); // BNE
        3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));//BLT
        3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));//BGE
        3'b110: branch_taken = (rs1_data < rs2_data); // BLTU
        3'b111: branch_taken = (rs1_data >= rs2_data); //BGEU
        default: branch_taken = 1'b0;
      endcase
    end
  end
endmodule
