#include "c64g.def"
#include "harness.def"

#define SEG(x)	.assert *<x,"overrun":.dsb(x-*):.assert *=x,"oops"

MPOKE	= HARNESS+15
SPUSH	= HARNESS+3

; these are OK to use until we start the VM
zp0	= $fb
zp1	= $fd

	.word $0801
	* = $0801

; BASIC header "2010 SYS2061"
.byt $0b, $08, $da, $07, $9e, $32
.byt $30, $36, $31, $00, $00, $00 

	.assert *=2061,"header is wrong length"

	; self-test, verify geoRAM
	; we need 64K

	; check that registers respond
	lda #0
	sta $dfff
	lda #55
	sta $dffe
	lda $dffe
	cmp #55
	bne :+
	jmp nogram

:	; check that memory is persistent (use our routines to make sure
	; that WE aren't buggy)
	lda #$10
	sta dptr
	lda #(ROMSTART >> 8)-1
	sta dptr+1
	lda #28
	jsr MPOKE
	lda #$35
	sta dptr
	lda #$04
	sta dptr+1
	lda #189
	jsr MPOKE
	lda #$8a
	sta dptr
	lda #$00
	sta dptr+1
	lda #221
	jsr MPOKE
	lda #$10
	sta dptr
	lda #(ROMSTART >> 8)-1
	sta dptr+1
	MPEEK(dptr)
	cmp #28
	beq :+
	jmp nogram
:	lda #$35
	sta dptr
	lda #$04
	sta dptr+1
	MPEEK(dptr)
	cmp #189
	beq :+
	jmp nogram
:	lda #$8a
	sta dptr
	ZMPEEK
	cmp #221
	beq copygr

nogram	; geoRAM test failed
	ldy #0
:	lda nogramt,y
	bne :+
	rts
:	jsr $ffd2
	iny
	bne :--
	rts

nogramt	.byt $0d, "no georam found?", $0d, $00

copygr	; copy payload into geoRAM at the given location
	lda #0
	sta zp0
	lda #>PAYLOAD
	sta zp0+1
	ldx #>ROMSTART	; start of logical ROM
copyl	; convert to bank and page
	txa
	and #63
	sta $dffe
	txa
	and #192
	clc
	rol
	rol
	rol
	sta $dfff
	inc $d020
	ldy #0
:	lda (zp0),y
	sta $de00,y
	iny
	bne :-
	inc zp0+1
	inx
	bne copyl

	; mark page $ff as in use, since we touched it last
	lda #$ff
	sta curpage

	; check that transmission was complete (otherwise bad geoRAM?)
	lda #0
	sta dptr
	lda #>ROMSTART
	sta dptr+1
	MPEEK(dptr)
	cmp PAYLOAD
:	bne nogram

	lda #$ff
	sta dptr
	sta dptr+1
	MPEEK(dptr)
	cmp PAYLOAD+ROMSIZE-1
	bne :-

	; cold start
	lda #6
	sta 53280
	sta 53281
	lda #14
	sta 646
	lda #$93
	jsr $ffd2
	lda #23
	sta 53272
	lda #128
	sta 657		; turn off C=/SHIFT toggle
cold	lda PAYLOAD+ROMSIZE-4
	sta pc
	lda PAYLOAD+ROMSIZE-3
	sta pc+1
	lda #$ff
	sta sptr
	lda #0
	sta preg

lup	jsr VMU

	; check status
	cmp #R_BRK
	beq dobrk
	cmp #R_BADINS
	beq doill
	cmp #R_UDI
	beq doill
	cmp #R_MFAULT	; nb - current version can't generate this
	beq doill
	; other conditions ignored

	; three-finger salute (CTRL-SHIFT-Commodore)
	lda 653
	cmp #7
	beq cold

	; check for emulated ROM routines
	; these come from disassembling the reset routine at $ff0f
	; use the targets rather than ff03, ff06, ff09, ff0c so that
	; the vectors can be redirected to user code if desired
	;
	; f931 = init (no-op)
	; f941 = input_char (wait) ($ff03 vectored at $03d0)
	; f94c = input_char (no wait, carry flag) ($ff06 vectored at $03d2)
	; f959 = output_char ($ff09 vectored at $03d4)
	; fa05 = print string at a, x ($ff0c)

	lda pc+1
	cmp #$f9
	beq lowchek
	cmp #$fa
	bne lup
	; $fa05 is the only routine in $faxx we patch
	lda pc
	cmp #$05
	bne lup
	jmp epstrax
	; check $f9xx routines
lowchek	lda pc
	cmp #$31
	beq euinit
	cmp #$41
	beq euinput
	cmp #$4c
	beq euscan
	cmp #$59
	beq euout
	jmp lup

	; brk handler
dobrk	; stack already set up by VM
	lda PAYLOAD+ROMSIZE-2
	sta pc
	lda PAYLOAD+ROMSIZE-1
	sta pc+1
	jmp lup

	; illegal failure handler
	; effectively turn the faulting instruction into a brk
doill	; do what VM opbrk would do, but wind the pc back one instruction
	; since the bad opcode was already fetched
	lda pc
	clc
	adc #1		; not 2
	sta hold0
	lda pc+1
	adc #0
	sta hold1       
	; put high byte on first so it comes off last
	jsr SPUSH
	lda hold0
	jsr SPUSH
	lda preg
	ora #%00110000
	jsr SPUSH
	lda preg
	ora #%00010000  ; set bit 4 for B-flag, leave IRQs alone
	sta preg
	jmp dobrk

	; emulated routines
euinit	; basically a nop
	jsr DORTS
	jmp lup

euinput	; loop until we get something
	jsr $ffe4
	cmp #0		; paranoia
	beq euinput
	tax
	lda pet2a,x
	sta areg
	jsr DORTS
	jmp lup

euscan	; return immediately, setting carry if a non-zero value
	jsr $ffe4
	cmp #0
	beq euscanz
	; got key
	tax
	lda pet2a,x
	sta areg
	lda preg	; "sec"
	ora #1
	sta preg
	jsr DORTS
	jmp lup
euscanz	; don't got key
	lda preg	; "clc"
	and #254
	sta preg
	jsr DORTS
	jmp lup

euout	ldx areg
	lda a2pet,x
	cmp #13
	bne :+
	; erase cursor
	lda #32
	jsr $ffd2
	lda #157
	jsr $ffd2
	lda #13
:	jsr $ffd2
	jsr cursor
	jsr DORTS
	jmp lup

epstrax	; this is actually a monitor routine, but since it's vectored,
	; we can accelerate it here too. emulate all of its behaviour,
	; including printing no more than 255 bytes.
	; don't use zp0/zp1 here because they're now live
	lda #32		; erase cursor, if any
	jsr $ffd2
	lda #157
	jsr $ffd2
	lda xreg
	sta hhold0
	lda areg
	sta hhold1
	lda #0
	sta hold0	; counter, since MPEEK can clobber any register
epslup	MPEEK(hhold0)
	cmp #0
	bne :+
epsxit	jsr cursor
	jsr DORTS
	jmp lup
:	tax
	lda a2pet,x
	jsr $ffd2
	inc hhold0
	bne :+
	inc hhold1
:	inc hold0
	bne epslup
	jmp epsxit

	; print a reversed space and back up over it
cursor	lda #<cursort
	sta hhold0
	lda #>cursort
	sta hhold1
	; disable quote mode, if we just printed a quote mark
	ldy #0
	sty 212
:	lda (hhold0),y
	bne :+
	rts
:	jsr $ffd2
	iny
	bne :--
	rts
cursort	.byt 18, 32, 146, 157, 0 ; reverse space, left crsr
	
; ascii tables
#include "pettab.def"

	SEG(HARNESS)
	.bin 0,0,"harness.o"
	SEG(VMSADDR)
	.bin 0,0,"6o6.o"
	SEG(PAYLOAD)
	.bin 0,0,"monbas65_6551.rom.trunc"

