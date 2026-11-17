module Alu (
  input [31:0] a,
  input [31:0] b,
  input [3:0] alu_op,

  output reg [31:0] result
);
// ALU op def
  localparam ADD = 4'd0;
  localparam SUB = 4'd1;
  localparam AND = 4'd2;
  localparam OR = 4'd3;
  localparam XOR = 4'd4;
  localparam SLL = 4'd5;
  localparam SRL = 4'd6;
  localparam SRA = 4'd7;
  localparam SLT = 4'd8;
  localparam SLTU = 4'd9;


// ALU impl
  always @(*) begin
    case(alu_op)
      ADD: result = a + b;

      SUB: result = a - b;

      AND: result = a & b;

      OR: result = a | b;

      XOR: result = a ^ b;

      SLL: result = a << b[4:0];

      SRL: result = a >> b[4:0];

      SRA: result = $signed(a) >>> b[4:0];

      SLT: result = ($signed(a) < $signed(b))? 32'd1 : 32'd0;

      SLTU: result = (a < b)? 32'd1 : 32'd0;


      default: result = 32'd0;
    endcase
  end

endmodule

