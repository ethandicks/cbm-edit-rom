; PET/CBM EDIT ROM - C64/VIC Keyboard scanning routines
; ================   Provided by Edilbert Kirk
;
; TODO: These routines need to be adapted for PET
; NOTE: C64 tables were removed in favour of VIC tables
;--------------------------------------------------------------

; **********************
; VIC-20 VIA2 (MOS 6522)
; **********************

VIA2_DATB  = $9120   ; VIA 2 DRB, keyboard column drive
VIA2_DATA  = $9121   ; VIA 2 DRA, keyboard row port
                     ; Vic 20 keyboard matrix layout
                     ;       c7   c6   c5   c4   c3   c2   c1   c0
                     ;   +------------------------------------------------
                     ; r7|   F7   F5   F3   F1   DN  RGT  RET  DEL
                     ; r6|    /   UP    =  RSH HOME    ;    *    £
                     ; r5|    ,    @    :    .    -    L    P    +
                     ; r4|    0    O    K    M    N    J    I    9
                     ; r3|    8    U    H    B    V    G    Y    7
                     ; r2|    6    T    F    C    X    D    R    5
                     ; r1|    4    E    S    Z  LSH    A    W    3
                     ; r0|    2    Q  CBM   SP  RUN  CTL  LFT    1
VIA2_DATN  = $912F   ; VIA 2 DRA, keyboard row, no handshake

; register names for keyboard driver

KEYB_COL   = VIA2_DATB
KEYB_ROW   = VIA2_DATA
KEYB_ROWN  = VIA2_DATN

; key coordinates

CTRL_COL = %11111011 ; $fb = col 2
CTRL_ROW = %11111110 ; $fe = row 0

STND_COL = %11110111 ; $7f = col 3

STKEY  = $91         ; keyboard row, bx = 0 = key down
NDX    = $C6         ; keyboard buffer length/index
; The keyscan interrupt routine uses this location to indicate which key
; is currently being pressed. The value here is then used as an index
; into the appropriate keyboard table to determine which character to
; print when a key is struck.

; The correspondence between the key pressed and the number stored here
; is as follows:

; $00   1      $10   unused $20   [SPC]  $30   Q
; $01   3      $11   A      $21   Z      $31   E
; $02   5      $12   D      $22   C      $32   T
; $03   7      $13   G      $23   B      $33   U
; $04   9      $14   J      $24   M      $34   O
; $05   +      $15   L      $25   .      $35   @
; $06   [PND]  $16   ;      $26   unused $36   [U ARROW]
; $07   [DEL]  $17   [RIGHT]$27   [F1]   $37   [F5]   
; $08   [<-]   $18   [STOP] $28   unused $38   2
; $09   W      $19   unused $29   S      $39   4
; $0A   R      $1A   X      $2A   F      $3A   6
; $0B   Y      $1B   V      $2B   H      $3B   8
; $0C   I      $1C   N      $2C   K      $3C   0
; $0D   P      $1D   ,      $2D   :      $3D   -
; $0E   *      $1E   /      $2E   =      $3E   [HOME]
; $0F   [RET]  $1F   [DOWN] $2F   [F3]   $3F   [F7]

SFDX   = $CB         ; which key

; This pointer points to the address of the keyboard matrix lookup table
; currently being used. Although there are only 64 keys on the keyboard
; matrix, each key can be used to print up to four different characters,
; depending on whether it is struck by itself or in combination with the
; SHIFT, CTRL, or C= keys.

; These tables hold the ASCII value of each of the 64 keys for one of
; these possible combinations of keypresses. When it comes time to print
; the character, the table that is used determines which character is
; printed.

; The addresses of the tables are:

;   KBD_NORMAL          ; unshifted
;   KBD_SHIFTED         ; shifted
;   KBD_CBMKEY          ; commodore
;   KBD_CONTROL         ; control

KBDPTR = $F5         ; keyboard pointer
KBUFFR = $0277       ;   .. to $0280 keyboard buffer
KBMAXL = $0289       ;   maximum keyboard buffer size
KEYRPT = $028A       ;   key repeat. $80 = repeat all, $40 = repeat none,
                     ;   $00 = repeat cursor movement keys, insert/delete
                     ;   key and the space bar
KRPTSP = $028B       ;   repeat speed counter
KRPTDL = $028C       ;   repeat delay counter

; This flag signals which of the SHIFT, CTRL, or C= keys are currently
; being pressed.

; A value of $01 signifies that one of the SHIFT keys is being pressed,
; a $02 shows that the C= key is down, and $04 means that the CTRL key
; is being pressed. If more than one key is held down, these values will
; be added e.g $03 indicates that SHIFT and C= are both held down.

; Pressing the SHIFT and C= keys at the same time will toggle the
; character set that is presently being used between the uppercase/
; graphics set, and the lowercase/uppercase set.

; While this changes the appearance of all of the characters on the
; screen at once it has nothing whatever to do with the keyboard shift
; tables and should not be confused with the printing of SHIFTed
; characters, which affects only one character at a time.

SHFLAG   = $028D     ; keyboard shift/control flag
                     ; bit   key(s) 1 = down
                     ; ---   ---------------
                     ; 7-3   unused
                     ;  2   CTRL
                     ;  1   C=
                     ;  0   SHIFT

; This location, in combination with the one above, is used to debounce
; the special SHIFT keys. This will keep the SHIFT/C= combination from
; changing character sets back and forth during a single pressing of
; both keys.

LSTSHF   = $028E     ; SHIFT/CTRL/C= keypress last pattern

; This location points to the address of the Operating System routine
; which actually determines which keyboard matrix lookup table will be
; used.

; The routine looks at the value of the SHIFT flag at $28D, and based on
; what value it finds there, stores the address of the correct table to
; use at location $F5.

KEYLOG   = $028F     ; keyboard decode logic pointer

; This flag is used to enable or disable the feature which lets you
; switch between the uppercase/graphics and upper/lowercase character
; sets by pressing the SHIFT and Commodore logo keys simultaneously.

MODE     = $0291     ; shift mode switch, $00 = enabled, $80 = locked

; This flag is set to disable the scroll temporarily when there are
; characters waiting in the keyboard buffer, these may include cursor
; movement characters that would eliminate the need for a scroll.

AUTODN   = $0292     ; screen scrolling flag, $00 = enabled

InHa_10
   LDA #0
   STA MODE          ; clear shift mode switch
   STA BLNON         ; clear cursor blink phase
   LDA #<Keyboard_Decoder
   STA KEYLOG
   LDA #>Keyboard_Decoder
   STA KEYLOG+1
   LDA #$0A          ; 10d
   STA KBMAXL        ; set maximum size of keyboard buffer
   STA KRPTDL        ; set repeat delay counter
   LDA #Default_Color
   STA COLOR         ; set current colour code
   LDA #$04          ; speed 4
   STA KRPTSP        ; set repeat speed counter
   LDA #$0C          ; cursor flash timing
   STA BLNCT         ; set cursor timing countdown
   STA BLNSW         ; set cursor enable, $00 = flash cursor



;************
Kernal_SCNKEY
;************
; 1) check if key pressed, if not then exit the routine
; 2) init I/O ports of VIA 2 for keyboard scan and set pointers to
;    decode table 1. clear the character counter
; 3) set one line of port B low and test for a closed key on port A by
;    shifting the byte read from the port. if the carry is clear then a
;    key is closed so save the count which is incremented on each shift.
;    check for shift/stop/cbm keys and flag if closed
; 4) repeat step 3 for the whole matrix
; 5) evaluate the SHIFT/CTRL/C= keys, this may change the decode table
;    selected
; 6) use the key count saved in step 3 as an index into the table
;    selected in step 5
; 7) check for key repeat operation
; 8) save the decoded key to the buffer if first press or repeat

   LDA #0
   STA SHFLAG        ; clear keyboard shift/control/c= flag
   LDY #$40          ; set no key
   STY SFDX          ; save which key
   STA KEYB_COL      ; clear keyboard column
   LDX KEYB_ROW      ; get keyboard row
   CPX #$FF          ; compare with all bits set
   BEQ KeSc_50       ; if no key pressed clear current key and exit

#if C64
   TAY               ; clear key count
#endif
#if VIC
   LDA #$FE
   STA KEYB_COL      ; select keyboard col 0
   LDY #0            ; clear key count
#endif

   LDA #<KBD_NORMAL  ; get decode table low byte
   STA KBDPTR        ; set keyboard pointer low byte
   LDA #>KBD_NORMAL  ; get decode table high byte
   STA KBDPTR+1      ; set keyboard pointer high byte

#if C64
   LDA #$FE
   STA KEYB_COL      ; select keyboard col 0
#endif

KeSc_05
   LDX #8            ; set row count

#if C64
   PHA
KeSc_10
#endif

   LDA KEYB_ROW      ; get VIA/CIA keyboard row
   CMP KEYB_ROW      ; compare with itself

#if C64
   BNE KeSc_10       ; loop if changing
#endif
#if VIC
   BNE KeSc_05      ; loop if changing
#endif

KeSc_15
   LSR A             ; shift row to Cb
   BCS KeSc_30       ; if no key closed on this row go do next row
   PHA               ; save row
   LDA (KBDPTR),Y    ; get character from decode table
   CMP #$05          ; compare with $05, there is no $05 key but the control
   BCS KeSc_20       ; if not shift/control/c=/stop go save key count
   CMP #$03          ; compare with $03, stop
   BEQ KeSc_20       ; if stop go save key count and continue
   ORA SHFLAG        ; OR keyboard shift/control/c= flag
   STA SHFLAG        ; save keyboard shift/control/c= flag
   BPL KeSc_25       ; skip save key, branch always

KeSc_20
   STY SFDX          ; save key count

KeSc_25
   PLA               ; restore row

KeSc_30
   INY               ; increment key count
   CPY #$41          ; compare with max+1
   BCS KeSc_35       ; exit loop if >= max+1
   DEX               ; decrement row count
   BNE KeSc_15       ; loop if more rows to do
   SEC               ; set carry for keyboard column shift

#if C64
   PLA
   ROL A
   STA KEYB_COL   
#endif
#if VIC
   ROL KEYB_COL      ; shift VIA 2 DRB, keyboard column
#endif

   BNE KeSc_05      ; loop for next column, branch always

KeSc_35
#if C64
   PLA
#endif

   JMP (KEYLOG)      ; normally Keyboard_Decoder

; key decoding continues here after the SHIFT/CTRL/C= keys are evaluated

KeSc_40
   LDY SFDX          ; get saved key count
   LDA (KBDPTR),Y    ; get character from decode table
   TAX               ; copy character to X
   CPY LSTX          ; compare key count with last key count
   BEQ KeSc_45       ; if this key = current key, key held, go test repeat
   LDY #$10          ; set repeat delay count
   STY KRPTDL        ; save repeat delay count
   BNE KeSc_65       ; go save key to buffer and exit, branch always

KeSc_45
   AND #$7F          ; clear b7
   BIT KEYRPT        ; test key repeat
   BMI KeSc_55       ; branch if repeat all
   BVS KeSc_70       ; branch if repeat none
   CMP #$7F          ; compare with end marker

KeSc_50
   BEQ KeSc_65       ; if $00/end marker go save key to buffer and exit
   CMP #$14          ; compare with [INSERT]/[DELETE]
   BEQ KeSc_55       ; if [INSERT]/[DELETE] go test for repeat
   CMP #' '          ; compare with [SPACE]
   BEQ KeSc_55       ; if [SPACE] go test for repeat
   CMP #$1D          ; compare with [CURSOR RIGHT]
   BEQ KeSc_55       ; if [CURSOR RIGHT] go test for repeat
   CMP #$11          ; compare with [CURSOR DOWN]
   BNE KeSc_70       ; if not [CURSOR DOWN] just exit

KeSc_55
   LDY KRPTDL        ; get repeat delay counter
   BEQ KeSc_60       ; branch if delay expired
   DEC KRPTDL        ; else decrement repeat delay counter
   BNE KeSc_70       ; branch if delay not expired

KeSc_60
   DEC KRPTSP        ; decrement repeat speed counter
   BNE KeSc_70       ; branch if repeat speed count not expired
   LDY #$04          ; set for 4/60ths of a second
   STY KRPTSP        ; set repeat speed counter
   LDY NDX           ; get keyboard buffer index
   DEY               ; decrement it
   BPL KeSc_70       ; if the buffer isn't empty just exit

KeSc_65
   LDY SFDX          ; get the key count
   STY LSTX          ; save as the current key count
   LDY SHFLAG        ; get keyboard shift/control/c= flag
   STY LSTSHF        ; save as last keyboard shift pattern
   CPX #$FF          ; compare character with table end marker or no key
   BEQ KeSc_70       ; if table end marker or no key just exit
   TXA               ; copy character to A
   LDX NDX           ; get keyboard buffer index
   CPX KBMAXL        ; compare with keyboard buffer size
   BCS KeSc_70       ; if buffer full just exit
   STA KBUFFR,X      ; save character to keyboard buffer
   INX               ; increment index
   STX NDX           ; save keyboard buffer index

KeSc_70
   LDA #STND_COL     ; col 3 on VIC / col 7 on C64
   STA KEYB_COL      ; set VIA/CIA keyboard column
   RTS

; ****************
  Keyboard_Decoder
; ****************

   LDA SHFLAG        ; get keyboard shift/control/c= flag
   CMP #$03          ; compare with [SHIFT][C=]
   BNE KeDe_10       ; branch if not
   CMP LSTSHF        ; compare with last
   BEQ KeSc_70       ; exit if still the same
   LDA MODE          ; get shift mode switch $00 = enabled, $80 = locked
   BMI KeDe_30       ; if locked continue keyboard decode

                     ; switch character ROM
#if C64
   LDA MEM_CONTROL   ; get start of character memory, ROM
   EOR #$02          ; toggle $8000,$8800
   STA MEM_CONTROL   ; set start of character memory, ROM
#endif
#if VIC
   LDA VIC_R5        ; get start of character memory, ROM
   EOR #$02          ; toggle $8000,$8800
   STA VIC_R5        ; set start of character memory, ROM
#endif

#if VIC & JIFFY
   JMP KeSc_40       ; continue keyboard decode
#else
   JMP KeDe_30       ; continue keyboard decode
#endif

KeDe_10
   ASL A             ; convert flag to index 
   CMP #8            ; compare with [CTRL]
   BCC KeDe_20       ; branch if not [CTRL] pressed
   LDA #6            ; [CTRL] : table 3 : index 6

KeDe_20
   TAX               ; copy index to X
   LDA KBD_Decode_Pointer,X
   STA KBDPTR
   LDA KBD_Decode_Pointer+1,X
   STA KBDPTR+1
KeDe_30
   JMP KeSc_40       ; continue keyboard decode

#if VIC & JIFFY
KeDe_60
   LDA #4
   JSR LISTEN
   LDA MEM_CONTROL
   AND #2
   BEQ KeDe_62
   LDA #7

KeDe_62
   ORA #$60
   JSR SECOND
   LDA CSRIDX
   PHA
   LDA TBLX
   PHA
   JMP $edaa

   TAX               ; copy index to X
   LDA KBD_Decode_Pointer,X
   STA KBDPTR
   LDA KBD_Decode_Pointer+1,X
   STA KBDPTR+1
   JMP KeSc_40       ; continue keyboard decode
   
#endif

; ==================
KBD_Decode_Pointer
; ==================

   .word   KBD_NORMAL  ; 0   normal
   .word   KBD_SHIFTED ; 1   shifted
   .word   KBD_CBMKEY  ; 2   commodore
#if VIC & JIFFY
   .word   KBD_COMMCON ; 6   commodore control
#else
   .word   KBD_CONTROL ; 3   control
#endif

#if VIC
   .word   KBD_NORMAL  		; 4   control
   .word   KBD_SHIFTED 		; 5   shift - control
   .word   KBD_COMMCON 		; 6   commodore control
   .word   KBD_CONTROL 		; 7   shift - commdore - control
   .word   Switch_Text_Graphics ; 8   unused
   .word   KBD_COMMCON 		; 9   unused
   .word   KBD_COMMCON 		; a   unused
   .word   KBD_CONTROL 		; b   unused
#endif

;********** Vic 20 keyboard matrix layout
;
;      c7   c6   c5   c4   c3   c2   c1   c0
;   +---------------------------------------
; r7|  F7   F5   F3   F1   DN  RGT  RET  DEL
; r6|   /   UP    =  RSH HOME    ;    *    £
; r5|   ,    @    :    .    -    L    P    +
; r4|   0    O    K    M    N    J    I    9
; r3|   8    U    H    B    V    G    Y    7
; r2|   6    T    F    C    X    D    R    5
; r1|   4    E    S    Z  LSH    A    W    3
; r0|   2    Q  CBM   SP  RUN  CTL  LFT    1
;   +----------------------------------------

; NOTE: I've seen this before, and this shows how messed up things are...
; The ROWS and COLS are reversed and INVERTED. C0 should be R7, C1 should be R6

KBD_NORMAL           			 ; keyboard decode table - unshifted
;
;					  ---- ---- ---- ---- ---- ---- ---- ----
   .byte $31,$33,$35,$37,$39,$2B,$5C,$14 ;   1    3    5    7    9    +    £  DEL
   .byte $5F,$57,$52,$59,$49,$50,$2A,$0D ; LFT    W    R    Y    I    P    *  RET
   .byte $04,$41,$44,$47,$4A,$4C,$3B,$1D ; CTL    A    D    G    J    L    ;  RGT    
   .byte $03,$01,$58,$56,$4E,$2C,$2F,$11 ; RUN  LSH    X    V    N    -  HOM   DN
   .byte $20,$5A,$43,$42,$4D,$2E,$01,$85 ; SPC    Z    C    B    M    .  RSH   F1
   .byte $02,$53,$46,$48,$4B,$3A,$3D,$86 ; CBM    S    F    H    K    :    =   F3
   .byte $51,$45,$54,$55,$4F,$40,$5E,$87 ;   Q    E    T    U    O    @   UP   F5
   .byte $32,$34,$36,$38,$30,$2D,$13,$88 ;   2    4    6    8    0    ,    /   F7
   .byte $FF

KBD_SHIFTED          ; keyboard decode table - shifted

   .byte $21,$23,$25,$27,$29,$DB,$A9,$94
   .byte $5F,$D7,$D2,$D9,$C9,$D0,$C0,$8D
   .byte $04,$C1,$C4,$C7,$CA,$CC,$5D,$9D
   .byte $83,$01,$D8,$D6,$CE,$3C,$3F,$91
   .byte $A0,$DA,$C3,$C2,$CD,$3E,$01,$89
   .byte $02,$D3,$C6,$C8,$CB,$5B,$3D,$8A
   .byte $D1,$C5,$D4,$D5,$CF,$BA,$DE,$8B
   .byte $22,$24,$26,$28,$30,$DD,$93,$8C
   .byte $FF

KBD_CBMKEY           ; keyboard decode table - commodore

   .byte $21,$23,$25,$27,$29,$A6,$A8,$94
   .byte $5F,$B3,$B2,$B7,$A2,$AF,$DF,$8D
   .byte $04,$B0,$AC,$A5,$B5,$B6,$5D,$9D
   .byte $83,$01,$BD,$BE,$AA,$3C,$3F,$91
   .byte $A0,$AD,$BC,$BF,$A7,$3E,$01,$89
   .byte $02,$AE,$BB,$B4,$A1,$5B,$3D,$8A
   .byte $AB,$B1,$A3,$B8,$B9,$A4,$DE,$8B
   .byte $22,$24,$26,$28,$30,$DC,$93,$8C
   .byte $FF

KBD_CONTROL          ; keyboard decode table - control

   .byte   $90,$1C,$9C,$1F,$12,$FF,$FF,$FF
   .byte   $06,$FF,$12,$FF,$FF,$FF,$FF,$FF
   .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
   .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
   .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
   .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
   .byte   $FF,$FF

KBD_COMMCON         ; keyboard decode table - cbm - control

   .byte   $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
   .byte   $FF,$04,$FF,$FF,$FF,$FF,$FF,$E2
   .byte   $9D,$83,$01,$FF,$FF,$FF,$FF,$FF
   .byte   $91,$A0,$FF,$FF,$FF,$FF,$EE,$01
   .byte   $89,$02,$FF,$FF,$FF,$FF,$E1,$FD
   .byte   $8A,$FF,$FF,$FF,$FF,$FF,$B0,$E0
   .byte   $8B,$F2,$F4,$F6,$FF,$F0,$ED,$93
   .byte   $8C,$FF

