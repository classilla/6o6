; kernel for test suite

#include "basic.def"
#include "ktest_h.def"

	* = KERNEL

cold	lda #$00
	sta pc
	sta lastpc
	sta preg
	lda #$04
	sta pc+1
	sta lastpc+1
	lda #$ff
	sta sptr

	; we don't need to implement IRQs or NMIs, just bank switching
	; (done in our custom run6502)
lup	jsr VMU

	cmp #R_BRK
	bne notbrk
	jmp dobrk

notbrk	cmp #R_OK
	beq chekpc
	; we don't handle other return codes from the VM
fail	ldx pc+1
	ldy pc
	lda areg
	; fail
	rol 0
	jmp 0

chekpc	lda pc
	cmp lastpc
	bne noloop
	lda pc+1
	cmp lastpc+1
	beq loop
noloop	sta lastpc+1
	lda pc
	sta lastpc
	jmp lup

loop	; loop detected, we must halt
	lda pc
	cmp #$69
	bne fail
	lda pc+1
	cmp #$34
	bne fail
yay	ldx pc+1
	ldy pc
	; succeed
	rol 1
	jmp 1

dobrk	; 6o6 already set up the stack, we just handle the vector
	sta $01		; bank in upper emulated vectors
	lda EMURAM+$7ffe
	sta pc
	lda EMURAM+$7fff
	sta pc+1
	jmp lup

lastpc	.word 0
