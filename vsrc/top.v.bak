module top(
  input clk,
  input rst_n,

  //UART
  input uart_rxd,
  output uart_txd,

  output [3:0] led
);

//wire
  // Drv by Cpu
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [31:0] pc;
    wire dmem_re;
    wire dmem_we;
    wire [3:0] dmem_be;
    wire [31:0] inst;
    wire [31:0] dmem_rdata;

// CPU
  Cpu u_Cpu (
    .clk(clk),
    .rst_n(rst_n),
    .inst(inst),
    .dmem_rdata(dmem_rdata),

    .dmem_addr(dmem_addr),
    .dmem_wdata(dmem_wdata),
    .pc(pc),
    .dmem_re(dmem_re),
    .dmem_we(dmem_we),
    .dmem_be(dmem_be)
  );

// ROM
  reg [31:0] rom[0:1023];

  // init rom
    integer i;
    initial begin
      for(i=0; i<1024; i=i+1) begin
        rom[i] = 32'h00000013;
      end
      $readmemh("test.hex", rom);
    end

// RAM
  reg [31:0] ram[0:3071];

  // init ram
    integer y;
    initial begin
      for(y=0; y<3072; y=y+1) begin
        ram[y] = 32'h00000000;
      end
    end

// if addr decode
  wire if_is_rom;
  wire if_is_ram;

  assign if_is_rom = (pc < 32'h0000_1000);
  assign if_is_ram = (pc >= 32'h0001_0000) && (pc < 32'h0001_3000);

  assign inst = if_is_rom? rom[pc[11:2]] :
                if_is_ram? ram[pc[13:2]] :
                  32'h0000_0000;

// memory access addr
  wire mem_is_rom;
  wire mem_is_ram;

  assign mem_is_rom = (dmem_addr < 32'h0000_1000);
  assign mem_is_ram = (dmem_addr >= 32'h0001_0000) && (dmem_addr < 32'h0001_3000);

  assign dmem_rdata = mem_is_ram? ram[dmem_addr[13:2]] :
                      mem_is_rom? rom[dmem_addr[11:2]] :
                      32'h0000_0000;

// RAM wirte impl


  wire ram_we;
  assign ram_we = mem_is_ram & dmem_we;

  always @(posedge clk) begin
    if(ram_we) begin
      if(dmem_be[0]) begin
        ram[dmem_addr[13:2]][7:0] <= dmem_wdata[7:0];
      end

      if(dmem_be[1]) begin
        ram[dmem_addr[13:2]][15:8] <= dmem_wdata[15:8];
      end

      if(dmem_be[2]) begin
        ram[dmem_addr[13:2]][23:16] <= dmem_wdata[23:16];
      end

      if(dmem_be[3]) begin
        ram[dmem_addr[13:2]][31:24] <= dmem_wdata[31:24];
      end
    end
  end

// UART
  assign uart_txd = 1'b1;

// led check
  assign led[0] = dmem_we;
  assign led[1] = pc[2];
  assign led[2] = mem_is_ram && dmem_we;
  assign led[3] = mem_is_ram;

endmodule
