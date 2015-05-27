; PET/CBM EDIT ROM - CRTC Register Table Selection
; ================
; Sets the CRTC Table depending on options
; COLUMNS ---- 40 or 80 column hardware
; SOFT40 ----- Software Defined 40-column modes

!if COLUMNS=80 {
		!if REFRESH = 0 { !source "crtc-80-50hz.asm" }
		!if REFRESH = 1 { !source "crtc-80-60hz.asm" }
		!if REFRESH = 2 { !source "crtc-80-pal.asm" }
		!if REFRESH = 3 { !source "crtc-80-ntsc.asm" }
}

!if COLUMNS=40 {
	!if SOFT40=1 {
		!if REFRESH = 0 { !source "crtc-soft40-50hz.asm" }
		!if REFRESH = 1 { !source "crtc-soft40-60hz.asm" }
		!if REFRESH = 2 { !source "crtc-soft40-pal.asm" }
		!if REFRESH = 3 { !source "crtc-soft40-ntsc.asm" }

	} ELSE {
		!if REFRESH = 0 { !source "crtc-40-50hz.asm" }
		!if REFRESH = 1 { !source "crtc-40-60hz.asm" }
		!if REFRESH = 2 { !source "crtc-40-pal.asm" }
		!if REFRESH = 3 { !source "crtc-40-ntsc.asm" }
	}
}