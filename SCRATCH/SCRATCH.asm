; VFD
; HENRY LOVE
; 06/05/19
; This program uses timer 2 to update the vfd.

; ======Registers======
; R0 - used in delay fxn
; R1 - used in VFD ISR

; ======Loops======
; loop0


; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

INIT:

setb P1.1

ljmp MAIN
	
MAIN:
	cpl P1.1
	lcall delay
ljmp MAIN

delay:
	mov R0, #0FFh			; load R0 for 255 counts
	mov R1, #0FFh			; load R1 for 255 counts		

	loop1:
		djnz R1, loop1		; decrement count in R1
	mov R1, #0FFh			; reload R1 in case loop is needed again
	
	djnz R0, loop1			; count R1 down again until R0 counts down
ret

end


