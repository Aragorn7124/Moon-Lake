`timescale 1ns/1ps

module Tb_Cpu;

  reg clk;
  reg rst_n;

  wire [31:0] pc;
  wire [31:0] inst;
  wire [31:0] dmem_addr;
  wire [31:0] dmem_wdata;
  wire [31:0] dmem_rdata;
  wire dmem_re;
  wire dmem_we;
  wire [3:0] dmem_be;

// u_module
  Cpu u_Cpu(
    .clk(clk),
    .rst_n(rst_n),
    .dmem_rdata(dmem_rdata),
    .inst(inst),

    .pc(pc),
    .dmem_wdata(dmem_wdata),
    .dmem_be(dmem_be),
    .dmem_addr(dmem_addr),
    .dmem_re(dmem_re),
    .dmem_we(dmem_we)
  );

// inst MEM space 4KB
  reg [31:0] imem[0:1023];

// data MEM space 4KB
  reg [31:0] dmem[0:1023];

// pc get inst
  assign inst = imem[pc[11:2]];

// read dmem data
  assign dmem_rdata = dmem[dmem_addr[11:2]];

// wirte dmem data
  always @(posedge clk) begin
    if(dmem_we) begin
      if(dmem_be[0]) begin
        dmem[dmem_addr[11:2]][7:0] <= dmem_wdata[7:0];
      end
      if(dmem_be[1]) begin
        dmem[dmem_addr[11:2]][15:8] <= dmem_wdata[15:8];
      end

      if(dmem_be[2]) begin
        dmem[dmem_addr[11:2]][23:16] <= dmem_wdata[23:16];
      end

      if(dmem_be[3]) begin
        dmem[dmem_addr[11:2]][31:24] <= dmem_wdata[31:24];
      end
    end
  end

// clk
  initial begin
    clk = 0;
    forever begin
      #10;
      clk = ~clk;
    end
  end

// rst
  initial begin
    rst_n = 0;
    #50;
    rst_n = 1;
  end

// vcd
  initial begin
    $dumpfile("Tb_Cpu.vcd");
    $dumpvars(0,Tb_Cpu.u_Cpu);
  end


// sim init
  integer i;
  initial begin
    for(i=0; i<1024; i=i+1) begin
      imem[i] = 32'h00000013;
      dmem[i] = 32'd0;
    end



    $readmemh("test.hex", imem);

        #2000;
    $display("--- Simulation Finished ---");
    $display("x3 (should be 30) = %d", u_Cpu.u_GPR.regs[3]);
    $display("x4 (should be 30) = %d", u_Cpu.u_GPR.regs[4]);
    $display("x5 (should be 0)  = %d", u_Cpu.u_GPR.regs[5]);
    $display("x6 (should be 1)  = %d", u_Cpu.u_GPR.regs[6]);
    $finish;

  end
endmodule
