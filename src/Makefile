PREFIX  ?= riscv32-unknown-elf-
AS      = $(PREFIX)as
CC	= $(PREFIX)gcc
LD	= $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy
OD      ?= od

KTEXT   ?= 0x000
ENTRY   ?= 0x040
TEXT    ?= 0x040
DATA    ?= 0xC00
BSS     ?= 0x800

RISCV ?= $(HOME)/.local/riscv

PATH := $(RISCV)/bin:$(PATH)

.PHONY: all clean

all: boot.mem

test: testbench.text.mem testbench.data.mem

%.text.bin: %.elf
	$(OBJCOPY) -O binary -j .vector -j .loader -j .text $< $@

%.data.bin: %.elf
	$(OBJCOPY) -O binary -j .data -j .bss $< $@

%.elf: %.c crt0.S
	$(CC) -T core.ld -nostdlib -nostartfiles -o $@ $^

%.o: %.S
	$(AS) -march=rv32i -mabi=ilp32 -g -o $@ $^

%.elf: %.o
	$(CC) -T core.ld -nostdlib -nostartfiles -o $@ $^

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.mem: %.bin
	$(OD) -An -tx4 -w4 -v $< > $@

clean:
	-$(RM) *.elf *.bin *.mem *.o
