OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x00000000;       /* 代码从地址 0 开始 */
  .text : { *(.text) }
}
