#include CONFIGFILE

	* = KERNEL
	; NOT payload!

	ldx #0
:	lda string,x
	beq :+
	jsr CHROUT
	inx
	bne :-
:	rts
	
	; character set handled by xa
string	.asc "hello world", CR, $00

	.assert *<(KERNEL+256), "adjust copy loop for a longer payload"

