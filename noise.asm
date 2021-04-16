; Noise X16
; Written by LRFLEW
; Licensed under the BSD 2-clause license

	; Vera Addresses
	!src "vera.inc"

	; Addresses
	writeaddr = $10
	readaddr = $12

	; Number of Loops for VRAM Write
	unrollloop = 6
	bytesperloop = 320*240/2/unrollloop

	; boilerplate
	!cpu 65c02
	*= $0801
	!byte $0b,$08,$01,$00,$9e,$32,$30,$36,$31,$00,$00,$00

init:
	; init vera
	stz VERA_IEN
	stz VERA_CTRL

unrollstart:
	unrollsize = (bytesperloop - 1) * (payloadend - payload)
	unrolltail = ($100 - ( payloadsize & $FF)) & $FF
	unrollhead = (unrollsize + $FF) >> 8
	unrollreadaddr = payload - unrolltail
	unrollwriteaddr = payloaddest - unrolltail

	; Write a large unrolled loop procedurally
	lda #>unrollwriteaddr
	sta writeaddr+1
	sta readaddr+1
	lda #<unrollwriteaddr
	sta writeaddr
	lda #<unrollreadaddr
	sta readaddr
	ldx #<unrollhead
	ldy #<unrolltail

unroll:
	lda (readaddr), Y
	sta (writeaddr), Y

	iny
	bne unroll
	inc writeaddr+1
	inc readaddr+1
	dex
	bne unroll

cap:
	lda trailer, Y
	sta (writeaddr), Y

	iny
	cpy #<(trailerend - trailer)
	bne cap

start:
	; set scaling
	ldx #$40
	stx VERA_DC_HSCALE
	stx VERA_DC_VSCALE

	; disable layer 1 and sprites
	lda VERA_DC_VIDEO
	and #$07
	ora #$10
	sta VERA_DC_VIDEO

	; set layer 0 to 4bpp bitmap
	ldx #$06
	stx VERA_L0_CONFIG
	; with address of $00000
	stz VERA_L0_TILEBASE
	; set layer 0 palette offset
	ldy #$01
	sty VERA_L0_HSCROLL_H

	; setup write to VRAM
	lda #$10
	stz VERA_ADDR_L
	sta VERA_ADDR_H
	sty VERA_CTRL
	stz VERA_ADDR_L
	sta VERA_ADDR_H

outloop:
	; setup Vera addresses
	sty VERA_CTRL
	stz VERA_ADDR_M
	stz VERA_CTRL
	stz VERA_ADDR_M

	clc
	lda #$35

	; init counter in x and start loop
	ldx #<unrollloop
	bra inloop

trailer:
	jmp loopend
trailerend:

loopend:
	dex
	beq outloop

inloop:
payload:
	; This PRNG is based on my submission to cc65's rand()
	; implementation, licenced under the zlib license
	adc VERA_DATA0
	sta VERA_DATA1
payloadend:

payloaddest:

	; redefine unroll* variables with new name
	; to avoid "Value not defined" errors
	payloadsize = (bytesperloop - 1) * (payloadend - payload)
	payloadtail = ($100 - ( payloadsize & $FF)) & $FF
	payloadhead = (payloadsize + $FF) >> 8
	payloadreadaddr = payload - payloadtail
	payloadwriteaddr = payloaddest - payloadtail

	; Check for overrun when decompressing
	!if payloadsize >= ($9F00 - payloaddest) {
	    !error "Payload Too Large for LoRAM"
	}
	; The code is optimized assuming these constraints
	!if (payloadreadaddr & $FF00) != (payloadwriteaddr & $FF00) {
		!error "Payload Crosses Page Boundary"
	}
