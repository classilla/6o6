CP	= cp
RM	= rm
XA	= xa

.SUFFIXES: .asm .o .prg

vmgr.prg: vmgr.asm 6o6.o harness.o monbas65_6551.rom.trunc
	$(XA) -o $@ -DCONFIGFILE=c64g.def -DHSTUB=harness.def -DC64=1 \
		-a -O PETSCII -P $@.lst \
		-l $@.sym vmgr.asm
	$(CP) $@ ~/c64/prg || echo "Never mind."

.asm.o:
	$(XA) -o $@ -DCONFIGFILE=c64g.def -DHSTUB=harness.def \
		-a -O PETSCII \
		-l $@.sym $<

clean:
	$(RM) -f *.o *.sym *.lst *.prg
