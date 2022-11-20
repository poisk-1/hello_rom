src = hello_rom.asm
part = AT28C256
rom_size_kb = 32

.PHONY: all
all: hello_rom.rom

hello_rom.bin: $(src)
	nasm -f bin -o $@ -l hello_rom.lst $(src)

romify: romify.c
	gcc -o $@ -DROM_SIZE_KB=$(rom_size_kb) romify.c

hello_rom.rom: romify hello_rom.bin
	./romify hello_rom.bin $@

.PHONY: clean
clean:
	$(RM) hello_rom.bin
	$(RM) hello_rom.rom
	$(RM) romify

.PHONY: program
program: hello_rom.rom
	minipro -p $(part) -w hello_rom.rom
