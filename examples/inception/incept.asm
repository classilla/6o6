; a three-layer dream
; time runs slower in deeper layers
; rts is a kick
; ((((INCEPTION))))

#include CONFIGFILE

#define SEG(x)	.assert *<x,"overrun":.dsb(x-*):.assert *=x,"oops"

; the page count of the VM element we're copying up in memory (see copyup)
#define	COPYSIZE	47
; the offset between VM copies. we overlap by one page.
#define OFFSET		(COPYSIZE-1)

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

	* = $0803

#endif

	lda #0
	sta stage

	; stage one -- 6o6 runs payload
stage1	jsr shostg
	jsr KERNEL

	; stage two -- 6o6 runs 6o6 runs payload
	; copy up 6o6 and the payload into their new location, leaving
	; a copy of 6o6 behind
stage2	jsr shostg
	lda #((KERNEL >> 8)+OFFSET)
	jsr copyup
	jsr KERNEL

	; stage three -- 6o6 runs 6o6 runs 6o6 runs payload
stage3	jsr shostg
	lda #((KERNEL >> 8)+OFFSET+OFFSET)
	jsr copyup
	jsr KERNEL

	; there is no stage four
end	; restore original payload so you can run it again
	; change this if you make the payload longer than 256 bytes
	lda #((KERNEL >> 8)+OFFSET+OFFSET+OFFSET)
	sta zp0+1
	lda #((KERNEL >> 8)+OFFSET)
	sta zp1+1
	ldy #0
	sty zp0
	sty zp1
:	lda (zp0),y
	sta (zp1),y
	iny
	bne :-

#ifdef C64
	rts
#else
	jmp $03d0
#endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; print the next stage string
shostg	ldx #0
	inc stage
:	lda staget,x
	jsr CHROUT
	inx
	cpx #7
	bne :-
	lda stage
	clc
#ifdef C64
	adc #$30
#else
	; I'm sure this seemed like a good idea to Woz at the time
	adc #$b0
#endif
	jsr CHROUT
	lda #CR
	jmp CHROUT

	; make 6o6 into the new payload and move the payload up.
	; pass the final page as the argument; every move is fixed-size
	; (in this case COPYSIZE pages). since COPYSIZE can be greater than
	; OFFSET, copy from the top down.
copyup	sta zp0+1	; from
	clc
	adc #OFFSET
	sta zp1+1	; to
	lda #0
	sta zp0
	sta zp1
	ldx #COPYSIZE	; page counter

copyupl	ldy #0
:	lda (zp0),y
	sta (zp1),y
	iny
	bne :-
	dec zp0+1
	dec zp1+1
	dex
	bne copyupl
	rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

stage	.byt 1
brkvec	.word 0
staget	.asc CR, "stage "

	; initial locations

	SEG(KERNEL)
	.bin 0,0,"kernel.o"
	SEG(HARNESS)
	.bin 0,0,"harness.o"
	SEG(VMSADDR)
	.bin 0,0,"6o6.o"
	SEG(PAYLOAD)
	.bin 0,0,"payload.o"

