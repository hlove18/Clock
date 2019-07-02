; VFD
; HENRY LOVE
; 06/05/19
; This program uses timer 2 to update the vfd.

; ======Registers======
; R0 - used in delay fxn
; R1 - used in VFD ISR

; ======Loops======
; loop0


; ======Continues======
; cont0
; cont1
; cont2
; cont3
; cont4
; cont5
; cont6
; cont7
; cont8
; cont9
; cont10
; cont11
; cont12


; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

; Timer 2 interrupt
.org 002Bh
;DECA_ISR:
	clr TF2					; clear timer 2 interrupt flag
	lcall UPDATE_DECA
	reti

.org 0003h
DECA_ISR:
	lcall UPDATE_DECA
	reti

.org 100h
INIT:

	; DECA Variables
	.equ DECA_STATE, 20h

	; Bit for direction of decatron
	.equ DECA_FORWARDS?, 21h.0

	.equ SECONDS, 22h
	.equ SECONDS_BUFFER, 23h
	mov SECONDS, #01h
	mov SECONDS_BUFFER, SECONDS
	
	; Initalize the DECATRON
	lcall DECA_INIT

	; External interrupt 0 initialization
	mov IE, #81h		; initalize IE
	setb IT0 			; interrupt 0 set as falling edge triggered

	; ==========================
	; Interrupt initialization
	setb EA 			; enable interrupts

	; Timer 2 interrupt initialization
	setb ET2			; enable timer 2 interrupt
	mov T2CON, #04h		; set timer 2 in auto reload
	; load timer 2 so it fires every 60us:
	mov RCAP2H, #0FFh	; set high byte of timer 2 reload
	mov RCAP2L, #00h	; set low byte of timer 2 reload 
	; ===========================

	sjmp MAIN

MAIN:

	lcall LONG_DELAY
	lcall LONG_DELAY
	lcall LONG_DELAY
	inc SECONDS
	mov R7, SECONDS
	cjne R7, #3Ch, cont19
		mov SECONDS, #01h
	cont19:
	sjmp MAIN


UPDATE_DECA:
	mov R3, DECA_STATE
	
	;jnb P0.0, cont5
	;	clr P0.0 				; "unset" the decatron
	;cont5: 

	djnz R4, cont4
		lcall DECA_TOGGLE
		sjmp cont3				; TRY BOTH WITH AND WITHOUT THIS LINE
	cont4:

	cjne R3, #00h, cont1
		; arc jumps to G1
		jb DECA_FORWARDS?, cont6
			setb P0.1
			clr P0.2
			mov DECA_STATE, #02h
			sjmp cont1
		cont6:
		; Pull G1 low (note inverter between 8051 pin and decatron)
		setb P0.1
		inc DECA_STATE
	cont1:

	cjne R3, #01h, cont2
		; arc jumps to G2
		jb DECA_FORWARDS?, cont7
			setb P0.2
			dec DECA_STATE
			sjmp cont2
		cont7:
		; Pull G2 low (note inverter between 8051 pin and decatron)
		setb P0.2
		; pull G1 high again
		clr P0.1
		inc DECA_STATE
	cont2:

	cjne R3, #02h, cont3
		; arc jumps to Kx
		jb DECA_FORWARDS?, cont8
			clr P0.1
			dec DECA_STATE
			sjmp cont3
		cont8:
		; pull G2 high again
		clr P0.2
		mov DECA_STATE, #00h
	cont3:


	; ==================
	; Display DECA_STATE on nixie
	; mov R5, #80h
	; mov a, DECA_STATE
	; orl a, R5

	; mov P2, a
	; ==================
	
ret

DECA_INIT:
	mov DECA_STATE, #00h   	; initialize the decatron

	mov R4, SECONDS     	; initialize R4
	
	setb P0.0				; reset decatron
	lcall LONG_DELAY
	clr P0.0
	lcall LONG_DELAY

	setb P0.0				; reset decatron
	lcall LONG_DELAY
	clr P0.0
	lcall LONG_DELAY

	setb P0.0				; reset decatron
	lcall LONG_DELAY
	clr P0.0
	lcall LONG_DELAY

	clr P0.1
	clr P0.2

	setb DECA_FORWARDS? 	; set the direction of the decatron
ret

DECA_TOGGLE:
	cpl DECA_FORWARDS? 		; toggle the decatron direction

	mov a, SECONDS   		; move SECONDS into the accumulator
	cjne a, #01h, cont12	; if SECONDS = 1, then no need to toggle, skip to the end, otherwise, continue
		mov R4, SECONDS 	; reload R4
		sjmp cont14      	; jump to the very end
	cont12:

		; See if seconds is greater than or less than (or equal to) 30
		clr c 				; clear the carry bit
		mov a, #1Eh			; move 30 into the accumulator
		subb a, SECONDS		; perform 30-SECONDS.  if SECONDS is greater than 30, the carry flag (c) will be set
	
		jb DECA_FORWARDS?, cont10
			; if going from backwards to forwards

			jnc cont16 	; if the carry flag is set, SECONDS > 30
			; else if seconds are greater than 30:
			clr c 				; clear the carry flag
			mov a, #3Ch			; move 60 into the accumulator
			subb a, SECONDS		; perform 60-SECONDS.
			mov SECONDS_BUFFER, a


			cont16:
				; if seconds are less than or equal to 30:
				mov R4, SECONDS_BUFFER 					; reload R4 with SECONDS_BUFFER

				; update the DECA_STATE
				mov R3, DECA_STATE
				inc R3
				cjne R3, #03h, cont11
					mov R3, #00h
				cont11:
				mov DECA_STATE, R3
				ret
	cont10:
		; if going from forwards to backwards
		jnc cont17 	; if the carry flag is set, SECONDS > 30
			; seconds are greater than 30
			mov R4, SECONDS_BUFFER
			sjmp cont18

		cont17:
		; if seconds are less than or equal to 30:
		mov R4, SECONDS 						; update R4 with seconds
		mov SECONDS_BUFFER, SECONDS 	 		; update the SECONDS_BUFFER with seconds

		cont18:
		; update the DECA_STATE
		mov R3, DECA_STATE
		dec R3
		cjne R3, #0FFh, cont13
			mov R3, #02h
		cont13:
		mov DECA_STATE, R3
	;jnb DECA_FORWARDS?, cont9
		;mov R4, SECONDS 		; reload R4 (R4 holds the "seconds")
	;cont9:
	cont14:
ret

DELAY:
	;push R0 				; push R0 onto the stack to preserve its value
	mov R0, #0FFh			; load R0 for 255 counts
	loop0:
	djnz R0, loop0
	;pop	R0					; restore value of R0 to value before DELAY was called
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


