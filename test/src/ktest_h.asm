; harness for test suite

#include "basic.def"
#include "ktest_h.def"

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
	lda dptr+1
	bmi mpokeb1
	sta $00		; bank in 0
	bpl mpokeb0
mpokeb1	sta $01		; bank in 1
mpokeb0	and #$7f
	clc
	adc #>EMURAM	; relocate to $7000-$efff
	sta hhold1
	txa
	ldy dptr
	sta (hhold0),y
	rts
	
	; load .a with location indicated by dptr
mpeek	MPEEK(dptr)	; use inline
	rts

	; push .a onto stack (must maintain stack pointer itself)
	; this version is faultless
spush	sta $00		; bank in 0
	ldx sptr
	sta EMURAM+$0100,x
	dec sptr
	rts

	; pull .a from stack (must maintain stack pointer itself)
	; this version is faultless
spull	inc sptr
	sta $00		; bank in 0
	ldx sptr
	lda EMURAM+$0100,x
	rts

	; emulate tsx
stsx	ldx sptr
	rts

	; emulate txs
stxs	stx sptr
	rts

