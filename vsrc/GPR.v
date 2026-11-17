module GPR (
  input clk,
  input rst_n,
  //read port 1
  input [4:0] r_addr1,
  output [31:0] r_data1,
  //read port 2
  input [4:0] r_addr2,
  output [31:0] r_data2,
  //write port
  input w_en,
  input [4:0] w_addr,
  input [31:0] w_data
);

// Regs def
  reg [31:0] regs [31:0];

// read GPR impl
  assign r_data1 = (r_addr1 == 5'd0)? 32'd0 : regs[r_addr1];
  assign r_data2 = (r_addr2 == 5'd0)? 32'd0 : regs[r_addr2];

// write GPR impl
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
      for(i=0; i<32; i=i+1)begin
        regs[i] <= 32'd0;
      end
    end
    else if(w_en && (w_addr != 5'd0)) begin
      regs[w_addr] <= w_data;
    end
  end


endmodule
