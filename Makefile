.PHONY: all clean

all: noise.prg

noise.prg: noise.asm vera.inc
	acme -f cbm -o $@ $<

clean:
	rm noise.prg
