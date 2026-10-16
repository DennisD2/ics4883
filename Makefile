
all: binfile

binfile: ics4883.asm
	asl ics4883.asm
	p2bin -l 0 ics4883.p
	cmp -l ics4883.bin ics4883.bin
