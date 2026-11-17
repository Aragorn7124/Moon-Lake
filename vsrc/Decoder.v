`include "RV32i_def.vh"
module RV32i_Decoder(
  input [31:0] inst,

  // Decode
  output [4:0] rd,
  output [4:0] rs1,
  output [4:0] rs2,

  // Imm fmt sel
  output [2:0] imm_fmt,

  //Reg Write Back
  output reg_we,
  output [1:0] wb_src_sel,// 00:alu 01:mem 10:pc+4 11:imm

  //Mem access ctrl
  output mem_we,
  output mem_re,
  output [2:0] mem_size, // mem funct3

  //Alu ctrl
  output alu_a_src_sel, // 0:rs1  1:pc
  output alu_b_src_sel, // 0:rs2  1:imm
  output [3:0] alu_op,

  // ctrl stream sign
  output is_branch,
  output is_jalr,
  output is_jal,
  output is_ebreak,
  output is_ecall,
  output is_fence,
  output illegal_inst
);

  //decode pos
  wire [6:0] funct7;
  wire [2:0] funct3;
  wire [6:0] opcode;
  assign rd = inst[11:7];
  assign rs1 = inst[19:15];
  assign rs2 = inst[24:20];
  assign funct3 = inst[14:12];
  assign funct7 = inst[31:25];
  assign opcode = inst[6:0];

  // imm fmt sel
    // inst op def
      localparam S_STORE = 7'b0100011; //  S type store

      localparam B_BRANCH = 7'b1100011; // B type br

      localparam U_LUI = 7'b0110111; // U type lui
      localparam U_AUIPC = 7'b0010111; // U type auipc

      localparam J_JAL = 7'b1101111; // J type jal



    // imm fmt sel impl
      assign imm_fmt = (opcode == S_STORE)?                     `RV32I_IMM_FMT_S :
                       (opcode == B_BRANCH)?                    `RV32I_IMM_FMT_B :
                       (opcode == U_LUI || opcode == U_AUIPC)?  `RV32I_IMM_FMT_U :
                       (opcode == J_JAL)?                       `RV32I_IMM_FMT_J :
                                                                `RV32I_IMM_FMT_I;




  //ctrl flag

    //addi op = 0010011 f =000
    wire is_addi;
    assign is_addi = (opcode == 7'b0010011) & (funct3 == 3'b000);

    //jalr op = 1100111 f = 000
    assign is_jalr = (opcode == 7'b1100111) & (funct3 == 3'b000);

    //lui op = 0110111
    wire is_lui;
    assign is_lui = (opcode == 7'b0110111);

    //add op = 0110011 f = 000
    wire is_add;
    assign is_add = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0000000);

    //lw op = 0000011 f = 010
    wire is_lw;
    assign is_lw = (opcode == 7'b0000011) & (funct3 == 3'b010);

    //lbu op = 0000011 f = 100
    wire is_lbu;
    assign is_lbu = (opcode == 7'b0000011) & (funct3 == 3'b100);

    //sw op = 0100011 f = 010
    wire is_sw;
    assign is_sw = (opcode == 7'b0100011) & (funct3 == 3'b010);

    //sb op = 0100011 f = 000
    wire is_sb;
    assign is_sb = (opcode == 7'b0100011) & (funct3 == 3'b000);

    //andi op = 0010011, funct3 = 111
    wire is_andi;
    assign is_andi = (opcode == 7'b0010011) & (funct3 == 3'b111);

    //slli op = 0010011, funct3 = 001
    wire is_slli;
    assign is_slli = (opcode == 7'b0010011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);

    // sub op = 0110011, funct3 = 000 funct7 = 0100000
    wire is_sub;
    assign is_sub = (opcode == 7'b0110011) & (funct3 == 3'b000) & (funct7 == 7'b0100000);

    // auipc op = 0010111
    wire is_auipc;
    assign is_auipc = (opcode == 7'b0010111);

    // jal op = 1101111
    assign is_jal = (opcode == 7'b1101111);

    //beq op = 1100011 funct3 = 000
    wire is_beq;
    assign is_beq = (opcode == 7'b1100011) & (funct3 == 3'b000);

    //bne op = 110011 funct3 = 001
    wire is_bne;
    assign is_bne = (opcode == 7'b1100011) & (funct3 == 3'b001);

    //blt op = 1100011 funct3 = 100
    wire is_blt;
    assign is_blt = (opcode == 7'b1100011) & (funct3 == 3'b100);

    //bge op = 1100011 funct3 = 101
    wire is_bge;
    assign is_bge = (opcode == 7'b1100011) & (funct3 == 3'b101);

    //bltu op = 1100011 funct3 = 110
    wire is_bltu;
    assign is_bltu = (opcode == 7'b1100011) & (funct3 == 3'b110);

    //bgeu op = 1100011 funct3 = 111
    wire is_bgeu;
    assign is_bgeu = (opcode == 7'b1100011) & (funct3 == 3'b111);

    //lb op = 0000011 funct3 = 000
    wire is_lb;
    assign is_lb = (opcode == 7'b0000011) & (funct3 == 3'b000);

    //lh op = 0000011 funct3 = 001
    wire is_lh;
    assign is_lh = (opcode == 7'b0000011) & (funct3 == 3'b001);

    //lhu op = 0000011 funct3 = 101
    wire is_lhu;
    assign is_lhu = (opcode == 7'b0000011) & (funct3 == 3'b101);

    //sh op = 0100011 funct3 = 001
    wire is_sh;
    assign is_sh = (opcode == 7'b0100011) & (funct3 == 3'b001);

    //slti op = 0010011 funct3 = 010
    wire is_slti;
    assign is_slti = (opcode == 7'b0010011) & (funct3 == 3'b010);

    //sltiu op = 0010011 funct3 = 011
    wire is_sltiu;
    assign is_sltiu = (opcode == 7'b0010011) & (funct3 == 3'b011);

    //xori op = 0010011 funct3 = 100
    wire is_xori;
    assign is_xori = (opcode == 7'b0010011) & (funct3 == 3'b100);

    //ori op = 0010011 funct3 = 110
    wire is_ori;
    assign is_ori = (opcode == 7'b0010011) & (funct3 == 3'b110);

    //srli op = 0010011 funct3 = 101 f7 = 0000000
    wire is_srli;
    assign is_srli = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);

    //srai op = 0010011 funct3 = 101 f7 = 0100000
    wire is_srai;
    assign is_srai = (opcode == 7'b0010011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);

    //sll op = 0110011 funct3 = 001 f7 = 0000000
    wire is_sll;
    assign is_sll = (opcode == 7'b0110011) & (funct3 == 3'b001) & (funct7 == 7'b0000000);

    //slt op = 0110011 funct3 = 010 f7 = 0000000
    wire is_slt;
    assign is_slt = (opcode == 7'b0110011) & (funct3 == 3'b010) & (funct7 == 7'b0000000);

    //sltu op = 0110011 funct3 = 011,f7 = 0000000
    wire is_sltu;
    assign is_sltu = (opcode == 7'b0110011) & (funct3 == 3'b011) & (funct7 == 7'b0000000);

    //XOR op = 0110011 funct3 = 100, f7 = 0000000
    wire is_xor;
    assign is_xor = (opcode == 7'b0110011) & (funct3 == 3'b100) & (funct7 == 7'b0000000);

    //srl op = 0110011 fun3 = 101 f7 = 0000000
    wire is_srl;
    assign is_srl = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0000000);

    //sra op = 0110011 funct3 = 101 f7 = 0100000
    wire is_sra;
    assign is_sra = (opcode == 7'b0110011) & (funct3 == 3'b101) & (funct7 == 7'b0100000);

    //OR op = 0110011 funct3 = 110 f7 = 0000000
    wire is_or;
    assign is_or = (opcode == 7'b0110011) & (funct3 == 3'b110) & (funct7 == 7'b0000000);

    //and op = 0110011 funct3 = 111 f7 = 0000000
    wire is_and;
    assign is_and = (opcode == 7'b0110011) & (funct3 == 3'b111) & (funct7 == 7'b0000000);

    //ecall inst is 0x00000073
    assign is_ecall = (inst == 32'h00000073);

    // fence: op = 0001111
    assign is_fence = (opcode == 7'b0001111) & (funct3 == 3'b000);


  //inst allowlist
    assign illegal_inst = ~(is_add | is_sub | is_sll | is_slt | is_sltu | is_xor | is_srl | is_sra | is_or | is_and | is_addi | is_slti | is_sltiu | is_xori | is_ori | is_andi | is_slli | is_srli | is_srai | is_lb | is_lh | is_lw | is_lbu | is_lhu | is_sb | is_sh | is_sw | is_beq | is_bne | is_blt | is_bge | is_bltu | is_bgeu | is_jal | is_jalr | is_lui | is_auipc | is_ecall | is_ebreak | is_fence
    );




  //reg w ctrl
  assign reg_we = is_addi | is_jalr | is_lui | is_add | is_lw | is_lbu | is_andi | is_slli | is_sub | is_auipc | is_jal | is_lb |is_lh | is_lhu | is_slti | is_sltiu | is_xori | is_ori | is_srli | is_srai | is_sll | is_slt | is_sltu | is_xor | is_srl | is_sra | is_or | is_and;

  //alu a src chose 0=rs1 1:pc
  assign alu_a_src_sel = is_auipc;
  //alu b src chose 0:rs2 1:imm
  assign alu_b_src_sel = is_addi | is_jalr | is_lw | is_lbu | is_sw | is_sb | is_andi | is_slli | is_auipc | is_lb | is_lh | is_lhu | is_ori |
  is_sh | is_slti | is_sltiu | is_xori | is_srli | is_srai;

  //wb ctrl
  assign wb_src_sel = (is_jalr | is_jal)? 2'b10 :
                  is_lui?    2'b11 :
                  is_lw?     2'b01 :
                  is_lb?     2'b01 :
                  is_lh?     2'b01 :
                  is_lhu?    2'b01 :
                  is_lbu?    2'b01 :
                             2'b00 ;

  //alu op choose
  assign alu_op = is_addi   ? 4'b0000 :  // ADD
                  is_auipc  ? 4'b0000 :  // ADD
                  is_sub    ? 4'b0001 :  // SUB
                  is_andi   ? 4'b0010 :  // AND
                  is_and    ? 4'b0010 :  // AND
                  is_ori    ? 4'b0011 :  // OR
                  is_or     ? 4'b0011 :  // OR
                  is_xori   ? 4'b0100 :  // XOR
                  is_xor    ? 4'b0100 :  // XOR
                  is_slli   ? 4'b0101 :  // SLL
                  is_sll    ? 4'b0101 :  // SLL
                  is_srli   ? 4'b0110 :  // SRL
                  is_srl    ? 4'b0110 :  // SRL
                  is_srai   ? 4'b0111 :  // SRA
                  is_sra    ? 4'b0111 :  // SRA
                  is_slti   ? 4'b1000 :  // SLT
                  is_slt    ? 4'b1000 :  // SLT
                  is_sltiu  ? 4'b1001 :  // SLTU
                  is_sltu   ? 4'b1001 :  // SLTU
                              4'b0000;    // default: ADD


  //mem
  assign mem_we = is_sw | is_sb | is_sh;
  assign mem_size = funct3;
  assign mem_re = is_lw | is_lbu | is_lb | is_lh | is_lhu;

  // ebreak
  assign is_ebreak = (inst == 32'h00100073);

  //is_branch instr
  assign is_branch = is_beq | is_bne | is_blt | is_bge | is_bltu | is_bgeu;


endmodule
