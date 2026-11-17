module Load_Unit (
  input [31:0] dmem_data,
  input [1:0] low_addr,
  input [2:0] mem_size,

  output reg [31:0] load_data
);

// vars byte and half def
  reg [7:0] byte_data;
  wire [15:0] half_data;

// byte sel
  always @(*) begin
    case(low_addr)
      2'b00: byte_data = dmem_data[7:0];
      2'b01: byte_data = dmem_data[15:8];
      2'b10: byte_data = dmem_data[23:16];
      2'b11: byte_data = dmem_data[31:24];
      default: byte_data = 8'b0;
    endcase
  end

// half data sel
  assign half_data = (low_addr[1] == 1'b0)? dmem_data[15:0] : dmem_data[31:16];


// sel extend mode by mem_size
  always @(*) begin
    case(mem_size)
      3'b000: load_data = {{24{byte_data[7]}}, byte_data};
      3'b100: load_data = {24'b0, byte_data};
      3'b001: load_data = {{16{half_data[15]}}, half_data};
      3'b101: load_data = {16'b0, half_data};
      3'b010: load_data = dmem_data;
      default: load_data = 32'b0;
    endcase
  end

endmodule
