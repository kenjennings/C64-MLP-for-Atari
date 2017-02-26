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
;; x is the character pixels of the character(s) that should be
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
;; When moving horizontally check these Vertical offsets based on the Y Delta.
;; First byte is the offset to start at.  
;; Each $01 byte after the first byte represents testing +1 position 
;; from the previous test.
;; The byte $00 means no more testing.
;; This allows a table to variably describe 3 or 4 offsets.
COLLIDE_LOOKUP_Y  
    .byte $fe,$01,$01,$01,$00 ;; Y Delta -3, 4 tests from Y-2 to Y+1
    .byte $fe,$01,$01,$01,$00 ;; Y Delta -2, 4 tests from Y-2 to Y+1
    .byte $ff,$01,$01,$00,$00 ;; Y Delta -1, 3 tests from Y-1 to Y+1
    .byte $ff,$01,$01,$00,$00 ;; Y Delta  0, 3 tests from Y-1 to Y+1
    .byte $ff,$01,$01,$00,$00 ;; Y Delta +1, 3 tests from Y-1 to Y+1
    .byte $ff,$01,$01,$00,$00 ;; Y Delta +2, 3 tests from Y-1 to Y+1
    .byte $ff,$01,$01,$01,$00 ;; Y Delta +3, 4 tests from Y-1 to Y+2
    .byte $ff,$01,$01,$01,$00 ;; Y Delta +4, 4 tests from Y-1 to Y+2
;; 
;; Moving UP from Y Delta -1:
;; X Delta -1 = test position Y-2 at X-1, X, X+1
;; X Delta  0 = test position Y-2 at X-1, X, X+1
;; X Delta +1 = test position Y-2 at X-1, X, X+1
;; X Delta +2 = test position Y-2 at      X, X+1
;;
;; Moving DOWN from Y Delta +2:
;; X Delta -1 = test position Y+2 at X-1, X, X+1
;; X Delta  0 = test position Y+2 at X-1, X, X+1
;; X Delta +1 = test position Y+2 at X-1, X, X+1
;; X Delta +2 = test position Y+2 at      X, X+1
;;
;; When moving vertically check these Horizontal offsets based on the X Delta.
;; First byte is the offset to start at. (0 is valid here) 
;; Each $01 byte after the first byte represents testing +1 position 
;; from the previous test.
;; The byte $00 means no more testing.
;; This allows a table to variably describe 2 or 3 offsets.
COLLIDE_LOOKUP_X
    .byte $ff,$01,$01,$00 ;; X Delta -1, 3 tests from X-1 to X+1
    .byte $ff,$01,$01,$00 ;; X Delta -0, 3 tests from X-1 to X+1
    .byte $ff,$01,$01,$00 ;; X Delta +1, 3 tests from X-1 to X+1
    .byte $00,$01,$00,$00 ;; X Delta +2, 2 tests from X   to X+1
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
;; PARAM7 == Adjusted X column (SPRITE_CHAR_POS_X - 1)
;; PARAM6 == Index into COLLIDE_LOOKUP_Y (SPRITE_POS_Y_DELTA adjusted to 0, then * 5)
;; PARAM5 == Adjusted Y row (SPRITE_CHAR_POS_Y - lookup from COLLIDE_LOOKUP_Y)
;--------------------------------------------------------------------------------
;; #region "CanMoveLeft"
;; The sprite may move up to the 2nd character position minus the max delta -1.
.LOCAL
CanMoveLeft
		; border test
		lda SPRITE_CHAR_POS_X,x  ;; sprite is at < $2 ?  
		sta PARAM7 ;; if we need to use POS X later, then save it now
		cmp #$01				  ;; 1 means 1 column more than the first (0th) 

		;; The only way to get here is by crossing from X delta -1 on the 
		;; previous character into X delta +2 for the current character.
		;; Therefore, we are at the limit for X position and delta, so refuse to 
		;; move any further.
		beq ?Blocked

        ;; Moving from X Delta 2 is the only reason the left edge position
        ;; will change, so only X Delta 2 requires collision test.
        ;; All other deltas can return unblocked.
        lda SPRITE_POS_X_DELTA,x
        cmp #$02
        bne ?Unblocked 		;; Everything not 2 is OK for movement
        
        ;; Adjust POS X to one column less (left) of the current position.
		dec PARAM7 ;; saved earlier

        ;; Decrementing the X position (in PARAM7) was the last difference 
        ;; between testing left and right, because the remainder
        ;; of the logic is all driven from the COLLIDE_LOOKUP_Y table.
        
        jsr TestCollisionX ; common code tests and loops.
        
        rts
 
?Unblocked
		lda #$00								  ; return value #0 = not blocked
		rts

?Blocked
		lda #$01				       ; we can't move, so load a #1 in A and return
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
;; PARAM7 == Adjusted X column (SPRITE_CHAR_POS_X + 2)
;; PARAM6 == Index into COLLIDE_LOOKUP_Y (SPRITE_POS_Y_DELTA adjusted to 0, then * 5)
;; PARAM5 == Adjusted Y row (SPRITE_CHAR_POS_Y - lookup from COLLIDE_LOOKUP_Y)
;---------------------------------------------------------------------------------
;; #region "CanMoveRight"
.LOCAL
CanMoveRight
		; border test
		lda SPRITE_CHAR_POS_X,x  ;; sprite is at < $37 ?  
		sta PARAM7 ;; if we need to use POS X later, then save it now
		cmp #37				  ;; 37 means 1 column less than the last (39th),
							;; because position 38 is also covered by the sprite 
		bne ?checkRight
        ;; We are at the limit for X position and delta, so refuse to 
		;; move any further.
		lda SPRITE_POS_X_DELTA,x ; column 37, delta +2 is the limit for movement 
		cmp #2
		beq ?Blocked

?checkRight
        ;; Moving from X Delta 2 is the only reason the right edge position
        ;; will change, so only X Delta 2 requires collision test. 
        ;; All other deltas can return unblocked.
        lda SPRITE_POS_X_DELTA,x
        cmp #2
        bne ?Unblocked  		;; Everything not 2 is OK for movement
        
        ;; Adjust POS X to two column more (right) of the current position.
		inc PARAM7 ;; saved earlier
		inc PARAM7

        ;; Incrementing the X position (in PARAM7) was the last difference 
        ;; between testing left and right, because the remainder
        ;; of the logic is all driven from the COLLIDE_LOOKUP_Y table.
        
        ;; Common code loops and tests
        jsr TestCollisionX
		
		rts

?Unblocked
		lda #$00								  ; return value #0 = not blocked
		rts

?Blocked
		lda #$01				       ; we can't move, so load a #1 in A and return
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
;; PARAM7 == Adjusted X column (SPRITE_CHAR_POS_X - lookup from COLLIDE_LOOKUP_X) 
;; PARAM6 == Index into COLLIDE_LOOKUP_X (SPRITE_POS_X_DELTA adjusted to 0, then * 4)
;; PARAM5 == Adjusted Y row (SPRITE_CHAR_POS_Y - 2)
;---------------------------------------------------------------------------------
;; #region "CanMoveUp"
.LOCAL
CanMoveUp
        ;; border test
        lda SPRITE_CHAR_POS_Y,x  ;; If sprite is not in position 5
        sta PARAM5               ;; then test if movement possible.
        cmp #5
        bne ?checkUp
        
		lda SPRITE_POS_Y_DELTA,x  ; Sprite is in position 5
		cmp #$FF				  ;; it cannot move past Delta -1
		beq ?Blocked

?checkUp
        ;; Moving from Y Delta -1 is the only reason the top edge position
        ;; will change, so only Y Delta -1 requires collision test. 
        ;; All other deltas can return unblocked.
		lda SPRITE_POS_Y_DELTA,x 
		cmp #$FF 
		bne ?Unblocked    ;; Everything not -1 can move.

        ;; Adjust POS Y to two rows above the current position.
		dec PARAM5 ;; saved earlier
		dec PARAM5

        ;; Decrementing the Y position (in PARAM5) was the last difference 
        ;; between testing up and down, because the remainder
        ;; of the logic is all driven from the COLLIDE_LOOKUP_X table.
        
        ;; Common code loops and tests
        jsr TestCollisionY
		
		rts

?Unblocked
		lda #$00								  ; return value #0 = not blocked
		rts

?Blocked
		lda #$01				       ; we can't move, so load a #1 in A and return
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
        ;; border test
        lda SPRITE_CHAR_POS_Y,x  ;; If sprite is not in position 16
        sta PARAM5               ;; then test if movement possible.
        cmp #16
        bne ?checkDown
        
		lda SPRITE_POS_Y_DELTA,x  ; Sprite is in position 16 
		cmp #2				  ;; it cannot move past Delta 2
		beq ?Blocked

?checkDown
        ;; Moving from Y Delta 2 is the only reason the bottom edge position
        ;; will change, so only Y Delta 2 requires collision test. 
        ;; All other deltas can return unblocked.
		lda SPRITE_POS_Y_DELTA,x 
		cmp #2
		bne ?Unblocked    ;; Everything not 2 can move.

        ;; Adjust POS Y to two rows below the current position.
		inc PARAM5 ;; saved earlier
		inc PARAM5

        ;; Incrementing the Y position (in PARAM5) was the last difference 
        ;; between testing up and down, because the remainder
        ;; of the logic is all driven from the COLLIDE_LOOKUP_X table.
        
        ;; Common code loops and tests
        jsr TestCollisionY
		
		rts

?Unblocked
		lda #$00								  ; return value #0 = not blocked
		rts

?Blocked
		lda #$01				       ; we can't move, so load a #1 in A and return
		rts

;; #endregion		

;=================================================================================
;												   TEST CHARACTER FOR BLOCKING
;
;; For now, any character with high bit set is an impenetrable rock
;=================================================================================
.LOCAL
TestBlocking
 ;;       cmp #128				      ; is the character > 128?
		and #$80 ;; If it is any inverse character
		bne ?Blocking  ;;  or bmi works here too
		
		lda #0
		rts
		
?Blocking
		lda #1
		rts


;=================================================================================
;												   Common Left and Right
; X == sprite number.
;
; PARAM7 == Adjusted X Column (by caller)
; PARAM6 == starting index into COLLIDE_LOOKUP_Y from converted DELTA Y value 
; PARAM5 == Starting POS Y determined from current POS Y and COLLIDE_LOOKUP_Y entry
; Y == PARAM5, ready to use to determine screen memory
;=================================================================================
.LOCAL
TestCollisionX
        ;; Check a vertical line of characters to the left or right
        ;; of the current position.

		;; Convert Y delta into array entry starting offset (y * 5)
		clc
        lda SPRITE_POS_Y_DELTA,x ;; first normalize to 0
        adc #$03               ;; -3 to 4 adjusted to  0 to 7
        sta PARAM6          ;; now multiply times 5
        asl ;; * 2
		asl ;; * 4
		clc
		adc PARAM6 ;; + (* 1) == * 5
		sta PARAM6 ;; Now it is a starting value for walking through COLLIDE_LOOKUP_Y

		;; acquire initial adjusted character Y position.
		clc
		tay
		lda SPRITE_CHAR_POS_Y,x
		adc COLLIDE_LOOKUP_Y,y   ; Yes, adding $fe or $ff actually subtracts.  and ignore the carry.
		sta PARAM5
		
		tay ;; 

		;; at this point:
		;; PARAM6 is the index into COLLIDE_LOOKUP_Y
		;; PARAM5 is the test Y location adjusted by COLLIDE_LOOKUP_Y

?loopTestY ;; Test position, return Z flag blocked or not.
        ;; acquire the pointer to screen memory
        jsr Load_Pointer1_As_Screen  		;; Y is the value of PARAM5 and ready to use to determine screen memory...

		ldy PARAM7    ;; Get POS X to adjust screen location

		;; test adjusted screen memory location.  
		lda (ZEROPAGE_POINTER_1),y		      ; fetch the character from screen mem
		jsr TestBlocking					; test to see if it blocks

		bne ?Blocked				; Z clear, not blocked.  Z set, blocked.

		;; Check the next location in COLLIDE_LOOKUP_Y
		inc PARAM6
		ldy PARAM6
		lda COLLIDE_LOOKUP_Y,y
		beq ?Unblocked   ;; a 0 entry is the end of array, so we're clear to move

		;; Continue testing.
		;; increment the Y position and retest.
		inc PARAM5
		ldy PARAM5
		bne ?loopTestY   ;; continue testing. 

?Unblocked
		lda #$00								  ; return value #0 = not blocked
		rts

?Blocked
		lda #$01				       ; we can't move, so load a #1 in A and return
		rts


;=================================================================================
;												   Common Up and Down
;
; X == sprite number.
;
; PARAM7 == Starting POS X determined from current POS X and COLLIDE_LOOKUP_X entry
; PARAM6 == starting index into COLLIDE_LOOKUP_X from converted DELTA X value 
; PARAM5 == Adjusted Y Row (by caller)
; Y == PARAM5,  to determine screen memory
;=================================================================================
.LOCAL
TestCollisionY
        ;; To check a Horizontal line of characters above or below
        ;; the current position some initialization:

		;; Convert X delta into array entry starting offset (X * 4)
		clc
        lda SPRITE_POS_X_DELTA,x ;; first normalize to 0
        adc #$01               ;; -1 to 2 adjusted to  0 to 3
        ;; now multiply times 4
        asl ;; * 2
		asl ;; * 4

		sta PARAM6 ;; Now it is a starting value for walking through COLLIDE_LOOKUP_X

		;; acquire initial adjusted character X position.
		clc
		tay
		lda SPRITE_CHAR_POS_X,x
		adc COLLIDE_LOOKUP_X,y   ; Yes, adding $ff actually subtracts.  and ignore the carry.
		sta PARAM7

		ldy PARAM5 ;; Y row for testing

        ;; acquire the pointer to screen memory
        jsr Load_Pointer1_As_Screen ;; Y is the value of PARAM5  to determine screen memory...
		
		;; at this point:
		;; PARAM6 is the index into COLLIDE_LOOKUP_X
		;; PARAM7 is the test X location adjusted by COLLIDE_LOOKUP_X
		
?loopTestX ;; Test position, return Z flag blocked or not.
		ldy PARAM7    ;; Get POS X to adjust screen location
		
		;; test adjusted screen memory location.  
		lda (ZEROPAGE_POINTER_1),y		      ; fetch the character from screen mem
		jsr TestBlocking					; test to see if it blocks

		bne ?Blocked				; Z clear, not blocked.  Z set, blocked.

		;; Check the next location in COLLIDE_LOOKUP_X
		inc PARAM6
		ldy PARAM6
		lda COLLIDE_LOOKUP_X,y
		beq ?Unblocked   ;; a 0 entry is the end of array, so we're clear to move

		;; Continue testing.
		;; increment the X position and retest.
		inc PARAM7
		bne ?loopTestX   ;; continue testing. 

?Unblocked
		lda #$00								  ; return value #0 = not blocked
		rts

?Blocked
		lda #$01				       ; we can't move, so load a #1 in A and return
		rts


;=================================================================================
;								Load screen row base address into ZeroPage_Pointer1
; Inputs:
; Y == Y character row position.
;
; Outputs:
;
;=================================================================================
Load_Pointer1_As_Screen
        ;; acquire the pointer to screen memory
		lda SCREEN_LINE_OFFSET_TABLE_LO,y       ; store the address in ZEROPAGE_POINTER_1
		sta ZEROPAGE_POINTER_1
		lda SCREEN_LINE_OFFSET_TABLE_HI,y
		sta ZEROPAGE_POINTER_1 + 1
    rts

