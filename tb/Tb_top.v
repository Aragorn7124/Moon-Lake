`timescale 1ns/1ps

module Tb_top;

  reg clk;
  reg rst_n;

  wire uart_txd;
  wire [3:0] led;

// u_module
  top u_top(
    .clk(clk),
    .rst_n(rst_n),
    .uart_rxd(1'b1),
    .uart_txd(uart_txd),
    .led(led)
  );

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

// wite

// vcd
  initial begin
    $dumpfile("Tb_Cpu.vcd");
    $dumpvars(0,Tb_top);
  end


// sim init
  integer i;
  initial begin
    #5000;



        $display("--- SoC Simulation Finished ---");
        // 通过层次化路径偷看 CPU 的寄存器（路径: tb_top -> u_top -> u_Cpu -> u_GPR -> regs）
        $display("x3 (should be 30) = %d", u_top.u_Cpu.u_GPR.regs[3]);
        $display("x4 (should be 30) = %d", u_top.u_Cpu.u_GPR.regs[4]);
        $display("x5 (should be 0)  = %d", u_top.u_Cpu.u_GPR.regs[5]);
        $display("x6 (should be 1)  = %d", u_top.u_Cpu.u_GPR.regs[6]);
        $display("PC (should be loop) = 0x%h", u_top.pc);
        $finish;
  end
endmodule
