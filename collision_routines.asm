;===============================================================================
;														   COLLISION ROUTINES
;===============================================================================
;														    Peter 'Sig' Hewett
;																       - 2016
;; Atari-fied for eclipse/wudsn/atasm by Ken Jennings
;; FYI -- comments with double ;; are Ken's for Atari
;-------------------------------------------------------------------------------
; Routines dealing with collisions between game objects
;-------------------------------------------------------------------------------

;===============================================================================
;										       SPRITE TO BACKGROUND CHARACTERS
;===============================================================================
; Checks to see if the sprite is colliding with a background character.
; Many of these checks will be 'forward looking' (especially in movement checks)
; We will be looking to where the sprite will be, not where it is, and then
; letting the sprite handling routines update the positions and deltas for us
; if we move.
;-------------------------------------------------------------------------------

;; ------------------------------------------------------------------------------
;; Atari discussion....
;; The dimensions and copordinates of C64 sprites and Atari P/M graphics
;; are entirely different, so the coordinates for placement, centering on
;; characters, and the deltas will be  different on the Atari.
;;
;; First is a really huge assumption... Based on screen grabs from the video 
;; of the C64 version it appears to me the goal is to center the sprite in the 
;; X and Y directions. (Me, personally, considering the subject is a platformer
;; game I would center the object horizontally on a character, but align the 
;; bottomn of the sprite to the bottom of the character position.)  Anywho...  
;;
;; A second problem is that Players and characters are both an even number
;; of color clocks wide. While this allows them to be perfectly aligned on 
;; each other they actually have no "center" location. Likewise, the even 
;; number of scan lines in a character means there is no exact center line on
;; a character.  Therefore, "center" must be slightly off center in terms of
;; pixels and scan lines. This means in both the horizonal and vertical 
;; directions there must be an uneven amount of delta toward one direction 
;; vs its opposite direction.
;;
;; Given that Player pixels and coordinates are on color clocks (8 per Player) 
;; and multi-color font glyph pixels are color clocks (4 per character), this 
;; illustration below is how the code aligns the 8 pixels wide by 21 scan 
;; lines tall Player on a group of 3x3 (multicolor) characters each 4 color 
;; clocks wide by 8 scan lines tall.
;;
;; P is the Player outline/dimensions in color clocks/scan lines.
;; x, c, and . are character pixels.
;; Player pixels are drawn over character pixels.
;; Numbers/hex count player pixels and scan lines relative to Player origin.
;;
;; --     0 1 2 3 4 5 6 7     
;; -- x x x x .|.|. . x x x x
;; 00 x x P P P|P|P P P P x x
;; 01 x x P x .|.|. . x P x x
;; 02 x x P x .|.|. . x P x x
;; 03 x x P x .|.|. . x P x x
;; 04 x x P x .|.|. . x P x x
;; 05 x x P x .|.|. . x P x x  
;; 06 x x P x .|.|. . x P x x  
;; 07 . . P . c|c|c c . P . . -3 Player Delta Y vs char center
;; 08 . . P . c|c|c c . P . . -2
;; 09 . . P . c|c|c c . P . . -1 
;;    ---------+-+----------- 
;; 0A . . P . c|c|c c . P . .  0 << Character "center" pixel
;;    ---------+-+-----------
;; 0B . . P . c|c|c c . P . .  1 
;; 0C . . P . c|c|c c . P . .  2
;; 0D . . P . c|c|c c . P . .  3
;; 0E . . P . c|c|c c . P . .  4
;; 0F x x P x .|.|. . x P x x
;; 10 x x P x .|.|. . x P x x
;; 11 x x P x .|.|. . x P x x
;; 12 x x P x .|.|. . x P x x
;; 13 x x P x .|.|. . x P x x
;; 14 x x P P P|P|P P P P x x
;; -- x x x x .|.|. . x x x x
;; -- x x x x .|.|. . x x x x
;; --        -1 0 1 2		 Player Delta X vs char center
;;
;; Useless Factoids:
;;
;; Character Center X == Player Origin X + 3 
;; Character Center Y == Player Origin Y + 10
;;
;; Character Origin X == PM Origin X + 2
;; Character Origin Y == PM Origin Y + 7
;;
;; Character Max X == PM Origin X + 5
;; Character Max Y == PM Origin Y + 14   
;; 
;; Because the player is both wider and taller than a character in order
;; to position a Player centered over every possible character the allowable 
;; minimum/maximum positioning in terms of color clocks and scan lines must be 
;; expanded by the amount of overlap:
;;
;; Minimum Player X = Minimum Player Base X - 2 for overlap
;; OR
;; Minimum Player X = PLAYFIELD_LEFT_EDGE_NORMAL - 2 for overlap
;;
;; Maximum Player X = PLAYFIELD_LEFT_EDGE_NORMAL + 152 + 2 for overlap  
;; OR
;; Maximum Player X = PLAYFIELD_RIGHT_EDGE_NORMAL - 5 
;; (152 is the result of: 40 chars * 4 pixels - 8 to align right side of player on playfied)
;; 
;; Minimum Player Y == Mimimum scanline - 7 
;; Maximum Player Y == Minimum Player Y + 200 
;;
;; --------------------------------------------------------------------------
;;
;; Therefore, overlaps....  Since the Player is 8 color clocks wide it covers
;; more space than a 4 color clock character (8 is bigger than 4, trust me)
;; thus depending on where the Player is placed its 8 color clocks can 
;; overlap two or three characters.  
;;
;; P is the Player dimensions in color clocks
;; c, and . are character pixels.
;; * are the pixels of the Player's current character position
;; x are the character pixels of the character(s) that are 
;; considered overlapped.
;;
;; X Delta -1
;;          PPP*PPPP
;; cccc....xxxx****xxxx....cccc   overlap X-1, X, and X+1
;;
;;
;; X Delta 0
;;           PPP*PPPP
;; cccc....xxxx****xxxx....cccc   overlap X-1, X, and X+1
;;
;;
;; X Delta 1
;;            PPP*PPPP
;; cccc....xxxx****xxxx....cccc   overlap X-1, X, and X+1
;;
;;
;; X Delta 2
;;             PPP*PPPP
;; cccc....cccc****xxxx....cccc   overlap X, and X+1
;;
;; In the vertical direction the Player is 21 Scan lines tall, so it 
;; always overlaps a minimum of three, 8 scan line characters, sometimes
;; 4 characters.  Again, which characters are overlapped depends on 
;; the delta position. Illustrations are rotated from vertical to 
;; horizontal...
;;
;; Y Delta -3
;;               PPPPPPPPPP*PPPPPPPPPP
;; ccccccccxxxxxxxxxxxxxxxx********xxxxxxxx........cccccccc   overlap Y-2, Y-1, Y, and Y+1
;;
;;
;; Y Delta -2
;;                PPPPPPPPPP*PPPPPPPPPP
;; ccccccccxxxxxxxxxxxxxxxx********xxxxxxxx........cccccccc   overlap Y-2, Y-1, Y, and Y+1
;;
;;
;; Y Delta -1
;;                 PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxx........cccccccc   overlap Y-1, Y, and Y+1
;;
;;
;; Y Delta 0
;;                  PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxx........cccccccc   overlap Y-1, Y, and Y+1
;;
;;
;; Y Delta 1
;;                   PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxx........cccccccc   overlap Y-1, Y, and Y+1
;;
;;
;; Y Delta 2
;;                    PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxx........cccccccc   overlap Y-1, Y, and Y+1
;;
;;
;; Y Delta 3
;;                     PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxxxxxxxxxxcccccccc   overlap Y-1, Y, Y+1, and Y+2
;;
;;
;; Y Delta 4
;;                      PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxxxxxxxxxxcccccccc   overlap Y-1, Y, Y+1, and Y+2
;;
;; --------------------------------------------------------------------------
;;
;; Therefore, predictive collision detection....   How the Player overlaps 
;; then relates to which characters should be tested to allow motion.  The 
;; target to test is the position the Player will move to....
;;
;; Assume both lines overlap.
;;
;; P is the Player dimensions in color clocks
;; c, and . are character pixels.
;; * are the pixels of the Player's current character position
;; x is the character pixels of the character(s) that should be r
;; tested to allow movement left or right.
;;
;; X Delta -1
;;          PPP*PPPP
;; cccc....xxxx****xxxx....cccc   test left X-1 or right X+1
;;
;;
;; X Delta 0
;;           PPP*PPPP
;; cccc....xxxx****xxxx....cccc   test left X-1 or right X+1
;;
;;
;; X Delta 1
;;            PPP*PPPP
;; cccc....xxxx****xxxx....cccc   test left X-1 or right X+1
;;
;;
;; X Delta 2
;;             PPP*PPPP
;; cccc....xxxx****ccccxxxxcccc   test left X-1 or right X+2
;;
;;
;; Similar thought in the vertical direction.
;; Again, which characters to test vertically depends on 
;; the delta position...
;;
;; Y Delta -3
;;               PPPPPPPPPP*PPPPPPPPPP
;; ccccccccxxxxxxxx........********xxxxxxxx........cccccccc   test up Y-2 or down Y+1
;;
;;
;; Y Delta -2
;;                PPPPPPPPPP*PPPPPPPPPP
;; ccccccccxxxxxxxx........********xxxxxxxx........cccccccc   test up Y-2 or down Y+1
;;
;;
;; Y Delta -1
;;                 PPPPPPPPPP*PPPPPPPPPP
;; ccccccccxxxxxxxx........********xxxxxxxx........cccccccc   test up Y-2 or down Y+1
;;
;;
;; Y Delta 0
;;                  PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxx........cccccccc   test up Y-1 or down Y+1
;;
;;
;; Y Delta 1
;;                   PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********xxxxxxxx........cccccccc   test up Y-1 or down Y+1
;;
;;
;; Y Delta 2
;;                    PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********ccccccccxxxxxxxxcccccccc   test up Y-1 or down Y+2
;;
;;
;; Y Delta 3
;;                     PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********ccccccccxxxxxxxxcccccccc   test up Y-1 or down Y+2
;;
;;
;; Y Delta 4
;;                      PPPPPPPPPP*PPPPPPPPPP
;; cccccccc........xxxxxxxx********ccccccccxxxxxxxxcccccccc   test up Y-1 or down Y+2
;;
;; --------------------------------------------------------------------------
;;
;; Therefore, movement tests...
;; Testing for collisions  only needs to occur at the point 
;; where the change in delta results in a change in the target character 
;; to test.  If the new delta will not result in changing the target
;; character, then testing the target has no purpose, because it had 
;; previously been checked in order to put the Player at its current 
;; character position. 
;;
;; Conveniently, at X Delta +2 the Player is in a position where it 
;; exactly covers two characters (the current character position and the
;; character at X Position + 1.)  So, the only time collision detection 
;; is needed is when the Player will move from X Delta +2.
;;
;; In the Y direction the change in character occlusion occurs when 
;; the Player moves up from Y Delta - 1, and down from Y Delta + 2.
;;
;; and so.....
;;
;; Moving left or right from X Delta +2:
;; Y Delta -3 = test position (left) X-1 or (right) X+2 at Y-2, Y-1, Y, Y+1
;; Y Delta -2 = test position (left) X-1 or (right) X+2 at Y-2, Y-1, Y, Y+1
;; Y Delta -1 = test position (left) X-1 or (right) X+2 at      Y-1, Y, Y+1
;; Y Delta  0 = test position (left) X-1 or (right) X+2 at      Y-1, Y, Y+1
;; Y Delta +1 = test position (left) X-1 or (right) X+2 at      Y-1, Y, Y+1
;; Y Delta +2 = test position (left) X-1 or (right) X+2 at      Y-1, Y, Y+1
;; Y Delta +3 = test position (left) X-1 or (right) X+2 at      Y-1, Y, Y+1, Y+2
;; Y Delta +4 = test position (left) X-1 or (right) X+2 at      Y-1, Y, Y+1, Y+2
;; 
;; Moving up from Y Delta -1:
;; X Delta -1 = test position Y-2 at X-1, X, X+1
;; X Delta  0 = test position Y-2 at X-1, X, X+1
;; X Delta +1 = test position Y-2 at X-1, X, X+1
;; X Delta +2 = test position Y-2 at      X, X+1
;;
;; Moving down from Y Delta +2:
;; X Delta -1 = test position Y+2 at X-1, X, X+1
;; X Delta  0 = test position Y+2 at X-1, X, X+1
;; X Delta +1 = test position Y+2 at X-1, X, X+1
;; X Delta +2 = test position Y+2 at      X, X+1
;;
;; --------------------------------------------------------------------------
;;
;; The Breakout Problem.
;; (Discussion Of A Border Condition [aka bug] That Occurs 
;; When Optimizing Pre-Movement Collision Detection Which 
;; Is Entirely Pointless, Because This Program's Methods
;; Are Not Optimized.)
;;
;; In many games typical of the retro era the collision detection is 
;; evaluated only after two opjects overlap each other.  This is 
;; perfectly fine for the purpose of sudden finality (big boom kill
;; player.)  
;;
;; However, there are situations where allowing motion to continue until 
;; an overlapping collision occur is not an optimal or visually pleasant
;; result.  One of these is a platformer type of game.  If the game
;; relies on actual collision to stop the motion of an object it then has
;; to move the player back to a previous non-colliding position. When the 
;; object moves and hits something the position reset would be seen as 
;; jitter or bouncing which may be undesirable. 
;; 
;; Therefore, many kinds of games rely on detecting collisions before
;; they occur.  An object may move up toward a potential collision, but 
;; logic determines that further motion in the same direction will be
;; a collision and so prevents the movement.  This game at the current
;; stage exercises this behavior.
;;
;; There is another kind of game relying on collisions that many 
;; programmers have written and copied due to its simplicity -- Breakout.
;; All the game needs is management of block-sized pixels.  However,
;; the nature of the game -- one bouncing, giant brick running into other 
;; bricks at different angles -- amplifies problems in different kinds of 
;; collision detection.
;;
;; The problem occurs with objects colliding at diagonal angles. 
;; A common programmer optimization for predictive collision detection 
;; treats diagnonal movement separately from strictly horizonal and 
;; vertical motion. Here is an illustration of an object (*) moving 
;; diagonally through other objects/blocks:
;;
;;      MOVING XXXXXXXX
;;     TO HERE XXXXXXXX
;;     XXXXXXXX******** << Moving from here
;;     XXXXXXXX********
;;
;; When large motion steps occur (the size of the block/object) then
;; diagonal motion will move the block in one step between the other 
;; blocks. Collision detection relying on actual overlap and predictive
;; collision detection that tests only the destination position are
;; both fooled by this situation.  The block travels through the 
;; "gap" between the other blocks and then continues to travel 
;; without colliding with anything.
;;
;; If object motion is not smaller than the blocks then overlapping
;; collision detection cannot stop the block.  Predictive collision 
;; detection will not catch the collision if it tests only the 
;; diagnonal destination position.  However, if the predictive 
;; method checks the vertical position above and the horizontal 
;; position to the left of the block, then it can rebound the 
;; moving block successfully.
;;
;; Optimizing for diagonal movement is a temptation that can 
;; break a game like this experimental platformer which moves objects
;; by indvidual pixels/scan lines on a grid of large blocks (characters.)
;; If an object is allowed to move diagonally in one step it 
;; can overlap a scanline of a character above it or a line of pixels  
;; horizontally next to it because the character at the diagonal was
;; empty.   So, don't try to optimize diagonal motion.  Always test the 
;; diagonal, vertical, and horizontal possibilities.
;;
;; In its current state the game evaluates horizontal and vertical 
;; motion separately and should not be fooled by a diagonal "gap."
;;
;--------------------------------------------------------------------------------
;														       CAN MOVE LEFT
;--------------------------------------------------------------------------------
; Checks ahead to see if this sprite can move left, or if it's going to to be
; stopped by a blocking character.
;
; X = sprite we want to check for
;
; returns A = 0 we can move or A = 1 we are blocked
; X register is left intact
;--------------------------------------------------------------------------------
;; #region "CanMoveLeft"
;; The sprite may move up to the 2nd character position minus the max delta -1.
.LOCAL
CanMoveLeft
												; border test
;;		lda SPRITE_CHAR_POS_X,x				 ; if Char X is 0
;;		bne @trimLeft
;;		lda SPRITE_POS_X_DELTA,x				; and delta is 0
;;		bne @trimLeft
		
		lda SPRITE_CHAR_POS_X,x  ; sprite is at < $26 (or 38)  
		cmp #1				  ;; 38 means 1 column less than the last (39th) 
		bne @checkLeft
		lda SPRITE_POS_X_DELTA,x ; Can be centered,  and stops at -1
		bpl @checkLeft
		
		lda #1						  ; return blocked
		rts
		
;;@trimLeft
;;		lda SPRITE_POS_X_DELTA,x		; fetch the X delta for this sprite
;;		adc SPRITE_DELTA_TRIM_X,x       ; add delta trim X
;; ;;		and #%111				       ; Mask the result for 0-7
;;		and ~00000111 ;; atasm syntax

;;		beq @checkLeft				  ; if delta != 0 no need to check for a blocking
										; character - we're not flush with the char set
;;		lda #0						  ; load a return code of #0 and return
;;		rts

@checkLeft
;;		lda SPRITE_POS_Y_DELTA,x		; if the Y Delta is 0, we only need to check 2 characters
;;		beq @checkLeft2				 ; on the direct left of the sprite base because we are 'flush'
										; on the Y axis with the character map

										; Here we aren't flush - so we have to check 3 characters

		ldy SPRITE_CHAR_POS_Y,x		 ; fetch sprites Y character position (in screen memory)

		iny ;; this is used for the right, but why wasn't it here for the left?

		lda SCREEN_LINE_OFFSET_TABLE_LO,y       ; store the address in ZEROPAGE_POINTER_1
		sta ZEROPAGE_POINTER_1
		lda SCREEN_LINE_OFFSET_TABLE_HI,y
		sta ZEROPAGE_POINTER_1 + 1
		
;;		lda SPRITE_CHAR_POS_X,x				 ; fetch sprites X position (in screen memory)
;;		clc
;;		adc #39								  ; add 39 (go down one row and one place to the left)
;;		tay								     ; store it in the Y register
		ldy SPRITE_CHAR_POS_X,x				 ; fetch sprites X position, store it in Y
		dey
		
		lda (ZEROPAGE_POINTER_1),y		      ; fetch the character from screen mem
		jsr TestBlocking						; test to see if it blocks
		bne @blockedLeft						; returned 1  - so blocked

;;@checkLeft2
;;		ldy SPRITE_CHAR_POS_Y,x				 ; fetch the sprites Y position and store it in Y
;;		dey								     ; decrement by 1 (so 1 character UP)
;;		lda SCREEN_LINE_OFFSET_TABLE_LO,y       ; store that memory location in ZEROPAGE_POINTER_1
;;		sta ZEROPAGE_POINTER_1
;;		lda SCREEN_LINE_OFFSET_TABLE_HI,y 
;;		sta ZEROPAGE_POINTER_1 + 1

;;		ldy SPRITE_CHAR_POS_X,x				 ; get the sprites X position and store in Y
;;		dey								     ; decrement by 1 (one character left)
		
;;		lda (ZEROPAGE_POINTER_1),y		      ; fetch the contents of screen mem 1 left and 1 up
;;		jsr TestBlocking						; test for blocking
;;		bne @blockedLeft

;;		tya								     ; transfer screen X pos to the accumulator
;;		clc		     
;;		adc #40								 ; add 40 - bringing it one row down from the last
;;		tay								     ; check made, then transfer it back to Y
		
;;		lda (ZEROPAGE_POINTER_1),y		      ; fetch the character from that screen location
;;		jsr TestBlocking						; and test it for blocking
;;		bne @blockedLeft

		lda #0								  ; return value #0 = not blocked
		rts

@blockedLeft
		lda #1				       ; we can't move, so load a #1 in A and return
		rts

;; #endregion

;--------------------------------------------------------------------------------
;														       CAN MOVE RIGHT
;--------------------------------------------------------------------------------
; Checks ahead to see if this sprite can move right, or if it's going to to be
; stopped by a blocking character.
;
; X = sprite we want to check for
;
; returns A = 0 we can move or A = 1 we are blocked
; X register is left intact
;---------------------------------------------------------------------------------
;; Lets see if I can figure this out on the Atari....
;; The sprite may move up to the 38th character position plus the max delta 2.
 

;; #region "CanMoveRight"
.LOCAL
CanMoveRight
;;		clc				      ; simple right border check
		lda SPRITE_CHAR_POS_X,x  ; sprite is at < $26 (or 38)  
		cmp #38				  ;; 38 means 1 column less than the last (39th) 
		bne @checkRight
		lda SPRITE_POS_X_DELTA,x ; Can be centered,  and +1 but not +2
		cmp #2
		bne @checkRight
		
		lda #1						  ; return blocked
		rts

;;		bne @trimRight
;; ;;		clc
;;		lda SPRITE_POS_X_DELTA,x		 ; and delta < $04
;; ;;		cmp #4
;;		bpl @trimRight
		
;;		lda #1						  ; return blocked
;;		rts

;;Not really understanding this
		
;;@trimRight
;;		clc
;;		lda SPRITE_POS_X_DELTA,x		; if Delta = 0, perform checks
;;		adc SPRITE_DELTA_TRIM_X,x       ; add delta trim
;; ;;		and #%111				       ; Mask the result for 0-7
;;		and ~00000111 ;; atasm syntax

;;		beq @checkRight

;;		lda #0						  ; we can move, return 0
;;		rts

@checkRight
;;		lda SPRITE_POS_Y_DELTA,x       ; flush check on Y - if so, only check 2 chars
;;      beq @rightCheck2

		ldy SPRITE_CHAR_POS_Y,x		 ; Check third character position - we are not flush with
		iny						     ; the screen character coords
		lda SCREEN_LINE_OFFSET_TABLE_LO,y
		sta ZEROPAGE_POINTER_1
		lda SCREEN_LINE_OFFSET_TABLE_HI,y
		sta ZEROPAGE_POINTER_1 + 1
		
		ldy SPRITE_CHAR_POS_X,x				 ; fetch sprites X position, store it in Y
		iny
;;		iny

		lda (ZEROPAGE_POINTER_1),y
		jsr TestBlocking
		bne @blockedRight
		
;;@rightCheck2
;;		ldy SPRITE_CHAR_POS_Y,x
;;		dey
;;		lda SCREEN_LINE_OFFSET_TABLE_LO,y
;;		sta ZEROPAGE_POINTER_1
;;		lda SCREEN_LINE_OFFSET_TABLE_HI,y
;;		sta ZEROPAGE_POINTER_1 + 1

;;		ldy SPRITE_CHAR_POS_X,x
;;		iny
;;		iny

;;		lda (ZEROPAGE_POINTER_1),y

;;		jsr TestBlocking
;;		bne @blockedRight

;;		tya
;;		clc
;;		adc #40
;;		tay
;;		lda (ZEROPAGE_POINTER_1),y
;;		jsr TestBlocking
;;		bne @blockedRight

		lda #0
		rts

@blockedRight
		lda #1
		rts

;; #endregion

;--------------------------------------------------------------------------------
;														       CAN MOVE UP
;--------------------------------------------------------------------------------
; Checks ahead to see if this sprite can move up, or if it's going to to be
; stopped by a blocking character.
;
; X = sprite we want to check for
;
; returns A = 0 we can move or A = 1 we are blocked
; X register is left intact
;---------------------------------------------------------------------------------
;; #region "CanMoveUp"
.LOCAL
CanMoveUp
		lda SPRITE_POS_Y_DELTA,x  ; sprite is at < $26 (or 38)  
		cmp #1				  ;; 38 means 1 column less than the last (39th) 
		bne @checkUp
		lda SPRITE_POS_Y_DELTA,x ; Can be centered,  and stops at -2
		adc #$02 
		bpl @checkUp
		
		lda #1						  ; return blocked
		rts

;;		lda SPRITE_POS_Y_DELTA,x		; load Delta Y value
;;		beq @checkUp				    ; if it's 0 we need to check characters

;;		lda #0						  ; if not we can just return and move
;;		rts


@checkUp
		ldy SPRITE_CHAR_POS_Y,x		 ; Check third character position - we are not flush with
		dey						     ; the screen character coords
		lda SCREEN_LINE_OFFSET_TABLE_LO,y
		sta ZEROPAGE_POINTER_1
		lda SCREEN_LINE_OFFSET_TABLE_HI,y
		sta ZEROPAGE_POINTER_1 + 1
		
		ldy SPRITE_CHAR_POS_X,x				 ; fetch sprites X position, store it in Y
;;		iny
;;		iny

		lda (ZEROPAGE_POINTER_1),y
		jsr TestBlocking
		bne @upBlocked


;;		lda SPRITE_POS_X_DELTA,x		; Check X delta - if 0 we only need to check one
;		adc SPRITE_DELTA_TRIM_X,x       ; add our trim and make keep within 0-7 range
;		and #%111
		
;;		beq @checkUp2				   ; character above the player
										; else we are not flush on X and need to check 2

;;		ldy SPRITE_CHAR_POS_Y,x		 ; fetch the sprite Y char coord - store in Y
;;		dey
;;		dey						     ; subtract 2

;;		lda SCREEN_LINE_OFFSET_TABLE_LO,y       ; fetch the address of screen line address
;;		sta ZEROPAGE_POINTER_1
;;		lda SCREEN_LINE_OFFSET_TABLE_HI,y
;;		sta ZEROPAGE_POINTER_1 + 1

;;		ldy SPRITE_CHAR_POS_x,x				 ; fetch X position
;;		iny								     ; add one
;; ;		iny								     ; extra for trim

;;		lda (ZEROPAGE_POINTER_1),y

;;		jsr TestBlocking
;;		bne @upBlocked

;;@checkUp2
;;		ldy SPRITE_CHAR_POS_Y,x				 ; get the sprite Y char coordinate
;;		dey								     ; subtract 2
;;		dey
;;		lda SCREEN_LINE_OFFSET_TABLE_LO,y       ; fetch the address of that line
;;		sta ZEROPAGE_POINTER_1
;;		lda SCREEN_LINE_OFFSET_TABLE_HI,y
;;		sta ZEROPAGE_POINTER_1 + 1

;;		ldy SPRITE_CHAR_POS_X,x				 ; fetch the sprite X char coordinate
;		iny								     ; add one for trim

;;		lda (ZEROPAGE_POINTER_1),y

;;		jsr TestBlocking
;;		bne @upBlocked

		lda #0
		rts
		
@upBlocked
		lda #1
		rts

;; #endregion

;--------------------------------------------------------------------------------
;														       CAN MOVE DOWN
;--------------------------------------------------------------------------------
; Checks ahead to see if this sprite can move up, or if it's going to to be
; stopped by a blocking character.
;
; X = sprite we want to check for
;
; returns A = 0 we can move or A = 1 we are blocked
; X register is left intact
;---------------------------------------------------------------------------------
;; #region "CanMoveDown"
.LOCAL
CanMoveDown
		lda SPRITE_CHAR_POS_Y,x  ; sprite is at < $26 (or 38)  
		cmp #19				  ;; 19th Row is max
		bne @downCheck
		lda SPRITE_POS_Y_DELTA,x ; Can be centered,  and +1 and +2, but not +3
		cmp #3
		bne @downCheck
		
		lda #1						  ; return blocked
		rts

;;		lda SPRITE_POS_Y_DELTA,x				; fetch Y delta for this sprite
;;		beq @downCheck						  ; only check if 0 - and flush with screen characters

;;		lda #0								  ; else return with 0 - we can move
;;		rts

@downCheck
		ldy SPRITE_CHAR_POS_Y,x		 ; Check third character position - we are not flush with
		iny						     ; the screen character coords
		lda SCREEN_LINE_OFFSET_TABLE_LO,y
		sta ZEROPAGE_POINTER_1
		lda SCREEN_LINE_OFFSET_TABLE_HI,y
		sta ZEROPAGE_POINTER_1 + 1
		
		ldy SPRITE_CHAR_POS_X,x				 ; fetch sprites X position, store it in Y
;;		iny
;;		iny

		lda (ZEROPAGE_POINTER_1),y
		jsr TestBlocking
		bne @downBlocked
		

;;		lda SPRITE_POS_X_DELTA,x				; Check X delta to see if we're flush on the X axis
;;		beq @downCheck2						 ; if not we need to check 2 characters
		
;;		ldy SPRITE_CHAR_POS_Y,x				 ; fetch character Y position and store it in Y
;;		iny								     ; add 1

;;		lda SCREEN_LINE_OFFSET_TABLE_LO,y       ; fetch address for the screen line
;;		sta ZEROPAGE_POINTER_1
;;		lda SCREEN_LINE_OFFSET_TABLE_HI,y
;;		sta ZEROPAGE_POINTER_1 + 1
		
;;		ldy SPRITE_CHAR_POS_X,x				 ; fetch X character pos for sprite
;;		iny								     ; increase by 1
;;		lda (ZEROPAGE_POINTER_1),y		      ; fetch character at this position

;;		jsr TestBlocking
;;       bne @downBlocked

;; @downCheck2								     ; Check character above the sprite
;;		ldy SPRITE_CHAR_POS_Y,x				 ; load the sprite Y character position
;;		iny								     ; add 1

;;		lda SCREEN_LINE_OFFSET_TABLE_LO,y       ; fetch address for screen line
;;		sta ZEROPAGE_POINTER_1
;;		lda SCREEN_LINE_OFFSET_TABLE_HI,y
;;		sta ZEROPAGE_POINTER_1 + 1
		
;;		ldy SPRITE_CHAR_POS_X,x				 ; fetch X character position and store in Y

;;		lda (ZEROPAGE_POINTER_1),y		      ; fetch character off screen and store in A
		
;;		jsr TestBlocking						; test for blocking
;;		bne @downBlocked

		lda #0								   ; if not blocking return 0
		rts

@downBlocked
		lda #1								  ; if blocked return 1
		rts
;; #endregion		

;=================================================================================
;												   TEST CHARACTER FOR BLOCKING
;=================================================================================
TestBlocking
 ;;       cmp #128				      ; is the character > 128?
		and #$80 ;; If it is any inverse
		bne @blocking  ;;  or bmi works here too
		
		lda #0
		rts
@blocking
		lda #1
		rts

