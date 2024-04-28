#include CONFIGFILE
#include "harness.def"

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

	; all keys repeat
	lda #128
	sta 650

#else

	; Apple II version
	; these are OK to use until we start the VM
zp0	= $fa
zp1	= $fc

	; "CALL 2051"
	* = $0803

#endif

	; initialize both processor states
	; start in CPU 0
cold	lda #0
	sta FLAG
	sta pc
	sta preg
	sta cpu0p
	sta cpu0pc
	sta cpu1p
	sta cpu1pc
	lda #2
	sta pc+1
	sta cpu0pc+1
	sta cpu1pc+1
	lda #$ff
	sta sptr
	sta cpu0s
	sta cpu1s

lup	; check if user has requested to switch tasks by pressing a key
	; holding the key will switch back and forth
#ifdef C64
	; this repeats because we changed 650
	jsr $ffe4
	cmp #0
	bne swap
	jmp run
#else
	lda $c000
	bmi :+
	jmp run
:	lda #0
	sta 49168
#endif

	; user requested swap, do the context switch
	; these are simple-minded implementations but easy to follow
	; they also don't depend on zero page locations being contiguous
swap	lda FLAG
	bne swap10
swap01	; move task 0 off CPU, put task 1 on CPU
	lda areg
	ldx xreg
	ldy yreg
	sta cpu0a
	stx cpu0x
	sty cpu0y
	lda preg
	ldx sptr
	ldy pc
	sta cpu0p
	stx cpu0s
	sty cpu0pc
	ldy pc+1
	sty cpu0pc+1

	lda cpu1a
	ldx cpu1x
	ldy cpu1y
	sta areg
	stx xreg
	sty yreg
	lda cpu1p
	ldx cpu1s
	ldy cpu1pc
	sta preg
	stx sptr
	sty pc
	ldy cpu1pc+1
	sty pc+1

	lda #1
	sta FLAG
	jmp run
swap10	; move task 1 off CPU, put task 0 on CPU 
	lda areg
	ldx xreg
	ldy yreg
	sta cpu1a
	stx cpu1x
	sty cpu1y
	lda preg
	ldx sptr
	ldy pc
	sta cpu1p
	stx cpu1s
	sty cpu1pc
	ldy pc+1
	sty cpu1pc+1

	lda cpu0a
	ldx cpu0x
	ldy cpu0y
	sta areg
	stx xreg
	sty yreg
	lda cpu0p
	ldx cpu0s
	ldy cpu0pc
	sta preg
	stx sptr
	sty pc
	ldy cpu0pc+1
	sty pc+1

	lda #0
	sta FLAG

run	jsr VMU

	; if we get a stack underflow, treat as clean termination status
	cmp #R_STACKUNDER
	bne chekok
dun	rts		; propagates up

	; otherwise we don't handle any return status other than OK
chekok	cmp #R_OK
	beq chekpc
	; err out, wait for a rescue
bail	sta $d020
	inc $d020
	jmp bail

	; check for a call to $ffd2 and redirect to Kernal call
chekpc	lda pc+1
	cmp #>CHROUT
	bne lupj
	lda pc
	cmp #<CHROUT
	bne lupj

kffd2	lda areg
	jsr CHROUT	; propagates up
	jsr DORTS
	cmp #R_STACKUNDER
	beq dun
lupj	jmp lup

	; saved processor states
cpu0a	.byt 0
cpu0x	.byt 0
cpu0y	.byt 0
cpu0p	.byt 0
cpu0s	.byt 0
cpu0pc	.word 0

cpu1a	.byt 0
cpu1x	.byt 0
cpu1y	.byt 0
cpu1p	.byt 0
cpu1s	.byt 0
cpu1pc	.word 0

	; images
	SEG(HARNESS)
	.bin 0,0,"harness.o"
	SEG(VMSADDR)
	.bin 0,0,"6o6.o"

	; first task
	; zero page and stack at EMURAM
	SEG(EMURAM+$0200)
	.bin 0,0,"payload1.o"
	; second task
	; zero page and stack at EMURAM+$0300
	SEG(EMURAM+$0500)
	.bin 0,0,"payload2.o"

