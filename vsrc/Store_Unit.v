module Store_Unit (
  input [31:0] rs2_data,
  input [1:0] low_addr,
  input [2:0] mem_size,
  input dmem_we,

  output reg [31:0] dmem_wdata,
  output reg [3:0] dmem_be
);

// Store impl
  always @(*) begin
    dmem_be = 4'b0000;
    dmem_wdata = 32'd0;
    if(dmem_we) begin
      case(mem_size)
        3'b010: begin
          dmem_be = 4'b1111;
          dmem_wdata = rs2_data;
        end

        3'b000: begin
          dmem_be = 4'b0001 << low_addr;
          dmem_wdata = {4{rs2_data[7:0]}};
        end

        3'b001: begin
          dmem_be = (low_addr[1])? 4'b1100 : 4'b0011;
          dmem_wdata = {2{rs2_data[15:0]}};
        end

        default: begin
          dmem_be = 4'b0000;
          dmem_wdata = 32'd0;
        end
      endcase
    end
  end
endmodule
