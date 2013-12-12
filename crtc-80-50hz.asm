; PET/CBM EDIT ROM - CRTC Setup Tables
; ================   80 Column x 25 Lines, 50 Hz Line, 20 kHz for internal monitor
; Set to match 901471-04 ROM
;
; These tables are used to program the CRTC chip to set the screen to the proper rows, columns, and timing 

;--------- Text Mode - 80 column, 50 Hz, 20 kHz

CRT_CONFIG_TEXT
           !byte $32,$28,$28,$08,$26,$02,$19,$20
           !byte $00,$09,$00,$00,$10,$00,$00,$00
           !byte $00,$00

;--------- Graphics Mode - 80 column, 50 Hz, 20 kHz

CRT_CONFIG_GRAPHICS
           !byte $32,$28,$28,$08,$30,$00,$19,$25
           !byte $00,$07,$00,$00,$10,$00,$00,$00
           !byte $00,$00
