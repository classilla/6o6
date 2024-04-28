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
mpoke	ldx dptr+1
	cpx #>ROMSTART
	bcc :+
	; no writes to emulated ROM, cheaters
	rts
	; page unchanged? if so, skip all this nonsense
:	cpx curpage
	beq :++
	; map the high byte maps onto the geoRAM page registers
	stx curpage	; cache it
	cpx #64
	bcs :+
	; below $4000, direct mapping
	stx $dffe
	ldx #0
	stx $dfff
	ldx dptr
	sta $de00,x
	rts
	; $4000 and up indirect mapping, convert to block and bank
:	tay
	txa
	and #63
	sta $dffe
	txa
	and #192
	clc		; carry is still set
	rol
	rol
	rol
	sta $dfff
	tya
:	ldx dptr
	sta $de00,x
	rts

	; load .a with location indicated by dptr
mpeek	MPEEK(dptr)		; use inline version
	rts

	; push .a onto stack (must maintain stack pointer itself)
	; allow stack to overflow
spush	ldx sptr
	ldy #0
	sty $dfff
	ldy #1
	sty $dffe		; select page 1
	sty curpage
	sta $de00,x
	dec sptr
	rts

	; pull .a from stack (must maintain stack pointer itself)
	; allow stack to underflow
spull	inc sptr
	ldx sptr
	ldy #0
	sty $dfff
	ldy #1
	sty $dffe		; select page 1
	sty curpage
	lda $de00,x
	rts

	; emulate tsx
stsx	ldx sptr
	rts

	; emulate txs
stxs	stx sptr
	rts

