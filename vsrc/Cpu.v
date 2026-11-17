`include "RV32i_def.vh"
module Cpu (
  input clk,
  input rst_n,

  // IF port
  output [31:0] pc,
  input [31:0] inst,

  // MEM port
  output [31:0] dmem_addr,
  output [31:0] dmem_wdata,
  input [31:0] dmem_rdata,
  output dmem_we,
  output dmem_re,
  output [3:0] dmem_be
);

// wire
  // IF -- instruction fetch and up pc
    // Drv by Pc_U
      wire [31:0] pc_plus_4; //  used by GPR rd need MUX

  // ID -- Decode fetch and output ctrl sign
    //Drv by RV32i_Decoder
      wire [4:0] rd; // used by GPR
      wire [4:0] rs1; // used by GPR
      wire [4:0] rs2; // used by GPR
      wire [2:0] imm_fmt; // used by Imm_Decode
      wire reg_we; // used by GPR
      wire [2:0] mem_size; // used by S/L_U
      wire [1:0] wb_src_sel; // used by GPR, need MUX
      wire alu_a_src_sel; // used by ALU , need MUX
      wire alu_b_src_sel; // used by ALU , need MUX
      wire [3:0] alu_op; // used by ALU, need MUX
      wire is_branch; // used by Branch_U
      wire is_jalr; // used by Pc_U
      wire is_jal; // used by Branch_U
      wire is_ebreak; //
      wire is_ecall; // used by
      wire is_fence; // used by
      wire illegal_inst; // used by


    //Drv by Imm_Decode
      wire [31:0] imm; // used by ALU, GPR need MUX

    //Drv by Branch_Unit
      wire branch_taken; // used by Pc_U
      wire [31:0] branch_target; // used by Pc_U

    //Drv by GPR
      wire [31:0] rs1_data;
      wire [31:0] rs2_data;

    //Drv by Load Unit
      wire [31:0] load_data; // used gpr wb

    //Drv by ALU
      wire [31:0] alu_result;
      wire [1:0] low_addr; // used by Store_U and Load_U


  // MUX
    // GPR
      reg [31:0] gpr_rd_data;
      always @(*) begin
        case (wb_src_sel)
          2'b00: gpr_rd_data = alu_result;
          2'b01: gpr_rd_data = load_data;
          2'b10: gpr_rd_data = pc_plus_4;
          2'b11: gpr_rd_data = imm;
          default: gpr_rd_data = 32'b0;
        endcase
      end

    // ALU MUX
      wire [31:0] alu_operand_a;
      assign alu_operand_a = alu_a_src_sel? pc : rs1_data;

      wire [31:0] alu_operand_b;
      assign alu_operand_b = alu_b_src_sel? imm : rs2_data;

      assign dmem_addr = alu_result;
      assign low_addr = alu_result[1:0];






// u module
  Pc_Unit u_Pc_Unit (
    .clk(clk),
    .rst_n(rst_n),
    .branch_taken(branch_taken),
    .branch_target(branch_target),
    .is_jalr(is_jalr),
    .alu_result(alu_result),

    .pc(pc),
    .pc_plus_4(pc_plus_4)
  );

  RV32i_Decoder u_RV32i_Decoder(
    .inst(inst),

    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm_fmt(imm_fmt),
    .reg_we(reg_we),
    .wb_src_sel(wb_src_sel),
    .mem_we(dmem_we),
    .mem_re(dmem_re),
    .mem_size(mem_size),
    .alu_a_src_sel(alu_a_src_sel),
    .alu_b_src_sel(alu_b_src_sel),
    .alu_op(alu_op),
    .is_branch(is_branch),
    .is_jalr(is_jalr),
    .is_jal(is_jal),
    .is_ebreak(is_ebreak),
    .is_ecall(is_ecall),
    .is_fence(is_fence),
    .illegal_inst(illegal_inst)
  );

  Imm_Decode u_Imm_Decode (
    .inst(inst),
    .imm_fmt(imm_fmt),

    .imm(imm)
  );

  Branch_Unit u_Branch_Unit (
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .pc(pc),
    .imm(imm),
    .funct3(mem_size),
    .is_branch(is_branch),
    .is_jal(is_jal),

    .branch_taken(branch_taken),
    .branch_target(branch_target)
  );

  GPR u_GPR(
    .clk(clk),
    .rst_n(rst_n),
    .r_addr1(rs1),
    .r_addr2(rs2),
    .w_en(reg_we),
    .w_addr(rd),
    .w_data(gpr_rd_data),

    .r_data1(rs1_data),
    .r_data2(rs2_data)
  );

  Alu u_Alu (
    .a(alu_operand_a),
    .b(alu_operand_b),
    .alu_op(alu_op),

    .result(alu_result)
  );

  Store_Unit u_Store_Unit(
    .rs2_data(rs2_data),
    .low_addr(low_addr),
    .mem_size(mem_size),
    .dmem_we(dmem_we),

    .dmem_wdata(dmem_wdata),
    .dmem_be(dmem_be)
  );

  Load_Unit u_Load_Unit(
    .dmem_data(dmem_rdata),
    .low_addr(low_addr),
    .mem_size(mem_size),

    .load_data(load_data)
  );

endmodule
