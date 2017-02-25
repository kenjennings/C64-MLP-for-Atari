;===================================================================================================
;																		       SPRITE ROUTINES
;===================================================================================================
;																		      Peter 'Sig' Hewett
;																						 - 2016
;; Atari-fied for eclipse/wudsn/atasm by Ken Jennings
;; FYI -- comments with double ;; are Ken's for Atari
;---------------------------------------------------------------------------------------------------
; Routines for more advanced handling and manipulation of sprites
;---------------------------------------------------------------------------------------------------

;===================================================================================================
;																				 MOVE SPRITE LEFT
;===================================================================================================
; Moves a sprite left one pixel - using the whole screen (with the X extended bit)
; X = number of hardware sprite to move (0 - 7) - Register is left intact
;
; NOTE : to move a sprite multiple pixels, you call this multiple times. One day I might have a crack
;		at doing one for multiple pixels, but at this point I don't think I could do one that would
;		justify the extra code and provide a performance boost to make it worthwhile.
;---------------------------------------------------------------------------------------------------
; Fixed bug in the strange extended bit behavior.  Flipping the bit on negative flag sets it on $FF
; but also flips it on every other change from 128 ($80) to 255 ($FF) making it flicker.
; Checking instead for 0 corrects this.
;---------------------------------------------------------------------------------------------------

;; #region "MoveSpriteLeft"
.LOCAL
MoveSpriteLeft
		dec SPRITE_POS_X,x ;; Atari -- Atari does not need the extended bit, so just dec it .
		lda SPRITE_POS_X,x				      ; First check for 0 (NOT negative)
;;		bne ?decNoChange						; branch if NOT 0
;;   Oddly laid out. it looks like two decrements?

;;		dec SPRITE_POS_X,x				      ; Decrement Sprite X position by 1 (to $FF)

;;		lda BIT_TABLE,x						 ; fetch the bit needed to change for this sprite
;;		eor SPRITE_POS_X_EXTEND				 ; use it as a mask to flip the correct X extend bit 
;;		sta SPRITE_POS_X_EXTEND				 ; store teh data then save it in the VIC II register
;;		sta VIC_SPRITE_X_EXTEND				 ; $D011 - Sprite extended X bits (one bit per sprite)
;;		jmp ?noChangeInExtendedFlag		     ; Jump to saving the X position

;; ?decNoChange								    ; Not zero X so we decrement
;;       dec SPRITE_POS_X,x
;; ?noChangeInExtendedFlag
;; Atari P/M coords do not require times 2 offset.

;;		txa								     ; copy X to the accumulator (sprite number)
;;		asl								     ; shift it left (multiply by 2)
;;		tay								     ; save it in Y (to calculate the register to save to)

;;		lda SPRITE_POS_X,x				      ; Load our variable saved X position
;;		sta VIC_SPRITE_X_POS,y				  ; save it in $D000 offset by Y to the correct VIC
												; sprite register
		sta HPOSP0,x  ;; Atari horizontal position.
												; Here we decrement the Sprite delta - we moved
												; a pixel so the delta goes down by one
		dec SPRITE_POS_X_DELTA,x
		lda SPRITE_POS_X_DELTA,x
		cmp #$FE ;; Atari -- To center a character the X delta is -1, 0, 1, 2
		beq ?resetDelta						 ; test for change to negative
		rts								     ; if delta is still > 0 we're done

?resetDelta								     
;;		lda #$07								; if delta falls below 0
		lda #$02	;; Atari -- 4 color clocks per character -- X delta is -1, 0, 1, 2
		sta SPRITE_POS_X_DELTA,x				; reset it to #$07 - one char
		dec SPRITE_CHAR_POS_X,x				 ; delta has reset - so decrement character position
		rts
     
;; #endregion


;===================================================================================================
;																		       MOVE SPRITE RIGHT
;===================================================================================================
; Moves a sprite right one pixel and adjusts the extended X bit if needed to carry to all the way
; across the screen.
; X = the number of the hardware sprite to move - this register is left intact
;
; NOTE : to move a sprite multiple pixels, this routine must be called multiple times
;---------------------------------------------------------------------------------------------------
;; #region "MoveSpriteRight"
.LOCAL
MoveSpriteRight
		inc SPRITE_POS_X,x				      ; increase Sprite X position by 1
		lda SPRITE_POS_X,x				      ; load the sprite position
;;		bne ?noChangeInExtendedFlag		     ; if not #$00 then no change in x flag
		
;;		lda BIT_TABLE,x						 ; get the correct bit to set for this sprite
;;		eor SPRITE_POS_X_EXTEND				 ; eor in the extended bit (toggle it on or off)
;;		sta SPRITE_POS_X_EXTEND				 ; store the new flags
;;		sta VIC_SPRITE_X_EXTEND				 ; set it in the VIC register

;;?noChangeInExtendedFlag						  
;;		txa								     ; transfer the sprite # to A
;;		asl								     ; multiply it by 2
;;		tay								     ; transfer the result to Y

;;		lda SPRITE_POS_X,x				      ; copy the new position to our variable
;;		sta VIC_SPRITE_X_POS,y				  ; update the correct X position register in the VIC

		sta HPOSP0,x ;; Atari -- horizontal position
												; Our X position is now incremented, so delta also
												; increases by 1
		inc SPRITE_POS_X_DELTA,x
		lda SPRITE_POS_X_DELTA,x
;;		cmp #$08								; if it's crossed over to 8, we reset it to 0
		cmp #$03	;; Atari -- is 4 color clocks per character.
					;; Atari -- To center a character the X delta is -1, 0, 1, 2
		beq ?reset_delta
		rts								     ; if it hasn't we're done
?reset_delta								    
;;		lda #$00
		lda #$FF ;; Atari Y Delta -1
		sta SPRITE_POS_X_DELTA,x				; reset delta to 0 - this means we've crossed a
		inc SPRITE_CHAR_POS_X,x				 ; a character boundry, so increase our CHAR position
		rts

;; #endregion

;===================================================================================================
;																				  MOVE SPRITE UP
;===================================================================================================
; Up and down have no special considerations to consider - they wrap at 255
; X = number of hardware sprite to move
;---------------------------------------------------------------------------------------------------
;; #region "MoveSpriteUp"
.LOCAL
MoveSpriteUp
		jsr AtariPMRippleUp

		dec SPRITE_POS_Y,x				      ; decrement the sprite position variable
;		lda SPRITE_POS_Y,x
 ;;       txa								     ; copy the sprite number to A
 ;;      asl								     ; multiply it by 2
 ;;       tay								     ; transfer it to Y
		
 ;;       lda SPRITE_POS_Y,x				      ; load the sprite position for this sprite
;;		sta VIC_SPRITE_Y_POS,y				  ; send it to the correct VIC register - $D001 + y
		lda SPRITE_0_PTR,x		
		jsr CopySpriteToPM  ;; Atari -- any vertical movement or animation needs a redraw.
										    ; Y position has decreased, so our delta decreases
		dec SPRITE_POS_Y_DELTA,x
		lda SPRITE_POS_Y_DELTA,x 
		cmp #$FC ;; Atari -- To center a character the Y delta is -3, -2, -1, 0, 1, 2, 3, 4
;;		bmi @reset_delta						; test to see if it drops to negative
		beq ?reset_delta   
		rts								     ; if not we're done
?reset_delta
;;		lda #$07								; reset the delta to 0
		lda #4;; Atari Y Delta 4
		sta SPRITE_POS_Y_DELTA,x
		dec SPRITE_CHAR_POS_Y,x				 ; if delta resets, we've crossed a character border
		rts

;; #endregion

;===================================================================================================
;																		       MOVE SPRITE DOWN
;===================================================================================================
; Much the same
; X = number of hardware sprite to move
;---------------------------------------------------------------------------------------------------
;; #region "MoveSpriteDown"

.LOCAL
MoveSpriteDown
		jsr AtariPMRippleDown

		inc SPRITE_POS_Y,x				      ; increment the y pos variable for this sprite
												; sans comments it looks kinda naked.......
;;		txa
;;		asl
;;		tay

;;		lda SPRITE_POS_Y,x
;;		sta VIC_SPRITE_Y_POS,y

		lda SPRITE_0_PTR,x	
		jsr CopySpriteToPM  ;; Atari -- any vertical movement or animation needs a redraw.
		 
		inc SPRITE_POS_Y_DELTA,x
		lda SPRITE_POS_Y_DELTA,x
;;		cmp #$08
		cmp #$05 ;; Atari -- To center a character the Y delta is -3, -2, -1, 0, 1, 2, 3, 4
		beq ?reset_delta
		rts

?reset_delta
;;		lda #$00
		lda #$FD ;; Atari Y Delta -3
		sta SPRITE_POS_Y_DELTA,x
		inc SPRITE_CHAR_POS_Y,x
		rts

;; #endregion

;===================================================================================================
;																		     SPRITE TO CHAR POS
;===================================================================================================
; Puts a sprite at the position of character X Y. Calculates the proper sprite coords from the
; screen memory position then sets it there directly.
; The primary use of this is the inital positioning of any sprite as it will align it with the
; proper delta set up.
;
; PARAM 1 = Character x pos (column)
; PARAM 2 = Character y pos (row)
; X = sprite number
;---------------------------------------------------------------------------------------------------
;; #region "SpriteToCharPos"
.LOCAL
SpriteToCharPos
;;		lda BIT_TABLE,x				 ; Lookup the bit for this sprite number (0-7)
;;		eor #$ff						; flip all bits (invert the byte %0001 would become %1110)
;;		and SPRITE_POS_X_EXTEND		 ; mask out the X extend bit for this sprite
;;		sta SPRITE_POS_X_EXTEND		 ; store the result back - we've erased just this sprites bit
;;		sta VIC_SPRITE_X_EXTEND		 ; store this in the VIC register for extended X bits

		lda PARAM1				      ; load the X pos in character coords (the column)
		sta SPRITE_CHAR_POS_X,x		 ; store it in the character X position variable
;;		cmp #30						 ; if X is less than 30, no need set the extended bit
;;		bcc @noExtendedX
		
;;		lda BIT_TABLE,x				 ; look up the the bit for this sprite number
;;		ora SPRITE_POS_X_EXTEND		 ; OR in the X extend values - we have set the correct bit
;;		sta SPRITE_POS_X_EXTEND		 ; Store the results back in the X extend variable
;;		sta VIC_SPRITE_X_EXTEND		 ; and the VIC X extend register

@noExtendedX
										; Setup our Y register so we transfer X/Y values to the
										; correct VIC register for this sprite
;;		txa						     ; first, transfer the sprite number to A
;;		asl						     ; multiply it by 2 (shift left)
;;		tay						     ; then store it in Y 
										; (note : see how VIC sprite pos registers are ordered
										;  to understand why I'm doing this)

;;		lda PARAM1				      ; load in the X Char position
		asl						     ; 3 x shift left = multiplication by 8
		asl
;;		asl  	;; Atari -- * 4.   4 color clocks per char
		clc						     
;;		adc #24 - SPRITE_DELTA_OFFSET_X ; add the edge of screen (24) minus the delta offset
										; to the rough center 8 pixels (1 char) of the sprite
		adc #[PLAYFIELD_LEFT_EDGE_NORMAL-2] ;; Atari align to edge.  center 8 color clock sprite 
											;; on 4 color clock text position

		sta SPRITE_POS_X,x		      ; save in the correct sprite pos x variable
;;       sta VIC_SPRITE_X_POS,y		  ; save in the correct VIC sprite pos register
		sta HPOSP0,x ;; Atari 

;; Atari -- need to remove old P/M first
		jsr ClearSpriteToPM

		lda PARAM2				      ; load in the y char position (rows)
		sta SPRITE_CHAR_POS_Y,x		 ; store it in the character y pos for this sprite
		asl						     ; 3 x shift left = multiplication by 8
		asl
		asl
		clc
 ;;       adc #50 - SPRITE_DELTA_OFFSET_Y ; add top edge of screen (50) minus the delta offset
		adc #[PM_1LINE_NORMAL_TOP-11] ;; Atari "normal" is 1 text line shorter than our custom screen.
									;; Therefore this starts 4 scanlines earlier.   Then the shape size
									;; is 21 lines of data, so subtract 7 more to center (ish)

       sta SPRITE_POS_Y,x		      ; store in the correct sprite pos y variable
 ;;       sta VIC_SPRITE_Y_POS,y		  ; and the correct VIC sprite pos register

		lda SPRITE_0_PTR,x
		jsr CopySpriteToPM  ;; Atari -- any vertical movement or animation needs a redraw.
 
		lda #0 ;; Atari -- this aligns to the "center" of the target character
		sta SPRITE_POS_X_DELTA,x		;set both x and y delta values to 0 - we are aligned
		sta SPRITE_POS_Y_DELTA,x		;on a character border (for the purposes of collisions)
		rts

;; #endregion

;; Atari extras....

;===================================================================================================
;																				COPY SPRITE TO PM
;===================================================================================================
;; Update Player/Missile image.
;;
;; X = number of sprite updated.
;; A = sprite image number
;---------------------------------------------------------------------------------------------------
;; An Atari-specific peculiarity, since P/M graphics are a vertical bitmap.
;; When a (VIC) Sprite pointer is changed or the 
;; Y sprite position is changed then a new image 
;; must be copied to the player.
;; This assumes another mechanism erased the player, or the 
;; sprite data includes enough 0 bytes to empty the overlap 
;; area left behind by vertical movement.
;---------------------------------------------------------------------------------------------------
;; FYI:
;; sprite image source == SPRITE_X_PTR * 64 + SCREEN_MEM
;; destination = PMADR_BASE for sprite + SPRITE_POS_Y
;; A == sprite image number
;; X == sprite
;---------------------------------------------------------------------------------------------------
.LOCAL
CopySpriteToPM
	sta PARAM7
;; Save regs so this is non-disruptive to caller
	saveRegs ;; macro
;; sprite image number converted to address
;; in a lookup table to avoid about a dozen 
;; instructions to multiply the index by 64...
	ldy PARAM7 ;; sprite image number
	lda SPRITE_INDEX_LOOKUP_LO,y
	sta ZEROPAGE_POINTER_6
	lda SPRITE_INDEX_LOOKUP_HI,y
	sta ZEROPAGE_POINTER_6+1	
;; sprite Y position into zero page...
;; and add to player base memory
	lda SPRITE_POS_Y,x
	sta ZEROPAGE_POINTER_7; ;; low byte is Y position
	lda PMADR_BASE,x
	sta ZEROPAGE_POINTER_7+1 ;; high byte from PMADR table.
;; Now copy 21 bytes from sprite image to PM memory.
;; Optimal-ish code size version.  
;; Execution-optimal version would be 21 sets of LDA, STA, DEY.
	ldy #20 ;; 20 to 0 is 21 bytes
?LoopCopySpriteImage
	lda (ZEROPAGE_POINTER_6),y ;; source sprite imaage
	sta (ZEROPAGE_POINTER_7),y ;; target P/M memory
	dey
	bpl ?LoopCopySpriteImage
;; restore regs
	safeRTS ;; macro

;===================================================================================================
;																		       CLEAR SPRITE TO PM
;===================================================================================================
;; Clear Player/Missile image  at Y position
;;
;; X = number of sprite updated.
;---------------------------------------------------------------------------------------------------
;; An Atari-specific function.
;; Erase only the part of P/M memory where 
;; there was an image (or so we hope).
;---------------------------------------------------------------------------------------------------
;; destination = PMADR_BASE for sprite + SPRITE_POS_Y
;---------------------------------------------------------------------------------------------------
.LOCAL
ClearSpriteToPM
;; Save regs so this is non-disruptive to caller
	saveRegs ;; macro
;;  get this player base memory (high byte)
	lda PMADR_BASE,x
	sta ZEROPAGE_POINTER_7+1
;; "add" sprite Y position (low byte)...
	lda SPRITE_POS_Y,x
	sta ZEROPAGE_POINTER_7
;;  Now zero the 21 bytes in PM memory
	ldy #20 ;; 20 to 0 is 21 bytes
	lda #0
?LoopClearPMImage ;; the optimal code size version
	sta (ZEROPAGE_POINTER_7),y
	dey
	bpl ?LoopClearPMImage
;; restore regs
	safeRTS ;; macro
	
;===================================================================================================
;																		       MOVE PM OFF SCREEN
;===================================================================================================
;; Move Player/Missiles off screen (to be not visible.)
;;
;---------------------------------------------------------------------------------------------------
;; An Atari-specific function.
;; Setting HPOS to 0 for all players/missile guarantees they are not visible even if the 
;; P/M memory has data or junk in it, no matter what the width is for P/M graphics.
;---------------------------------------------------------------------------------------------------
.LOCAL
MovePMOffScreen
;; Save regs so this is non-disruptive to caller
	saveRegs ;; macro
;; sprite Y position to zero page...
;;  and add to player base memory
	lda #$00 ;; 0 position
	ldx #$03 ;; four objects, 3 to 0
?LoopZeroPMPosition ;; the optimal code size version
	sta HPOSP0,x ;; Players 3, 2, 1, 0
	sta HPOSM0,x ;; Missiles 3, 2, 1, 0 just to be sure.
	dex
	bpl ?LoopZeroPMPosition
;; restore regs
	safeRTS ;; macro

;===================================================================================================
;																		       PM RIPPLE UP 
;===================================================================================================
;; Move Player/Missiles image up one scan line from current position
;; looping from top line to bottom/end.
;;
;---------------------------------------------------------------------------------------------------
;; An Atari-specific peculiarity.
;; 
;---------------------------------------------------------------------------------------------------
.LOCAL
AtariPMRippleUp
	;; Save regs so this is non-disruptive to caller
	saveRegs ;; macro
	
	; High byte P/M memory pointers...
	lda PMADR_BASE,X
	sta ZEROPAGE_POINTER_6+1 ; copy destination
	sta ZEROPAGE_POINTER_7+1 ; copy source

	; Low byte P/M memory pointer is the Y position...	
	lda SPRITE_POS_Y,x
	sta ZEROPAGE_POINTER_6  ;; copy destination
	sta ZEROPAGE_POINTER_7  ;; copy target
	dec ZEROPAGE_POINTER_6 ;; one line higher, decrement.
	;
	ldx #20  ;; 20 to 0 is 21 bytes of data (to avoid cmp)
	ldy #0 ;;  but this has to count up 0 to 20
	;
;; Copy 21 bytes.
;; Code-size optimal version.
;; Execution speed version would be 21 sets of LDA, STA, INY
?RippleUp ;; the optimal code size version
	lda (ZEROPAGE_POINTER_7),y ;; from source
	sta (ZEROPAGE_POINTER_6),y ;; to target one line higher
	iny ;; move to next (lower line of data)
	dex ;; to avoid cmp...
	bpl ?RippleUp ;; 20 to 0 is positive. end when $FF
	dey ;; go back up to the last line of source data
	lda #0
	sta (ZEROPAGE_POINTER_7),y ;; clear the last source byte.
	
	;; restore regs
	safeRTS ;; macro
	
;===================================================================================================
;																		       PM RIPPLE DOWN 
;===================================================================================================
;; Move Player/Missiles image DOWN one scan line from current position
;; looping from bottom/end byte to top.
;;
;---------------------------------------------------------------------------------------------------
;; An Atari-specific peculiarity.
;; x == sprite number
;---------------------------------------------------------------------------------------------------
.LOCAL
AtariPMRippleDown
	;; Save regs so this is non-disruptive to caller
	saveRegs ;; macro
	
	; High byte P/M memory pointers...
	lda PMADR_BASE,X
	sta ZEROPAGE_POINTER_6+1 ; copy destination
	sta ZEROPAGE_POINTER_7+1 ; copy source

	; Low byte P/M memory pointer is the Y position...	
	lda SPRITE_POS_Y,x
	sta ZEROPAGE_POINTER_6  ; copy destination
	sta ZEROPAGE_POINTER_7  ; copy target
	inc ZEROPAGE_POINTER_6 ; one line lower, increment.
	;
	ldy #20 ; 20 to 0 is 21 bytes of data
	;
;; Copy 21 bytes.
;; Code-size optimal version.
;; Execution speed version would be 21 sets of LDA, STA, DEY
?RippleDown
	lda (ZEROPAGE_POINTER_7),y ;; from source
	sta (ZEROPAGE_POINTER_6),y ;; to target one line lower
	dey ; up one line
	bpl ?RippleDown ; 20 to 0 is positive. end when $FF
	iny ;; Go back down to the last line of source data.
	lda #0
	sta (ZEROPAGE_POINTER_7),y ;; clear the last source byte.
	
	;; restore regs
	safeRTS ;; macro


;;------------------------------------------------------------
;; Extra stuff to assist the Atari simulation of C64 sprites.
;; A gratuitous and flagrant waste of memeory to produce a 
;; lookup table of 256 pointers to sprite images.
;; This half-K of tables save a dozen instructions to multiply 
;; the sprite index by 64 and add it to the screen memory 
;; bank address.
;;------------------------------------------------------------
;; SCREEN_MEM must be defined first!!!
;;------------------------------------------------------------

;;	.byte "Sprite Index Lookup Lo"
SPRITE_INDEX_LOOKUP_LO
	r .= 0
	.REPT 256
	.BYTE <[SCREEN_MEM+[r*64]]
	r .= r+1
	.ENDR
;;
;;	.byte "Sprite Index Lookup Hi"	
SPRITE_INDEX_LOOKUP_HI
	r .= 0
	.REPT 256
	.BYTE >[SCREEN_MEM+[r*64]]
	r .= r+1
	.ENDR
	;;
;;.byte "End of Sprite Index Lookup"

	