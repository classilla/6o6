EMURAM=28672
EMUAR=139
EMUXR=140
EMUYR=141
EMUPC=253
KERNEL=1024
HARNESS=2048
VMSADDR=4096
VMU=4111

LS	= ls
LIB6502	= ./lib6502-1.3
RUN6502 = $(LIB6502)/run6502

.DEFAULT: test

.PHONY: test testcore testbasic testfull clean

test: testcore testbasic testfull

# build lib6502 and run6502, ensure it passes the suite

$(RUN6502): klaus_6502/bin_files/6502_functional_test.bin
	( cd $(LIB6502) && \
		EMURAM=$(EMURAM) EMUPC=$(EMUPC) VMU=$(VMU)\
		EMUAR=$(EMUAR) EMUXR=$(EMUXR) EMUYR=$(EMUYR) \
		$(MAKE) )
	$(RUN6502) -L -l 0 $<

# build 6o6 with simple harness to test run6502, ensure it runs correctly
# exercise both fast and slow pathways

testbasic: $(RUN6502) ../6o6.asm src/6o6.asm
	( cd src && $(MAKE) clean )
	( cd src && \
		EMURAM=$(EMURAM) EMUPC=$(EMUPC) KERNEL=$(KERNEL) \
		HARNESS=$(HARNESS) VMSADDR=$(VMSADDR) VMU=$(VMU) \
		HELPINGS=0 HELPINGSALWAYS=0 HSTUB=ktest_h_slow.def \
		$(MAKE) test )
	( cd src && $(LS) -l *.o )
	( cd src && $(MAKE) clean )
	( cd src && \
		EMURAM=$(EMURAM) EMUPC=$(EMUPC) KERNEL=$(KERNEL) \
		HARNESS=$(HARNESS) VMSADDR=$(VMSADDR) VMU=$(VMU) \
		HELPINGS=0 HELPINGSALWAYS=0 HSTUB=ktest_h.def \
		$(MAKE) test )
	( cd src && $(LS) -l *.o )
	( cd src && $(MAKE) clean )
	( cd src && \
		EMURAM=$(EMURAM) EMUPC=$(EMUPC) KERNEL=$(KERNEL) \
		HARNESS=$(HARNESS) VMSADDR=$(VMSADDR) VMU=$(VMU) \
		HELPINGS=1 HELPINGSALWAYS=1 HSTUB=ktest_h.def \
		$(MAKE) test )
	( cd src && $(LS) -l *.o )

# build 6o6 with simple harness, run against full suite
# exercise both fast and slow pathways

testfull: $(RUN6502) ../6o6.asm src/6o6.asm
	( cd src && $(MAKE) clean )
	( cd src && \
		EMURAM=$(EMURAM) EMUPC=$(EMUPC) KERNEL=$(KERNEL) \
		HARNESS=$(HARNESS) VMSADDR=$(VMSADDR) VMU=$(VMU) \
		HELPINGS=0 HELPINGSALWAYS=0 HSTUB=ktest_h_slow.def \
		$(MAKE) testfull )
	( cd src && $(MAKE) clean )
	( cd src && \
		EMURAM=$(EMURAM) EMUPC=$(EMUPC) KERNEL=$(KERNEL) \
		HARNESS=$(HARNESS) VMSADDR=$(VMSADDR) VMU=$(VMU) \
		HELPINGS=0 HELPINGSALWAYS=0 HSTUB=ktest_h.def \
		$(MAKE) testfull )
	( cd src && $(MAKE) clean )
	( cd src && \
		EMURAM=$(EMURAM) EMUPC=$(EMUPC) KERNEL=$(KERNEL) \
		HARNESS=$(HARNESS) VMSADDR=$(VMSADDR) VMU=$(VMU) \
		HELPINGS=1 HELPINGSALWAYS=1 HSTUB=ktest_h.def \
		$(MAKE) testfull )

clean:
	( cd $(LIB6502) && $(MAKE) clean )
	( cd src && $(MAKE) clean )
