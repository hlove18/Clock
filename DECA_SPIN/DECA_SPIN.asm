; VFD
; HENRY LOVE
; 06/23/19
; This program uses P0 to spin a decatron.

; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

INIT:

	mov P0, #00h
	lcall LONG_DELAY

	mov R2, #04h

	sjmp MAIN

MAIN:
	
	;loop3:
		setb P0.1
		lcall MED_DELAY
		
		setb P0.2
		lcall MED_DELAY
		
		clr P0.1
		lcall MED_DELAY

		clr P0.2
		lcall MED_DELAY
	;djnz R2, loop3

	;mov R2, #04h

	;setb P0.0
	;lcall MED_DELAY
	;clr P0.0

	sjmp MAIN


SHORT_DELAY:
	;push R0 				; push R0 onto the stack to preserve its value
	mov R0, #0FFh			; load R0 for 255 counts
	loop0:
	djnz R0, loop0
	;pop	R0					; restore value of R0 to value before DELAY was called
ret

MED_DELAY:
	mov R0, #0Fh			; load R0 for 255 counts
	mov R1, #0FFh			; load R1 for 255 counts		

	loop1:
		djnz R1, loop1		; decrement count in R1
	mov R1, #0FFh			; reload R1 in case loop is needed again
	
	djnz R0, loop1			; count R1 down again until R0 counts down
ret

LONG_DELAY:
	mov R0, #0FFh			; load R0 for 255 counts
	mov R1, #0FFh			; load R1 for 255 counts		

	loop2:
		djnz R1, loop2		; decrement count in R1
	mov R1, #0FFh			; reload R1 in case loop is needed again
	
	djnz R0, loop2			; count R1 down again until R0 counts down
ret

end


