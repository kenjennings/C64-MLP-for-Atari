;===================================================================================================
; C64 Brain Assembly Language Project Framework 1.1
; 2016 - Peter 'Sig' Hewett aka RetroRomIcon
; C64 Project source available at:
;; https://drive.google.com/drive/folders/0B2awXrw3k0FPZ1EtYUh1S1BrTm8
;;
;; Atari-fied for eclipse/wudsn/atasm by Ken Jennings
;; FYI -- comments with double ;; are Ken's for Atari
;; Atari/atasm source available at Google Drive:
;; https://drive.google.com/drive/folders/0B2m-YU97EHFER3RFZ3I1b25FM0k
;; And at Github here:
;; https://github.com/kenjennings/C64-MLP-for-Atari
;;
;===================================================================================================
;; #region "ChangeLog"
; Changelog
; 1.1 - changed custom charset to reflect the layout in 'Bear Essentials'
;     - changed chars so 0-9 A-Z start at 0 so displaying hex (0-F) debug
;       info / scores / numbers will be easier
;     - removed many 'tutorial comments' and left only notes
;     - exported VIC and register defines to a seperate file
;     - added screen clear with color and character to clear with
;     - added 'raster time' indicator (yellow bar)
;
; 1.2   Added DisplayText - display a 0 truncated string at X/Y with linebreak and color
;       Added DisplayByte - display the contents of a byte in hex at X/Y
;       Changed Character A-Z 0-9 back to normal, because I'm stupid
;       Added Joystick Read and basic Move Player
;       Added Sprite move u/d/l/r with extended X bit updating
;       Added Handling variables for all hardware sprites
;       Moved routines to 'core' and 'sprites' asm files to keep things neat
;
; 1.3   Setup multicolor sprites with killbot as SPRITE 0 and 1
;       Expanded ANIM_FRAME and SPRITE_DIRECTION variables to include all 8 sprites
;       Cleaned up code from live session so 'AnimTest2' works for all sprites using X register
;       Added 'standing still' to AnimTest2 if direction = 0
;
;       Extended Debug Panel to include char pos and delta x y values
;       Added SPRITE_CHAR_POS_X/Y and SPRITE_POS_X/Y_DELTA variables for all sprites
;       Extended MoveSprite routines to include delta and character coord updates
;       Sprite loading directly from the sprite editor - no more exporting to binary needed
;       Character set loading directly from the character editor - no more exporting to binary
;       Added loadpointer macro
;       Added SpriteToCharPos to set a sprite to character screen coords
;       Added DrawVLine and DrawHLine routines to draw simple character lines
;       Added CanMoveLeft and CanMoveRight to test for blocking characters
;       Added CanMoveUp and CanMoveDown to test for blocking characters
;       Added SPRITE_DELTA_TRIM_X/Y variable to fine tune a sprite to background collision
;       Added TestBlock - test for characters that block (128 - 255)
;       Bounds check on left/right of visible screen through character collision checks
;       Added raster.asm with routines to initialize and remove raster irq chains.
;       Setup a basic raster interrupt chain for the top of screen to handle joystick and
;       and timers, and another at the start of the 'score panel'
;
;       Did some cleanup implementing CBM PRG Studio's ;; #region / ;; #endregion to collapse code
;       
;       TODO - track down and fix a few small 'glitch exceptions' on collisions on up/down
;		      while using trim to adjust for wider sprites - though on a platform style game
;		      these may not be an issue
;		     
;       Demo - Extended animation over 8 sprite images under joy control
;       Demo - Sprite to character collisons using wall borders and a simple platform
;       Demo - Raster color change to show scorboard raster interrupt position
;;
;; 1.3alpha -- Atari version.
;; 		* Modified for atasm building from eclipse/wudsn on linux.
;;		  (atasm -- all the joy of Mac/65, none of the line numbers)
;;		* Mostly, code was not deleted.  Instead, things not needed, or sometimes
;;		  not understood are commented out and applicable replacement code
;;		  added nearby.
;;		* Page zero working locations had to be moved to usable locations on the Atari.
;;		* Screen graphics are built in exactly the same memory location as the C64 version.
;;		* References to color memory are removed.
;;		* Writing text to the screen stuffs values directly into screen memory,
;;		  so the text needs to be in Atari internal format (.SBYTE) , not ASCII/ATASCII 
;;		  format.  This means 0 cannot be an end of string sentinel, since it is a valid
;;		  character in internal format (blank space.)   So, changes are applied for the 
;;		  text writing code using other values for line breaks and end of string.
;;		* Hline and Vline on the screen are nearly unmodified.  Only the color memory
;;		  references are removed.
;;		* The byte to hex display is replaced/optimized.
;;		* A multi-color character set is temporarily added to allow legible text for the
;;		  diagnostics. This has A-Z and 0-9 in multiple colors. It also puts the brick
;;		  character at $20, $40, $60, (and for COLPF3 use $E0.)
;		* Joystick direction determination is replaced with a lookup table.
;;		* Raster interrupts are done by Display List interrupts.  Not entirely sure 
;;		  they occur at the same scan line locations on the screen.
;;		* The left/right/up/down determination had a bit of rework.
;;		* Naturally, sprites are significantly redone.  All the 24x21 images had to be 
;;		  redrawn as 8x21.  However, the finished sprite images are still padded out 
;;		  to 64 bytes, so the frame locations/offsets are the same as the C64.  Also,
;;		  any place a sprite image offset is reset it requires the Atari copy the 
;;		  new image into the Player/Missile memory map.
;;		* The sprite animation is redone.  The animation counter is moved into the
;;		  frame counter. This simplifies a lot of movement code that was setting
;;		  and changing animation frames.
;;		* Collision detection (character position alignment) is mostly broken, because
;;		  I vandalized the code by attempting to center the Players on the center of 
;;		  characters.  This has messed up the math, so the controllable player object 
;;		  overlaps character edges where it should not. 
;;		  FIXING THIS IS TO DO FOR 1.3beta.
;;
;; 1.3beta -- Atari version.
;;		* Guess what?  Collision detection is fixed.  (Aka. collision avoidance.)
;;		  The Player can move anywhere and has pixel perfect movement to the 
;;		  limit of any blocking characters on the playfield. (Any character 
;;		  with the high bit set is treated as blocking.)  This is the only 
;;		  place where original code is deleted and redone from scratch.
;;		  The logic is table driven, so left/right is largely one single block  
;;		  of common code, and up/down is another set.
;;		* To test the boundary/collision code more walls have been added
;;		  to the playfield 
;; 
;-------------------------------------------------------------------------------------------------
;; #endreg

 .include "DOS.asm" ;; Need this for the LOMEM start and run address.

		*=LOMEM_DOS ;; $2000 	; After Atari DOS 2.0s
;;		*=LOMEM_DOS_DUP ;; $3308 	; After Atari DOS 2.0s and DUP
PRG_START 

;===============================================================================
;																   DIRECTIVES
;===============================================================================
;; Operator Calc		; IMPORTANT - calculations are made BEFORE hi/lo bytes
				     ;		     in precidence (for expressions and tables)
;===============================================================================
;																   DEFINITIONS
;===============================================================================
;; IncAsm "VICII.asm"				      ; VICII register includes
;; IncAsm "macros.asm"				     ; macro includes
 .include "macros.asm"
 .include "ANTIC.asm"
 .include "GTIA.asm"
 .include "POKEY.asm"
 .include "PIA.asm"
 .include "OS.asm"

;===============================================================================
;===============================================================================
;																     CONSTANTS
;===============================================================================
; Defining things as constants, as above, makes things both easier to read
; and also makes things easier to change.
;--------------------------------------------------------------------------------
;; #region "Constants"

SCREEN_MEM = $4000				   ; Bank 1 - Screen 0
COLOR_MEM  = $D800				   ; Color mem never changes
CHAR_MEM   = $4800				   ; Base of character set memory
SPRITE_MEM = $5000				   ; Base of sprite memory

COLOR_DIFF = COLOR_MEM-SCREEN_MEM  ; difference between color and screen ram
								     ; a workaround for CBM PRG STUDIOs poor
								     ; expression handling

SPRITE_POINTER_BASE = SCREEN_MEM+$3f8 ; last 8 bytes of screen mem

SPRITE_BASE = 64						; the pointer to the first image

;; Atari Note.   On any assignment to these locations
;; an image should be copied to P/M memory.
SPRITE_0_PTR = SPRITE_POINTER_BASE + 0  ; Sprite pointers
SPRITE_1_PTR = SPRITE_POINTER_BASE + 1
SPRITE_2_PTR = SPRITE_POINTER_BASE + 2
SPRITE_3_PTR = SPRITE_POINTER_BASE + 3
SPRITE_4_PTR = SPRITE_POINTER_BASE + 4
SPRITE_5_PTR = SPRITE_POINTER_BASE + 5
SPRITE_6_PTR = SPRITE_POINTER_BASE + 6
SPRITE_7_PTR = SPRITE_POINTER_BASE + 7

;;SPRITE_DELTA_OFFSET_X = 8		       ; Offset from SPRITE coords to Delta Char coords
SPRITE_DELTA_OFFSET_X = 3 ;; Atari -- I think this is how it  is used... it works out to 3.

;;SPRITE_DELTA_OFFSET_Y = 11		      ; approx the center of the sprite
SPRITE_DELTA_OFFSET_Y = 10 ;; Atari -- not sure yet if that should mean delta to 
		;; character center or just the Nth line of data for sprite.

NUMBER_OF_SPRITES_DIV_4 = 3		   ; This is for my personal version, which
								      ; loads sprites and characters under IO ROM

;; #endregion

;===============================================================================
;														    ZERO PAGE VARIABLES
;===============================================================================
;; #region "ZeroPage"
;; PARAM1 = $03				 ; These will be used to pass parameters to routines
;; PARAM2 = $04				 ; when you can't use registers or other reasons
;; PARAM3 = $05						    
;; PARAM4 = $06				 ; essentially, think of these as extra data registers
;; PARAM5 = $07

;; ZEROPAGE_POINTER_1 = $17     ; Similar only for pointers that hold a word long address
;; ZEROPAGE_POINTER_2 = $19
;; ZEROPAGE_POINTER_3 = $21
;; ZEROPAGE_POINTER_4 = $23

;; The Atari OS has defined purpose for most of these Page Zero 
;; locations shown above.
;; Since no Floating Point will be used here we'll borrow the FP 
;; registers in Page Zero.

PARAM1 =   $D6     ; FR0 $D6
PARAM2 =   $D7     ; FR0 $D7
PARAM3 =   $D8     ; FR0 $D8
PARAM4 =   $D9     ; FR0 $D9
PARAM5 =   $DA     ; FRE $DA
PARAM6 =   $DB     ; FRE $DB
PARAM6 =   $DC     ; FRE $DC
PARAM7 =   $DD     ; FRE $DD

ZEROPAGE_POINTER_1 =   $DE     ; FRE $DE/DF
ZEROPAGE_POINTER_2 =   $E0     ; FR1 $E0/$E1
ZEROPAGE_POINTER_3 =   $E2     ; FR1 $E2/$E3
ZEROPAGE_POINTER_4 =   $E4     ; FR1 $E4/$E5 
ZEROPAGE_POINTER_5 =   $E6     ; FR2 $E6/$E7 
ZEROPAGE_POINTER_6 =   $E8     ; FR2 $E8/$E9  Added for Atari PM address math
ZEROPAGE_POINTER_7 =   $EA     ; FR2 $EA/$EB  Added for Atari PM image redraw

;; #endregion

;===============================================================================
;														   BASIC KICKSTART
;===============================================================================
KICKSTART
; Sys call to start the program - 10 SYS (2064)

;; Atari uses a structured executable file format 
;; that loads data to specific memory and provides
;; a run address.  No need to interact with BASIC.

;;*=$0801

;;		BYTE $0E,$08,$0A,$00,$9E,$20,$28,$32,$30,$36,$34,$29,$00,$00,$00


;==============================================================================
;														      PROGRAM START
;==============================================================================
;; *=$0810
;;		*=$2000 	; After Atari DOS
;; PRG_START

;;		lda #0						  ; Turn off sprites 
;;		sta VIC_SPRITE_ENABLE

;;		lda VIC_SCREEN_CONTROL		  ; turn screen off with bit 4
;;		and #%11101111				  ; mask out bit 4 - Screen on/off
;;		sta VIC_SCREEN_CONTROL		  ; save back - setting bit 4 to off

;; Make sure decimal mode is not set
	cld
	
;; Stop all screen activity.
;; Stop DLI activity.
;; Kill Sprites (Player/Missile graphics)
	lda #0
	sta SDMCTL ; ANTIC stop DMA for display list, screen, and player/missiles
;; Note that SDMCTL is copied to DMACTL during the Vertical Blank Interrupt, so 
;; this won't take effect until the start of the next frame.  
;; Remember to make sure the end of frame is reached before resetting 
;; the display list address, the display list interrupt vector, and turning
;; on the display DMA.  
	sta GRACTL ; GTIA -- stop accepting DMA data for Player/Missiles

	lda #NMI_VBI ; set Non-Maskable Interrupts without NMI_DLI for display list interrupts
	sta NMIEN

;; Excessive cleanliness.  Make sure all players/missiles are off screen
	jsr MovePMOffScreen

		;-----------------------------------------------------------------------
		;												       VIC BANK SETUP
		;-----------------------------------------------------------------------
;; #region "VIC Setup"
		; To set the VIC bank we have to change the first 2 bits in the
		; CIA 2 register. So we want to be careful and only change the
		; bits we need to.

;;		lda VIC_BANK		    ; Fetch the status of CIA 2 ($DD00)
;;		and #%11111100		  ; mask for bits 2-8
;;		ora #%00000010		  ; the first 2 bits are your desired VIC bank value
								; In this case bank 1 ($4000 - $7FFF)
								  ;       %00 - Bank #3 - $C000 - $FFFF
								  ;       %01 - Bank #2 - $8000 - $BFFF
								  ;       %10 - Bank #1 - $4000 - $7FFF
								  ;       %11 - Bank #0 - $0000 - $3FFF
;;		sta VIC_BANK

;; So, for reference, base memory for screen things is $4000

		;-----------------------------------------------------------------------
		;										  CHARACTER SET AND SCREEN MEM
		;-----------------------------------------------------------------------
		; Within the VIC Bank we can set where we want our screen and character
		; set memory to be using the VIC_MEMORY_CONTROL at $D018
		; It is important to note that the values given are RELATIVE to the start
		; address of the VIC bank you are using.
       
;;		lda #%00000010   ; bits 1-3 (001) = character memory 2 : $0800 - $0FFF
						   ; bits 4-7 (000) = screen memory 0 : $0000 - $03FF
						   ; this leaves screen 1 intact at $0400 - $07ff

;;		sta VIC_MEMORY_CONTROL

		; Because these are RELATIVE to the VIC banks base address (Bank 1 = $4000)
		; this gives us a base screen memory address of $4000 and a base
		; character set memory of $4800
		; 
		; Sprite pointers are the last 8 bytes of screen memory (25 * 40 = 1000 and
		; yet each screen reserves 1024 bytes). So Sprite pointers start at
		; $4000 + $3f8.

		; Sprite data starts at $5000 - giving the initial image a pointer value of 64
		; (The sprite data starts at Bank Address + $1000.  $1000 / 64 = 64)
;; #endregion		
		;-----------------------------------------------------------------------
		;												       SYSTEM SETUP
		;-----------------------------------------------------------------------
;; #region "System Setup"
System_Setup

		; Here is where I copy my charset and sprite data if using Bank 3 to under
		; the IO ROM. I'll leave this as a stub in case it comes up later.
 
;;		sei		   

		; Here you would load and store the Processor Port ($0001), then use 
		; it to turn off LORAM (BASIC), HIRAM (KERNAL), CHAREN (CHARACTER ROM)
		; then use a routine to copy your sprite and character mem under there
		; before restoring the original value of $0001 and turning interrupts
		; back on.

;;		cli
;; #endregion
		;-----------------------------------------------------------------------
		;												       SCREEN SETUP
		;------------------------------------------------------------------------
;; #region "Screen Setup"
Screen_Setup
		lda #COLOR_BLACK
;;		sta VIC_BORDER_COLOR		    ; Set border and background to black
;;		sta VIC_BACKGROUND_COLOR		
		sta COLOR4 ;; shadow for hardware register COLBK

;;		lda #$40						; use character #$40 as fill character (bricks)

;; using Multicolor character set on Atari:
;; $20, $40, $60 are  bricks in different colors. 
;; also can use $60+high bit ($E0) for fourth color.
		lda #$60
		
;;		ldy #COLOR_BLUE				 ; use blue as fill color 
;; color cell not used on Atari
		jsr ClearScreen				 ; clear screen

										; Display a little message to test our 
										; custom character set and text display routines

										; Setup for the DisplayText routine
      ;  lda #<VERSION_TEXT		      ; Loading a pointer to TEST_TEXT - load the low byte 
      ;  sta ZEROPAGE_POINTER_1		  ; or the address into the pointer variable
      ;  lda #>VERSION_TEXT		      ; Then the high byte to complete the one word address
       ; sta ZEROPAGE_POINTER_1 + 1      ; (just in case someone didn't know what that was)
       
										 ; loadPointer Macro - you need never type all that out
										 ; again

		loadPointer ZEROPAGE_POINTER_1, VERSION_TEXT

		lda #0						 
		sta PARAM1				      ; PARAM1 and PARAM2 hold X and Y screen character coords
		lda #1
		sta PARAM2				      ; To write the text at
;;		lda #COLOR_WHITE				; PARAM3 hold the color 
;;		sta PARAM3

		jsr DisplayText
		;--------------------------------------------------------- DEBUG TEXT CONSOLE
										; Display the little debug panel showing
										; sprite pos and extended X bit status

										; ZEROPAGE_POINTER_1 contains the address to the text

		;lda #<CONSOLE_TEXT		      ; Load the pointer to the text low byte
		;sta ZEROPAGE_POINTER_1
		;lda #>CONSOLE_TEXT		      ; Load the pointer to the text high byte
		;sta ZEROPAGE_POINTER_1 + 1

		loadpointer ZEROPAGE_POINTER_1, CONSOLE_TEXT

		lda #0						  ; PARAM1 contains X screen coord (column)
		sta PARAM1
		lda #20						 ; PARAM2 contains Y screen coord (row)
		sta PARAM2
;;		lda #COLOR_WHITE				; PARAM3 contains the color to use
;;		sta PARAM3
		jsr DisplayText				 ; Then we display the text

		;------------------------------------------------------------ WALLS
		; Draw walls on left and right of the screen
								
		lda #0				  ; X character coord
		sta PARAM1
		lda #3				  ; Y character coord
		sta PARAM2
		lda #15				;  end Y character coord
		sta PARAM3
		
;;		lda #$c0				; character to draw
		lda #$E0 ;; Atari -- Moved brick to $20/$40,$60,$E0
		
		sta PARAM4
;;		lda #COLOR_YELLOW       ; color to use
;;		sta PARAM5
		jsr DrawVLine
								; Routine doesn't trash PARAM variables so with care
								; you can shorten your workload
		lda #39				 ; change X to 39 - other side of the screen
		sta PARAM1
		jsr DrawVLine		   ; draw the same line over there
		
								; setup for horizontal lines
		lda #1				  ; Top Wall
		sta PARAM1		      ; starting at X 1
		lda #3				 
		sta PARAM2		      ; starting at Y 3
		lda #39
		sta PARAM3		      ; ending at X 39
		jsr DrawHLine

								; Bottom Wall (Floor)
		lda #0
		sta PARAM1
		lda #18				 
		sta PARAM2		      ; starting at Y 18
		lda #40
		sta PARAM3
		jsr DrawHLine

		lda #25
		sta PARAM1
		lda #11
		sta PARAM2
		lda #30
		sta PARAM3
		jsr DrawHLine

;;
;; Draw some maze-y-ness to test collision detection.
;; Note Atari Player has a minimum coverage of 2 chars x 3 chars.
;; C64 covers 3 chars x 3 chars.
;; So, a maze drawn for Atari with vertical halls
;; only 2 chars wide won't allow a C64 sprite.
;; Remember to use 3.
;;
		lda #4				  ; X character coord
		sta PARAM1
		lda #7				  ; Y character coord
		sta PARAM2
		lda #12			      ;  end Y character coord
		sta PARAM3
		jsr DrawVLine

		lda #4				  
		sta PARAM1		      ; starting at X 
		lda #7				 
		sta PARAM2		      ; starting at Y 
		lda #8
		sta PARAM3		      ; ending at X 
		jsr DrawHLine

		lda #11				  ; X character coord
		sta PARAM1
		lda #3				  ; Y character coord
		sta PARAM2
		lda #12			      ;  end Y character coord
		sta PARAM3
		jsr DrawVLine

		lda #4			  ; Top Wall
		sta PARAM1		      ; starting at X 
		lda #11				 
		sta PARAM2		      ; starting at Y 
		lda #11
		sta PARAM3		      ; ending at X 
		jsr DrawHLine
				

;; 
;; #endregion
		;------------------------------------------------------------------------
		;												       SPRITE SETUP
		;------------------------------------------------------------------------
;; #region "Sprite Setup"
		;-------------------------------------------- SETUP AND DISPLAY TEST SPRITE 0
;		lda #0
;		sta VIC_SPRITE_MULTICOLOR       ; set all sprites to single color for now

;;		lda #%00000011				  ; make SPRITE 0 - 1 (KillBot) multicolor
;;		sta VIC_SPRITE_MULTICOLOR 

;;		lda #COLOR_LTRED				  ; set shared sprite multicolor 1
;;		sta VIC_SPRITE_MULTICOLOR_1
;;		lda #COLOR_YELLOW
;;		sta VIC_SPRITE_MULTICOLOR_2     ; set shared sprite multicolor 2

;;		lda #COLOR_WHITE
;;		sta VIC_SPRITE_COLOR		    ; set sprite 0 color to White

		;------------------------------------------------ SETUP SPRITE 0 START POSITION
;;		lda #0
;;		sta VIC_SPRITE_X_EXTEND		 ; clear extended X bits

;		no more setting sprites up like this
;
;		lda #100
;		sta VIC_SPRITE_X_POS		    ; display at 100,100 sprite coords for now
;		sta VIC_SPRITE_Y_POS
;		sta SPRITE_POS_X
;		sta SPRITE_POS_Y
;
		; We are now using a system that tracks the sprites position in character coords
		; on the screen. To avoid many costly calculations every frame, we set the sprite 
		; to initally be on a character border, and increase/decrease it's delta values
		; and character coords as it moves. This way we need only do these calculations
		; once.
		;
		; To initially place a sprite we use 'SpriteToCharPos'

;; Sprite 0
;;		lda #COLOR_WHITE				 ; Set sprite 0 to white
;;		sta VIC_SPRITE_COLOR

		lda #COLOR_GREY+$0C
		sta PCOLOR0

		lda #SPRITE_BASE				; Take our first sprite image (Kilbot)
		sta SPRITE_0_PTR				; store it in the pointer for sprite 0

		lda #0 ;; not really necessary, but animation base frame should be set
		sta ANIM_FRAME

		lda #19
		sta PARAM1		      ; Character column 19 (X coord)

		lda #10
		sta PARAM2		      ; Character row 10 (Y coord)

		LDX #0	 ; Sprite # in X (0)
		jsr CopySpriteToPM  ;; Atari -- any vertical movement or animation needs a redraw.
		jsr SpriteToCharPos 

;; Atari -- may need to fix this trim idea
		lda #3
		sta SPRITE_DELTA_TRIM_X		 ; Trim delta for better collisions

		;-----------------------------------------------------------------------

;;       lda #100						; Store X/Y coords of Sprite 1 at 100,200
;;;;		sta VIC_SPRITE_X_POS + 2		; Add 2 to arrive at $D002 - Sprite 1 X
;;		  sta SPRITE_POS_X + 1		    ; Store in our X pos variable

;;		lda #COLOR_CYAN				 ; Set sprite 1 to cyan
;;		sta VIC_SPRITE_COLOR + 1		; Sprite color registers run concurrently 0-8

		lda #COLOR_AQUA+$0A
		sta PCOLOR1
	
		ldx #$01 ;; Sprite # in X (1)

		lda #SPRITE_BASE+24		  ; Take sprite image 24 (Running guy)
		sta SPRITE_0_PTR,x
		lda #1 
		sta SPRITE_DIRECTION,x       ; start running dude moving right
		lda #24 
		sta ANIM_FRAME,x		     ; starting sprite image for runner 

		lda #5
		sta PARAM1 ; Character column 5 (X coord)
		lda #16
		sta PARAM2 ; Character row 16 (Y coord)

		jsr CopySpriteToPM ;; Atari -- any vertical movement or animation needs a redraw.
		jsr SpriteToCharPos
		
;;		lda #%00000011				  ; Turn on sprites 0 and 1
;;		sta VIC_SPRITE_ENABLE 

		jsr DisplayInfoNow		      ; a lable to update the joystick test info
;; #endregion		

		;------------------------------------------------------------------------
		;												       RASTER SETUP
;; make sure we do hit end of frame to insure screen is off and it is safe to update 
;; the DLI vectors.
		jsr WaitFrame
;; Start DLI.
		jsr InitRasterIRQ
      
;;		lda VIC_SCREEN_CONTROL
;;		and #%11101111				  ; mask for bit 4 - Screen on/off
;;		ora #%00010000				  ; or in bit 4 - turn screen on
;;		sta VIC_SCREEN_CONTROL

;; Start Player/Missiles and the screen.
;; P/M Horizontal positions were moved off screen earlier, so there 
;; should be no glitches during startup.

	;; Tell ANTIC where to find the custom character set.
	lda #>CUSTOM_CSET 
	sta CHBAS

	;;  tell ANTIC where to find the new display list.
	lda #<DISPLAY_LIST 
	sta SDLSTL
	lda #>DISPLAY_LIST ;;
	sta SDLSTH 

	;; Tell ANTIC where P/M memory occurs for DMA to GTIA
	lda #>PLAYER_MISSILE_BASE	
	sta PMBASE

	;; Enable GTIA to accept DMA to the GRAFxx registers.
	lda #ENABLE_PLAYERS | ENABLE_MISSILES 
	sta GRACTL

	;; Start screen and P/M graphics
	;; The OS copies SDMCTL to DMACTL during the Vertical Blank Interrupt, 
	;; so we are guaranteed that this cleanly restarts the display 
	;; during the next VBI.
	lda #ENABLE_DL_DMA | PM_1LINE_RESOLUTION | ENABLE_PM_DMA | PLAYFIELD_WIDTH_NORMAL
	sta SDMCTL
	
		;=======================================================================
		;														   MAIN LOOP
		;=======================================================================
		; The main loop of the program - timed to the vertical blanking period
		;-----------------------------------------------------------------------
MainLoop
		jsr WaitFrame				   ; wait for the vertical blank period

;;		lda #COLOR_YELLOW		       ; Raster time indicator - turn the border yellow
		lda #COLOR_YELLOW_GREEN+$0C		    
;;		sta VIC_BORDER_COLOR		    ; before the main loop starts
		sta COLBK
;   These are now under raster interrupt
;		jsr UpdateTimers				; update the basic timers
;		jsr ReadJoystick				; read the joystick
;		jsr JoyButton				   ; read the joystick button

		jsr UpdateSprites		       ; update the sprites

		jsr DisplayInfo				 ; Display simple debug info
		
		lda #COLOR_BLACK				; Restore the border to black - this gives a visual
;;		sta VIC_BORDER_COLOR		    ; on how much 'raster time' you have to work with
		sta COLBK

;; Atari -- Turn off the color cycling "attract" mode 
;; that acts as anti-burn-in on CRTs.
		lda #$00
		sta ATRACT
				
		jmp MainLoop

		;=======================================================================
		;=======================================================================
		;														     ROUTINES
		;=======================================================================
;;		incAsm "raster.asm"						 ; raster interrupts
;;		incAsm "core_routines.asm"				  ; core framework routines
;;		incAsm "sprite_routines.asm"				; sprite handling
;;		incAsm "collision_routines.asm"		     ; sprite collision routines
;;		incAsm "screen_routines.asm"				; screen drawing and handling

;;  atasm...
		.INCLUDE "raster.asm"				;; raster interrupts
		.INCLUDE "core_routines.asm"		;; core framework routines
		.INCLUDE "sprite_routines.asm"		;; sprite handling
		.INCLUDE "collision_routines.asm"	;; sprite collision routines
		.INCLUDE "screen_routines.asm"		;; screen drawing and handling

		;-----------------------------------------------------------------------
		;														 UPDATE PLAYER
		;-----------------------------------------------------------------------
		; Update the Player Sprite using a joystick read and some simple sprite
		; anim tests.
		;------------------------------------------------------------------------
;; #region "UpdateSprites"

UpdateSprites
		;------------------------------------------------------------------------
		;				       SPRITE 0 DEMO - JOYSTICK AND 2 FRAME FLIP ANIM
; 0  to 3  == Standing
; 4  to 7  == Up
; 8  to 11 == Down
; 12 to 15 == Right
; 16 to 19 == Left

		ldx #$00						; Sprite 0 in X		

		lda JOY_X				       ; Fetch Joystick X and move horizontally

		sta SPRITE_DIRECTION,x		  ; store this in SPRITE_DIRECTION for sprite 0
						       
										; now we test this data from the joystick. it can only
										; be -1 o or 1 for left - still or right

;;		cmp #0						  ; 0 = no input in X axis
;;  fetching value above set the Z flag, so cmp not necessary.

		beq @testUpDown				 ; so we can go on to test the Y axis

		bmi @moveLeft				   ; Our joystick reader treats this as a signed bytes
										; so we use BMI (BRanch Minus) rather than BCC or BCS
		jsr CanMoveRight
		bne @testUpDown

		ldx #0
		lda #12				
		sta ANIM_FRAME,x       ;; display the Right frames.

		jsr MoveSpriteRight		     ; Joystick X positive - move right
		jmp @testUpDown

@moveLeft
		ldx #0
		jsr CanMoveLeft				 ; check to see if we can move left
		bne @testUpDown				 ; if blocked - no can move that way

		ldx #0
		lda #16		       
		sta ANIM_FRAME,x       ;; display the Left frames.

		jsr MoveSpriteLeft		      ; Joystick X negative - move left

@testUpDown
										; Now that we're using a delta system, I can't do a simple
										; update by adding the Joystick Y axis to the VIC_SPRITE_Y
										; we MUST go through the SpriteMove routines.

		lda JOY_Y				       ; Fetch the Joystick Y axis value (-1 0 or 1)
 ;;       cmp #$00						; if 0 then it's not moved - so we're done
 		bne doUpAndDown

		ldx #0
		lda SPRITE_DIRECTION,x ;; But if there is currently horizontal ...
		bne @done		      ;; motion then we can't display the idle frames.
		lda #0				 ;; No horizontal motion means ...
		sta ANIM_FRAME,x       ;; display the down frames.
		beq @done    ; and move on to the animation

doUpAndDown
		bmi @moveUp				     ; if Joystick is negative, then we move up

		ldx #0
		jsr CanMoveDown		;; Check if we can move down
		bne @done  
		
		ldx #0				 ;; yes, moving down.
		lda SPRITE_DIRECTION,x ;; But if there is currently horizontal ...
		bne ?noFrameDown       ;; motion then we can't disply the down frames.
		lda #8				 ;; No horizontal motion means ...
		sta ANIM_FRAME,x       ;; display the down frames.

?noFrameDown
		jsr MoveSpriteDown		      ; if it's positive, we move it down
		jmp @done				       ; and move on to the animation

@moveUp
		ldx #0
		jsr CanMoveUp ;; Check if we can move up
		bne @done
		
		ldx #0				 ;; yes, moving up.
		lda SPRITE_DIRECTION,x ;; But if there is currently horizontal ...
		bne ?noFrameUp		 ;; motion then we can't disply the up frames.
		lda #4				 ;; No horizontal motion means ...
		sta ANIM_FRAME,x       ;; display the up frames.

?noFrameUp		
		jsr MoveSpriteUp		      

@done 
		ldx #0

		jsr AnimTest2    ; UPDATE SIMPLE ANIMATION

		;------------------------------------------------------------------
		;						       SPRITE 1 DEMO - RUNNING MAN
		;------------------------------------------------------------------
		
		ldx #01						 ; Set the X register to the sprite number [1]
		lda SPRITE_DIRECTION,x		  ; Check direction
		bmi @moveLeft1
										; Moving Right
;;		ldx #$01						; Load the sprite number in x (Hardware Sprite 1)
		jsr MoveSpriteRight		     ; Move it right - this routine leaves X register intact
										
										; RIGHT SCREEN BORDER CHECK
										; Check for edge of screen ($53 with X extend set)
;;       lda BIT_TABLE,x				 ; get the relevent bit for this Sprite (Bit 2)
;;		and SPRITE_POS_X_EXTEND		 ; if I and these together - it will return 1 extend is set
;;		beq @updateAnim				 ; if it returns 0 - there's no need for further checks

;;		clc						     ; clear carry flag
		lda SPRITE_POS_X,x		      ; Get the sprites X position
;;		cmp #$53						; Sprite coords for just off edge of screen
		cmp #[PLAYFIELD_RIGHT_EDGE_NORMAL-5] 
		;; Atari -- ; Sprite coords for just off edge of playfield
		;; adjusted so that 8 color clock player is 
		;; centered on 4 color clock character like this:
		;; 
		;; ..543210....
		;; ..pppppppp..
		;; ccccCCCC....
		;; .......^--playfield right edge/last color clock

	    bcc @updateAnim				 ; if it's less than $53, we're ok, and done evaluating

;;		lda #-1
		lda #$FF ;; atasm warns about use of -1
		sta SPRITE_DIRECTION,x		   ; Set direction to left

;; Sprite values will be updated by AnimTest2 only when the ANIMATE_FLAG
;; strobes, so here force the new base image.

		lda #28 
		sta ANIM_FRAME,x		     ; starting sprite image for runner 

		lda #SPRITE_BASE+28		  ; Take sprite image 28 (Running guy)
		sta SPRITE_0_PTR,x

		jsr CopySpriteToPM  ;; Atari -- any vertical movement or animation needs a redraw.

		jmp @updateAnim

@moveLeft1
		ldx #$01						; Load the sprite number in X
		jsr MoveSpriteLeft		      ; Move sprite one pixel left

										; LEFT SCREEN BORDER CHECK
										; Check for edge of screen ($05 with X extend cleared)
;;		lda BIT_TABLE,x				 ; Get the relevent bit for the sprite 
;;		and SPRITE_POS_X_EXTEND		 ; and it with the extend bit data
;;		bne @updateAnim				 ; if it's set, we're around the right 1/3 of the screen 
     
		clc
		lda SPRITE_POS_X,x		      ; check if sprite pos is less than $05
;;		cmp #$05		
		cmp #PLAYFIELD_LEFT_EDGE_NORMAL-2
		bcs @updateAnim				 ; if it's greater than, we're done
		
		lda #1
		sta SPRITE_DIRECTION,x		  ; set Direction to Right

;; Sprite values will be updated by AnimTest2 only when the ANIMATE_FLAG
;; strobes, so here force the new base image.

		lda #24 
		sta ANIM_FRAME,x		     ; starting sprite image for runner 

		lda #SPRITE_BASE+24		  ; Take sprite image 28 (Running guy)
		sta SPRITE_0_PTR,x

		jsr CopySpriteToPM  ;; Atari -- any vertical movement or animation needs a redraw.

@updateAnim
		jsr AnimTest2

		rts
;; #endregion

		;-----------------------------------------------------------------------
		;														 DISPLAY INFO
		;-----------------------------------------------------------------------
		; Updates the info in our Debug 'console'
		;-----------------------------------------------------------------------
;; #region "DisplayInfo"
DisplayInfo
		lda JOY_X				       ; only display if changed position		       
		ora JOY_Y
		bne DisplayInfoNow
		rts

		;----------------------------------- DEBUGGING INFO - Screen pos and extended bit
DisplayInfoNow
;@displayPos								    ; Display the debug data
		lda SPRITE_POS_X						; Byte to be displayed
		ldx #20								 ; Y position to display at (row)								 
		ldy #5								  ; X position to display at (column)
		jsr DisplayByte						 ; Display the byte

		lda SPRITE_POS_Y
		ldx #21
		ldy #5
		jsr DisplayByte
												; check the extended x bit
;;		lda SPRITE_POS_X_EXTEND
;;		and #$01								; mask bit one
;;		bne @extend						     ; if it's set, display an *

;;		lda #' '								; if not, display a space
;;		lda #$00 ;; Atari "blank" space internal code
;;		sta SCREEN_MEM + #810
;;		sta SCREEN_MEM + 810 ;; atasm objects to # embedded in formula
;;		lda #COLOR_WHITE
;;		sta COLOR_MEM + #810
 
 ;;       jmp @displayCharCoords				  ; display the next bunch of info
		
;; @extend

;;		lda #'*'
;;		lda #$0A ;; atasm.  Atari internal code for '*.   But that may need to be mapped elsewhere.
;; ;;		sta SCREEN_MEM + #810
;;		sta SCREEN_MEM + 810 ;; atasm objects to # embedded in formula
;;		lda #COLOR_WHITE
;;		sta COLOR_MEM + #810

		;------------------------------------------ DISPLAY CHAR X and Y POS AND DELTA
@displayCharCoords
		lda SPRITE_CHAR_POS_X		 ; Address of data to display
		ldx #20						 ; Y position
		ldy #13						 ; X position
		jsr DisplayByte				 ; Call the display routine

		lda SPRITE_CHAR_POS_Y		; Address of data to display
		ldx #21				        ; Y position
		ldy #13				        ; X position
		jsr DisplayByte				; Call the display routine

		lda SPRITE_POS_X_DELTA		; Address of data to display
		ldx #20				        ; Y position
		ldy #21						; X position
		jsr DisplayByte				; Call the display routine

		lda SPRITE_POS_Y_DELTA		; Address of data to display
		ldx #21						; Y position
		ldy #21						; X position
		jsr DisplayByte				; Call the display routine

		rts

;; #endregion

;delta_debug
;		;------------ DEBUG MY DELTA and CHAR POS - remove later
;		; change color of character one row down from sprite
;		
;		ldx SPRITE_CHAR_POS_Y				    ; sprite 0's char pos Y
;		inx								      ; inc by 1 (character UNDER)

;		lda SCREEN_LINE_OFFSET_TABLE_LO,x       ; fetch the Y pos line address
;		sta ZEROPAGE_POINTER_1
;		lda SCREEN_LINE_OFFSET_TABLE_HI,x
;		sta ZEROPAGE_POINTER_1 + 1

;		clc
;		adc #>COLOR_DIFF						; add color diff to get color ram
;		sta ZEROPAGE_POINTER_1 + 1
;		
;		ldy SPRITE_CHAR_POS_X				   ; put the sprite character X in Y
;		lda #COLOR_LTRED				
;		sta (ZEROPAGE_POINTER_1),y		      ; use that offset to change the character to red
;		rts
;		;--------------------------------------------------------------------


;; FYI -- AnimTest below is never called in the code.  so commenting out....
		;-----------------------------------------------------------------------
		;												       ANIM TEST
		;-----------------------------------------------------------------------
		; A basic test - flip the sprite back and forth between images 0 and 1
		; this is hardcoded to sprite 0 atm.
		;-----------------------------------------------------------------------
;;.LOCAL
;;AnimTest
;;   using the SaveRegs...
;;	saveRegs ;; macro

;;		lda SLOW_TIMER				  ; Take the value of slow timer
;;		and #$01						; check the value of the first bit
;;		beq ?frame1				     ; if it's 0, use the first frame
;;		lda #SPRITE_BASE + 2				; Take our first sprite image

;;		sta SPRITE_0_PTR				; store it in the pointer for sprite 0

;;		ldx #00
;;		jsr CopySpriteToPM ;; Atari -- any vertical movement or animation needs a redraw.

;;	safeRTS ;; macro
		
;;?frame1								 ; if it's 1, use the second frame
;;		lda #SPRITE_BASE + 4		     ; Take our second sprite image
;;		sta SPRITE_0_PTR				; store it in the pointer for sprite 0
;;		ldx #00
;;		jsr CopySpriteToPM ;; Atari -- any vertical movement or animation needs a redraw.

;;	safeRTS ;; macro

;--------------------------------------------------------------------------------
;																    ANIM TEST 2
;--------------------------------------------------------------------------------
; Slightly more complex animation flipping between 4 images with both left and
; right animations for a running character.
;
; X contains the sprite number you want to animate.
;
; NOTE this is hardcoded to sprite images 0 to 20 - which contain 'killbot'
; 0  to 3  == Standing
; 4  to 7  == Up
; 8  to 11 == Down
; 12 to 15 == Right
; 16 to 19 == Left
;;
;; Running guy - SPRITES 24 -31
;;	24 - 27 Running Right
;;  28 - 31 Running left
;--------------------------------------------------------------------------------
AnimTest2
;; I've decided this is confused.  It refers to fixed frame numbers, but in 
;; different parts uses the frame numbers from different sprite animations
;; (killbot vs running man).  
;; In order to make this sane it needs separate sections for X=0
;; animating killbot and X=1 animating the running man.
;;
;; Ummmm.  Sprite direction appears to be left and right.
;; Q: So, where is the sprite direction indicating up and down?
;; A: Up/Down is simply superceeded by left/right.

;;								   ; Use TIMER to update the animation.
;;		lda TIMER				  ; Every frame is too fast - and slow timer won't
;;								   ; generate a 'pulse' (it stays on then off) - so we check
;;								   ; BOTH  bits 1 and 2 (3) for a quick regular pulse every
;;								   ; couple of frames
;;		;and #$03
;;		and #$07				   ; slow down the animation a bit
;;		beq ?updateAnimation
;;		rts

;; Moved the animation pulse/flag into the timer update routine.  
;; (after all, it is another timer-based whatzit.)
;; So, now just evaluate the animation flag...
		lda ANIMATE_FLAG
		bne ?updateAnimation
		
		rts

?updateAnimation

		cpx #0 ;; Doing killbot? ---------------------------------------------------
		beq ?doKillbotAnim
	
;; Because the animation frames are managed by the TIMER routine automatically, 
;; literally none of the range checking and frame resetting is needed.  

		jmp ?updateAnim
	
;; ;; This is for animating Running Man... ----------------------------------------
;;    lda SPRITE_DIRECTION,x   ;;  Should be either Right +1, or Left -1		
;;	  bmi ?runnerMoveLeft  ;; if direction is -1 we are moving left

;; ;; This is running man moving right
;;	  lda ANIM_FRAME,x
;;	  cmp #28
;;	  bne ?updateAnim
;; ;; Reset running man moving right	
;;	lda #24
;;	sta ANIM_FRAME,x
;;	bne ?updateAnim ;; anim frame was nonzero, so this branches always

;; ?runnerMoveLeft
;; ;; This is running man moving left
;;	lda ANIM_FRAME,x
;;	cmp #32
;;	bne ?updateAnim
;; ;; Reset running man moving left	
;;	lda #28
;;	sta ANIM_FRAME,x
;;	bne ?updateAnim ;; anim frame was nonzero, so this branches always


;; I think we have a problem here. When setting Direction the animation must change
;; but this logic falls through and can get confused incrementing/decrementing frames
;; from whatever the previous pattern could be.
;; Therefore, any attempt to change sprite direction must also reset the anim frame to 
;; the first frame that corresponds to the direction/state.
;; This realization now makes me wonder why ANIM_FRAME counts sprite images...  
;; There should be two items here -- a base frame number that corresponds to the direction
;; state  (up, down, left, right) and then a separate frame counter from 0 to 3 to 
;; cycle the animation relative to the base state.
;; So, that is what I did.
;; Much of this logic for frame determination is sidestepped.

?doKillbotAnim  ;; -------------------------------------------------------------------
		lda SPRITE_DIRECTION,x		; see if we're standing still - equal would be 0
		beq ?updateAnim
;;		
;;		bne ?left_right		       ; if we're moving - test for left/right direction

 ;;       clc
 ;;       lda ANIM_FRAME,x		      ; Standing still - we use frames 0 to 3
 ;;       cmp #4						; if we hit 4 we need to reset to start
 ;;       bne ?updateAnim ;; was bcc
 ;;       lda #0						; reset to start (frame 0)
 ;;       sta ANIM_FRAME,x		      ; store if in proper place for this sprite
;;		jmp ?updateAnim

		
;; ?left_right						   ; if we go from standing to moving, the frame will be
								      ; very low and will just increment until it hits a max frame
								      ; for the other cases - which would be very ugly
;;		clc
;;		lda ANIM_FRAME,x		      ; if the animframe is 12 or more, we were probably already
;;		cmp #11				       ; moving - so we can just continue with our direction checks


;;		bcs ?left_check
;;		bne ?left_check
;;		lda #20				       ; if not we set it to a value that both cases will correct
;;		lda #24
;; not sure what's supposed to happen here.  neither 20, nor 24 is valid for Killbot.
;;		sta ANIM_FRAME,x		      ; automatically - setting it to the correct start frame

?left_check
;;		lda SPRITE_DIRECTION,x		; if direction is -1 we are moving left
		bmi ?movingLeft
		
;;       clc						 ; Sprite moving right - use frames 3-7 ??? (12 to 15)
;;       lda ANIM_FRAME,x
;;		cmp #16						 
;;		bcc ?updateAnim
       lda #12				      ; reset back to start frame
       sta ANIM_FRAME,x
;;		jmp ?updateAnim
		bne ?updateAnim
				
?movingLeft						 ; Sprite moving left - use frames 9-12  ??? (16 to 19)
;;		lda ANIM_FRAME,x		    
;;		cmp #20				     ; Check to make sure the anim frame isn't = 20
;;		beq ?resetLeft		      ; Reset to the start frame if it's overrun
		lda #16
		
;;		clc						 ; a special case when you go from right to left
;;		cmp #16				     ; the anim frame will be between 12 - 15
;;		bcc ?resetLeft		      ; left alone it will increment up to 16
								    ; which leaves an ugly result
;;		jmp ?updateAnim
				

?resetLeft
;;		lda #16				     ; reset to frame start if it overruns
		sta ANIM_FRAME,x
;;		jmp ?updateAnim
								    ; Update the displayed frame
?updateAnim
		clc
		lda ANIM_FRAME,x			;; make sure we have current sprite's base frame
		adc ANIM_COUNTER			;; 0 to 3 frame offset maintained during TIMER increment
		adc #SPRITE_BASE		   ; pointer = SPRITE_BASE + FRAME #
		sta SPRITE_0_PTR,x		 ; store new image pointer the correct sprite pointer
								   ; (which would be SPRITE_0_PTR + x)
		jsr CopySpriteToPM  ;; Atari -- any vertical movement or animation needs a redraw.
		rts

;===============================================================================
;												       CHARSET AND SPRITE DATA
;===============================================================================
; Charset and Sprite data directly loaded here.

DATA_INCLUDES
; CHARACTER SET SETUP
;--------------------
; Going with the 'Bear Essentials' model would be :
;
; 000 - 063    Normal font (letters / numbers / punctuation, sprite will pass over)
; 064 - 127    Backgrounds (sprite will pass over)
; 128 - 143    Collapsing platforms (deteriorate and eventually disappear when stood on)
; 144 - 153    Conveyors (move the character left or right when stood on)
; 154 - 191    Semi solid platforms (can be stood on, but can jump and walk through)
; 192 - 239    Solid platforms (cannot pass through)
; 240 - 255    Death (spikes etc)
;
	*=$4800
CUSTOM_CSET
;;incbin "Chars.cst",0,255
	.INCBIN "multicoltext.cset"

	*=$5000
PM_KILLBOT
;;	.incbin "killbot.spt",1,20,true		  ; Killbot -     SPRITES 0 - 19
	.incbin "killbot.bin"      ; Killbot -     SPRITES 0 - 19
;; 0  - 3  Standing
;; 4  - 7  Walking up
;; 8  - 11 Walking down
;; 12 - 15 Walking Right
;; 16 - 19 Walking Left

PM_SPRITES
;;incbin "Sprites.spt",1,4,true		   ; Waving guy -  SPRITES 20 - 23
	.incbin "sprites.bin"

PM_RUNNER	
;;incbin "RunningMan.spt",1,4,true		; Running guy - SPRITES 24 -31
	.incbin "runner.bin"
;;	24 - 27 Running Right
;;  28 - 31 Running left
	
;; TEMPORARILY DISABLED
;;	.INCBIN "killbot.spt"
;;	.INCBIN "sprites.spt"
;;	.INCBIN "runningman.spt"	

;-------------------------------------------------------------------------------
;														       PROGRAM DATA
;-------------------------------------------------------------------------------
; All program data and variables fall in after the Sprite data

;; Let's force the rest of this to fall at $8000 
;; after the current VIC bank in use.
	*=$8000
;; Atari uses a display list "program" to specify the graphics screen.
;; Contrary to popular opinion the Atari is not limited to 192 scan lines.
;; The display list below results in the same 200 scan lines of 
;; multi-color character text as the C64/VIC-II. (and it need not stop at 200.)

DISPLAY_LIST
;;  20 blank scan lines for spacing...
;; last blank instruction includes a DLI flag
	.byte DL_BLANK_8,DL_BLANK_8,DL_BLANK_4|DL_DLI
;; 25 lines of multi-color text
;; First line starts the memory scan
	.BYTE DL_TEXT_4|DL_LMS
	.WORD SCREEN_MEM
;; and the remaining 24 lines...
	.BYTE DL_TEXT_4,DL_TEXT_4,DL_TEXT_4,DL_TEXT_4
	.BYTE DL_TEXT_4,DL_TEXT_4,DL_TEXT_4,DL_TEXT_4
	.BYTE DL_TEXT_4,DL_TEXT_4,DL_TEXT_4,DL_TEXT_4
	.BYTE DL_TEXT_4,DL_TEXT_4,DL_TEXT_4,DL_TEXT_4
	.BYTE DL_TEXT_4,DL_TEXT_4|DL_DLI,DL_TEXT_4,DL_TEXT_4
	.BYTE DL_TEXT_4,DL_TEXT_4,DL_TEXT_4,DL_TEXT_4
;; End with the jump to vertical blank
	.BYTE DL_JUMP_VB
	.WORD DISPLAY_LIST

														; Timer Variables
TIMER												   ; Fast timer updates every frame
	.BYTE 0

SLOW_TIMER										      ; Slow timer updates every 16th frame
	.BYTE 0

VERSION_TEXT
;;		byte 'mlp framework v1.3',0
	.SBYTE +$80,"mlp framework v1.3 by peter sig hewett"
	.BYTE $9B
	.SBYTE "ATARI PORT V1.3BETA BY KEN JENNINGS"
	.BYTE $FF
	
CONSOLE_TEXT
;;		byte ' xpos:$     ypos:$    chrx:$   chry:$   / dltx:$     dlty:$				      ',0

;; Atari -- squeezing layout.  maybe I'll add some 
;; diagnostics for the animated runner.  Or maybe
;; add the collision values later.
	.SBYTE +$80,"xpos:   chrx:   dltx:   "
	.BYTE $9B
	.SBYTE +$80,"ypos:   chry:   dlty:   "
	.BYTE $FF

;---------------------------------------------------------------------------------------------------
;																				       JOYSTICK

JOY_X						   ; current positon of Joystick(2)
	.BYTE $00				; -1 0 or +1

JOY_Y
	.BYTE $00				; -1 0 or +1

BUTTON_PRESSED				  ; holds 1 when the button is held down
	.BYTE $00

BUTTON_ACTION				   ; holds 1 when a single press is made (button released)
	.BYTE $00		
;---------------------------------------------------------------------------------------------------
;																				       SPRITES
SPRITE_POS_X										    ; Hardware sprite X position
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_POS_X_DELTA								      ; Delta X positon (0-7) - position within
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00		    ; a character

SPRITE_CHAR_POS_X								       ; Char pos X - sprite position in character
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00			 ; coords (0-40)

SPRITE_DELTA_TRIM_X
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00 		    ; Trim delta for better collisions

SPRITE_POS_X_EXTEND								     ; extended flag for X positon > 255									
	.BYTE $00										; bits 0-7 correspond to sprite numbers

SPRITE_POS_Y										    ; Hardware sprite Y position
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_POS_Y_DELTA
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00

SPRITE_CHAR_POS_Y
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00
												; Some variables for the anim demo - direction the
												; sprite is moving (left or right) and the current frame
SPRITE_DIRECTION
	.BYTE $00,$01,$00,$00,$00,$00,$00,$00  ; Direction of the sprite (-1 0 1)

;;  I think there should be a separate direction managed for X and Y.
SPRITE_DIRECTION_Y
	.BYTE $00,$01,$00,$00,$00,$00,$00,$00		; Direction of the sprite (-1 0 1)

ANIM_FRAME
	.BYTE $00,$00,$00,$00,$00,$00,$00,$00	   ; Current animation base frame  

ANIM_COUNTER
	.BYTE $00				;; animation frame counter -- 0 to 3
	
ANIMATE_FLAG
;;										       ;; Every few frame ticks this toggles 1 to flag 
;;										       ;; the time to update sprite images.
	.BYTE $00

;; Atari -- need a lookup for base address of the player/missiles.
;; since P/M memory is always aligned to a page, the low byte for
;; address is always zero, so only the high byte is needed for the
;; lookup table.
PMADR_BASE
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_PLAYER0]
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_PLAYER1]
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_PLAYER2]
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_PLAYER3]
	
;; For now, describe  players 4-7 as missiles.  
;; Thinking about  page flipping during VBI to provide a 
;; second set of 4 players in alternating frames.	
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_MISSILES]
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_MISSILES]
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_MISSILES]
	.BYTE	>[PLAYER_MISSILE_BASE+PMADR_1LINE_MISSILES]
	
;---------------------------------------------------------------------------------------------------
; Bit Table
; Take a value from 0 to 7 and return it's bit value
BIT_TABLE
;;		byte 1,2,4,8,16,32,64,128
	.BYTE ~00000001
	.BYTE ~00000010
	.BYTE ~00000100
	.BYTE ~00001000
	.BYTE ~00010000
	.BYTE ~00100000
	.BYTE ~01000000
	.BYTE ~10000000

;; In many cases a Mask table is also helpful
MASK_TABLE 
	.BYTE ~11111110
	.BYTE ~11111101
	.BYTE ~11111011
	.BYTE ~11110111
	.BYTE ~11101111
	.BYTE ~11011111
	.BYTE ~10111111
	.BYTE ~01111111

; Bit Table in the reverse order
; Take a value from 0 to 7 and return it's bit value
BIT_TABLE_REV
;;		byte 128,64,32,16,8,4,2,1
	.BYTE ~10000000
	.BYTE ~01000000
	.BYTE ~00100000
	.BYTE ~00010000
	.BYTE ~00001000
	.BYTE ~00000100
	.BYTE ~00000010
	.BYTE ~00000001

;; And a mask table for the same  
MASK_TABLE_REV
	.BYTE ~01111111
	.BYTE ~10111111
	.BYTE ~11011111
	.BYTE ~11101111
	.BYTE ~11110111
	.BYTE ~11111011
	.BYTE ~11111101
	.BYTE ~11111110

;---------------------------------------------------------------------------------------------------
; Screen Line Offset Tables
; Query a line with lda (POINTER TO TABLE),x (where x holds the line number)
; and it will return the screen address for that line

; C64 PRG STUDIO has a lack of expression support that makes creating some tables very problematic
; Be aware that you can only use ONE expression after a defined constant, no braces, and be sure to
; account for order of precedence.

; For these tables you MUST have the Operator Calc directive set at the top of your main file
; or have it checked in options or BAD THINGS WILL HAPPEN!! It basically means that calculations
; will be performed BEFORE giving back the hi/lo byte with '>' rather than the default of
; hi/lo byte THEN the calculation

SCREEN_LINE_OFFSET_TABLE_LO		
;;		  byte <SCREEN_MEM				      
;;		  byte <SCREEN_MEM + 40				 
;;		  byte <SCREEN_MEM + 80
;;		  byte <SCREEN_MEM + 120
;;		  byte <SCREEN_MEM + 160
;;		  byte <SCREEN_MEM + 200
;;		  byte <SCREEN_MEM + 240
;;		  byte <SCREEN_MEM + 280
;;		  byte <SCREEN_MEM + 320
;;		  byte <SCREEN_MEM + 360
;;		  byte <SCREEN_MEM + 400
;;		  byte <SCREEN_MEM + 440
;;		  byte <SCREEN_MEM + 480
;;		  byte <SCREEN_MEM + 520
;;		  byte <SCREEN_MEM + 560
;;		  byte <SCREEN_MEM + 600
;;		  byte <SCREEN_MEM + 640
;;		  byte <SCREEN_MEM + 680
;;		  byte <SCREEN_MEM + 720
;;		  byte <SCREEN_MEM + 760
;;		  byte <SCREEN_MEM + 800
;;		  byte <SCREEN_MEM + 840
;;		  byte <SCREEN_MEM + 880
;;		  byte <SCREEN_MEM + 920
;;		  byte <SCREEN_MEM + 960
;; An atasm gymnastic to build the table at assembly time....
	r .= 0
	.REPT 25
	.BYTE <[SCREEN_MEM+[r*40]]
	r .= r+1
	.ENDR
SCREEN_LINE_OFFSET_TABLE_HI
;;		  byte >SCREEN_MEM
;;		  byte >SCREEN_MEM + 40
;;		  byte >SCREEN_MEM + 80
;;		  byte >SCREEN_MEM + 120
;;		  byte >SCREEN_MEM + 160
;;		  byte >SCREEN_MEM + 200
;;		  byte >SCREEN_MEM + 240
;;		  byte >SCREEN_MEM + 280
;;		  byte >SCREEN_MEM + 320
;;		  byte >SCREEN_MEM + 360
;;		  byte >SCREEN_MEM + 400
;;		  byte >SCREEN_MEM + 440
;;		  byte >SCREEN_MEM + 480
;;		  byte >SCREEN_MEM + 520
;;		  byte >SCREEN_MEM + 560
;;		  byte >SCREEN_MEM + 600
;;		  byte >SCREEN_MEM + 640
;;		  byte >SCREEN_MEM + 680
;;		  byte >SCREEN_MEM + 720
;;		  byte >SCREEN_MEM + 760
;;		  byte >SCREEN_MEM + 800
;;		  byte >SCREEN_MEM + 840
;;		  byte >SCREEN_MEM + 880
;;		  byte >SCREEN_MEM + 920
;;		  byte >SCREEN_MEM + 960
;; An atasm gymnastic to build the table at assembly time....
	r .= 0
	.REPT 25
	.BYTE >[SCREEN_MEM+[r*40]]
	r .= r+1
	.ENDR

;; --------------------------------------------------------------------
;; Align to the next nearest 2K boundary for 
;; single-line resolution Player/Missiles
	*=[*&$F800]+$0800 
PLAYER_MISSILE_BASE  ;; Player/missile memory goes here.

;; --------------------------------------------------------------------

;; Store the program start location in 
;; the Atari DOS RUN Address
	*=DOS_RUN_ADDR
	.word PRG_START

;; --------------------------------------------------------------------

    .END ;; finito
    	
