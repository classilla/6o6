
; verify execution environment works correctly


	* = $0000
	; pad zero page
	.dsb $0400
	.assert *=$0400, "bad padding!"

	; set up success vector, same as klaus' test suite standard build
	lda #$4c
	sta $3469
	lda #$69
	sta $346a
	lda #$34
	sta $346b

	lda #$55
	sta $0234
	sta $8243
	lda #$aa
	sta $8234
	sta $0243
	lda $0234
	cmp #$55
fail1	bne *
	lda $8243
	cmp #$55
fail2	bne *
	lda $8234
	cmp #$aa
fail3	bne *
	lda $0243
	cmp #$aa
fail4	bne *

	; passed
	jmp $3469

