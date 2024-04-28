# This Makefile is not designed to be run directly.
# Do 'make test' in the parent.

RM	= rm
XA	= xa
ECHO	= echo
DATE	= date

RUN6502	= ../lib6502-1.3/run6502
KLAUS	= ../klaus_6502/bin_files/6502_functional_test.bin

.SUFFIXES: .asm .o

.PHONY: test clean hey_dummy_read_the_directions obj

hey_dummy_read_the_directions:
	@echo Do "'"make test"'" in the parent directory.

test: obj $(RUN6502)
	$(RUN6502) -R $(KERNEL) -6 -LL \
		-l $(EMURAM) checkenv.o \
		-l $(KERNEL) ktest_k.o \
		-l $(HARNESS) ktest_h.o \
		-l $(VMSADDR) 6o6.o 

testfull: obj $(RUN6502) $(KLAUS)
	@$(DATE)
	$(RUN6502) -R $(KERNEL) -6 -L \
		-l $(EMURAM) $(KLAUS) \
		-l $(KERNEL) ktest_k.o \
		-l $(HARNESS) ktest_h.o \
		-l $(VMSADDR) 6o6.o 
	@$(DATE)
	
obj: 6o6.o checkenv.o ktest_k.o ktest_h.o

clean:
	$(RM) -f *.o *.sym *.lst

.asm.o:
	$(XA) -o $@ -DEMURAM=$(EMURAM) -DEMUPC=$(EMUPC) -DVMU=$(VMU) \
		-DHARNESS=$(HARNESS) -DKERNEL=$(KERNEL) \
		-DHELPINGS=$(HELPINGS) -DVMSADDR=$(VMSADDR) \
		-DHELPINGSALWAYS=$(HELPINGSALWAYS) \
		-DFAULTLESS=1 -DACCURATE_IRQ=1 -DNO_SADDR_IN_FILE=1 \
		-DCONFIGFILE=basic.def -DHSTUB=$(HSTUB) \
		-l $@.sym -P $@.lst $?

