;===================================================================================================
;																		       RASTER INTERRUPTS
;===================================================================================================
;																		      Peter 'Sig' Hewett
;																						 - 2016
; A chain of raster irq's and routines for installing/removing them
;---------------------------------------------------------------------------------------------------
;; Atari-fied for eclipse/wudsn/atasm by Ken Jennings
;; FYI -- comments with double ;; are Ken's for Atari
;---------------------------------------------------------------------------------------------------
;																		       INSTALL RASTER IRQ
;---------------------------------------------------------------------------------------------------

InitRasterIRQ
;;		sei				     ; stop all interrupts
;;		lda PROC_PORT
		
;;		lda #$7f				; disable cia #1 generating timer irqs
;;		sta INT_CONTROL		 ; which are used by the system to flash cursor, etc.

;;		lda #$01				; tell the VIC we want to generate raster irqs
								; Note - by directly writing #$01 and not setting bits
								; we are also turning off sprite/sprite sprite/background
								; and light pen interrupts.. But those are rather shite anyways
								; and won't be missed

;;		sta VIC_INTERRUPT_CONTROL

;;		lda #$10				; number of the rasterline we want the IRQ to occur at
;;		sta VIC_RASTER_LINE     ; we used this for WaitFrame, remember? Reading gives the current
								; raster line, writing sets the line for a raster interrupt to occur

								; The raster counter goes from 0-312, so we need to set the
								; most significant bit (MSB)

								; The MSB for setting the raster line is bit 7 of $D011 - this
								; is also VIC_SCREEN_CONTROL, that sets the height of the screen,
								; if it's turned on, text or bitmap mode, and other things.
								; so we could easily use this 'short' method
;		lda #$14		       ; screen on and at 25 rows..
;		sta $D011
								; But doing things properly and only setting the bits we want is a
								; good practice to get into.
								; also we now have the option of turning the screen on when we want
								; to - like after everything is set up

;;		lda VIC_SCREEN_CONTROL  ; Fetch the VIC_SCREEN_CONTROL
;;		and #%01111111		  ; mask the surrounding bits
;		ora #%00000000		  ; or in the value we want to set the MSB (Most significant bit)
								; in this case, it's cleared
;;		sta VIC_SCREEN_CONTROL
								; set the irq vector to point to our routine

;; Atari -- Assume this is called when the screen is off, therefore
;; no DLI can trigger while this is running.  But, just in case, turn
;; off the interrupt.

		lda # NMI_VBI ;; enable only VBI, disable DLI.
		sta NMIEN
	
		lda #<IrqTopScreen 
;;     sta $0314
		sta VDSLST  ;; Set DLI routine vector.
	
		lda #>IrqTopScreen
;;      sta $0315
		sta VDSLST+1
								; Acknowlege any pending cia timer interrupts
								; just to be 100% safe
;;		lda $dc0d
;;		lda $dd0d

;;		cli				     ; turn interrupts back on

;; Atari -- Assume this is called when the screen is off, therefore
;; no DLI can trigger while this part is running.

	lda # NMI_DLI | NMI_VBI ;; enable DLI and VBI 
	sta NMIEN

	rts

;---------------------------------------------------------------------------------------------------
;																		      RELEASE RASTER IRQs
;---------------------------------------------------------------------------------------------------
ReleaseRasterIRQ
;;		sei						     ; stop all interrupts
;;
;;		lda #$37						; make sure the IO regs at $dxxx
;;		sta $01						 ; are visible
;;		
;;		lda #$ff						; enable cia #1 generating timing irq's
;;		sta $dc0d
;;
;;		lda #$00						; no more raster IRQ's
;;		sta $d01a
;;
;;		lda #$31
;;		sta $0314
;;		lda #$ea
;;		sta $0315
;;
;;		lda $dc0d				       ; acknowlege any pending cia timer interrupts
;;		lda $dd0d
;;
;;		cli

;; Assume this is called  when the screen is off, so no DLI can be in progress.
 
		lda #NMI_VBI ;; enable only VBI 
		sta NMIEN
	
		rts

;; On the Atari, screen-oriented interrupts are driven from the display list.

;; First interrupt is at scan line 16.  I don't know if that counts the 
;; blank area or only actual text lines.
;; It sets background(?) to blue and does some joystick polling. 
;; Not really sure what effect it has on the screen, because in the video I 
;; couldn't see where anything turns blue at the top of the screen.
;; Maybe it is actually coloring the text on the first line on the screen. (?)
;; Later it returns the color to black .... 
;; just can't see where this happens in the video.
;; For the sake of seeing something happen, I'll assume this starts on the scanline
;; immediately before the first line of text.

;; The second interrupt occurs at scan line $CA/202 --- based on screen capture
;; of the video this seems to be at the end of text line 19 and start of line 20.
;; This changes the background color green.  At the end of the region the color 
;; is somehow changed to black.  On the Atari this occurs naturally during
;; the VBI updating hardware register COLBK from shadow COLOR4.

;===================================================================================================
;																		       IRQ - TOP SCREEN 
;===================================================================================================
; Irq set to the very top of the visible screen (IN BORDER) good for screen setup and timers
;
;---------------------------------------------------------------------------------------------------
IrqTopScreen
								; acknowledge VIC irq
;;		lda $D019
;;		sta $D019

		pha		;; Atari -- Save A register.

								; install scroller irq
;;		lda #<IrqScoreBoard
;;		sta $0314

;;		lda #>IrqScoreBoard
;;		sta $0315
								 ; nr of rasterline we want the NEXT irq to occur at
;;		lda #$CA
;;		sta $D012
		;======================================================================= OUR CODE GOES HERE
		
;       lda #COLOR_GREY3
;       sta VIC_BACKGROUND_COLOR
;;		lda #COLOR_BLUE
;;		sta VIC_BORDER_COLOR

		lda #COLOR_BLUE1+$06 
		sta WSYNC  ;; Make a clean transition.
		sta COLBK ;; Atari background/border

;; Some of these maintenance routines may go away.
;; Atari OS does polling of controllers, and 
;; maintains a jiffy clock.   These routine may 
;; be redundant, but for the time being we're 
;; keeing them so the base code stays mostly 
;; compatible with C64.
		
		jsr UpdateTimers  ; Atari OS has RTCLOK
		jsr ReadJoystick ; Atari OS updates STICKx
		jsr JoyButton ;; Atari OS updates STRIGx
		
		lda #COLOR_BLACK
;;		sta VIC_BORDER_COLOR      
		sta COLBK ;; Atari background/border
		
;;	Atari.  LAST thing to do is chain to next interrupt.

		lda #<IrqScoreBoard
		sta VDSLST ;; Disply list interrupt vector

		lda #>IrqScoreBoard
		sta VDSLST+1		
      
		;-------------------------------------------------------------------------------------------
 ;;       jmp $ea31

		pla ;; Atari -- restore A.  
		rti ;; return to OS.
		
;===================================================================================================
;																 IRQ - BOTTOM SCREEN / SCOREBOARD
;===================================================================================================    
; IRQ at the top of the scoreboard

IrqScoreBoard
								; acknowledge VIC irq
;;		lda $D019
;;		sta $D019

		pha		;; Atari -- Save A register.
		
								; install scroller irq
;;		lda #<IrqTopScreen
;;		sta $0314
;;		lda #>IrqTopScreen
;;		sta $0315
		
								 ; nr of rasterline we want the NEXT irq to occur at
;;		lda #$09
;;		sta $D012
		;======================================================================= OUR CODE GOES HERE
		lda #COLOR_GREEN
;;		sta VIC_BORDER_COLOR
		sta WSYNC  ;; Make a clean transition.
		sta COLBK ;; Atari background/border

;;	Atari.  LAST thing to do is chain to next interrupt.

		lda #<IrqTopScreen
		sta VDSLST ;; Disply list interrupt vector

		lda #>IrqTopScreen
		sta VDSLST+1		
		;-------------------------------------------------------------------------------------------
 ;;       jmp $ea31		

		pla ;; Atari -- restore A. 
		rti ;;  return to OS.

