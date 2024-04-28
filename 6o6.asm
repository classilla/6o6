; "6o6" 6502-on-6502 virtualizer 1.0
; copyright 2002-2024 cameron kaiser -- all rights reserved
; https://github.com/classilla/6o6
; https://oldvcr.blogspot.com/
;
; this program is under the auspices of the Floodgap Free Software License.
; this license is not GPL and is not compatible with the GPL. this license
; might restrict your ability to use it in commercial applications if it is
; sold as part of a product. you should read and understand the FFSL license
; terms BEFORE USING IT.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; configurable options
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; set these either here or with -DXXX=Y on the xa command line. you do not
; need to set any of these, but the VM you generate may not be fully tuned
; for your application.
;
; you can also use a configuration file here for the defines ...
#ifdef CONFIGFILE
#include CONFIGFILE
#endif
;
; if your application is not sensitive to exact PC control, you can save
; (in some cases) substantial overhead by letting the VM go back for "extra
; helpings" of eligible instructions, effectively fusing them together.
; BUT SEE DOCUMENTATION FIRST for how to properly configure at runtime!!!
; if you don't use, or can't use, extra helpings, turn it off to avoid
; the expense to checking the flag byte on every eligible instruction.
; #define HELPINGS 1
; if you expect to ALWAYS use extra helpings, then also define this to
; also avoid checking the flag byte on every eligible instruction.
; #define HELPINGSALWAYS 1
; if your harness never calls bailout, then you can save a few instructions
; per virtual instruction by defining FAULTLESS since the VM doesn't have to
; unwind anything.
; #define FAULTLESS 1
; the user-defined interrupt instruction allows breakpoints and hypercalls but
; may be more complex if you don't use those features. it occupies opcode $42
; which is normally illegal or NOP/WDM. if you want to make it illegal also,
; #define UDI_IS_ILLEGAL 1
; 6o6 can handle the I flag being set but your kernel or host OS might not.
; if sei should be an illegal instruction (which you can trap), then
; #define SEI_IS_ILLEGAL 1
; if sei should just be ignored, then
; #define SEI_IS_NOP 1
; on the other hand, by default BRK does not set the I flag (no need to since
; simulated IRQs are the responsibility of your kernel). if you want this, then
; #define ACCURATE_IRQ 1
; you probably don't want this with the SEI_IS_* options at the same time!
; this also affects how the I flag is handled by the doirq utility routine.
; 
; finally, if you are on a non-Commodore computer where the starting address
; is specified in some other fashion, or you're inlining it into another file,
; then
; #define NO_SADDR_IN_FILE 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; harness and memory configuration
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; you MUST specify a harness address and starting address either here or
; with -DXXX=Y on the xa command line. if you do not, the VM will NOT BUILD.
;
; you can use a different configuration file here ...
#ifdef HSTUB
#include HSTUB
#endif
; this file can contain your MPEEK and ZMPEEK macros for inline memory
; access. if you don't provide any, then your mpeek routine is used
; (slower but smaller) and you get a warning.

#ifndef HARNESS
#ifldef HARNESS
; labels are ok too
#else
#error you did not specify a harness address, read the docs
#endif
#endif
#ifndef VMSADDR
#ifldef VMSADDR
; labels are ok too
#else
#error you did not specify a starting address, read the docs
#endif
#endif

; set this to point to where your harness is located in memory
harness	= HARNESS
; (your harness should have entry points laid out like this, or
;  the VM will NOT WORK)
mpeek	= harness
spush	= mpeek+3
spull	= mpeek+6
stsx	= mpeek+9
stxs	= mpeek+12
mpoke	= mpeek+15

; ... and VMSADDR should be the starting address you want this loaded at.
#ifndef NO_SADDR_IN_FILE
	.word VMSADDR
#endif
	* = VMSADDR

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; the below sections are modified at your peril or delight
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; processor model
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; inline macros
; these should be as minimally invasive on surrounding code as possible,
; and should try to have a clear isolation between the state of the
; virtualizer and the state of the guest.

#ifndef MPEEK
#echo WARNING missing MPEEK macro, substituting harness call
#define MPEEK(x)	jsr mpeek
#define	FETCH		lda pc:sta dptr:lda pc+1:sta dptr+1:MPEEK(dptr)
#endif

#ifndef ZMPEEK
#echo WARNING missing ZMPEEK macro, substituting harness call
#define ZMPEEK		lda #0:sta dptr+1:jsr mpeek
#endif

; massage options for convenience
#ifndef HELPINGS
#define HELPINGS 0
#endif
#ifndef HELPINGSALWAYS
#define HELPINGSALWAYS 0
#endif
#ifdef FAULTLESS
#if FAULTLESS
#else
#undef FAULTLESS
#endif
#endif

/* general register getters */
#define	GETP	lda preg:pha:plp
#define	GETX	ldx xreg
#define	GETXP	lda preg:pha:GETX:plp
#define	GETY	ldy yreg
#define	GETYP	lda preg:pha:GETY:plp
#define GETA	lda areg
#define	GETAP	lda preg:pha:GETA:plp
#define	GETAXP	lda preg:pha:GETA:GETX:plp
#define GETAYP	lda preg:pha:GETA:GETY:plp
#define	GETAXYP	lda preg:pha:GETA:GETX:GETY:plp
/* move X or Y directly into A for stores */
#define GETXA	lda xreg
#define GETYA	lda yreg
/* most of the time, we're not just putting the register, but reg AND p */
#define CLEANP	cld:cli
/* note: you may need to account for the decimal flag in your IRQ or NMI */
#define	PUTP	php:CLEANP:pla:sta preg
#define PUTXP	php:CLEANP:stx xreg:pla:sta preg
#define	PUTYP	php:CLEANP:sty yreg:pla:sta preg
#define	PUTAP	php:CLEANP:sta areg:pla:sta preg
#define PUTAXP	php:CLEANP:sta areg:stx xreg:pla:sta preg
#define	PUTAYP	php:CLEANP:sta areg:sty yreg:pla:sta preg
#define	PUTAXYP	php:CLEANP:sta areg:stx xreg:sty yreg:pla:sta preg

#define	INCPC1	inc pc:bne *+4:inc pc+1

/* fix EXITEH branch offset if this changes!!! */
#define	EXITOK	lda #R_OK:rts
#define	EXITIMP INCPC1:EXITOK

#if HELPINGS
#if HELPINGSALWAYS
#define EXITEH	INCPC1:jmp execopp
#else
; see above, length of exitok must be three bytes
#define EXITEH	INCPC1:lda pc:cmp ehmode:bcc *+5:EXITOK: \
		jmp execopp
#endif
#else
; all extra helping eligible instructions exit via EXITIMP normally
#define EXITEH	EXITIMP
#endif

#ifndef FETCH
#define	FETCH	MPEEK(pc)
#endif

; addressing modes

#define IMMPEEK	MPEEK(dptr):sta IMMPTR
#define ZMMPEEK ZMPEEK:sta IMMPTR
#define	ZPWORK	MPEEK(dptr):sta hold0
#define	ARGIMM	INCPC1:FETCH:sta IMMPTR
#define	ARGZP	INCPC1:FETCH:sta dptr
#define	ARGZPF	ARGZP:ZMMPEEK
/* if we're following with an mpoke, then we must set the whole pointer */
#define ARGZPP	ARGZP:lda #0:sta dptr+1
#define	ARGZPM	ARGZPP:ZPWORK
/* zero page wraps, which makes indexed x and y really easy */
#define	ARGZPX	INCPC1:FETCH:clc:adc xreg:\
		sta dptr:lda #0:sta dptr+1
#define	ARGZPXF	ARGZPX:ZMMPEEK
#define	ARGZPXM	ARGZPX:ZPWORK
#define	ARGZPY	INCPC1:FETCH:clc:adc yreg:\
		sta dptr:lda #0:sta dptr+1
#define	ARGZPYF	ARGZPY:ZMMPEEK
#define ARGABS	INCPC1:FETCH:sta hold0:INCPC1:FETCH:sta dptr+1:\
		lda hold0:sta dptr
#define	ARGABSF	ARGABS:IMMPEEK
#define	ARGABSM	ARGABS:ZPWORK
#define ARGABSX	INCPC1:FETCH:clc:adc xreg:\
		sta hold0:php:INCPC1:FETCH:plp:adc #0:sta dptr+1:\
		lda hold0:sta dptr
#define	ARGABXF	ARGABSX:IMMPEEK
#define	ARGABXM	ARGABSX:ZPWORK
#define ARGABSY	INCPC1:FETCH:clc:adc yreg:\
		sta hold0:php:INCPC1:FETCH:plp:adc #0:sta dptr+1:\
		lda hold0:sta dptr
#define	ARGABYF	ARGABSY:IMMPEEK
/* this doesn't work the same way as ARGZPX -- there is NO WRAPPING
	out of ZERO PAGE. the MPEEKs DO wrap */
#define	ARGINDX	INCPC1:FETCH:clc:adc xreg:sta dptr:ZMPEEK:\
		sta hold0:inc dptr:ZMPEEK:\
		sta dptr+1:lda hold0:sta dptr
#define	ARGINXF	ARGINDX:IMMPEEK
/* same wrapping bug as indirect JMP, so we don't need to roll dptr+1
	back and forth */
#define	ARGINDY INCPC1:FETCH:sta dptr:ZMPEEK:\
		clc:adc yreg:sta hold1:php:clc:inc dptr:ZMPEEK:plp:\
		adc #0:sta dptr+1:lda hold1:sta dptr
#define	ARGINYF	ARGINDY:IMMPEEK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; externally accessible jump table
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; +0  bailout routine (your harness can call this to unwind the stack)
; +3  rts (your emulated kernel routines can call this to emulate a terminal
;          RTS at the end like a real routine would do)
; +6  irq (sets up stack for an IRQ or NMI, but you still need to set the
;          new PC)
; +9  future expansion
; +12 future expansion
; +15  execop (runs a single instruction or extra helpings group in the VM)
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	jmp bailout
	; both of these are at the end
	jmp dorts
	jmp doirq
	; for future expansion
	nop:nop:nop
	nop:nop:nop
	; execop follows

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; instruction dispatch
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; main instruction dispatch (and reentry point for extra helpings)
	; pc is assumed to contain location of next instruction

execop
	; this can DEFINITELY fault
#ifndef FAULTLESS
	tsx
	stx abandon
#endif
	; for extra helpings assume the stack remained unchanged
execopp	FETCH
	tax
	ldy vectabl,x
	sty execopg+1
	ldy vectabh,x
	sty execopg+2
	ldy #0
execopg	jmp $0000

	; immediate abandon ship (usually called by memory access drivers)
	; set accumulator to the return code
bailout	
#ifndef FAULTLESS
	ldx abandon
	txs
#endif
	rts

	; master instruction decode table

vectabl	.byt	<opbrk,<opora01,<opbad,<opbad
	.byt 	<opbad,<opora05,<opasl06,<opbad	; $00-7
	.byt 	<opphp,<opora09,<opasl0a,<opbad
	.byt 	<opbad,<opora0d,<opasl0e,<opbad	; $08-f
	.byt	<opbpl,<opora11,<opbad,<opbad
	.byt	<opbad,<opora15,<opasl16,<opbad	; $10-7
	.byt	<opclc,<opora19,<opbad,<opbad
	.byt	<opbad,<opora1d,<opasl1e,<opbad	; $18-f
	.byt	<opjsr,<opand21,<opbad,<opbad
	.byt	<opbit24,<opand25,<oprol26,<opbad	; $20-7
	.byt	<opplp,<opand29,<oprol2a,<opbad
	.byt	<opbit2c,<opand2d,<oprol2e,<opbad	; $28-f
	.byt	<opbmi,<opand31,<opbad,<opbad
	.byt	<opbad,<opand35,<oprol36,<opbad	; $30-7
	.byt	<opsec,<opand39,<opbad,<opbad
	.byt	<opbad,<opand3d,<oprol3e,<opbad	; $38-f
#ifdef UDI_IS_ILLEGAL
	.byt	<oprti,<opeor41,<opbad,<opbad
#else
	.byt	<oprti,<opeor41,<opudi,<opbad
#endif
	.byt	<opbad,<opeor45,<oplsr46,<opbad	; $40-7
	.byt	<oppha,<opeor49,<oplsr4a,<opbad
	.byt	<opjmp4c,<opeor4d,<oplsr4e,<opbad	; $48-f
	.byt	<opbvc,<opeor51,<opbad,<opbad
	.byt	<opbad,<opeor55,<oplsr56,<opbad	; $50-7
	.byt	<opcli,<opeor59,<opbad,<opbad
	.byt	<opbad,<opeor5d,<oplsr5e,<opbad	; $58-f
	.byt	<oprts,<opadc61,<opbad,<opbad
	.byt	<opbad,<opadc65,<opror66,<opbad	; $60-7
	.byt	<oppla,<opadc69,<opror6a,<opbad
	.byt	<opjmp6c,<opadc6d,<opror6e,<opbad	; $68-f
	.byt	<opbvs,<opadc71,<opbad,<opbad
	.byt	<opbad,<opadc75,<opror76,<opbad	; $70-7
#ifdef SEI_IS_ILLEGAL
	.byt	<opbad,<opadc79,<opbad,<opbad
#else
	.byt	<opsei,<opadc79,<opbad,<opbad
#endif
	.byt	<opbad,<opadc7d,<opror7e,<opbad	; $78-f
	.byt	<opbad,<opsta81,<opbad,<opbad
	.byt	<opsty84,<opsta85,<opstx86,<opbad	; $80-7
	.byt	<opdey,<opbad,<optxa,<opbad
	.byt	<opsty8c,<opsta8d,<opstx8e,<opbad	; $88-f
	.byt	<opbcc,<opsta91,<opbad,<opbad
	.byt	<opsty94,<opsta95,<opstx96,<opbad	; $90-7
	.byt	<optya,<opsta99,<optxs,<opbad
	.byt	<opbad,<opsta9d,<opbad,<opbad	; $98-f
	.byt	<opldya0,<opldaa1,<opldxa2,<opbad
	.byt	<opldya4,<opldaa5,<opldxa6,<opbad	; $a0-7
	.byt	<optay,<opldaa9,<optax,<opbad
	.byt	<opldyac,<opldaad,<opldxae,<opbad	; $a8-f
	.byt	<opbcs,<opldab1,<opbad,<opbad
	.byt	<opldyb4,<opldab5,<opldxb6,<opbad	; $b0-7
	.byt	<opclv,<opldab9,<optsx,<opbad
	.byt	<opldybc,<opldabd,<opldxbe,<opbad	; $b8-f
	.byt	<opcpyc0,<opcmpc1,<opbad,<opbad
	.byt	<opcpyc4,<opcmpc5,<opdecc6,<opbad	; $c0-7
	.byt	<opiny,<opcmpc9,<opdex,<opbad
	.byt	<opcpycc,<opcmpcd,<opdecce,<opbad	; $c8-f
	.byt	<opbne,<opcmpd1,<opbad,<opbad
	.byt	<opbad,<opcmpd5,<opdecd6,<opbad	; $d0-7
	.byt	<opcld,<opcmpd9,<opbad,<opbad
	.byt	<opbad,<opcmpdd,<opdecde,<opbad	; $d8-f
	.byt	<opcpxe0,<opsbce1,<opbad,<opbad
	.byt	<opcpxe4,<opsbce5,<opince6,<opbad	; $e0-7
	.byt	<opinx,<opsbce9,<opnop,<opbad
	.byt	<opcpxec,<opsbced,<opincee,<opbad	; $e8-f
	.byt	<opbeq,<opsbcf1,<opbad,<opbad
	.byt	<opbad,<opsbcf5,<opincf6,<opbad	; $f0-7
	.byt	<opsed,<opsbcf9,<opbad,<opbad
	.byt	<opbad,<opsbcfd,<opincfe,<opbad	; $f8-f

vectabh	.byt	>opbrk,>opora01,>opbad,>opbad
	.byt 	>opbad,>opora05,>opasl06,>opbad	; $00-7
	.byt 	>opphp,>opora09,>opasl0a,>opbad
	.byt 	>opbad,>opora0d,>opasl0e,>opbad	; $08-f
	.byt	>opbpl,>opora11,>opbad,>opbad
	.byt	>opbad,>opora15,>opasl16,>opbad	; $10-7
	.byt	>opclc,>opora19,>opbad,>opbad
	.byt	>opbad,>opora1d,>opasl1e,>opbad	; $18-f
	.byt	>opjsr,>opand21,>opbad,>opbad
	.byt	>opbit24,>opand25,>oprol26,>opbad	; $20-7
	.byt	>opplp,>opand29,>oprol2a,>opbad
	.byt	>opbit2c,>opand2d,>oprol2e,>opbad	; $28-f
	.byt	>opbmi,>opand31,>opbad,>opbad
	.byt	>opbad,>opand35,>oprol36,>opbad	; $30-7
	.byt	>opsec,>opand39,>opbad,>opbad
	.byt	>opbad,>opand3d,>oprol3e,>opbad	; $38-f
#ifdef UDI_IS_ILLEGAL
	.byt	>oprti,>opeor41,>opbad,>opbad
#else
	.byt	>oprti,>opeor41,>opudi,>opbad
#endif
	.byt	>opbad,>opeor45,>oplsr46,>opbad	; $40-7
	.byt	>oppha,>opeor49,>oplsr4a,>opbad
	.byt	>opjmp4c,>opeor4d,>oplsr4e,>opbad	; $48-f
	.byt	>opbvc,>opeor51,>opbad,>opbad
	.byt	>opbad,>opeor55,>oplsr56,>opbad	; $50-7
	.byt	>opcli,>opeor59,>opbad,>opbad
	.byt	>opbad,>opeor5d,>oplsr5e,>opbad	; $58-f
	.byt	>oprts,>opadc61,>opbad,>opbad
	.byt	>opbad,>opadc65,>opror66,>opbad	; $60-7
	.byt	>oppla,>opadc69,>opror6a,>opbad
	.byt	>opjmp6c,>opadc6d,>opror6e,>opbad	; $68-f
	.byt	>opbvs,>opadc71,>opbad,>opbad
	.byt	>opbad,>opadc75,>opror76,>opbad	; $70-7
#ifdef SEI_IS_ILLEGAL
	.byt	>opbad,>opadc79,>opbad,>opbad
#else
	.byt	>opsei,>opadc79,>opbad,>opbad
#endif
	.byt	>opbad,>opadc7d,>opror7e,>opbad	; $78-f
	.byt	>opbad,>opsta81,>opbad,>opbad
	.byt	>opsty84,>opsta85,>opstx86,>opbad	; $80-7
	.byt	>opdey,>opbad,>optxa,>opbad
	.byt	>opsty8c,>opsta8d,>opstx8e,>opbad	; $88-f
	.byt	>opbcc,>opsta91,>opbad,>opbad
	.byt	>opsty94,>opsta95,>opstx96,>opbad	; $90-7
	.byt	>optya,>opsta99,>optxs,>opbad
	.byt	>opbad,>opsta9d,>opbad,>opbad	; $98-f
	.byt	>opldya0,>opldaa1,>opldxa2,>opbad
	.byt	>opldya4,>opldaa5,>opldxa6,>opbad	; $a0-7
	.byt	>optay,>opldaa9,>optax,>opbad
	.byt	>opldyac,>opldaad,>opldxae,>opbad	; $a8-f
	.byt	>opbcs,>opldab1,>opbad,>opbad
	.byt	>opldyb4,>opldab5,>opldxb6,>opbad	; $b0-7
	.byt	>opclv,>opldab9,>optsx,>opbad
	.byt	>opldybc,>opldabd,>opldxbe,>opbad	; $b8-f
	.byt	>opcpyc0,>opcmpc1,>opbad,>opbad
	.byt	>opcpyc4,>opcmpc5,>opdecc6,>opbad	; $c0-7
	.byt	>opiny,>opcmpc9,>opdex,>opbad
	.byt	>opcpycc,>opcmpcd,>opdecce,>opbad	; $c8-f
	.byt	>opbne,>opcmpd1,>opbad,>opbad
	.byt	>opbad,>opcmpd5,>opdecd6,>opbad	; $d0-7
	.byt	>opcld,>opcmpd9,>opbad,>opbad
	.byt	>opbad,>opcmpdd,>opdecde,>opbad	; $d8-f
	.byt	>opcpxe0,>opsbce1,>opbad,>opbad
	.byt	>opcpxe4,>opsbce5,>opince6,>opbad	; $e0-7
	.byt	>opinx,>opsbce9,>opnop,>opbad
	.byt	>opcpxec,>opsbced,>opincee,>opbad	; $e8-f
	.byt	>opbeq,>opsbcf1,>opbad,>opbad
	.byt	>opbad,>opsbcf5,>opincf6,>opbad	; $f0-7
	.byt	>opsed,>opsbcf9,>opbad,>opbad
	.byt	>opbad,>opsbcfd,>opincfe,>opbad	; $f8-f

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; instruction logic
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#ifndef UDI_IS_ILLEGAL
	; 'user-defined' interrupt -- mostly for debugging
	; op-code $42 (replaces JAM and WDM)
	; load x and y with your parameters and execute for an
	; immediate return
opudi	GETX
	GETY
	lda #R_UDI
	; don't increment PC!
	rts			; normal exit
#endif

	; illegal instruction
opbad	tay
	lda #R_BADINS
	INCPC1			; mark instruction was fetched
	jmp bailout		; not a normal exit

	; real instructions here

#if HELPINGS
-IMMPTR	= hpadc69+1
opadc69	ARGIMM
	GETAP
hpadc69	adc #$00
	PUTAP
	EXITEH
-IMMPTR	= ipadc65+1
opadc65	ARGZPF
jpadc69	GETAP
ipadc65	adc #$00
	PUTAP
	EXITIMP
#else
-IMMPTR	= ipadc69+1
opadc69	ARGIMM
jpadc69	GETAP
ipadc69	adc #$00
	PUTAP
	EXITIMP
opadc65	ARGZPF
	jmp jpadc69
#endif
opadc75	ARGZPXF
	jmp jpadc69
opadc6d	ARGABSF
	jmp jpadc69
opadc7d	ARGABXF
	jmp jpadc69
opadc79	ARGABYF
	jmp jpadc69
opadc61	ARGINXF
	jmp jpadc69
opadc71	ARGINYF
	jmp jpadc69

#if HELPINGS
-IMMPTR	= hpand29+1
opand29	ARGIMM
	GETAP
hpand29	and #$00
	PUTAP
	EXITEH
-IMMPTR	= ipand25+1
opand25	ARGZPF
jpand29	GETAP
ipand25	and #$00
	PUTAP
	EXITIMP
#else
-IMMPTR	= ipand29+1
opand29	ARGIMM
jpand29	GETAP
ipand29	and #$00
	PUTAP
	EXITIMP
opand25	ARGZPF
	jmp jpand29
#endif
opand35	ARGZPXF
	jmp jpand29
opand2d	ARGABSF
	jmp jpand29
opand3d	ARGABXF
	jmp jpand29
opand39	ARGABYF
	jmp jpand29
opand21	ARGINXF
	jmp jpand29
opand31	ARGINYF
	jmp jpand29

opasl0a	GETP
	asl areg
	PUTP
	EXITEH
opasl06	ARGZPM
ipaslxx	GETP
	asl hold0
	PUTP
	lda hold0
	jsr mpoke	; last location still in dptr
	EXITIMP
opasl16	ARGZPXM
	jmp ipaslxx
opasl0e	ARGABSM
	jmp ipaslxx
opasl1e	ARGABXM
	jmp ipaslxx

	; branch class

#define BRANCH(fl,t,f) lda preg:and #fl:beq f:bne t
;               NV-BDIZC
opbcs	BRANCH(%00000001,gbtrue,gbfalse)
opbcc	BRANCH(%00000001,gbfalse,gbtrue)
opbeq	lda preg:and #%00000010:bne gbtrue
; place this here so that we are still in branch range
gbfalse	INCPC1
	EXITEH
; seems like bne-taken occurs a lot in loops, so give it the fastest path
; (see last slot)
opbvs	BRANCH(%01000000,gbtrue,gbfalse)
opbvc	BRANCH(%01000000,gbfalse,gbtrue)
opbmi	BRANCH(%10000000,gbtrue,gbfalse)
; bpl is also a somewhat common loop instruction, so save a cycle
opbpl	lda preg:and #%10000000:bne gbfalse:beq gbtrue
opbne	lda preg:and #%00000010:bne gbfalse	; not usually taken
gbtrue	INCPC1
	FETCH
	cmp #$80
	bcs gbrneg
gbrpos	; forward branch
	adc pc
	sta pc
	bcc gbdone
	inc pc+1
gbdone	EXITIMP
gbrneg	; backwards branch
	clc
	adc pc
	sta pc
	bcs gbdone
	dec pc+1
	EXITIMP
	
opbit24	ARGZPM
ipbitxx	GETAP
	bit hold0
	PUTP
	EXITIMP
opbit2c	ARGABSM
	jmp ipbitxx

	; escape hatch

opbrk	lda pc
	clc
	adc #2
	sta hold0
	lda pc+1
	adc #0
	sta hold1	
	; put high byte on first so it comes off last
	jsr spush
	lda hold0
	jsr spush
	lda preg
	ora #%00110000	; set bit 4 for B-flag and bit 5 for who knows
			; (this is the same as opphp)
	jsr spush
	lda preg
#ifdef ACCURATE_IRQ
	ora #%00010100	; set bit 4 for B-flag and bit 2 for I-flag
#else
	ora #%00010000	; set bit 4 for B-flag
#endif
	sta preg
	lda #R_BRK	; and alert calling process
	rts

#define FLAGONN(x)	lda preg:ora #x:sta preg:EXITEH
#define FLAGOFF(x)	lda preg:and #x:sta preg:EXITEH

		;NV-BDIZC
opclc	FLAGOFF(%11111110)
opsec	FLAGONN(%00000001)
opcld	FLAGOFF(%11110111)
opsed	FLAGONN(%00001000)
opcli	FLAGOFF(%11111011)
#ifdef SEI_IS_NOP
opsei	EXITEH
#else
opsei	FLAGONN(%00000100)
#endif
opclv	FLAGOFF(%10111111)

#if HELPINGS
-IMMPTR	= hpcmpc9+1
opcmpc9	ARGIMM
	GETAP
hpcmpc9	cmp #$00
	PUTP
	EXITEH
-IMMPTR	= ipcmpc5+1
opcmpc5	ARGZPF
jpcmpc9	GETAP
ipcmpc5	cmp #$00
	PUTP
	EXITIMP
#else
-IMMPTR	= ipcmpc9+1
opcmpc9	ARGIMM
jpcmpc9	GETAP
ipcmpc9	cmp #$00
	PUTP
	EXITIMP
opcmpc5	ARGZPF
	jmp jpcmpc9
#endif
opcmpd5	ARGZPXF
	jmp jpcmpc9
opcmpcd	ARGABSF
	jmp jpcmpc9
opcmpdd	ARGABXF
	jmp jpcmpc9
opcmpd9	ARGABYF
	jmp jpcmpc9
opcmpc1	ARGINXF
	jmp jpcmpc9
opcmpd1	ARGINYF
	jmp jpcmpc9

#if HELPINGS
-IMMPTR	= hpcpxe0 + 1
opcpxe0	ARGIMM
	GETXP
hpcpxe0	cpx #$00
	PUTP
	EXITEH
-IMMPTR	= ipcpxe4 + 1
opcpxe4	ARGZPF
jpcpxe0	GETXP
ipcpxe4	cpx #$00
	PUTP
	EXITIMP
#else
-IMMPTR	= ipcpxe0 + 1
opcpxe0	ARGIMM
jpcpxe0	GETXP
ipcpxe0	cpx #$00
	PUTP
	EXITIMP
opcpxe4	ARGZPF
	jmp jpcpxe0
#endif
opcpxec	ARGABSF
	jmp jpcpxe0

#if HELPINGS
-IMMPTR	= hpcpyc0 + 1
opcpyc0	ARGIMM
	GETYP
hpcpyc0	cpy #$00
	PUTP
	EXITEH
-IMMPTR	= ipcpyc4 + 1
opcpyc4	ARGZPF
jpcpyc0	GETYP
ipcpyc4	cpy #$00
	PUTP
	EXITIMP
#else
-IMMPTR	= ipcpyc0 + 1
opcpyc0	ARGIMM
jpcpyc0	GETYP
ipcpyc0	cpy #$00
	PUTP
	EXITIMP
opcpyc4	ARGZPF
	jmp jpcpyc0
#endif
opcpycc	ARGABSF
	jmp jpcpyc0

opdecc6	ARGZPM
ipdecxx	GETP
	dec hold0
	PUTP
	lda hold0
	jsr mpoke	; last location still in dptr
	EXITIMP
opdecd6	ARGZPXM
	jmp ipdecxx
opdecce	ARGABSM
	jmp ipdecxx
opdecde	ARGABXM
	jmp ipdecxx
	
opdex	GETP
	dec xreg
	PUTP
	EXITEH

opdey	GETP
	dec yreg
	PUTP
	EXITEH

#if HELPINGS
-IMMPTR	= hpeor49+1
opeor49	ARGIMM
	GETAP
hpeor49	eor #$00
	PUTAP
	EXITEH
-IMMPTR	= ipeor45+1
opeor45	ARGZPF
jpeor49	GETAP
ipeor45	eor #$00
	PUTAP
	EXITIMP
#else
-IMMPTR	= ipeor49+1
opeor49	ARGIMM
jpeor49	GETAP
ipeor49	eor #$00
	PUTAP
	EXITIMP
opeor45	ARGZPF
	jmp jpeor49
#endif
opeor55	ARGZPXF
	jmp jpeor49
opeor4d	ARGABSF
	jmp jpeor49
opeor5d	ARGABXF
	jmp jpeor49
opeor59	ARGABYF
	jmp jpeor49
opeor41	ARGINXF
	jmp jpeor49
opeor51	ARGINYF
	jmp jpeor49

opince6	ARGZPM
ipincxx	GETP
	inc hold0
	PUTP
	lda hold0
	jsr mpoke	; last location still in dptr
	EXITIMP
opincf6	ARGZPXM
	jmp ipincxx
opincee	ARGABSM
	jmp ipincxx
opincfe	ARGABXM
	jmp ipincxx

opinx	GETP
	inc xreg
	PUTP
	EXITEH

opiny	GETP
	inc yreg
	PUTP
	EXITEH

	; jmp/jsr combined routine

opjsr	; put return address-1 on the stack (which is actually pc+2)
	lda pc
	clc
	adc #2
	sta hold1
	lda pc+1
	adc #0
	jsr spush	; high byte on first so it comes off last
	lda hold1
	jsr spush
	; and fall through ...
opjmp4c	INCPC1
	FETCH
	sta hold1
	INCPC1
	FETCH
opjmpxx	sta pc+1
	lda hold1
	sta pc
	EXITOK		; not exitimp!!! pc is fine right where it is

	; IMPORTANT
	; the famous jmp ($xxff) bug is MAINTAINED in this emulated CPU!

opjmp6c	ARGABS
	MPEEK(dptr)
	sta hold1
	inc dptr
	MPEEK(dptr)
	jmp opjmpxx	

	; unroll all LDAs because they get used a lot.

-IMMPTR	= ipldaa9+1
opldaa9	ARGIMM
	GETP
ipldaa9	lda #$00
	PUTAP
	EXITEH
-IMMPTR	= ipldaa5+1
opldaa5	ARGZPF
	GETP
ipldaa5	lda #$00
	PUTAP
	EXITIMP
-IMMPTR	= ipldab5+1
opldab5	ARGZPXF
	GETP
ipldab5	lda #$00
	PUTAP
	EXITIMP
-IMMPTR	= ipldaad+1
opldaad	ARGABSF
	GETP
ipldaad	lda #$00
	PUTAP
	EXITIMP
-IMMPTR	= ipldabd+1
opldabd	ARGABXF
	GETP
ipldabd	lda #$00
	PUTAP
	EXITIMP
-IMMPTR	= ipldab9+1
opldab9	ARGABYF
	GETP
ipldab9	lda #$00
	PUTAP
	EXITIMP
-IMMPTR	= ipldaa1+1
opldaa1	ARGINXF
	GETP
ipldaa1	lda #$00
	PUTAP
	EXITIMP
-IMMPTR	= ipldab1+1
opldab1	ARGINYF
	GETP
ipldab1	lda #$00
	PUTAP
	EXITIMP

#if HELPINGS
-IMMPTR	= hpldxa2+1
opldxa2	ARGIMM
	GETP
hpldxa2	ldx #$00
	PUTXP
	EXITEH
-IMMPTR	= ipldxa6+1
opldxa6	ARGZPF
jpldxa2	GETP
ipldxa6	ldx #$00
	PUTXP
	EXITIMP
#else
-IMMPTR = ipldxa2+1
opldxa2	ARGIMM
jpldxa2	GETP
ipldxa2	ldx #$00
	PUTXP
	EXITIMP
opldxa6	ARGZPF
	jmp jpldxa2
#endif
opldxb6	ARGZPYF
	jmp jpldxa2
opldxae	ARGABSF
	jmp jpldxa2
opldxbe	ARGABYF
	jmp jpldxa2

#if HELPINGS
-IMMPTR	= hpldya0+1
opldya0	ARGIMM
	GETP
hpldya0	ldy #$00
	PUTYP
	EXITEH
-IMMPTR	= ipldya4+1
opldya4	ARGZPF
jpldya0	GETP
ipldya4	ldy #$00
	PUTYP
	EXITIMP
#else
-IMMPTR	= ipldya0+1
opldya0	ARGIMM
jpldya0	GETP
ipldya0	ldy #$00
	PUTYP
	EXITIMP
opldya4	ARGZPF
	jmp jpldya0
#endif
opldyb4	ARGZPXF
	jmp jpldya0
opldyac	ARGABSF
	jmp jpldya0
opldybc	ARGABXF
	jmp jpldya0

oplsr4a	GETP
	lsr areg
	PUTP
	EXITEH
oplsr46	ARGZPM
iplsrxx	GETP
	lsr hold0
	PUTP
	lda hold0
	jsr mpoke	; last location still in dptr
	EXITIMP
oplsr56	ARGZPXM
	jmp iplsrxx
oplsr4e	ARGABSM
	jmp iplsrxx
oplsr5e	ARGABXM
	jmp iplsrxx

opnop	EXITEH		; boy, if only they were all this easy ...

#if HELPINGS
-IMMPTR	= hpora09+1
opora09	ARGIMM
	GETAP
hpora09	ora #$00
	PUTAP
	EXITEH
-IMMPTR	= ipora05+1
opora05	ARGZPF
jpora09	GETAP
ipora05	ora #$00
	PUTAP
	EXITIMP
#else
-IMMPTR	= ipora09+1
opora09	ARGIMM
jpora09	GETAP
ipora09	ora #$00
	PUTAP
	EXITIMP
opora05	ARGZPF
	jmp jpora09
#endif
opora15	ARGZPXF
	jmp jpora09
opora0d	ARGABSF
	jmp jpora09
opora1d	ARGABXF
	jmp jpora09
opora19	ARGABYF
	jmp jpora09
opora01	ARGINXF
	jmp jpora09
opora11	ARGINYF
	jmp jpora09

oppha	GETA
	jsr spush
	EXITIMP

opphp	lda preg
	; the real 6502 sets the B and X flags on stack, don't ask me why
	ora #%00110000
	jsr spush
	EXITIMP

oppla	jsr spull
	sta opplaf+1	; has to set flags ... grr
	GETP		; no tainting from us
opplaf	lda #$00	; set NV
	PUTAP		; and save *this time*
	EXITIMP

opplp	jsr spull
	sta preg
	EXITIMP

oprol2a	GETP
	rol areg
	PUTP
	EXITEH
oprol26	ARGZPM
iprolxx	GETP
	rol hold0
	PUTP
	lda hold0
	jsr mpoke	; last location still in dptr
	EXITIMP
oprol36	ARGZPXM
	jmp iprolxx
oprol2e	ARGABSM
	jmp iprolxx
oprol3e	ARGABXM
	jmp iprolxx

opror6a	GETP
	ror areg
	PUTP
	EXITEH
opror66	ARGZPM
iprorxx	GETP
	ror hold0
	PUTP
	lda hold0
	jsr mpoke	; last location still in dptr
	EXITIMP
opror76	ARGZPXM
	jmp iprorxx
opror6e	ARGABSM
	jmp iprorxx
opror7e	ARGABXM
	jmp iprorxx

oprti	jsr spull
	sta preg
	jsr spull
	sta pc
	jsr spull
	sta pc+1
	EXITOK		; do NOT increment the PC here!!!!!

oprts	jsr spull
	sta pc
	jsr spull
	sta pc+1
	EXITIMP		; and add 1 to make us come out right

#if HELPINGS
-IMMPTR	= hpsbce9+1
opsbce9	ARGIMM
	GETAP
hpsbce9	sbc #$00
	PUTAP
	EXITEH
-IMMPTR	= ipsbce5+1
opsbce5	ARGZPF
jpsbce9	GETAP
ipsbce5	sbc #$00
	PUTAP
	EXITIMP
#else
-IMMPTR	= ipsbce9+1
opsbce9	ARGIMM
jpsbce9	GETAP
ipsbce9	sbc #$00
	PUTAP
	EXITIMP
opsbce5	ARGZPF
	jmp jpsbce9
#endif
opsbcf5	ARGZPXF
	jmp jpsbce9
opsbced	ARGABSF
	jmp jpsbce9
opsbcfd	ARGABXF
	jmp jpsbce9
opsbcf9	ARGABYF
	jmp jpsbce9
opsbce1	ARGINXF
	jmp jpsbce9
opsbcf1	ARGINYF
	jmp jpsbce9

; opsec, opsed, opsei already done

opsta85	ARGZPP
	GETA
	jsr mpoke
	EXITIMP
opsta95	ARGZPX
	GETA
	jsr mpoke
	EXITIMP
opsta8d	ARGABS
	GETA
	jsr mpoke
	EXITIMP
opsta9d	ARGABSX
	GETA
	jsr mpoke
	EXITIMP
opsta99	ARGABSY
	GETA
	jsr mpoke
	EXITIMP
opsta81	ARGINDX
	GETA
	jsr mpoke
	EXITIMP
opsta91	ARGINDY
	GETA
	jsr mpoke
	EXITIMP

opstx86	ARGZPP
ipstxxx	GETXA
	jsr mpoke
	EXITIMP
opstx96	ARGZPY
	jmp ipstxxx
opstx8e	ARGABS
	jmp ipstxxx

opsty84	ARGZPP
ipstyxx	GETYA
	jsr mpoke
	EXITIMP
opsty94	ARGZPX
	jmp ipstyxx
opsty8c	ARGABS
	jmp ipstyxx

optsx	jsr stsx
	stx optsxf+1	; darn it, setting flags AGAIN!!!!!
	GETP
optsxf	ldx #$00
	PUTXP
	EXITIMP
optxs	GETX		; does NOT set flags
	jsr stxs
	EXITIMP

optax	GETP
	lda areg	; sets same flags as tax, tay, etc.
	sta xreg
	PUTP
	EXITEH
optay	GETP
	lda areg
	sta yreg
	PUTP
	EXITEH
optxa	GETP
	lda xreg
	sta areg
	PUTP
	EXITEH
optya	GETP
	lda yreg
	sta areg
	PUTP
	EXITEH

	; whew!

	; convenience function for triggering an IRQ. you are still
	; responsible for setting PC in your kernel. also works for NMIs.
doirq
	; this can potentially fault
#ifndef FAULTLESS
	tsx
	stx abandon
#endif
	; put high byte on first so it comes off last
	lda pc+1
	jsr spush
	lda pc
	jsr spush
	; and then push status (ensure B flag is clear, keep X, set I?)
	lda preg
	;     NV-BDIZC    
#ifdef ACCURATE_IRQ
	ora #%00100100		; X | I
#else
	ora #%00100000		; X
#endif
	and #%11101111		; ~B
	jsr spush
	lda #R_OK
	rts

	; convenience function for returns from a JSR to an emulated routine.
	; this may fault if the stack would underflow (depending on your
	; harness), which you may choose to handle as normal termination.
dorts
	; this can potentially fault
#ifndef FAULTLESS
	tsx
	stx abandon
#endif
	jmp oprts
