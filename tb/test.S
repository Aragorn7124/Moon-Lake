# 测试目标：验证 ALU、访存、分支跳转
.globl _start
_start:
    # 1. 算术测试 (V1)
    addi x1, x0, 10     # x1 = 10
    addi x2, x0, 20     # x2 = 20
    add  x3, x1, x2     # x3 = 30 (0x1E)

    # 2. 存储测试 (V2)
    sw   x3, 0(x0)      # 把 30 写到地址 0x0000_0000
    lw   x4, 0(x0)      # 从 0x0000_0000 读回 x4

    # 3. 分支测试 (V3)
    beq  x0, x0, skip   # 永远相等，跳转到 skip
    addi x5, x0, 99     # 这句应该被跳过！x5 应该是 0
skip:
    addi x6, x0, 1      # x6 = 1

    # 4. 死循环，防止跑飞
loop:
    jal  x0, loop       # 停留在这里
