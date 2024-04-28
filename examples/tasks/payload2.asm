#include CONFIGFILE

	* = $0200

current	= $02

top	lda #48
	sta current

lup
#ifdef C64
	lda #18
	jsr CHROUT
#endif
	lda current
	; 00-3f on Apple is already inverse
	jsr CHROUT
#ifdef C64
	lda #146
	jsr CHROUT
#endif
	inc current
	lda current
	cmp #58
	bcc lup
	jmp top


