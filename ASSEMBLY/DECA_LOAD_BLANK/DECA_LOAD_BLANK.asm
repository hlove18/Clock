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

	; Flag for if DECA_RESET has been called
	.equ DECA_RESET_CALLED?, 21h.1
	clr DECA_RESET_CALLED?

	; DECATRON holds the value to be displayed on the decatron, i.e. the number of pins multiplexed.
	; For full illumination, move a value of 30 into DECATRON.
	; A value in DECATRON greater than 0 and up to 30 will display DECATRON wrapped clockwise.
	; A value in DECATRON greater than 30 but less than 60 will display 60-DECATRON wrapped counter-clockwise.
	; To blank the decatron, move a value of 0 into DECATRON.
	; It is not advised to move a value of 60 or above into DECATRON.
	.equ DECATRON, 22h
	.equ DECATRON_BUFFER, 23h

	mov DECATRON, #05h
	mov DECATRON_BUFFER, DECATRON
	
	; MOVED TO INSIDE UPDATE_DECA function because popping R4 caused issue
	; Initalize the DECATRON
	; lcall DECA_RESET

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

	;lcall LONG_DELAY
	lcall LONG_DELAY
	inc DECATRON
	mov R7, DECATRON
	cjne R7, #3Ch, cont19
		mov DECATRON, #00h
	cont19:
	sjmp MAIN


UPDATE_DECA:
	; This function sequentially cycles through any active (as dictated by DECATRON)
	; decatron cathodes to ravel and unravel the appropriate number of seconds.
	; DECA_STATE points to the next cathode (Kx, G1, or G2) that is to be illuminated.
	; DECA_TOGGLE is called when the direction of the cathode swiping is to be flipped (R4 = 0).
	; On a change of direction, the end cathode remains illuminated for the next cycle.
	; DECA_FORWARDS? keeps track of the direction of the cathode swiping.
	; DECATRON_BUFFER ensures the correct direction of raveling/unraveling.

	; R4 stores the count of how many cathodes need to be lit up before switching directions.
	; R3 stores DECA_STATE.

	; push any used SFRs onto the stack to preserve their values
	push 3
	; push 4
	push acc 
	
	jb DECA_RESET_CALLED?, update_deca_cont0	; check if the decatron needs to be initialized
		lcall DECA_RESET 						; call the decatron init function
		setb DECA_RESET_CALLED?					; set DECA_RESET_CALLED? flag
	update_deca_cont0:

	mov R3, DECA_STATE							; move DECA_STATE to R3

	djnz R4, update_deca_cont1 					; decrement R4 by 1, and check if it is zero
		lcall DECA_TOGGLE						; if R4 is zero, toggle the deca (call DECA_TOGGLE)
		sjmp update_deca_cont6 					; exit
	update_deca_cont1:

	cjne R3, #00h, update_deca_cont2 			; if we are in DECA_STATE 0, jump the arc to G1
		jb DECA_FORWARDS?, update_deca_cont3 	; check direction of swiping
			; if swiping counter-clockwise
			setb P0.1 							; pull G1 low (note inverter between 8051 pin and decatron)
			clr P0.2							; pull G2 high (note inverter between 8051 pin and decatron)
			mov DECA_STATE, #02h 				; DECA_STATE: 0 --> 2
			sjmp update_deca_cont6 				; exit
		update_deca_cont3:
		; if swiping clockwise
		setb P0.1 								; pull G1 low (note inverter between 8051 pin and decatron)
		clr P0.3 								; pull Kx high (note inverter between 8051 pin and decatron)
		clr P0.0 								; pull K0 high (note inverter between 8051 pin and decatron)
		inc DECA_STATE 							; DECA_STATE:  0 --> 1
		sjmp update_deca_cont6 					; exit
	update_deca_cont2:

	cjne R3, #01h, update_deca_cont4 			; if we are in DECA_STATE 1, jump the arc to G2
		jb DECA_FORWARDS?, update_deca_cont5 	; check direction of swiping
			; if swiping counter-clockwise
			setb P0.2 							; pull G2 low (note inverter between 8051 pin and decatron)
			clr P0.3 							; pull Kx high (note inverter between 8051 pin and decatron)
			clr P0.0 							; pull K0 high (note inverter between 8051 pin and decatron)
			dec DECA_STATE 						; DECA_STATE:  1 --> 0
			sjmp update_deca_cont6 				; exit
		update_deca_cont5:
		; if swiping clockwise
		setb P0.2 								; pull G2 low (note inverter between 8051 pin and decatron)
		clr P0.1 								; pull G1 high (note inverter between 8051 pin and decatron)
		inc DECA_STATE 							; DECA_STATE:  1 --> 2
		sjmp update_deca_cont6 					; exit
	update_deca_cont4:

	cjne R3, #02h, update_deca_cont6 			; if we are in DECA_STATE 1, jump the arc to Kx
		jb DECA_FORWARDS?, update_deca_cont7 	; check direction of swiping
			; if swiping counter-clockwise
			setb P0.3 							; pull Kx low (note inverter between 8051 pin and decatron)
			setb P0.0 							; pull K0 low (note inverter between 8051 pin and decatron)
			clr P0.1 							; pull G1 high (note inverter between 8051 pin and decatron)
			dec DECA_STATE 						; DECA_STATE:  2 --> 1
			sjmp update_deca_cont6 				; exit
		update_deca_cont7:
		; if swiping clockwise
		setb P0.3 								; pull Kx low (note inverter between 8051 pin and decatron)
		setb P0.0 								; pull K0 low (note inverter between 8051 pin and decatron)
		clr P0.2 								; pull G2 high (note inverter between 8051 pin and decatron)
		mov DECA_STATE, #00h 					; DECA_STATE:  2 --> 0
		sjmp update_deca_cont6 					; exit
	update_deca_cont6:

	; pop the original SFR values back into their place and restore their values
	pop acc
	; pop 4
	pop 3
	
ret


DECA_TOGGLE:
	; This function is called from UPDATE_DECA whenever the swiping direction has to change.
	; If going from forward to backwards, DECA_STATE is decremented by 2 (incremented by 1) (mod 3).
	; If going from backwards to forward, DECA_STATE is incremented by 2 (decremented by 1) (mod 3).
	; DECA_FORWARDS? is a bit that keeps track of swiping direction.
	; DECA_FORWARDS? = 1 when swiping is clockwise, = 0 when swiping is counter-clockwise.
	; DECATRON_BUFFER is loaded with the latest DECATRON count when swiping in the appropriate direction.
	; This prevents erratic raveling/unraveling patterns.

	; R4 stores the count of how many cathodes need to be lit up before switching directions.
	; R3 stores DECA_STATE.

	; No need to push SFRs onto the stack because this function is called only from UPDATE_DECA, which
	; does the pushing/popping.


	cpl DECA_FORWARDS? 							; toggle the swiping direction

	mov a, DECATRON   							; move DECATRON into the accumulator
	cjne a, #00h, deca_toggle_cont8				; if DECATRON = 0, then no need to toggle, blank the decatron and skip to the end, otherwise, continue
		clr P0.4								; turn off the decatron
		clr P0.0								; turn off K0
		clr P0.1								; turn off G1
		clr P0.2								; turn off G2
		clr P0.3								; turn off Kx
		sjmp deca_toggle_cont1 					; exit (NOTE: "ret" DOES NOT work for some reason...)
	deca_toggle_cont8:

	mov a, DECATRON   							; move DECATRON into the accumulator
	cjne a, #01h, deca_toggle_cont0				; if DECATRON = 1, then no need to toggle, skip to the end, otherwise, continue
		;mov R4, DECATRON 						; reload R4
		lcall DECA_RESET 						; reset the decatron (light up K0)
		sjmp deca_toggle_cont1 					; exit (NOTE: "ret" DOES NOT work for some reason...)
	deca_toggle_cont0:

	; see if DECATRON is greater than or less than (or equal to) 30
	clr c 										; clear the carry bit
	mov a, #1Eh									; move 30 into the accumulator
	subb a, DECATRON							; perform 30-DECATRON.  if DECATRON is greater than 30, the carry flag (c) will be set

	jb DECA_FORWARDS?, deca_toggle_cont2
		; if going from forwards to backwards
		jnc deca_toggle_cont3 					; if the carry flag is set, DECATRON > 30
			; if seconds are greater than 30:
			clr c 								; clear the carry flag
			mov a, #3Ch							; move 60 into the accumulator
			subb a, DECATRON					; perform 60-DECATRON.
			mov DECATRON_BUFFER, a 				; move the result into DECATRON_BUFFER
		deca_toggle_cont3:
		; if seconds are less than or equal to 30:
		mov R4, DECATRON_BUFFER 				; reload R4 with DECATRON_BUFFER  (this prevents erratic raveling)

		; update the DECA_STATE
		mov R3, DECA_STATE 						; move DECA_STATE into R3
		inc R3 									; increment R3 (same as decrementing twice after mod 3)
		cjne R3, #03h, deca_toggle_cont4 		; check if DECA_STATE needs to roll over from 3 to 0
			mov R3, #00h 						; if DECA_STATE = 3, set it to 0
		deca_toggle_cont4:
		mov DECA_STATE, R3 						; update DECA_STATE
		sjmp deca_toggle_cont1 					; exit ("ret" did work here, but changed to sjmp in case of monkey business...)

	deca_toggle_cont2:
	; if going from backwards to forwards
	jnc deca_toggle_cont5 						; if the carry flag is set, DECATRON > 30
		; if seconds are greater than 30
		mov R4, DECATRON_BUFFER 				; move DECATRON_BUFFER into R4 (this prevents erratic unraveling)
		sjmp deca_toggle_cont6 					; jump to update DECA_STATE

	deca_toggle_cont5:
	; if seconds are less than or equal to 30:
	mov R4, DECATRON 							; move DECATRON into R4
	mov DECATRON_BUFFER, DECATRON 				; update the DECATRON_BUFFER with DECATRON

	deca_toggle_cont6:
	; update the DECA_STATE
	mov R3, DECA_STATE 							; move DECA_STATE into R3
	dec R3 										; decrement R3 (same as incrementing twice after mod 3)
	cjne R3, #0FFh, deca_toggle_cont7 			; check if DECA_STATE needs to wrap around from 255 to 2
		mov R3, #02h 							; if DECA_STATE = 255, set it to 2
	deca_toggle_cont7:

	mov DECA_STATE, R3 							; update DECA_STATE

	deca_toggle_cont1:

ret 											; exit


DECA_RESET:
	mov DECA_STATE, #00h   	; initialize the decatron

	mov R4, DECATRON     	; initialize R4

	setb P0.0 				; turn on K0
	clr P0.1				; turn off G1
	clr P0.2 				; turn off G2
	clr P0.3 				; turn on Kx

	setb P0.4				; turn on the decatron

	setb DECA_FORWARDS? 	; set the direction of the decatron
ret



DELAY:
	;push R0 									; push R0 onto the stack to preserve its value
	mov R0, #0FFh								; load R0 for 255 counts
	loop0:
	djnz R0, loop0
	;pop	R0									; restore value of R0 to value before DELAY was called
ret



LONG_DELAY:
	mov R0, #0FFh								; load R0 for 255 counts
	mov R1, #0FFh								; load R1 for 255 counts		

	loop2:
		djnz R1, loop2							; decrement count in R1
	mov R1, #0FFh								; reload R1 in case loop is needed again
	
	djnz R0, loop2								; count R1 down again until R0 counts down
ret

end


