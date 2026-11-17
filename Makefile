#dir def
SRC_DIR = vsrc
TB_DIR = tb
INCLUDE_DIR = $(SRC_DIR)/include

#file def
VSRCS = $(wildcard $(SRC_DIR)/*.v) $(TB_DIR)/Tb_top.v
NAME ?= tb_top


#tool
CC = iverilog

com: $(VSRCS)
	$(CC) -I $(INCLUDE_DIR) -o $(NAME).vvp $(VSRCS)

vvp: com
	vvp $(NAME).vvp

look:
	gtkwave Tb_Cpu.vcd
