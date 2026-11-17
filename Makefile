# file dir
VSRC_DIR = vsrc
TB_DIR = tb
SIM_DIR = sim
VCD_DIR = vcd
INCLUDE = $(VSRC_DIR)/include

# file
TB_NAME ?=
VSRCS = $(wildcard $(VSRC_DIR)/*.v) $(TB_DIR)/$(TB_NAME).v
VVP_FILE = $(addsuffix .vvp, $(TB_NAME))
VCD_FILE = $(addsuffix .vcd, $(TB_NAME))

# tool
CC = iverilog
CC_FLAGS = -I $(INCLUDE)

# cmd
com: $(VSRCS)
	$(CC) $(CC_FLAGS) -o $(VVP_FILE) $(VSRCS)

sim: com
	vvp $(VVP_FILE)

look: sim
	gtkwave $(VCD_FILE)
