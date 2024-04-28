; kernel

#include CONFIGFILE
#include "harness.def"

	* = KERNEL

cold	lda #<KERNEL
	sta pc
	lda #>KERNEL
	sta pc+1
	lda #0
	sta preg
	lda #$ff
	sta sptr

lup	jsr VMU

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
	bne lup
	lda pc
	cmp #<CHROUT
	bne lup

kffd2	lda areg
	jsr CHROUT	; propagates up
	jsr DORTS
	cmp #R_STACKUNDER
	beq dun
	jmp lup

	.assert *<(KERNEL+256), "adjust swap copy size in hello.asm"

