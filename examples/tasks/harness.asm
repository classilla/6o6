; harness

#include CONFIGFILE
#include "harness.def"

	* = HARNESS

	jmp mpeek
	jmp spush
	jmp spull
	jmp stsx
	jmp stxs

        ; these drivers should not change dptr

	; poke .a into location indicated by dptr
        ; okay to clobber x and y
mpoke	tax
	lda dptr
	sta hhold0
	lda dptr+1
	; only pages 0, 1 and 2 are supported in either task
	cmp #$03
	bcc mpokelo
mpokefa	lda #R_MFAULT
	jmp BAILOUT
mpokelo	; add offset for task 1 (carry already clear)
	adc FLAG
	adc FLAG
	adc FLAG
	; add memory offset
	adc #>EMURAM
	; store
	sta hhold1
	txa
	ldy #0
	sta (hhold0),y
	rts

	; load .a with location indicated by dptr
mpeek	MPEEK(dptr)		; use inline version
	rts

	; push .a onto stack (must maintain stack pointer itself)
spush	ldx sptr
	bne spushok
	lda #R_STACKOVER	; overflow stack
	jmp BAILOUT
spushok	dec sptr
	ldy FLAG
	bne spusho1
	sta EMURAM+$0100,x
	rts
spusho1	sta EMURAM+$0400,x
	rts

	; pull .a from stack (must maintain stack pointer itself)
spull	inc sptr
	bne spullok
	lda #R_STACKUNDER	; underflow stack, terminate clean
	jmp BAILOUT
spullok ldx sptr
	lda FLAG
	bne spullo1
	lda EMURAM+$0100,x
	rts
spullo1	lda EMURAM+$0400,x
	rts

	; emulate tsx
stsx	ldx sptr
	rts

	; emulate txs
stxs	stx sptr
	rts

