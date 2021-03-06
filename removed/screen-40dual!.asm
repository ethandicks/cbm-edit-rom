; PET/CBM EDIT ROM - ColourPET/dual - Secondary Screen RAM Address Table - 40 Column screen
; ================ ****** ADJUSTED FOR SHIFT!!!!!!!!!!!!!!!!!!!!!!!!!
;
; These tables are used to calculate the starting address of each line on the screen.
; Tables have been offset by 1 to adjust for hardware shift problem with current design.
; Addresses are for ColourPET hardware Ver 1 with colour ram at $8400

;--------- LO Bytes Table

Line_Addr_Lo2
	!byte $01,$29,$51,$79,$a1,$c9,$f1,$19
	!byte $41,$69,$91,$b9,$e1,$09,$31,$59
	!byte $81,$a9,$d1,$f9,$21,$49,$71,$99
	!byte $c1

;---------- HI Bytes Table

Line_Addr_Hi2
	!byte $84,$84,$84,$84,$84,$84,$84,$85
	!byte $85,$85,$85,$85,$85,$86,$86,$86
	!byte $86,$86,$86,$86,$87,$87,$87,$87
	!byte $87
