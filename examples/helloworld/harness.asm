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
	cmp #>KERNEL
	bcs mpokehi
	; $0000 and $0100 go to EMURAM and EMURAM+0x100
mpokelo	adc #>EMURAM
	bcc mpokec	; carry still clear
	; accesses to kernel and up go to the payload
	; add offset keeping in mind carry is set
mpokehi	adc #(PAYLOAD >> 8)-(KERNEL >> 8)-1
	bcc mpokehj
	; fault if the result wraps
mpokefa	lda #R_MFAULT
	jmp BAILOUT
mpokehj ; fault if the result hits I/O
#ifdef C64
	; VIC
	cmp #$d0
#else
	; Apple II
	cmp #$c0
#endif
	bcs mpokefa
	; OK to store
mpokec	sta hhold1
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
spushok	sta EMURAM+$0100,x
	dec sptr
	rts

	; pull .a from stack (must maintain stack pointer itself)
spull	inc sptr
	bne spullok
	lda #R_STACKUNDER	; underflow stack, terminate clean
	jmp BAILOUT
spullok ldx sptr
	lda EMURAM+$0100,x
	rts

	; emulate tsx
stsx	ldx sptr
	rts

	; emulate txs
stxs	stx sptr
	rts

