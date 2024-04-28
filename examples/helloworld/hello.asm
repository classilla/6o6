#include CONFIGFILE

#define SEG(x)	.assert *<x,"overrun":.dsb(x-*):.assert *=x,"oops"

#ifdef C64

	; Commodore 64 version
	; these are OK to use until we start the VM
zp0	= $fb
zp1	= $fd

	.word $0801
	* = $0801

; BASIC header "2010 SYS2061"
.byt $0b, $08, $da, $07, $9e, $32
.byt $30, $36, $31, $00, $00, $00 

	.assert *=2061,"header is wrong length"

#else

	; Apple II version
	; these are OK to use until we start the VM
zp0	= $fa
zp1	= $fc

	; "CALL 2051"
	* = $0803

#endif

	ldy #0
:	lda nativet,y
	beq gonativ
	jsr CHROUT
	iny
	bne :-

gonativ	jsr KERNEL

	ldy #0
:	lda virtult,y
	beq govrtul
	jsr CHROUT
	iny
	bne :-

	; swap kernel and payload (a copy of the payload is already at PAYLOAD)
govrtul	jsr swap
	jsr KERNEL
	; swap back so you can run it again
	jsr swap

#ifdef C64
	rts
#else
	; DOS 3.3 forever
	jmp $03d0
#endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; swap the kernel and payload in memory so that the kernel will now
	; run the payload (already at PAYLOAD when loaded)
	; lengthen this loop if you make the kernel and/or payload longer
swap	lda #>(KERNEL-$0100)
	sta zp0+1
	lda #>(KERNEL)
	sta zp1+1
	ldy #0
	sty zp0
	sty zp1
:	lda (zp1),y
	tax
	lda (zp0),y
	sta (zp1),y
	txa
	sta (zp0),y
	iny
	bne :-
	rts

nativet	.asc CR, "native", CR, $00
virtult	.asc CR, "virtual", CR, $00

	.assert *<(KERNEL-$0100),"main code is too long"

	; initial locations

	SEG(KERNEL-$0100)
	.bin 0,0,"kernel.o"
	SEG(KERNEL)
	.bin 0,0,"payload.o"
	SEG(HARNESS)
	.bin 0,0,"harness.o"
	SEG(VMSADDR)
	.bin 0,0,"6o6.o"
	SEG(PAYLOAD)
	.bin 0,0,"payload.o"

