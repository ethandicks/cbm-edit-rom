; PET/CBM EDIT ROM  - Commented and Adapted by Steve J. Gray, Nov 17, 2015
; ================    sjgray@rogers.com
; 
; ***** THIS IS 40-COLUMN CODEBASE *****
;
; This is reverse engineered source code for the EDIT ROMs of the Commodore PET/CBM computers.
; The "901499-01" ROM was used as a base. Addresses inside [brackets] are original code addresses. 
; Much of this disassembly comes from the 80-column source code, my own disassembly, and combined with
; Edilbert Kirk's 80-column disassembly.
;
; The EDIT ROM is mapped from $E000 to EFFF (4K). Many Early versions used only $E000-E7FF (2K).
; Note that the area from $E800 to $E8FF (256 bytes) is not available due to the I/O chips in this range.
;
; PET/CBM machines come in several flavours:
;    * 40 or 80 column screens
;    * Normal, Business, or DIN keyboards
;    * 50 or 60 Hz power frequency
;    * Specialized options, ie: Execudesk
;
; In addition I am adapting the EDIT roms to these additional options:
;    * ColourPET - My own project to add colour capabilities
;    * Alternate Keyboards - Such as the VIC/C64 keyboard
;    * Soft40 - Simulate a 40 column screen on 80 column hardware
;    * Soft-switchable SOFT40
;    * Soft-switchable real 40/80 columns (requires hardware mod)
;    * Extended screen editor - C128 or CBM-II compatible ESC sequences
;    * Keyboard soft-reset (kinda like CTRL-ALT-DEL on PC's)
;    * Autoboot from default drive
;    * DOS Wedge
;
; See EDIT.ASM for assemble OPTIONS!
; Use MAKE.BAT to assemble a binary file with the current options.
;
;-----------------------------------------------------------------------------------------------
* = $e000	; Normal start address for EDIT ROM is $E000

;*********************************************************************************************************
;** Edit ROM Jump Table [E000]
;** Note: Not all KERNAL and BASIC calls go through this table.
;** There are FIVE hard-coded entry points: $E0A7, $E116, $E202, $E442, $E600
;*********************************************************************************************************

EDITOR		JMP RESET_EDITOR			; Main Initialization (called from Kernal power up reset at $FD16) 
		JMP GETKEY				; Get Character From Keyboard Buffer	(FIXED ENTRY POINT. Must not move!)
		JMP INPUT_CHARACTER			; Input From Screen or Keyboard		(FIXED ENTRY POINT. Must not move!)
		JMP CHROUT_SCREEN			; Output to Screen			(FIXED ENTRY POINT. Must not move!)
		JMP IRQ_MAIN				; Main IRQ Handler			(FIXED ENTRY POINT. Must not move!)
		JMP IRQ_NORMAL				; Actual IRQ (clock, keyboard scan)
		JMP IRQ_END				; Return From Interrupt			(FIXED ENTRY POINT. Must not move!)
		JMP WINDOW_CLEAR			; Clear Window
		JMP CRT_SET_TEXT			; Set CRTC to TEXT mode
		JMP CRT_SET_GRAPHICS			; Set CRTC to GRAPHICS mode
		JMP CRT_PROGRAM				; Program CRTC (Table pointer in A/X, chr set in Y)
		JMP WINDOW_SCROLL_DOWN			; Scroll DOWN
		JMP WINDOW_SCROLL_UP			; Scroll UP
		JMP SCAN_KEYBOARD			; Scan Keyboard
		JMP BEEP				; Ring BELL/CHIME
		JMP NOTSUPPORTED 			; Set REPEAT Flag   (Function Not supported)
		JMP NOTSUPPORTED 			; Set Window Top    (Function Not supported)
		JMP NOTSUPPORTED 			; Set Window Bottom (Function Not supported)

;*********************************************************************************************************
;** RESET_EDITOR  [E04B]  (Called from Jump Table)
;** Initializes Editor, then sets the screen to TEXT or GRAPHICS mode.
;*********************************************************************************************************

RESET_EDITOR
!IF COLOURPET=0 {
		JSR INIT_EDITOR
} ELSE {
		JSR ColourPET_Init			; Initialize ColourPET settings
}

!IF BOOTCASE=0 { JSR CRT_SET_TEXT }			; Set Screen to TEXT mode
!IF BOOTCASE=1 { JSR CRT_SET_GRAPHICS }			; Set Screen to GRAPHICS mode

		JSR BEEP_BEEP 				; Ring BELL
		JSR BEEP_BEEP 				; Ring BELL

;*********************************************************************************************************
;** WINDOW_CLEAR  [$E042]  (Called from Jump Table) 
;** This routine clears the screen. Since there is no windowing it clears EVERY byte in the screen memory,
;** including non-visible bytes. It also calculates the HI byte of the start of each screen line and
;** stores it into the Screen Line Link table. LO bytes are stored in ROM at $E798. These addresses are
;** used for printing to the screen. Entries with HI BIT CLEARED are linked to the line above it.
;*********************************************************************************************************

WINDOW_CLEAR	LDX #$18				; 24 lines
		LDA #$C0				; $83C0 = Address of first character on last line of screen?
		LDY #$83		

WCLOOP		STY LineLinkTable,X			; LOOP[      Save HI byte of screen address to table
		SEC					;
		SBC #$28				;   Subtract 40 characters (one physical line)
		BCS WCSKIP1				;   did we move past page? No, skip ahead
		DEY					;   Yes, next page
WCSKIP1		DEX					;   Previous line
		BPL WCLOOP				; ] Loop up for more

		STY ScrPtr+1				; Store in screen pointer HI
		INX					; X=0
		STX ReverseFlag    			; Clear RVS Flag
		STX ScrPtr    				; Store 0 to screen Pointer LO (pointer should point to $8000 - HOME position)

;[$E05A]	------------------------------- Clear all Screen Memory 

		LDA #$20				; <SPACE>
CLS_LOOP	STA SCREEN_RAM,X			; LOOP[  Screen RAM page 1
		STA SCREEN_RAM+$100,X			;        Screen RAM page 2
		STA SCREEN_RAM+$200,X			;        Screen RAM page 3
		STA SCREEN_RAM+$300,X			;        Screen RAM page 4 (this also clears non-visible)
		INX					;   Next position
		BNE CLS_LOOP				; ] Loop back for more

;*********************************************************************************************************
;** CURSOR_HOME  [$E06B]
;** Moves the cursor to the HOME position
;*********************************************************************************************************

CURSOR_HOME	LDY #$00				; ROW=0, COL=0
		STY CursorCol   			; Store to Cursor Column on Current Line
		STY CursorRow   			; Store to Current Cursor Physical Line Number

;*********************************************************************************************************
;** CURSOR_LM  [$E071]
;** Moves Cursor to start of line. Sets Screen-line pointer, and determines if line is linked 
;*********************************************************************************************************

CURSOR_LM	LDX CursorRow   			; Get Current Cursor Physical Line Number
		LDA LineLinkTable,X			; Get Current Line's Screen Line Link entry
		ORA #$80				; Make sure HIGH bit is set
		STA ScrPtr+1				; Store in Current Screen Line Address HI
		LDA Line_Addr_Lo,X			; Get the LO byte from table in ROM
		STA ScrPtr    				; Store to Current Screen Line Address LO
		LDA #$27       				; 40 characters/line minus 1 = 39
		STA RightMargin   			; Set Physical Screen Line Length = 40
		CPX #$18				; Line 24? (0-24) last line cannot be linked
		BEQ CLM_SKIP1				; Yes, skip ahead
		LDA LineLinkTable+1,X 			; Check next line in screen line link table
		BMI CLM_SKIP1  				; Is HIGH bit set? (negative value) Yes, so NO linked line
		LDA #$4F				; No, then line is linked. 79 = two screen lines
		STA RightMargin   			; Store in Physical Screen Line Length
CLM_SKIP1 	LDA CursorCol   			; Cursor Column on Current Line
		CMP #$28				; Is it greater than 40?
		BCC NOTSUPPORTED			; No, skip
		SBC #$28				; Yes, subtract 40
		STA CursorCol   			; Cursor Column on Current Line

;-------------- Unsupported Functions Jump Here [$E098]

NOTSUPPORTED	RTS

;*********************************************************************************************************
;** GETKEY [E0A7] (Called from Jump Table)
;** Get a KEY from keyboard buffer. Reads a character from 'KEYD' then shifts remaining buffer characters
;** If there is NO key it will return $FF.
;*********************************************************************************************************
!FILL $e0a7-*,$aa ; FIXED ENTRY POINT! This must not move!
;#########################################################################################################

GETKEY
!if DEBUG=1 { INC DBLINE+2,X }				; DEBUG
		LDY KEYD				; Get key at start of buffer
		LDX #0 					; Start at 0

GK_LOOP		LDA KEYD+1,X				; LOOP[ START - Now shift the next keys in line
		STA KEYD,X				;   to the front of the buffer
!if DEBUG=1 { STA DBLINE+10,X }				;   DEBUG - update screen
		INX
		CPX CharsInBuffer			;   Num Chars in Keyboard Buffer
		BNE GK_LOOP				; ] Done? No, loop for another

		DEC CharsInBuffer			; Reduce Num Chars in Keyboard Buffer

		TYA					; Put the character in Accumulator
!if DEBUG=1 { STA DBLINE+3 }				; DEBUG - 4th chr on bottom line
		CLI
		RTS

;*********************************************************************************************************
;** GETLINE [E0BC]
;** The PET is usually in this routine, waiting for keypresses and printing them or acting on them.
;** This routine continually loops until a <RETURN> is pressed. When <RETURN> is pressed then the line
;** where the cursor is, is processed. If the <RUN> key is pressed then the string is stuffed into
;** the keyboard buffer (overwriting whatever might be there)
;*********************************************************************************************************

GETLINE		JSR ChrOutMarginBeep			; Check for BELL at near-end of line 
GETLINE2	!IF DEBUG=1 { INC DBLINE+5 }		; DEBUG - 6th chr on bottom line
		LDA CharsInBuffer			; Are there any keys waiting?
		STA Blink 				; 0 chars -> blink cursor
		BEQ GETLINE2 				; loop until char in buffer

!if DEBUG=1 { INC DBLINE+6 }				; DEBUG - 7th chr on bottom line

;		--------------------------------------- Got a character, so process it

		SEI
		LDA BlinkPhase				; Flag: Last Cursor Blink On/Off
		BEQ GL_1				; no, so no need to restore original character
		LDA CursorChar				; Character Under Cursor
		LDY #0
		STY BlinkPhase				; Reset blinkphase
		JSR RESTORE_CHR_AT_CRSR			; Restore OLD character under cursor before processing new one
GL_1		JSR GETKEY				; Get Character From Keyboard Buffer
		CMP #$83				; Is it the <RUN> key?
		BNE GL_3				; No, skip ahead

;		--------------------------------------- Stuff the <RUN> string to the keyboard buffer

		SEI
		LDX #9					; Length of string
		STX CharsInBuffer			; Set number of characters in buffer
GL_2		LDA RUN_STRING-1,X			; LOOP[    Normally:  dL"*<RETURN>run<RETURN>
		STA KEYD-1,X				;   stuff it into the buffer
		DEX					;   next character
		BNE GL_2				; ] Loop back for more
		BEQ GETLINE2

;		--------------- Check for RETURN key

GL_3		CMP #$0D 				; Check if <RETURN> pressed
		BNE GETLINE				; if not go get more keys

;*********************************************************************************************************
;** PARSE_LINE [E0EE]
;** When the <RETURN> key is pressed the line where the cursor lives is executed
;*********************************************************************************************************

		!IF DEBUG=1 { INC DBLINE+7 }		; DEBUG - 8th chr on bottom line

		LDY RightMargin   			; Physical Screen Line Length
		STY CRSW   				; Flag: INPUT or GET from Keyboard

PL_LOOP		LDA (ScrPtr),Y				; LOOP[  Pointer: Current Screen Line Address
		CMP #$20				;   Is it <SPACE>?
		BNE PL_SKIP				;   No, found end of line, skip ahead
		DEY					;   Yes, move to previous position
		BNE PL_LOOP				; ] At start of line? No, loop back for more

;		------------------------ Process line

PL_SKIP 	INY					; last checked was not space so move one forward
		STY LastInputCol			; Pointer: End of Logical Line for INPUT
		LDY #0					; COL=0, QUOTEMODE=0		[40]
		STY CursorCol   			; Cursor Column on Current Line	[40]
		STY QuoteMode   			; Flag: Editor in Quote Mode
		LDA InputRow   				; Cursor Y-X Pos. at Start of INPUT
		BMI Screen_Input
		CMP CursorRow   			; Current Cursor Physical Line Number
		BNE Screen_Input
		LDA InputCol
		STA CursorCol   			; Cursor Column on Current Line
		CMP LastInputCol   			; Pointer: End of Logical Line for INPUT
		BCC Screen_Input
		BCS Screen_Input2

;*********************************************************************************************************
;** INPUT_CHARACTER [E116] (Called from Jump Table) - FIXED ENTRY POINT!!!!!
;** Push X and Y to stack then call Input a Character routine via pointer
;*********************************************************************************************************
!FILL $e116-*,$aa ; FIXED ENTRY POINT! This must not move!
;#########################################################################################################

INPUT_CHARACTER	TYA
		PHA
		TXA
		PHA

; 		On 80-column core there is a JMP(SCRIV) here
;		where SCRIV normally points to DEFAULT_SCREEN_VECTOR

;*********************************************************************************************************
;** DEFAULT_SCREEN_VECTOR [E11D]
;** Input from Screen Routine
;*********************************************************************************************************

DEFAULT_SCREEN_VECTOR
		LDA CRSW   				; Get Input Flag: INPUT or GET from Keyboard
		BEQ GETLINE2				; Is it ZERO? Yes, Loop back up to Input from Keyboard

;		--------------------------------------- Screen Input [$E11E]

Screen_Input	LDY CursorCol				; Cursor Column on Current Line
		LDA (ScrPtr),Y				; Pointer: Current Screen Line Address
		STA DATAX				; Current Character to Print
		AND #$3F
		ASL DATAX				; Current Character to Print
		BIT DATAX				; Current Character to Print
		BPL SI_SKIP1
		ORA #$80
SI_SKIP1	BCC SI_SKIP2
		LDX QuoteMode				; Flag: Editor in Quote Mode
		BNE SI_SKIP3
SI_SKIP2	BVS SI_SKIP3
		ORA #$40				; '@'
SI_SKIP3	INC CursorCol				; Cursor Column on Current Line
		JSR CheckQuote				; Switch Quote flag
		CPY LastInputCol			; Pointer: End of Logical Line for INPUT
		BNE SI_SKIP6

;		--------------------------------------- Screen Input 2 [$E141]

Screen_Input2	LDA #$00
		STA CRSW				; Flag: INPUT or GET from Keyboard
		LDA #$0D				; <RETURN>
		LDX DFLTN				; Default Input Device (0)
		CPX #$03				; 3=SCREEN
		BEQ SI_SKIP4
		LDX DFLTO				; Default Output (CMD) Device (3)
		CPX #$03	
		BEQ SI_SKIP5
SI_SKIP4	JSR CHROUT_SCREEN			; Output to screen
SI_SKIP5	LDA #$0D				; <RETURN>
SI_SKIP6 	STA DATAX  				; Current Character to Print
		PLA
		TAX
		PLA
		TAY
		LDA DATAX  				; Current Character to Print
		CMP #$DE				; Is it <PI>?
		BNE SI_DONE				; No, skip ahead
		LDA #$FF				; Yes, substitute screen code
SI_DONE		RTS

;[$E167]	--------------------------------------- Check Quote Mode 

CheckQuote	CMP #$22 				; Is it <QUOTE>?
		BNE CQ_DONE				; No, skip ahead
		LDA QuoteMode				; Flag: Editor in Quote Mode, $00 = NO
		EOR #1					; toggle the BIT
		STA QuoteMode				; Flag: Editor in Quote Mode, $00 = NO
		LDA #$22 				; reload the <QUOTE>
CQ_DONE		RTS

;*********************************************************************************************************
;** CHAR_TO_SCREEN [E177]
;** This puts a character in 'A' to screen. The character is handled differently according to the entry
;** point. For example, when QUOTE mode is ON special characters are printed in RVS using CHAR_TO_SCREEN3
;*********************************************************************************************************

CHAR_TO_SCREEN	ORA #$40 				; '@'
CHAR_TO_SCREEN2 LDX ReverseFlag    			; Flag: Print Reverse Chars. -1=Yes
		BEQ CTS_SKIP1

CHAR_TO_SCREEN3	ORA #$80				; Toggle the upper bit (reverse characters)
CTS_SKIP1	LDX INSRT  				; Flag: Insert Mode, >0 = # INSTs
		BEQ CTS_SKIP2
		DEC INSRT  				; Flag: Insert Mode, >0 = # INSTs
CTS_SKIP2

!IF COLOURPET=0 {
		JSR RESTORE_CHR_AT_CRSR
} ELSE {
		JSR Put_ColourChar_at_Cursor		; Put character AND Colour on screen
}
		INC CursorCol   			; Cursor Column on Current Line
		LDY RightMargin   			; Physical Screen Line Length
		CPY CursorCol   			; Cursor Column on Current Line
		BCS IRQ_EPILOG
		LDX CursorRow   			; Current Cursor Physical Line Number
		CPY #$4F				; 79=maximum line length (2 physical lines) minus 1
		BNE CTS_SKIP3
		JSR LINKLINES				; Set 80-column line indicator
		JSR CURSOR_DOWN				; Move Cursor to next line
		LDA #$00				; First character on line
		STA CursorCol   			; Cursor Column on Current Line
		BEQ IRQ_EPILOG

CTS_SKIP3	CPX #$18				; Last screen line?
		BNE LINKLINES2				; No, continue
		JSR SCROLL_UP				; Yes, Scroll screen and adjust line link

;*********************************************************************************************************
;** IRQ_EPILOG [E1A6]
;** IRQ Completion. We jump here when printing is complete.
;*********************************************************************************************************

IRQ_EPILOG	PLA
		TAY
		LDA INSRT				; Flag: Insert Mode, >0 = # INSTs
		BEQ IRQE_1
		LSR QuoteMode				; Flag: Editor in Quote Mode
IRQE_1		PLA
		TAX
		PLA
		CLI					; Allow interrupts again
		RTS

;*********************************************************************************************************
;** LINKLINES [$E1B3]
;** These routines are for 40-column line linking. When a character is printed to
;** column 40 the line and the line below are linked into one 80-character logical line.
;** IE: two physical lines become one logical line.
;** X hold physical line#. Checks ROW to make sure it's not on last line.
;*********************************************************************************************************

LINKLINES	CPX #$17				; Are we at last screen ROW? 23 ?
		BCS LL_SKIP				; Yes, skip out
		LDA LineLinkTable+2,X			; No, safe to link the next line to this one
		ORA #$80				; Link the line by SETTING the upper bit
		STA LineLinkTable+2,X			; Store to line link table
LL_SKIP		RTS

;		--------------------------------------- Convert 40 character line to 80 characters [$E1BE]

LINKLINES2	JSR LINKLINES3				; Adjust line link and move to start of line
		JMP IRQ_EPILOG				; Finish Up

;		--------------------------------------- Scroll screen UP [$E1C4]

SCROLL_UP	JSR WINDOW_SCROLL_UP			; Scroll Screen Up
		DEC InputRow   				; Cursor Y-X Pos. at Start of INPUT
		DEC CursorRow   			; Current Cursor Physical Line Number
		LDX CursorRow   			; Current Cursor Physical Line Number

;		------------------------------- Adjust Line Link and Move to start of line [$E1CD]

LINKLINES3	ASL LineLinkTable+1,X 			; Shift to lose HI BIT
		LSR LineLinkTable+1,X 			; HI BIT is now CLEARED
		JSR LINKLINES				; Set line link
		LDA CursorCol   			; Get Cursor Column on Current Line
		PHA					; Remember column
		JSR CURSOR_LM				; Cursor to start of line
		PLA					; Restore column
		STA CursorCol   			; Store Cursor Column on Current Line
		RTS

;*********************************************************************************************************
;** CURSOR_TO_EOPL [$E1DE]
;** Back to previous line when actioning DEL or LEFT 
;*********************************************************************************************************

CURSOR_TO_EOPL	LDY #$27				; Column 39
		LDX CursorRow   			; Get Current Cursor Physical Line Number
		BNE PL_SKIP1				; Is it Zero? No, ok to proceed, so skip ahead
		STX CursorCol   			; Yes, movement is invalid. Cursor Column on Current Line
		PLA					; pull the character from the stack
		PLA					; pull the character from the stack
		BNE IRQ_EPILOG				; jump back up to finish up

PL_SKIP1	LDA LineLinkTable-1,X			; Get PREVIOUS line's Line Link value
		BMI PL_SKIP2				; Is HI BIT SET? Yes, skip ahead
		DEX					; No, it's ok to go back to previous line
		LDA LineLinkTable-1,X			; Get PREVIOUS line's Line Link value
		LDY #$4F				; Column 79

PL_SKIP2	DEX
		STX CursorRow   			; Current Cursor Physical Line Number
		STA ScrPtr+1				; Store to Current Screen Line Address pointer
		LDA Line_Addr_Lo,X			; Get LO byte from ROM table
		STA ScrPtr    				; Store to Current Screen Line Address pointer
		STY CursorCol   			; Store to Cursor Column on Current Line
		STY RightMargin   			; Store to Physical Screen Line Length
		RTS

;*********************************************************************************************************
;** CHROUT_SCREEN [E202] (Called from Jump Table)
;** $E202 - FIXED ENTRY POINT! Some BASIC/KERNAL bypass the Jump Table and jump directly here
;** Output Character to Screen Dispatch 
;*********************************************************************************************************
!FILL $e202-*,$aa ; FIXED ENTRY POINT! This must not move!
;#########################################################################################################

CHROUT_SCREEN	PHA
		STA DATAX				; Current Character to Print
		TXA
		PHA
		TYA
		PHA
;							80-column machines have JMP(SCROV) here.
;							where SCROV would normally point to 'CHROUT_NORMAL'

;*********************************************************************************************************
;** CHROUT_NORMAL [E209]
;** Output Character to Screen. Character to print must be in DATAX.
;** On 80 column machines, SCROV vector would point here
;*********************************************************************************************************

CHROUT_NORMAL	LDA #0
		STA CRSW   				; Flag: INPUT or GET from Keyboard
		LDY CursorCol   			; Cursor Column on Current Line
		LDA DATAX  				; Current Character to Print
		AND #$7F				; Mask off top bit (graphics characters)

;[PATCH]	--------------------------------------- Check for ESC Character


!IF ESCCODES=1 {
		JMP CheckESC				; Check for ESC as last Char, then ESC as current Char. If so, perform it.
ESC_DONE	STA LASTCHAR				; Save the character

} ELSE {
		CMP #$1B				; <ESC>	key? **** Also SHIFT-ESC $9B (Conflicts with COLOUR CODE!)
		BNE CHROUT_CHECK
		JMP ESCAPE				; Cancel RVS/INS/QUOTE modes
}
ESC_DONE2

;[E21A]		--------------------------------------- Reload character and check HIGH BIT

CHROUT_CHECK	LDA DATAX  				; Current Character to Print
!IF COLOURPET=1 { JSR CheckColourCodes }		; Check table of color values @@@@@@@@@@@@@@@@ COLOURPET
		BPL CHROUT_LO				; Is top bit CLEAR? Yes, handle UNSHIFTED Character
		JMP CHROUT_HI				; No, Handle SHIFTED Character

;*********************************************************************************************************
;** Character Output with HIGH BIT CLEAR [E224]
;** This routine handles characters in the range 0 to 127.
;** Checked: RETURN,DELETE,RVS,HOME,CRSR-RIGHT,CRSR-DOWN,ERASE-EOL,TEXT,BELL,TAB
;*********************************************************************************************************

;		--------------------------------------- Check for RETURN

CHROUT_LO	CMP #$0D				; Is it <RETURN>?
		BNE COU_SKIP1				; No, skip ahead
		JMP CURSOR_RETURN			; Yes, Handle <RETURN>

;		--------------------------------------- Check for Control Codes Range (0-31)

COU_SKIP1 	CMP #$20				; <SPACE>
		BCC COU_SKIP2				; No, it's 0-31
		AND #$3F				; Yes, Mask off HI BIT
		JSR CheckQuote				; Switch Quote flag if found
		JMP CHAR_TO_SCREEN2

COU_SKIP2	LDX INSRT  				; Flag: Insert Mode, >0 = # INSTs
		BEQ COU_SKIP3				; Is FLAG=0? Yes, skip ahead
		JMP CHAR_TO_SCREEN3

;		--------------------------------------- Check for DELETE

COU_SKIP3	CMP #$14				; Is it <DEL>?
		BNE COU_SKIP6				; No, skip ahead

;		--------------------------------------- DELETE - Check if it would wrap to previous line

		DEY					; Yes, move to the left
		STY CursorCol   			; Cursor Column on Current Line
		BPL COU_SKIP4
		JSR CURSOR_TO_EOPL			; Back to previous line (rename this label?)
		JMP COU_SKIP5

;		--------------------------------------- Perform DELETE

COU_SKIP4
!IF COLOURPET=0 {
		INY
		LDA (ScrPtr),Y				; Pointer: Current Screen Line Address
		DEY		
		STA (ScrPtr),Y				; Pointer: Current Screen Line Address
		INY
		CPY RightMargin   			; Physical Screen Line Length
		BNE COU_SKIP4
} ELSE {
		JSR ColourPET_Scroll_Left		; Scroll both Screen and Colour LEFT	@@@@@@@@@@@@@@ ColourPET
}

COU_SKIP5
		LDA #$20				; <SPACE>
		STA (ScrPtr),Y				; Put it on the screen!
!IF COLOURPET=1 {
		LDA COLOURV				; Get the current Colour	@@@@@@@@@@@@@@@ ColourPET
		STA (COLOURPTR),Y			; Put it to Colour MEM		@@@@@@@@@@@@@@@ ColourPET
}
		BNE COU_SKIP11

COU_SKIP6	LDX QuoteMode   			; Flag: Editor in Quote Mode
		BEQ COU_SKIP7
		JMP CHAR_TO_SCREEN3

;		--------------------------------------- Check for RVS

COU_SKIP7	CMP #$12				; Is it <RVS>?
		BNE COU_SKIP8
		STA ReverseFlag    			; Flag: Print Reverse Chars. -1=Yes
		BEQ COU_SKIP11

;		--------------------------------------- Check for HOME

COU_SKIP8	CMP #$13				; Is it <HOME>?
		BNE COU_SKIP9				; No, skip ahead
		JSR CURSOR_HOME				; Cursor to start of line

;		--------------------------------------- Check for CURSOR RIGHT

COU_SKIP9	CMP #$1D				; Is it <CRSR-RIGHT>?
		BNE COU_SKIP12
		INY
		STY CursorCol   			; Cursor Column on Current Line
		DEY
		CPY RightMargin   			; Physical Screen Line Length
		BCC COU_SKIP11
		JSR CURSOR_DOWN				; Move Cursor to next line
		LDY #$00
COU_SKIP10	STY CursorCol   			; Cursor Column on Current Line
COU_SKIP11	JMP IRQ_EPILOG				; Finish Up

;		--------------------------------------- Check for CURSOR DOWN

COU_SKIP12	CMP #$11				; Is it <CRSR-DOWN>?
		BNE COU_SKIP14				; No, skip ahead
		CLC
		TYA
		ADC #$28				; Add 40 for next line
		TAY
		CMP RightMargin   			; Compare it to Screen Line Length
		BCC COU_SKIP10				; Less, so it's ok
		BEQ COU_SKIP10				; Equal, also ok
		JSR CURSOR_DOWN				; More, so Move Cursor to next line
COU_FINISH	JMP IRQ_EPILOG				; Finish Up

;		--------------------------------------- Check for ERASE TO END OF LINE

COU_SKIP14	!IF BUGFIX=0 { CMP #$10 }		; Is it CTRL-P? (BUG!)  This should be #10 or #$16
		!IF BUGFIX=1 { CMP #$16 }		; Is it CTRL-V? (BUG is FIXED!)
		BNE COU_SKIP15				; No, skip ahead

;[E2D4]		--------------------------------------- Erase to End of Line

!IF COLOURPET=1 {
		JSR ERASE_TO_EOL			; Replace with ColourPET Version
		JMP COU_FINISH				; Jump to continue
} ELSE {

ERASE_TO_EOL						; Original Routine
		LDA #$20				; Yes, set character to <SPACE>
		DEY
ETEL_LOOP 	INY					; LOOP[
		STA (ScrPtr),Y				;   Store <SPACE> to screen
		CPY RightMargin				;   Is it end of line?
		BCC ETEL_LOOP				; ] No, loop back for more
		BCS COU_FINISH				; Yes, Finish up
}
;		--------------------------------------- Check for TEXT MODE

COU_SKIP15	CMP #$0E				; Is it <TEXT>?
		BNE COU_SKIP16				; No, skip ahead
		JSR CRT_SET_TEXT			; Yes, Set screen to TEXT mode
		BMI COU_FINISH				; Finish up

;		--------------------------------------- Check for BELL

COU_SKIP16	CMP #$07				; Is it <BELL>?
		BNE COU_SKIP17				; No, skip ahead
		JSR BEEP				; Ring BELL
		BEQ COU_FINISH				; Finish up

;		--------------------------------------- Check for TAB

COU_SKIP17	CMP #$09				; Is it <TAB>?
		BNE COU_FINISH				; Finish up

COU_SKIP18	CPY RightMargin   			; Physical Screen Line Length
		BCC COU_SKIP20
		LDY RightMargin   			; Physical Screen Line Length

COU_SKIP19	STY CursorCol   			; Cursor Column on Current Line
		JMP IRQ_EPILOG				; Finish Up

COU_SKIP20	INY
		JSR CHECK_TAB				; Check TAB
		BEQ COU_SKIP18				; Is this a TAB position?
		BNE COU_SKIP19				; No, Loop back

;*********************************************************************************************************
;** CHROUT_HI [$E2D5]
;** Character Output when High Bit SET (characters in the range 128 to 256).
;** Handles: INS,CRSR-UP,RVS-OFF,CRSR-LEFT,CLR,ERASE-SOL,GRAPHICS,BELL,SET-TAB
;*********************************************************************************************************

CHROUT_HI
		AND #$7F				; strip off top bit
		CMP #$7F				; is it $FF?
		BNE COH_SKIP1				; No, skip
		LDA #$5E				; Yes, substitute with $5E (PI character)

COH_SKIP1	CMP #$20				; Is it <SPACE>?
		BCC COH_SKIP2				; Less? Yes, skip ahead and check more
		JMP CHAR_TO_SCREEN			; 32 to 127 -> 160-255. Jump and print it

;[E2E4]		--------------------------------------- Check for SHIFT-RETURN

COH_SKIP2	CMP #$0D				; Is it <SHIFT-RETURN>?
		BNE COH_SKIP3				; No, skip ahead (continue)
		JMP CURSOR_RETURN			; Yes, handle it

;[E2EB]		--------------------------------------- Check Quote Mode

COH_SKIP3	LDX QuoteMode   			; Flag: Editor in Quote Mode
		BNE COH_SKIP6				; No, skip ahead

;[E2EF]		--------------------------------------- Check for INSERT

		CMP #$14				; Is it <INS>? (SHIFT-DEL)
		BNE COH_SKIP5				; No, skip ahead

;[E2F3]		--------------------------------------- INS was pressed

CHECK_INSERT	LDY RightMargin   			; Right margin
		LDA (ScrPtr),Y				; Read the character at the end of the line
		CMP #$20				; Is the character a <SPACE>?
		BNE COH_SKIP4				; No, skip ahead
		CPY CursorCol				; Cursor Column on Current Line
		BNE DO_INSERT

COH_SKIP4	CPY #$4F				; Column 79?
		BEQ COU_SKIP11				; Yes, go back up for more
		JSR WINDOW_SCROLL_DOWN			; Check for and perform scrolling DOWN

;[E306]		--------------------------------------- Do INSERT

DO_INSERT 	LDY RightMargin   			; Start at right margin

!IF COLOURPET=0 {
INS_LOOP1 	DEY					; LOOP[  move back one
		LDA (ScrPtr),Y 				;   Get character from screen
		INY					;   Next character
		STA (ScrPtr),Y				;   Put character back to screen
		DEY					;   Next position
		CPY CursorCol   			;   Have we reached current Cursor position?
		BNE INS_LOOP1				; ] No, loop back for more
} ELSE {
		JSR ColourPET_Insert
}	
		LDA #$20				; <SPACE>
		STA (ScrPtr),Y 				; Write <SPACE> to screen at cursor position
		INC INSRT				; Flag: Insert Mode, >0 = # INSTs
		BNE COH_FINISH

COH_SKIP5	LDX INSRT  				; Flag: Insert Mode, >0 = # INSTs
		BEQ COH_CHECK1

COH_SKIP6	ORA #$40				; Set BIT 6
		JMP CHAR_TO_SCREEN3			; Print it

;[E324]		--------------------------------------- Check for CURSOR UP

COH_CHECK1	CMP #$11				; Is it <CRSR-UP>? (SHIFT-CRSR-DOWN)
		BNE COH_CHECK2

;[E32A]		--------------------------------------- Do Cursor UP

		LDA CursorCol   			; Cursor Column on Current Line
		CMP #$28				; Is it column 40?
		BCC COH_SKIP7				; No, skip ahead
		SBC #$28				; Yes, subtract 40
		STA CursorCol   			; Cursor Column on Current Line
		BCS COH_FINISH

COH_SKIP7	LDX CursorRow   			; Current Cursor Physical Line Number
		BEQ COH_FINISH
		LDA MYCH,X				; Serial Word Buffer
		BPL COH_SKIP8
		DEC CursorRow   			; Current Cursor Physical Line Number
		JSR CURSOR_LM				; Cursor to start of line
		BCC COH_FINISH

COH_SKIP8	DEX
		DEX
		STX CursorRow   			; Current Cursor Physical Line Number
		JSR CURSOR_LM				; Cursor to start of line
		LDA CursorCol   			; Cursor Column on Current Line
		CLC
		ADC #$28
		STA CursorCol				; Cursor Column on Current Line
		BNE COH_FINISH

;[E353]		--------------------------------------- Check for RVS OFF

COH_CHECK2	CMP #$12				; Is it <OFF>? (SHIFT-RVS)
		BNE COH_CHECK3				; No, skip ahead
		LDA #0					; Set RVS OFF
		STA ReverseFlag    			; Store it
		BEQ COH_FINISH

;[E35D]		--------------------------------------- Check for CURSOR LEFT

COH_CHECK3	CMP #$1D				; Is it <CRSR-LEFT>? (SHIFT-CRSR-RIGHT)
		BNE COH_CHECK4				; No, skip ahead

		DEY
		STY CursorCol   			; Cursor Column on Current Line
		BPL COH_FINISH
		JSR CURSOR_TO_EOPL
		JMP IRQ_EPILOG				; Finish Up

;[E36C]		--------------------------------------- Check for CLEAR SCREEN

COH_CHECK4	CMP #$13				; Is it <CLR>? (SHIFT-HOME)
		BNE COH_CHECK5				; No, skip ahead
		JSR WINDOW_CLEAR			; Yes, Clear the Screen
COH_FINISH	JMP IRQ_EPILOG				; Finish Up

;[E376]		--------------------------------------- Check for ERASE TO START OF LINE

COH_CHECK5	
!IF COLOURPET=0 {
		CMP #$16				; Is it <ERASE-END>? (SHIFT-CTRL-V) - CONFLICTS with COLOURPET!
		BNE COH_CHECK6				; No, skip ahead
} ELSE {
		JMP COH_CHECK6				; Just Skip ahead		@@@@@@@@@@ COLOURPET
}

;*********************************************************************************************************
;** ERASE_TO_SOL / ESCAPE_P [E37A]
;** Erases from cursor to Start of Line
;*********************************************************************************************************

ESCAPE_P
ERASE_TO_SOL	LDA #$20				; <SPACE>
		LDY #0					; Start at Left Margin
ESOL_LOOP	CPY CursorCol   			; LOOP[  Cursor Column on Current Line
		BCS COH_FINISH				;   Finish up
		STA (ScrPtr),Y				;   Pointer: Current Screen Line Address
!IF COLOURPET=1 {
		LDA COLOURV				;   Current Colour
		STA (COLOURPTR),Y			;   Write Current Colour to colour RAM
}
		INY
		BNE ESOL_LOOP				; ] Loop back for more

;[E387]		--------------------------------------- Check for SET GRAPHICS MODE

COH_CHECK6	CMP #$0E				; Is it <GRAPHICS>? (SHIFT-TEXT)
		BNE COH_CHECK7				; No, skip ahead
		JSR CRT_SET_GRAPHICS			; Yes, Set screen to graphics mode
		BMI COH_FINISH				; Finish up

;[E390]		--------------------------------------- Check for BELL

COH_CHECK7	CMP #$07				; Is it <BELL>?
		BNE COH_CHECK8				; No, skip ahead
		JSR BEEP_BEEP				; Ring the Bell
		BEQ COH_FINISH				; Finish up

;[E399]		--------------------------------------- Check for SET TAB

COH_CHECK8	CMP #$09				; Is it <SET-TAB>? (SHIFT-TAB)
		BNE COH_FINISH				; No, Finish up
		JSR CHECK_TAB				; Set TAB
		EOR TABS   				; Table of 80 bits to set TABs (80col)
		STA $03F0,X
		JMP IRQ_EPILOG				; Finish Up

;*********************************************************************************************************
;** CURSOR_DOWN  [$E3A9]
;** Do Cursor DOWN, Go to next line. If at bottom of window SCROLL UP.
;*********************************************************************************************************

CURSOR_DOWN	SEC
		LSR InputRow   				; Cursor Y-X Pos. at Start of INPUT
		LDX CursorRow   			; Current Cursor Physical Line Number

CD_LOOP1	INX					; LOOP[
		CPX #$19				;   Last line of screen?
		BNE CD_SKIP
		JSR WINDOW_SCROLL_UP			;   Scroll Screen Up

CD_SKIP		LDA LineLinkTable,X			;   Screen Line Link Table / Editor Temps (40 col)
		BPL CD_LOOP1				; ] Is HI bit CLEAR? Yes then go back for more
		STX CursorRow   			; Current Cursor Physical Line Number
		JMP CURSOR_LM				; Cursor to start of line

;*********************************************************************************************************
;** CURSOR_RETURN  [E3BF]
;** Cursor to start of line, then CURSOR DOWN. Also performs ESCAPE
;*********************************************************************************************************

CURSOR_RETURN	JSR CURSOR_DOWN				; Move to next line
		LDA #$00				; Column 0
		STA CursorCol   			; Set Cursor Column on Current Line

;*********************************************************************************************************
;** ESCAPE / ESCAPE_O [E3C6]
;** Cancels Insert, Reverse and Quote modes
;*********************************************************************************************************

ESCAPE_O				
ESCAPE		LDA #$00
		STA INSRT  				; Flag: Insert Mode, >0 = # INSTs
		STA ReverseFlag    			; Flag: Print Reverse Chars. -1=Yes
		STA QuoteMode   			; Flag: Editor in Quote Mode

!IF ESCCODES = 1 { STA LASTCHAR }

		JMP IRQ_EPILOG				; Finish Up

;*********************************************************************************************************
;** WINDOW_SCROLL_UP / ESCAPE_V  [E3D1] (Called from Jump Table)
;** Scrolls entire screen UP. Also scroll up line-link table
;*********************************************************************************************************

ESCAPE_V
WINDOW_SCROLL_UP
		LDX #$19				; 25 screen lines
		STX CursorRow   			; Current Cursor Physical Line Number

WSU_LOOP1	LDX #$FF

;[E3D7]		--------------------------------------- Set up screen pointers, scroll line link table entry for the current line

WSU_LOOP2	INX					; LOOP[
		LDA Line_Addr_Lo,X			;   Screen line address table LO
		STA ScrPtr    				;   Set up Pointer LO for screen scrolling
		LDA LineLinkTable,X			;   Screen Line Link Table (address table HI)
		ORA #$80				;   Make sure HI BIT is set
		STA ScrPtr+1				;   Set up pointer HI for screen scrolling 
		CPX #$18				;   Last Line?
		BCS WSU_SKIP2				;   Yes, so skip ahead to exit loop
		LDY LineLinkTable+1,X			;   No, so get NEXT Line's Line Link entry
		BMI WSU_SKIP1				;   is HI BIT set? Yes, leave it as is and skip ahead
		AND #$7F				;   No, then CLEAR HI BIT

WSU_SKIP1	STA LineLinkTable,X			;   Store it in the CURRENT Line Link entry (IE scroll the high bits UP)
		TYA
		ORA #$80				;   Set HI BIT
		STA SAL+1				;   $C8
		LDA Line_Addr_Lo+1,X			;   Screen line address table
		STA SAL    				;   Pointer: Tape Buffer/ Screen Scrolling

;[E3F9]		--------------------------------------- Now we scroll the video screen lines

		LDY #$27				;   40 characters per line

WSU_LOOP3	LDA (SAL),Y 				;   LOOP[[  Read character from screen
		STA (ScrPtr),Y 				;     Write it back
		DEY					;     Next character
		BPL WSU_LOOP3				;   ]] Loop back for more
		BMI WSU_LOOP2				; ] Loop back for more

WSU_SKIP2	STA LineLinkTable,X			; Store to Screen Line Link Table

;[E406]		--------------------------------------- Clear the last screen line

		LDY #$27				; 40 characters on line
		LDA #$20				; <SPACE>

WSU_LOOP4	STA (ScrPtr),Y 				; LOOP[  Write <SPACE> to the screen
		DEY					;   Next character
		BPL WSU_LOOP4				; ] Loop back for more

		DEC CursorRow   			; Current Cursor Physical Line Number
		LDA LineLinkTable			; Screen Line Link Table / Editor Temps (40 col)
		BPL WSU_LOOP1				; ] Loop back for more

;*********************************************************************************************************
;** Check Keyboard Scroll Control  [E415]
;*********************************************************************************************************

CHECK_SCROLL_CONTROL
		LDA PIA1_Port_B				; Keyboard COL read
		CMP #$FE				; Is KEY held down?
		BNE CSC_SKIP				; No, skip over delay

;[E41C]		--------------------------------------- Scroll delay

		LDY #$00

SCROLL_DELAY	NOP					; LOOP[
		DEX
		BNE SCROLL_DELAY 			; ] Loop back for more
		DEY
		BNE SCROLL_DELAY 			; ] Loop back for more

		STY CharsInBuffer    			; No. of Chars. in Keyboard Buffer (Queue)

;[E427]		--------------------------------------- Scroll complete

CSC_SKIP	LDX CursorRow   			; Current Cursor Physical Line Number
		RTS

!IF CRUNCH = 0 {
		TAX
		TAX
		TAX
		TAX
}

;*********************************************************************************************************
;** Jiffy Clock Timer Correction Patch  [E42E]
;*********************************************************************************************************

ADVANCE_TIMER	JSR UDTIME				; Update System Jiffy Clock. KERNAL routine $FFEA 
		INC JIFFY6DIV5				; Counter to speed TI by 6/5 (40col)
		LDA JIFFY6DIV5				; Counter to speed TI by 6/5 (40col)
		CMP #$06				; 6 IRQ's?
		BNE IRQ_NORMAL2				; No, do normal IRQ
		LDA #$00				; Reset IRQ adjustment counter
		STA JIFFY6DIV5 				; Counter to speed TI by 6/5 (40col)
		BEQ ADVANCE_TIMER			; was IRQ_MAIN		; Do normal IRQ

;*********************************************************************************************************
;** MAIN IRQ ENTRY [E442][E455] (Called from Jump Table) - FIXED ENTRY POINT!
;** This entry point must not move! It is called directly from KERNAL
;** The CRTC chip's V-Sync line is fed to a VIA to generate IRQ's. When an IRQ is triggered, the
;** Clock is updated, the keyboard scanned, ieee polled and tape monitored.
;*********************************************************************************************************
!FILL $e442-*,$aa ; FIXED ENTRY POINT! This routine must not move!
;#########################################################################################################

!SOURCE "irq.asm"

;*********************************************************************************************************
;** KEYBOARD SCANNER  [E4BE]
;** The Keyboard is scanned during the IRQ and one keystroke is stored to KEYD. Other routines transfer
;** this keystroke to or from a small 10-byte buffer. The keyboard scanner does the actual interfacing to
;** the hardware to read the rows and columns of the keyboard matrix. When a key is pressed it gets the
;** keycode from the keyboard matrix table. If no key is pressed, then $FF is returned.
;*********************************************************************************************************

!IF KEYSCAN=0 { !SOURCE "keyscan-g.asm" }		; Graphic Keyboard
!IF KEYSCAN=1 { !SOURCE "keyscan-b.asm" }		; Business Keyboard
!IF KEYSCAN=2 { !SOURCE "keyscan-din.asm" }		; German DIN Keyboard
!IF KEYSCAN=3 { !SOURCE "keyscan-c64.asm" }		; C64 Keyboard  (future implementation)
!IF KEYSCAN=4 { !SOURCE "keyscan-cbm2.asm" }		; CBM2 Keyboard (future implementation)

;*********************************************************************************************************
;** JUMP_TO_TAB [E588]
;** Tab positions are stored in a table of 80 bits (10 bytes). 
;*********************************************************************************************************

CHECK_TAB	TYA
		AND #$07				; Only look at lower 3 bits (values 0 to 7)
		TAX
		LDA POWERSOF2,X				; GetTable of BIT position values
		STA TABS   				; Table of 80 bits to set TABs
		TYA	
		LSR
		LSR
		LSR
		TAX
		LDA TABS+1,X				; Get the BITS for that group of tabs (Table of 80 bits to set TABs)
		BIT TABS   				; Set FLAG for testing???? (Table of 80 bits to set TABs)
		RTS

;################################################################################
		!fill $e600-*,$aa	;########################################
;################################################################################

;*********************************************************************************************************
;** IRQ_END  [E600] (Called from Jump Table) - FIXED ENTRY POINT!
;** The IRQ routine jumps here when completed. Do not modify this routine!
;*********************************************************************************************************
!FILL $e600-*,$aa ;FIXED ENTRY POINT! This routine must not move! It is called directly from KERNAL
;#########################################################################################################

IRQ_END		PLA
		TAY
		PLA
		TAX
		PLA
		RTI

;*********************************************************************************************************
;** RESTORE_CHR_AT_CRSR  [E606]
;** This routine is called to put the character back at the cursor position.
;** It is called to put the initial character on the screen and as part of the cursor blinking routine.
;** NOTE: ColourPET: DOES NOT set/change COLOUR ATTRIBUTE!
;*********************************************************************************************************

RESTORE_CHR_AT_CRSR
		LDY CursorCol  				; Cursor Column on Current Line
		STA (ScrPtr),Y				; Pointer: Current Screen Line Address
		LDA #$02
		STA BLNCT  				; Timer: Countdown to Toggle Cursor
		RTS

;*********************************************************************************************************
;** CRT_SET_TEXT  [$E60F]  (Called from Jump Table) 
;** TEXT MODE lower case, upper case and limited graphics.
;** Characters take 10 scanlines (normally)
;*********************************************************************************************************

CRT_SET_TEXT	LDA #<CRT_CONFIG_TEXT			; Point to CRTC Table
		LDX #>CRT_CONFIG_TEXT			; Point to CRTC Table
		LDY #$0E				; Character Set = TEXT
		BNE CRT_PROGRAM

;*********************************************************************************************************
;** CRT_SET_GRAPHICS  [$E617]  (Called from Jump Table) 
;** GRAPHICS mode has uppercase and full graphics.
;** Characters take 8 scanlines
;*********************************************************************************************************

CRT_SET_GRAPHICS
		LDA #<CRT_CONFIG_GRAPHICS      		; Point to CRTC Table
		LDX #>CRT_CONFIG_GRAPHICS      		; Point to CRTC Table
		LDY #$0C				; Character Set = GRAPHICS

;*********************************************************************************************************
;** CRT_PROGRAM  [$E61D] (Called from Jump Table)
;** The CRTC controller controls the parameters for generating the display on the monitor. The CRTC chip
;** has several registers that must be set properly according to the type of connected display. These set
;** characters on the line, left and right margins, lines on the screen, height of each line and
;** positioning of the top of the screen. The parameters are read from a table and written to the CRTC
;** controller chip. The VIA chip is used to select which of the two fonts from the CHARACTER ROM is used.
;**
;** Parameters: Table pointer in A/X, CHRSET in Y
;** OPTIONS: 'SS40' uses new routine in upper rom
;*********************************************************************************************************

CRT_PROGRAM
;		--------------------- Set 'Character Set' [$E61D]

		STA SAL					; Pointer LO: Tape Buffer/ Screen Scrolling
		STX SAL+1				; Pointer HI
		LDA VIA_PCR				; Get current register byte VIA Register C - CA2	CHIP 
		AND #$f0				; mask out lower nibble
		STA FNLEN				; save it to Temp Variable
		TYA					; Move 'Character Set' byte to A
		ORA FNLEN				; update lower nibble in Temp Variable
		STA VIA_PCR				; write it back to VIA Register C - CA2			CHIP

;		--------------------- Write to the CRTC controller [$E62E]

		LDY #$11				; Number of bytes to copy = 17

CRT_LOOP	LDA (SAL),Y				; LOOP[   Pointer: Tape Buffer/ Screen Scrolling
		STY CRT_Address				;   Select the register to update 6545/6845 CRT		CHIP
		STA CRT_Status				;   Write to the register
		DEY					;   Next character
		BPL CRT_LOOP				; ] Loop for more
		RTS

;*********************************************************************************************************
;** ChrOutMarginBeep  [E68C]
;** Checks the cursor position and rings the BELL if near the end of the line
;*********************************************************************************************************

ChrOutMarginBeep
		JSR CHROUT_SCREEN			; Output character to screen (chr code in A)
		TAX					; Save the character to X
		LDA RightMargin   			; Physical Screen Line Length
		SEC
		SBC CursorCol   			; Cursor Column on Current Line
		CMP #5					; Are we at the 5th last character on the line?
		BNE BELLDONE				; No, exit out
		TXA					; Yes, reload the character to print
		CMP #$1D				; Is it <CRSR-RIGHT>?
		BEQ BEEP_BEEP				; Yes, do Double BELL
		AND #$7F				; Mask off HI BIT
		CMP #$20				; Is it a control code?
		BCC BELLDONE				; Yes, exit out

;*********************************************************************************************************
;** BEEP / BEEP_BEEP [E654]/[E657]
;** Rings the BELL
;*********************************************************************************************************

BEEP_BEEP	JSR BEEP				; Double BELL
BEEP							; Single BELL

!if SILENT=0 {
		LDY CHIME				; Chime Time FLAG
} ELSE {
		!IF CRUNCH=0 { NOP }			; To keep code aligned
		RTS
}

!IF ESCCODES=1 {
		LDA BELLMODE				; Flag to Enable BELL
		BPL BELLENABLED				; Enabled, so do it
		RTS
}
BELLENABLED	BEQ BELLDONE
		LDA #16
		STA VIA_ACR
		LDA #15
		STA VIA_Shift

		LDX #7					; Size of BELL table
BELLOOP1	LDA SOUND_TAB-1,X			; LOOP[
		STA VIA_Timer_2_Lo
		LDA CHIME				; Chime Time

BELLOOP2	DEY					; LOOP[[
		BNE BELLOOP2				; ]] Delay loop
		SEC
		SBC #1
		BNE BELLOOP2				; ]] Delay loop
		DEX
		BNE BELLOOP1				; ] Delay loop
		STX VIA_Shift
		STX VIA_ACR
BELLDONE	RTS

;*********************************************************************************************************
;** INIT_EDITOR  [E683]
;** Initializes the Editor. Clears Clock. Sets IRQ Vector. Sets Keyboard buffer size. Clears TABs.
;** Sets zero-page locations. And finally, chimes the BELL.
;*********************************************************************************************************

INIT_EDITOR	LDA #$7f
		STA VIA_IER				; VIA, Register E - I/O Timers
		LDX #$6d
		LDA #0
INITED1		STA JIFFY_CLOCK,X			; Clear Real-Time Jiffy Clock (approx) 1/60 Sec
		DEX
		BPL INITED1
		LDX #$0A				; 10 bytes to set
INITED2		STA TABS+1,X				; LOOP[   TAB table $03F0
		DEX					;   Next position
		BPL INITED2				; ] Loop back for more
		STA RPTFLG				; Repeat Flag

;		--------------------------------------- Set IRQ Vector - Normally $E455 or $E900 for Execudesk

!IF EXECUDESK=1 {
		LDA #<IRQ_EDESK				; Execudesk IRQ Vector LO
		STA CINV
		LDA #>IRQ_EDESK				; Execudesk IRQ Vector HI
		STA CINV+1
} ELSE {
		LDA #<IRQ_NORMAL			; Normal IRQ Vector LO
		STA CINV
		LDA #>IRQ_NORMAL			; Normal IRQ Vector HI
		STA CINV+1
}
;		--------------- Continue

		LDA #$03				; 3=Screen
		STA DFLTO  				; Set Default Output (CMD) to Screen
		LDA #$0F
		STA PIA1_Port_A 			; Keyboard ROW select [$E810]
		ASL
		STA VIA_Port_B				; VIA Register 0 (flags) [$E840]
		STA VIA_DDR_B				;
		STX PIA2_Port_B				;
		STX VIA_Timer_1_Hi			;

		LDA #$3D
		STA PIA1_Cont_B				; PIA#1 Register 13 (Retrace flag and interrupt) [$E813]
		BIT PIA1_Port_B 			; Keyboard COL read

		LDA #$3C
		STA PIA2_Cont_A
		STA PIA2_Cont_B
		STA PIA1_Cont_A
		STX PIA2_Port_B

		LDA #$0C
		STA VIA_PCR 				; VIA Register C (cb2) [$E84C]
		STA BLNCT  				; Timer: Countdown to Toggle Cursor
		STA Blink  				; Cursor Blink enable: 0 = Flash Cursor

		LDA #$09
		STA XMAX  				; Max keyboard buffer size (40 col)

		LDA #$10
		STA CHIME 				; Chime Time 0=off (40col)
		STA DELAY				; Repeat key countdown (40col)
		STA KOUNT 				; Delay between repeats (40col)

!IF AUTORUN=1 {	JSR AUTOSTART }				; Do Autostart Prep

		RTS

;************** Check for screen scrolling [$E6EA]

ESCAPE_W						; Esc-w Scroll Down
WINDOW_SCROLL_DOWN
		LDX CursorRow  				; Get Current Cursor Physical Line Number
		INX					; Next line
		CPX #$18				; Will it be the last line on the screen (24)?
		BEQ CLEAR_SCREEN_LINE 			; Yes, Clear a screen line and move cursor to start of line
		BCC SCROLL_DOWN				; No it's less, Scroll screen lines DOWN
		JMP SCROLL_UP				; No it's more, Scroll screen up

;*********************************************************************************************************
;** SCROLL_DOWN  [$E6F6]
;** Scrolls the current screen DOWN. 
;** Used to INSERT a blank line. Scrolls all lines from bottom of screen up to current line
;** stored in 'CursorRow'.  Adjusts ALL Line Links.
;*********************************************************************************************************

SCROLL_DOWN	LDX #$17				; Start at bottom of the screen (ROW 24 minus 1)
SD_LOOP1 	LDA LineLinkTable+1,X			; LOOP[  Get NEXT line's HI byte from Line Link table
		ORA #$80				;   Make sure HI bit is set
		STA SAL+1				;   Store it to destination screen pointer
		LDY LineLinkTable,X			;   Get CURRENT line's HI byte from Line Link Table
		BMI SD_SKIP				;   Is HI bit SET? Yes, skip ahead
		AND #$7F				;   No, CLEAR HI bit
SD_SKIP		STA LineLinkTable+1,X			;   Store it back to Line link table
		TYA
		ORA #$80				;   SET HI bit
		STA ScrPtr+1				;   Store to screen line SOURCE pointer
		LDY #$27				;   40 characters per line minus 1 (0-39)
		LDA Line_Addr_Lo+1,X			;   Get screen's LO byte from Screen line address table
		STA SAL    				;   Store it to DESTINATION screen pointer
		LDA Line_Addr_Lo,X			;   Get Previous lines LO byte from Screen line address table
		STA ScrPtr    				;   Store it to the SOURCE pointer

;		--------------------------------------- Copy the line

SD_LOOP2	LDA (ScrPtr),Y 				;   LOOP[[  Read character from screen
		STA (SAL),Y				;     Write to new destination
		DEY					;     Next character
		BPL SD_LOOP2				;   ]] Loop back for more
		DEX					;   Next line (above)
		CPX CursorRow   			;   Current Cursor Physical Line Number
		BNE SD_LOOP1				; ] Loop back for more
		INX

;*********************************************************************************************************
;** CLEAR_SCREEN_LINE  [$E724]
;** Clears one line of the screen. X holds line#. Adjusts Line Link entry for specified line.
;*********************************************************************************************************

CLEAR_SCREEN_LINE
		LDA LineLinkTable,X			; Get current line's Line Link entry
		ORA #$80				; Make sure HI BIT is set
		STA ScrPtr+1				; Store it to the screen pointer
		AND #$7F				; Clear the HI BIT again
		STA LineLinkTable,X			; Store it to the Line Link Table
		LDA Line_Addr_Lo,X			; Get screen line's address LO byte from ROM table
		STA ScrPtr    				; Store it to screen pointer LO
		LDY #$27				; Y=40 columns
		LDA #$20				; <SPACE>

CSL_LOOP	STA (ScrPtr),Y				; LOOP[    Write SPACE to screen
		DEY					;   Next position
		BPL CSL_LOOP				; ] Loop back for more
		JMP CURSOR_LM				; Cursor to start of line

;*********************************************************************************************************
;** Keyboard Decoding Table  [E6D1]
;*********************************************************************************************************

!SOURCE "keyboard.asm"

;*********************************************************************************************************
;** SHIFT RUN/STOP string  [E721]
;*********************************************************************************************************

RUN_STRING	!byte $44,$cc,$22,$2a,$0d		; dL"*<RETURN>
		!byte $52,$55,$4e,$0d			; run<RETURN>

;*********************************************************************************************************
;** Screen Line Address Table [$E798]
;** This codebase has line linking so there is only one screen line table for the LO bytes.
;** High bytes are calculated and put in the Link-link table
;*********************************************************************************************************

!source "screen0v.asm"

;*********************************************************************************************************
;** CRTC Chip Register Setup Tables (2K ROMs) [E7B1]
;*********************************************************************************************************

!SOURCE "crtc-tables.asm"

;*********************************************************************************************************
;** BELL Sound Table  [E7D5]
;*********************************************************************************************************

SOUND_TAB	!byte $0e,$1e,$3e,$7e,$3e,$1e,$0e	; BELL chime values

;*********************************************************************************************************
;*** POWERS OF 2 TABLE  [$E7DC]
; This table is used by the TAB routine.
;*********************************************************************************************************

POWERSOF2       !byte $80,$40,$20,$10,$08,$04,$02,$01	; BIT table

;*********************************************************************************************************
;** VERSION BYTE?
;*********************************************************************************************************

!IF HERTZ=50 {	!byte $29 }				; 901498-01 [edit-4-40-n-50]
!IF HERTZ=60 {	!byte $BB }				; 901499-01 [edit-4-40-n-60]

;*********************************************************************************************************
;** SMALL PATCHES HERE
;*********************************************************************************************************

!IF BACKARROW = 1 { !SOURCE "editbarrow.asm" }	; Patch for Back Arrow toggling of screen mode

;*********************************************************************************************************
;** FILLER
;*********************************************************************************************************
!FILL $e800-*,$aa	; Fill to end of 2K
;#########################################################################################################
;END! DO NOT ADD ANYTHING BELOW THIS LINE!!!!!!!!