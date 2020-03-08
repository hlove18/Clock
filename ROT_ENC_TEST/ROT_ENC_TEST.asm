; CLOCK_0
; 07/09/19
; This program updates all displays and is the barebones structure for the clock

; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

; External interrupt 1
.org 0013h
ENC_A_ISR:
	lcall ENC_A
	reti

INIT:
	
	setb P3.2
	setb P3.3
	; Encoder interrupts
	setb EX1				; enable external interrupt 1 (gets enabled when rotary encoder is used)
	setb IT1					; set external interrupt 1 to be low-level triggered

	setb EA

	mov P1, #00h			; 0

	sjmp MAIN

MAIN:
	sjmp MAIN


ENC_A:
	; push any used SFRs onto the stack to preserve their values
	push acc

	cpl P1.0

	; pop the original SFR values back into their place and restore their values
	pop acc
ret 											; exit

end
