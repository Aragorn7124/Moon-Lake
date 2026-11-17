# 基于新起点 FPGA 开发板的单周期 RV32I SoC 项目设计文档

**项目代号**：Moon_Lake
**目标平台**：新起点 FPGA 开发板（Cyclone IV，50 MHz 系统时钟）
**文档版本**：V1.0
**设计范围**：单周期 RV32I 子集 + Boot ROM + 12 KB RAM + UART MMIO + 极简 Monitor Shell。不包含中断、异常、CSR、特权级、流水线、Cache、MMU、原子指令、乘除法、非对齐访问、压缩指令。


## 1. 系统概述

本项目的最终形态是一台“可交互的极简计算机”：上电后，CPU 从 Boot ROM 中的 Monitor 固件开始执行，通过 UART 在 PC 串口终端上呈现一个极简 Shell。用户可以输入命令，将手写机器码或汇编生成的二进制程序加载到 RAM 中，然后通过 `run` 命令跳转执行。程序可以通过 UART 输出字符，也可以读取上位机发送的字符，形成完整的 “加载—执行—交互” 闭环。

新起点开发板提供了本项目所需的全部硬件资源：50 MHz 系统时钟（M2）、低电平有效复位（M1）、USB 串口（RX N5 / TX M7），以及充足的内部 BRAM 用于构建 Boot ROM 和 RAM。FPGA 侧的资源消耗预计在 1500–2500 LUT 量级，12 KB RAM 可使用 Cyclone IV 的 M9K 块实现，Boot ROM 的 4 KB 同样利用 M9K 配置为 ROM 模式。


## 2. 顶层规格与地址空间

### 2.1 地址映射

地址空间的划分遵循“高位译码、块边界对齐、不比较低位”的原则，避免产生地址别名。

| 区域 | 地址范围 | 容量 | 访问属性 | 说明 |
|---|---|---|---|---|
| Boot ROM | `0x0000_0000` – `0x0000_0FFF` | 4 KB | 只读，取指 + 数据读 | Monitor 固件 + 内置 echo 程序 |
| RAM | `0x0001_0000` – `0x0001_2FFF` | 12 KB | 读/写，取指 + 数据 | 用户程序、数据、栈 |
| UART | `0xFFFF_0000` – `0xFFFF_000F` | 16 B | MMIO 读/写 | 3 个寄存器，见 §2.3 |
| 未映射 | 其他地址 | — | 读回 0，写忽略 | 不产生总线错误 |

取指路径需要同时支持 ROM 和 RAM：Monitor 代码在 ROM 中执行，用户程序通过 Shell 的 `run` 命令跳转到 RAM 中执行。因此 CPU 的指令地址总线必须直接送入 ROM 和 RAM 的读端口，由地址译码决定返回哪一路数据。

### 2.2 复位向量

复位向量固定为 `0x0000_0000`，即 Boot ROM 的起始地址。CPU 复位后的第一条指令从 ROM 地址 0 处取指。链接脚本必须将 `.text.init` 段放置在 `0x0000_0000`，确保 Monitor 的 `_start` 入口恰好在复位向量上。

### 2.3 UART MMIO 寄存器定义

UART 使用三个 32 位寄存器，地址偏移与位定义如下：

| 偏移 | 名称 | 方向 | 位定义 |
|---|---|---|---|
| `+0x00` | `UART_TX` | 写 | `[7:0]`：待发送字节；写入即启动发送。UART 忙时写入被硬件丢弃。 |
| `+0x00` | `UART_STATUS` | 读 | `[0]`：`tx_busy`，1 表示发送进行中；`[1]`：`rx_ready`，1 表示接收数据有效。 |
| `+0x04` | `UART_RX` | 读 | `[7:0]`：接收到的字节；`[31]`：`rx_ready` 副本。读取即清除 `rx_ready` 锁存。 |

`tx_busy` 的轮询语义是：程序在写入 `UART_TX` 之前，必须先读取 `UART_STATUS` 并确认 `tx_busy == 0`。由于单周期 CPU 没有流水线和乱序执行，轮询循环“读状态→条件分支→写数据”在时序上是安全的。`rx_ready` 采用“读清”语义：CPU 读取 `UART_RX` 的同一拍，SoC 清除接收锁存器，避免同一字节被重复读取。

UART 的基地址 `0xFFFF_0000` 无法用 `addi` 的 12 位立即数直接构造，固件中需用 `lui` 配合 `addi` 或 `ori` 来物化基地址。例如：

```
lui  t0, 0xFFFF0        # t0 = 0xFFFF0000
lw   t1, 0(t0)          # 读 UART_STATUS
andi t1, t1, 1
bnez t1, wait_tx        # tx_busy 则等待
```

### 2.4 数据访存接口契约

CPU 对数据侧暴露一个五端口接口，SoC 顶层根据地址译码将写使能和读数据路由到 ROM / RAM / UART：

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `dmem_addr` | 输出 | 32 | 字节地址 |
| `dmem_wdata` | 输出 | 32 | 写数据 |
| `dmem_we` | 输出 | 1 | 写使能 |
| `dmem_re` | 输出 | 1 | 读使能 |
| `dmem_rdata` | 输入 | 32 | 读数据，由 SoC 的读 MUX 提供 |
| `dmem_be` | 输出 | 4 | **字节写使能**，`be[i]=1` 表示写 `dmem_wdata[8i+7:8i]` |

`dmem_be` 是支持 `sb` 和字节写 RAM 的关键。CPU 在执行 `sb` 时，根据地址低两位将 32 位 `dmem_wdata` 中对应的字节 lane 复制到所有字节位置，并将 `dmem_be` 设置为仅目标 lane 有效。RAM 的写端口使用 `be` 信号控制每个字节的写入。ROM 忽略 `dmem_we` 和 `dmem_be`。

## 3. CPU 核设计

### 3.1 指令集覆盖

CPU 实现 RV32I 的一个确定性子集，覆盖用户需求中列出的全部类别：

| 类别 | 指令 |
|---|---|
| 算术立即数 | `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai` |
| 算术寄存器 | `add`, `sub`, `slt`, `sltu`, `xor`, `or`, `and`, `sll`, `srl`, `sra` |
| 加载 | `lb`, `lh`, `lw`, `lbu`, `lhu` |
| 存储 | `sb`, `sh`, `sw` |
| 跳转 | `jal`, `jalr` |
| 条件分支 | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| 立即数构造 | `lui`, `auipc` |

**不实现**：`fence`（视为 `nop` 或直接不译码）、`ecall` / `ebreak`、CSR 指令、M 扩展乘除法、原子指令、压缩指令。

加载指令中的 `lb` / `lh` / `lbu` / `lhu` 必须做符号扩展或零扩展，并且**只从对齐地址读取**。固件和用户程序有责任生成对齐地址；CPU 不对非对齐访问做特殊处理，也不产生异常。

### 3.2 微架构

采用经典单周期数据通路，所有阶段在一个时钟周期内完成：

**取指**：PC 输出当前地址，直接送入 IMEM（ROM / RAM 的取指端口）。PC 在时钟上升沿更新为 `pc_next`。`pc_next` 由分支比较结果、`jal` / `jalr` 目标和顺序递增三者经 MUX 产生。

**译码**：控制单元从 32 位指令中提取 `opcode`、`funct3`、`funct7`，产生全部控制信号。寄存器堆为 32×32 双读单写，`x0` 硬连线为 0，写 `x0` 被忽略。

**立即数生成**：支持 I 型、S 型、B 型、U 型、J 型五种格式的符号扩展。B 型和 J 型的立即数需要左移 1 位并补 0。

**执行**：ALU 支持加、减、与、或、异或、逻辑左移、逻辑右移、算术右移、比较（有符号 / 无符号）、`lui` 直通、`auipc` 的 `PC + 立即数`。分支比较器独立于 ALU 实现，根据 `funct3` 选择比较方式。

**访存**：`lw` / `sw` 使用字地址。`lh` / `lhu` / `sh` 和 `lb` / `lbu` / `sb` 根据地址低两位从 32 位数据中抽取或对齐到正确的字节 lane。CPU 输出的 `dmem_wdata` 已经经过 lane 复制，`dmem_be` 标识有效字节。

**写回**：写回 MUX 选择 ALU 结果、加载数据和 `PC+4`（`jal` / `jalr` 的链接值）。

### 3.3 关键时序约束

单周期设计的关键路径通常出现在“寄存器堆读 → ALU → 数据存储器读 → 写回 MUX”。在新起点板卡 50 MHz（20 ns 周期）下，Cyclone IV 的 LUT 和 M9K 延迟足以在单周期内完成这条路径，但仍建议：

- IMEM 和 DMEM 的行为级模型使用**同步读**（在时钟沿输出数据），避免异步读引入组合延迟环。
- 如果综合后时序报告显示负裕量，优先将时钟约束放宽到 40 MHz 或 25 MHz 进行功能验证，功能正确后再逐步收紧。
- Boot ROM 的读延迟要求为 **1 拍**：地址在时钟沿锁存到 BRAM 地址端口，数据在下一个时钟沿出现在 `q` 端口。CPU 的取指逻辑必须按照“地址在周期 N 发出，指令在周期 N+1 可用”的时序设计。RAM 取指同理。


## 4. 存储器子系统

### 4.1 Boot ROM（4 KB）

**实现方式**：使用 Quartus 的 BRAM IP，配置为 ROM（只读，无写端口），深度 1024 × 32 位（4 KB）。初始化文件使用 Intel `.mif` 格式，Quartus 在编译时将其加载到 M9K 块中。

`.mif` 文件的最小合法结构如下：

```
DEPTH = 1024;
WIDTH = 32;
ADDRESS_RADIX = HEX;
DATA_RADIX = HEX;
CONTENT
BEGIN
  0000 : 00000013;
  0001 : 00000013;
  ...
END;
```

**地址分配**：Monitor 代码从偏移 `0x000` 开始，占据前 2 KB（`0x000–0x7FF`）。内置 echo 程序的入口固定在偏移 `0x800`。Shell 的 `run` 命令在不带参数时，默认跳转到 `0x0000_0800` 执行 echo 程序。

**初始化文件生成**：固件由 RISC-V 工具链编译链接为 ELF，再用 `objcopy -O binary` 生成纯二进制，最后由 Python 脚本将 `.bin` 转换为 `.mif`。转换脚本的核心逻辑是按 4 字节小端序拼接为 32 位字，逐行输出 `地址 : 数据` 对。已有开源工具 `bin2mif` 或 `mifgen` 可直接使用，但为了教学透明性，建议项目中包含一个 30 行左右的独立 Python 脚本。

### 4.2 RAM（12 KB）

**实现方式**：BRAM IP，读写模式，深度 3072 × 32 位（12 KB）。RAM 需要支持**字节写**：写端口使用 `byteena` 信号（4 位），由 CPU 的 `dmem_be` 驱动。RAM 不需要初始化文件，上电内容任意。

**取指与数据访问的仲裁**：RAM 同时承担取指和数据访存。在单周期 CPU 中，取指发生在周期的开始，数据访存发生在周期的后段，两者在同一个周期内对同一块 RAM 提出读请求。为避免结构冒险，可以采用**双端口 BRAM**：端口 A 专用于取指（只读），端口 B 专用于数据访存（读/写）。Cyclone IV 的 M9K 天然支持简单双端口模式，12 KB 需要 6 个 M9K 块（每个 M9K 为 9 Kbit，配置为 1024×9 时 6 块可提供 6144×36 的等效容量，足以覆盖 3072×32）。如果双端口 BRAM 资源紧张，也可以退化为单端口 + 取指优先的时序方案，但调试复杂度会上升。

### 4.3 栈规划

Shell 栈和用户程序栈共用 RAM 顶部区域。RAM 范围为 `0x0001_0000`–`0x0001_2FFF`，顶部设为 `0x0001_3000`（RAM 结束地址 + 4，保持 16 字节对齐）。

- **Shell 栈**：Monitor 固件在初始化时将 `sp` 设为 `0x0001_3000`。Monitor 自身的函数调用和局部变量使用这一栈空间。
- **用户程序栈**：Shell 的 `run` 命令在执行跳转之前，强制将 `sp` 重新设为 `0x0001_3000`，然后跳转到用户程序入口。这样用户程序从干净栈顶开始，不会继承 Monitor 的栈帧。用户程序返回时，应通过 `jalr x0, ra, 0` 或约定的 HALT 指令将控制权交还 Monitor。由于没有异常机制，Monitor 无法“捕获”用户程序的非法行为；用户程序如果破坏 `ra` 或陷入死循环，只能通过板载复位恢复。

**内置 echo 程序**同样遵守这一约定：它从 `0x0000_0800` 开始执行，开头将 `sp` 设为 `0x0001_3000`，然后进入“读 UART_RX → 写 UART_TX”的循环。


## 5. UART 外设

### 5.1 参数与分频

新起点板卡的系统时钟为 50 MHz，板载 USB 串口使用 CH340 类芯片，推荐波特率 115200（也可选 9600，取决于上位机终端配置）。

以 115200 为目标，分频系数为：

\[
\text{DIV} = \frac{50{,}000{,}000}{115{,}200} \approx 434.03
\]

取 `DIV = 434`，实际波特率为 50 MHz / 434 ≈ 115207 bps，误差约 +0.006%，远优于 UART 通常允许的 ±2%。如果选用 9600 波特率，`DIV = 5208`，误差同样可以忽略。

**16 倍过采样**：接收侧使用 `DIV_16 = DIV / 16 ≈ 27` 作为过采样节拍。在 115200 下，每个位周期约 434 个系统时钟，接收状态机在每个位的中点附近采样，具体为起始位下降沿后等待约 217 个时钟（半个位周期）进入数据位采样阶段。

### 5.2 发送状态机

发送路径为简单四状态机：`IDLE → START → DATA[0..7] → STOP → IDLE`。`START` 状态将 `tx` 拉低一个位周期；`DATA` 状态从 LSB 到 MSB 逐位输出，每位持续 `DIV` 个时钟；`STOP` 状态将 `tx` 拉高一个位周期后回到 `IDLE`。

`tx_busy` 信号在 `IDLE` 时为 0，进入 `START` 后置 1，回到 `IDLE` 时清 0。CPU 在 `tx_busy=1` 期间写入 `UART_TX` 的数据被硬件丢弃，固件必须通过轮询避免这种情况。

### 5.3 接收状态机（三条铁律）

接收是 UART 设计中最容易出错的部分。本项目明确三条不可省略的规则：

**铁律一：两级同步，复位为空闲高电平。** `uart_rxd` 来自板外，与 `sys_clk` 异步。必须经过两级触发器同步到 `sys_clk` 域，且同步器的复位值应为 `1`（UART 空闲电平为高），避免复位期间被误判为起始位。

**铁律二：在位中点采样，不能用电平保持式消抖。** 检测到同步后的 `rxd` 出现下降沿后，不立即开始采样，而是等待约半个位周期（`DIV/2` 个时钟），确认 `rxd` 仍为低电平，才判定为有效起始位。随后每隔 `DIV` 个时钟在每一位的**中点**采样一次，连续采集 8 个数据位，最后在停止位中点检查 `rxd` 是否为高。中点采样的目的是避开位边沿的抖动和建立/保持时间不确定性。

**铁律三：接收有效脉冲“读走即清”。** 接收状态机在停止位采样完成后产生一个单周期宽的 `rx_valid` 脉冲，将接收到的字节锁存到 `rx_data_latch`，并置位 `rx_ready`。SoC 在 CPU 读取 `UART_RX` 地址的同一拍清除 `rx_ready`。这样同一字节不会被重复消费。可选地增加 1–2 字节小 FIFO 以容忍人快速打字，教学版先不加，验收时观察是否丢字后再决定是否增强。

### 5.4 UART 与 SoC 的接口

UART 模块对外暴露：

```
input  clk, rst_n;
input  uart_rxd;
output uart_txd;
// MMIO 接口
input        tx_wr;        // 来自 SoC 的译码：写 UART_TX
input  [7:0] tx_data;
output       tx_busy;
output       rx_ready;
output [7:0] rx_data;
input        rx_rd;        // 来自 SoC 的译码：读 UART_RX
```

SoC 顶层负责将 `dmem_addr`、`dmem_we`、`dmem_re` 译码为 `tx_wr` 和 `rx_rd`，并将 `tx_busy`、`rx_ready` 送入读 MUX。


## 6. SoC 顶层集成

### 6.1 地址译码

译码只比较地址的高位到块边界，不比较低位：

- `addr[31:12] == 20'h00000` → Boot ROM（4 KB，块边界 12 位）
- `addr[31:12] == 20'h00001` → RAM 的前 4 KB；但 RAM 为 12 KB，因此需要 `addr[31:14] == 18'h00004` 且 `addr[13:12] <= 2`，或者更简单地使用 `addr >= 0x0001_0000 && addr < 0x0001_3000` 的范围比较。范围比较的综合结果通常是一个减法器 + 进位判断，在 50 MHz 下完全可以接受。
- `addr[31:4] == 28'hFFFF000` → UART（16 字节 MMIO 窗口）。
- 其他 → 未映射，读数据为 0，写忽略。

**写使能路由**：
- `rom_we = 0`（ROM 永远不写）
- `ram_we = dmem_we && is_ram`
- `uart_tx_wr = dmem_we && is_uart && (addr[3:2] == 2'b00)`

**读数据 MUX**：
- `is_rom` → ROM 读数据
- `is_ram` → RAM 读数据
- `is_uart` 且 `addr[3:2] == 2'b00` → `{30'b0, rx_ready, tx_busy}`
- `is_uart` 且 `addr[3:2] == 2'b01` → `{rx_ready, 23'b0, rx_data}`
- 默认 → `32'b0`

### 6.2 取指路径的 ROM / RAM 选择

CPU 的 `pc` 直接送入 ROM 和 RAM 的取指端口。ROM 在 `pc < 0x0000_1000` 时返回有效指令；RAM 在 `pc` 落在 `0x0001_0000–0x0001_2FFF` 时返回有效指令。取指数据 MUX 根据 `pc` 的译码选择。由于 ROM 和 RAM 的读延迟都是 1 拍，CPU 的取指时序不需要区分当前处于哪一区域。

### 6.3 顶层端口与引脚约束

顶层模块的端口与用户提供的引脚表对应：

| 顶层端口 | 方向 | 引脚 | 说明 |
|---|---|---|---|
| `sys_clk` | input | M2 | 50 MHz |
| `sys_rst_n` | input | M1 | 低有效复位 |
| `uart_rxd` | input | N5 | USB 串口 RX |
| `uart_txd` | output | M7 | USB 串口 TX |
| `led[3:0]` | output | D11, C11, E10, F9 | 调试探针（建议 `led[0]` 接 `tx_busy`，`led[1]` 接 `rx_ready`，`led[2]` 接 `pc[2]` 或运行指示，`led[3]` 保留） |

Quartus 的 `.qsf` 约束文件中使用 `set_location_assignment` 完成绑定，并设置 `set_instance_assignment -name IO_STANDARD "3.3-V LVTTL"`。


## 7. 软件工具链与 Monitor 固件

### 7.1 工具链安装（Windows）

推荐使用 xPack 维护的 `riscv-none-elf-gcc` 预编译工具链。它提供 `riscv32-unknown-elf` 目标和 Newlib，适合裸机开发。

安装步骤：

1. 下载 xPack RISC-V GCC 的 Windows 归档，解压到不含空格的路径（如 `C:\xPacks\riscv-none-elf-gcc`）。
2. 将 `bin` 目录（如 `C:\xPacks\riscv-none-elf-gcc\...\bin`）加入系统 `PATH`，重启终端。
3. 验证：`riscv-none-elf-gcc --version` 和 `riscv-none-elf-objcopy --version` 应正常输出。

Linux 下可通过包管理器或源码构建获得同名工具链，项目中的 Makefile 通过 `CROSS_COMPILE ?= riscv-none-elf-` 参数化前缀，不硬编码平台。

### 7.2 链接脚本

链接脚本将固件布局到 Boot ROM 地址空间：

```
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x00000000;
  .text.init : { *(.text.init) }
  .text      : { *(.text) }
  .rodata    : { *(.rodata*) }
  .data      : { *(.data*) }
  .bss       : { *(.bss*) *(COMMON) }
  _end = .;
}
```

Monitor 固件中没有需要初始化的 `.data` 段写入 RAM 的逻辑，因为 RAM 上电内容任意，Monitor 不依赖 RAM 初值。所有常量放在 `.rodata` 中，随 `.text` 一起驻留 ROM。

### 7.3 启动代码与 HALT 约定

`_start` 汇编入口完成以下动作：

```
_start:
    lui  sp, 0x00010       # sp = 0x00010000 的下一页，实际设到 0x00013000
    addi sp, sp, 0x300     # 修正到 RAM 顶部
    jal  ra, main
halt:
    jal  x0, halt          # 无限循环，作为 Monitor 的终点
```

`main` 返回后执行 `halt` 处的无限循环。在仿真中，testbench 检测 PC 连续多个周期停留在同一条 `jal x0, 0` 上即判定程序结束。上板时，Monitor 的正常流程是进入 Shell 循环，不会到达 `halt`；`halt` 是防御性终点，用于仿真和意外返回。

### 7.4 Monitor Shell 命令集（最小可行版本）

| 命令 | 功能 |
|---|---|
| `help` | 打印命令列表 |
| `echo` | 跳转到 ROM `0x800` 的内置 echo 程序（永远回显） |
| `load` | 从 UART 接收十六进制文本行（每行一个 32 位字或连续字节），写入 RAM 指定起始地址 |
| `run <addr>` | 将 `sp` 设为 `0x0001_3000`，跳转到指定 RAM 地址执行 |
| `dump <addr> <len>` | 以十六进制打印 RAM 内容 |

`load` 和 `run` 是 Shell 的核心。`load` 协议可以极简：固定加载到 `0x0001_0000`，每行接收 8 个十六进制字符 + 换行，直到收到空行或 `EOF` 标记。`run` 不带参数时默认跳转到 `0x0001_0000`。

### 7.5 固件编译流程

```
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles \
    -T link.ld -o monitor.elf start.S monitor.c
riscv-none-elf-objcopy -O binary monitor.elf monitor.bin
python bin2mif.py monitor.bin boot_rom.mif --depth 1024 --width 32
```

`bin2mif.py` 读取小端序二进制，按 4 字节打包为 32 位字，不足 1024 字的部分补 `0x00000013`（`nop`），输出符合 §4.1 格式的 `.mif` 文件。内置 echo 程序单独汇编、单独转换，或作为 Monitor 工程中的一个独立 `.S` 文件在链接脚本中通过 `. = 0x800;` 固定到偏移 `0x800`。


## 8. 验证计划与上板调试

### 8.1 分阶段验证

| 阶段 | 验证对象 | 方法 | 通过标准 |
|---|---|---|---|
| V1 | CPU 算术/逻辑 | 手写汇编 testbench，结果写入 RAM 固定地址，仿真器自动比对 | `addi`/`add`/`sub`/`and`/`or`/`xor` 结果正确 |
| V2 | 加载/存储（含字节） | 汇编程序执行 `sb`/`sh`/`sw`/`lb`/`lbu`/`lh`，检查 RAM 和寄存器 | 字节 lane 和符号扩展正确 |
| V3 | 分支/跳转 | 循环、条件分支、`jal`/`jalr` 链接与返回 | 控制流符合预期，`x0` 保持为 0 |
| V4 | UART 发送 | 独立 UART TX 模块 testbench，或 SoC 仿真中采样 `uart_txd` | 115200 位时序正确，LSB first，1 停止位 |
| V5 | UART 接收 | testbench 向 `uart_rxd` 注入字节波形 | 中点采样正确，`rx_ready` 读清有效 |
| V6 | Hello World | Monitor 或内置程序通过 UART 输出字符串 | 上位机终端完整显示 “Hello, RV32I!” |
| V7 | Shell 交互 | `load` 加载一个小程序，`run` 执行，程序输出字符或回显 | 加载—执行—输出闭环 |
| V8 | 上板 | 烧录 `.sof` 或 `.pof`，连接串口终端 | V6 和 V7 在真实硬件上重复通过 |

### 8.2 上板调试手段

**UART 打印**：这是项目自带的“printf 调试”。在 Monitor 的关键路径插入 `putchar('A')`/`putchar('B')`，观察程序执行到了哪一步。UART 本身的正确性一旦建立，就成为最可靠的调试通道。

**LED 探针**：将 `tx_busy`、`rx_ready`、`pc[2]` 和 `dmem_we` 等信号接到 `led[3:0]`。如果程序“跑飞”，LED 的全灭或常亮能提供第一时间的线索。

**SignalTap II**：Cyclone IV 支持嵌入逻辑分析仪。当 UART 输出乱码或 Shell 无响应时，抓取 `pc`、`dmem_addr`、`dmem_we`、`tx_wr` 和 `rx_rd` 的波形，可以直接看到 CPU 是否在正确轮询、是否写入了正确的 MMIO 地址。对于单周期 CPU，SignalTap 的存储深度需求不高，1024 采样深度通常足够捕捉一次 Shell 交互。

### 8.3 常见陷阱清单

- **`x0` 写入**：寄存器堆的写端口必须显式屏蔽 `rd == 0` 的写入。漏掉这一点会导致依赖 `x0` 的程序行为随机错误。
- **MIF 路径**：Quartus 综合时 `.mif` 文件路径相对于工程目录，使用绝对路径或确认文件在工程目录下。
- **UART 同步器复位值**：如果两级同步器的复位值为 0，复位期间 `rxd` 同步结果被拉低，可能被误判为起始位。务必复位为 1。
- **取指与数据 RAM 冲突**：如果 RAM 使用单端口，取指和数据访存在同一周期竞争。优先使用双端口 BRAM，或至少在仿真中确认不会发生“取指时恰好执行 `lw` 到同一块 RAM”导致的取指错误。
- **单周期关键路径**：如果上板后行为不稳定，首先降低时钟频率进行验证，确认功能正确后再排查时序。50 MHz 对单周期 RV32I 通常是轻松的，但 RAM 的同步读延迟 + ALU + 写回 MUX 的路径仍应关注。


## 9. 交付物清单

| 交付物 | 说明 |
|---|---|
| `rtl/` | CPU 核、Boot ROM IP 包装、RAM IP 包装、UART、SoC 顶层、顶层模块 |
| `constraints/xqd.qsf` | 引脚约束与时序约束 |
| `firmware/` | `start.S`、`monitor.c`、`echo.S`、`link.ld`、Makefile |
| `tools/bin2mif.py` | 二进制 → `.mif` 转换脚本 |
| `sim/` | CPU 单元 testbench、UART testbench、SoC 集成 testbench |
| `docs/` | 本设计文档 + 地址映射表 + 寄存器手册 |
| `boot_rom.mif` | 由固件生成的初始化文件 |

---

这个方案以“单周期、无异常、轮询 UART”为硬边界，把全部复杂度集中在**地址译码、字节写通路、UART 中点采样、Shell 固件的内存布局**这四个真正需要理解的地方。Boot ROM 中的 Monitor 和 echo 程序让板卡上电即有一个可交互的起点，用户程序的加载与执行则打通了从指令到外设的完整链路。完成 V8 验收后，如果希望扩展，M 扩展或一个极简的 `mtvec`/`mcause` 异常骨架可以作为后续迭代，但不应在本阶段提前引入。