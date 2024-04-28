#include CONFIGFILE

	* = $0200

current	= $02

top	lda #65
	sta current

lup	lda current
#ifdef A2
	ora #$80
#endif
	jsr CHROUT
	inc current
	lda current
	cmp #91
	bcc lup
	jmp top


