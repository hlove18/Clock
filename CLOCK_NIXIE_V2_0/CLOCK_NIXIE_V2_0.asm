; CLOCK_2
; 01/22/2022
; This program updates all displays and is the barebones structure for the clock
;
; To do:
;   x change pins to match new PCB schematic:
;       x P0.5 changes from ALARM_ON_OFF --> REMOTE
;       x P0.6 changes from 12_24_HOUR --> NIX_COLON
;       x P0.7 changes from DEV_SWITCH --> not connected
;       x P1.0 should be VFD_BLANK (check this)
;       x P1.4 changes from NIX_COLON --> ALARM_ON_OFF
;   x set P0.7 high (it's an unused pin)
;   x remove 12_24_HOUR switch functionality (replaced by software setting)
;   - implement any switching for the nixie colons
;   - implement remote input

; !!!!! Switches on the built-in 8052 special function register and interrupt symbol definitions.
; This command must preceed any non-control lines in the code.
$MOD52

.org 0
ljmp INIT

; External interrupt 0
.org 0003h
ENC_A_ISR:
    lcall ENC_A
reti

; Timer 0 interrupt
.org 000Bh
TIMER_0_ISR:
    lcall TIMER_0_SERVICE       ; update the time
reti                            ; exit
    
; External interrupt 1
.org 0013h
ENC_B_ISR:
    lcall ENC_B
reti

; Timer 1 interrupt
.org 001Bh
TIMER_1_ISR:
    lcall TIMER_1_SERVICE       ; update the time
reti                            ; exit

; Serial Port interrupt
.org 0023h
SERIAL_ISR:
    lcall SERIAL_SERVICE        ; receive data
    clr RI                      ; clear receive interrupt flag
reti                            ; exit

; Timer 2 interrupt
.org 002Bh
DISPLAY_ISR:
    clr TF2                     ; clear timer 2 interrupt flag
    lcall UPDATE_DISPLAYS       ; update the displays
reti                            ; exit


.org 100h
INIT:
    ; !!!IMPORTANT!!! The following line moves the stack pointer to use upper 128bytes of data memory which is ONLY indirectly addressable
    ; Note the stack pointer (SP) gets intialized to one bellow where the stack actually begins.  This change prevents the stack from over
    ; writing our stored variables in addresss 20h to 7Fh (our directly addressable space).  This line fixes the bug that would cause the
    ; set time sub state to transition spuriously.
    mov SP, #7Fh            ; move the stack pointer to 7Fh. this is a big brain line of code.

    mov R5, #0Ch            ; move 12 into R5 for displays update (nixie is displayed 1/12 as often as VFD and decatron)

    mov R7, #090h           ; try toggling the flashing less often

    ; ====== Unused Inputs ======
    ; Pull P0.7 HIGH (unused input pin)
    setb P0.7

    ; ====== Remote ======
    ; Pull P0.5 HIGH (input used for REMOTE)
    setb P0.5

    ; ====== Nixie Colons ======
    ; Pull P0.6 HIGH (output for NIXIE_COLON)
    setb P0.6

    ; ====== State Variables ======
    ; Clock State Variable:
    .equ CLOCK_STATE, 7Fh
    .equ NEXT_CLOCK_STATE, 7Bh
    .equ TIMEOUT, 7Ah
    ; .equ TIMEOUT_MINUTES, 77h
    .equ TIMEOUT_LENGTH, 78h

    SHOW_TIME_STATE equ 1
    SET_TIME_STATE equ 2
    SHOW_ALARM_STATE equ 3
    SET_ALARM_STATE equ 4
    GPS_SYNC_STATE equ 5
    SETTINGS_STATE equ 6
    CYCLE_STATE equ 7
    mov NEXT_CLOCK_STATE, #SHOW_TIME_STATE

    mov TIMEOUT_LENGTH, #3Bh            ; (59 dec)

    ; !!!NOTE: THIS IS DIFFERENT THAN YOU WOULD EXPECT: MOV iram_addr1,iram_addr2 MOVES CONTENTS OF iram_addr1 INTO iram_addr2!!!
    ; COULD BE WRONG!!:
    mov CLOCK_STATE, #GPS_SYNC_STATE    ; start in GPS_SYNC_STATE (transition actions called at end of INIT)

    ; Set Time Sub-State Variable:
    .equ SET_TIME_SUB_STATE, 7Dh

    SET_MM_STATE equ 1
    SET_DD_STATE equ 2
    SET_YY_STATE equ 3
    SET_HR_STATE equ 4
    SET_MIN_STATE equ 5
    mov SET_TIME_SUB_STATE, #SET_MM_STATE

    ; Set Alarm Sub-State Variable:
    .equ SET_ALARM_SUB_STATE, 7Ch

    SET_ALARM_HR_STATE equ 1
    SET_ALARM_MIN_STATE equ 2
    mov SET_ALARM_SUB_STATE, #SET_ALARM_HR_STATE

    ; Pull P3.7 HIGH (input used for settings button)
    setb P3.7

    ; ========== Settings Menu Values ===============
    ; Settings Sub-State Variable:
    .equ SETTINGS_SUB_STATE, 6Ch

    SETTINGS_SHOW_DATE_ON_OFF_STATE         equ 1
    SETTINGS_SHOW_SNOOZE_STATE              equ 2
    SETTINGS_SHOW_BEEP_ON_OFF_STATE         equ 3
    SETTINGS_SHOW_12_OR_24_HR_MODE_STATE    equ 4
    SETTINGS_SHOW_RE_SYNC_STATE             equ 5

    SETTINGS_SHOW_TIMEZONE_STATE            equ 6
    SETTINGS_SHOW_AUTO_SYNC_STATE           equ 7

    SETTINGS_SHOW_GPS_SYNC_TIME_STATE       equ 8


    SETTINGS_SET_TIMEZONE_STATE             equ 11
    SETTINGS_SET_SNOOZE_STATE               equ 12
    SETTINGS_SET_GPS_SYNC_HR_STATE          equ 13
    SETTINGS_SET_GPS_SYNC_MIN_STATE         equ 14
    mov SETTINGS_SUB_STATE, #SETTINGS_SHOW_TIMEZONE_STATE


    .equ NUMBER_OF_ACTIVE_SETTINGS, 6Ah
    mov NUMBER_OF_ACTIVE_SETTINGS, #05h         ; assume for now there is no GPS present

    NUMBER_OF_SETTINGS equ 8                    ; total number of settings; update this if adding more or taking out settings

    ; Timezone setting
    TIMEZONE_MAX equ 28                         ; this corresponds to UTC+14
    TIMEZONE_MIN equ 3                          ; this corresponds to UTC-11

    ; Snooze duration
    SNOOZE_DURATION_MAX equ 90
    SNOOZE_DURATION_MIN equ 1

    ; VFD date display
    .equ DATE_ON?, 23h.1        ; corresponds to VFD displaying the date when in SHOW_TIME
    setb DATE_ON?               ; default to displaying the date
    clr P1.0                    ; enable the VFD display

    ; GPS automatic sync time
    ; max/min values for GPS_SYNC_TIME_HOURS
    GPS_SYNC_TIME_HOURS_MAX equ 23
    GPS_SYNC_TIME_HOURS_MIN equ 0
    ; max/min values for GPS_SYNC_TIME_MINUTES
    GPS_SYNC_TIME_MINUTES_MAX equ 59
    GPS_SYNC_TIME_MINUTES_MIN equ 0

    ; GPS auto sync enable
    .equ AUTO_SYNC?, 24h.2
    setb AUTO_SYNC?

    ; 12 or 24 hour mode
    .equ TWLV_HR_MODE?, 23h.2
    clr TWLV_HR_MODE?

    ; beep on/off
    .equ BEEP_ON?, 23h.3
    setb BEEP_ON?

    ; ========== GPS Variables =================
    ; disable the GPS
    clr P1.2
    ; Pull P1.3 HIGH (input used for GPS fix)
    setb P1.3

    ; bits:
    .equ GPS_PRESENT?,  24h.0
    .equ TIMEZONE_SET?, 24h.1

    ; fill in with values
    clr GPS_PRESENT?
    clr TIMEZONE_SET?

    ; GPS Sync Sub-State Variable:
    .equ GPS_SYNC_SUB_STATE, 77h

    GPS_OBTAIN_FIX_STATE equ 1
    GPS_OBTAIN_DATA_STATE equ 2
    GPS_SET_TIMEZONE_STATE equ 3
    mov GPS_SYNC_SUB_STATE, #GPS_OBTAIN_FIX_STATE

    ; GPS Obtain Data Sub-State Variable:
    .equ GPS_OBTAIN_DATA_SUB_STATE, 76h
    .equ GPS_OBTAIN_DATA_NEXT_SUB_STATE, 75h

    GPS_WAIT equ 1
    GPS_WAIT_FOR_DOLLAR equ 2
    GPS_WAIT_FOR_G equ 3
    GPS_WAIT_FOR_P equ 4
    GPS_WAIT_FOR_R equ 5
    GPS_WAIT_FOR_M equ 6
    GPS_WAIT_FOR_C equ 7
    GPS_WAIT_FOR_TIME equ 8
    GPS_WAIT_FOR_A equ 9
    GPS_WAIT_FOR_LATITUDE equ 10
    GPS_WAIT_FOR_LONGITUDE equ 11
    GPS_WAIT_FOR_DATE equ 12
    GPS_WAIT_FOR_STAR equ 13
    GPS_WAIT_FOR_CHECKSUM equ 14
    mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_DOLLAR
    mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_G

    .equ GPS_SYNC_TIME_HOURS, 6Dh
    .equ GPS_SYNC_TIME_MINUTES, 6Eh
    .equ GPS_FIX_HIGH_TIMEOUT, 6Fh
    .equ TIMEZONE, 70h                          ; TIMEZONE variable holds the offset from UTC minus 14 hours.
                                                ; Therefore, UTC is TIMEZONE = #0Eh.  US east coast is either UTC-4 or UTC-5 hours depending on
                                                ; daylights savings, so TIMEZONE will normally be #0Ah (UTC-4) or #09h (UTC-5).
                                                ; This offset is such that a UTC+14 offset can be unapplied easily by UNAPPLY_TIMEZONE_TO_GET_UTC.
    .equ GPS_POINTER, 71h
    .equ GPS_FIX_LPF, 72h
    .equ CALCULATED_GPS_CHECKSUM, 73h
    .equ GPS_WAIT_TIME, 74h
    mov GPS_POINTER, #08h                       ; load GPS_POINTER with memory address of RECEIVED_GPS_HRS_TENS
    mov TIMEZONE, #0Eh                          ; default to UTC
    mov GPS_FIX_HIGH_TIMEOUT, #020h             ; load 32 (dec) into GPS_FIX_HIGH_TIMEOUT
    mov GPS_SYNC_TIME_HOURS, #00h               ; default GPS sync time to 12:01am
    mov GPS_SYNC_TIME_MINUTES, #01h             ; default GPS sync time to 12:01am

    ; ====== Received GPS Variables ======
    ; !!!!!!! IMPORTANT: DO NOT MOVE THESE MEMORY LOCATIONS (pointers are used to update)
    ; Time
    .equ RECEIVED_GPS_HRS_TENS,                 08h         ; data stored here is in hex!
    .equ RECEIVED_GPS_HRS_ONES,                 09h         ; data stored here is in hex!
    .equ RECEIVED_GPS_MINS_TENS,                0Ah         ; data stored here is in hex!
    .equ RECEIVED_GPS_MINS_ONES,                0Bh         ; data stored here is in hex!
    .equ RECEIVED_GPS_SECS_TENS,                0Ch         ; data stored here is in hex!
    .equ RECEIVED_GPS_SECS_ONES,                0Dh         ; data stored here is in hex!

    ; Note:  not saving latitude and longitude data
    ; ; Latitude
    ; .equ RECEIVED_GPS_LAT_DEGS_TENS,          XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_DEGS_ONES,          XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_MINS_TENS,          XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_MINS_ONES,          XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_MINS_TENTHS,        XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_MINS_HNDRTHS,       XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_MINS_THSNDTHS,      XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_MINS_TEN_THSNDTHS,  XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LAT_DIRECTION,          XXh         ; data stored here is in ASCII! (either "N" for North, or "S" for South)

    ; ; Longitude
    ; .equ RECEIVED_GPS_LONG_DEGS_HNDRS,        XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_DEGS_TENS,         XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_DEGS_ONES,         XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_MINS_TENS,         XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_MINS_ONES,         XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_MINS_TENTHS,       XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_MINS_HNDRTHS,      XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_MINS_THSNDTHS,     XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_MINS_TEN_THSNDTHS, XXh         ; data stored here is in hex!
    ; .equ RECEIVED_GPS_LONG_DIRECTION,         XXh         ; data stored here is in ASCII! (either "E" for East, or "W" for West)

    ; Date
    .equ RECEIVED_GPS_DAY_TENS,                 0Eh         ; data stored here is in hex!
    .equ RECEIVED_GPS_DAY_ONES,                 0Fh         ; data stored here is in hex!
    .equ RECEIVED_GPS_MONTH_TENS,               10h         ; data stored here is in hex!
    .equ RECEIVED_GPS_MONTH_ONES,               11h         ; data stored here is in hex!
    .equ RECEIVED_GPS_YEAR_TENS,                12h         ; data stored here is in hex!
    .equ RECEIVED_GPS_YEAR_ONES,                13h         ; data stored here is in hex!

    ; Checksum 
    .equ RECEIVED_GPS_CHECKSUM,                 14h         ; data stored here is in hex!

    ; =============================

    ; Alarm State Variable:
    .equ ALARM_STATE, 7Eh

    ; Alarm State Space:
    ALARM_ENABLED_STATE equ 1
    ALARM_DISABLED_STATE equ 2
    ALARM_FIRING_STATE equ 3
    ALARM_SNOOZING_STATE equ 4

    ; Check alarm on/off switch to intitialize state variable
    jnb P1.4, init_cont0
        mov ALARM_STATE, #ALARM_ENABLED_STATE           ; alarm is enabled if P1.4 is high
        setb P1.6                                       ; turn on alarm light
        sjmp init_cont1

    init_cont0:
        mov ALARM_STATE, #ALARM_DISABLED_STATE          ; alarm is disabled if P1.4 is low
        clr P1.6                                        ; turn off alarm light
    init_cont1:

    ; Decatron State Variable:
    .equ DECA_STATE, 79h

    DECA_COUNTING_SECONDS_STATE equ 1
    DECA_FAST_STATE equ 2
    DECA_SCROLLING_STATE equ 3
    DECA_RADAR_STATE equ 4
    DECA_COUNTDOWN_STATE equ 5
    DECA_FLASHING_STATE equ 6
    DECA_FILL_UP_STATE equ 7
    lcall ENTER_DECA_COUNTING_SECONDS_STATE
    ; mov DECA_STATE, #DECA_COUNTING_SECONDS_STATE

    ; =============================

    ; ====== VFD Variables ======
    ; bytes:
    .equ GRID_EN_1, 30h
    .equ GRID_EN_2, 31h
    .equ GRID_INDX, 32h
    .equ GRID9,     33h
    .equ GRID8,     34h
    .equ GRID7,     35h
    .equ GRID6,     36h
    .equ GRID5,     37h
    .equ GRID4,     38h
    .equ GRID3,     39h
    .equ GRID2,     3Ah
    .equ GRID1,     3Bh
    ; Fill in with values
    mov GRID9, #0FFh
    mov GRID8, #00h
    mov GRID7, #01h
    mov GRID6, #0Ah
    mov GRID5, #03h
    mov GRID4, #01h
    mov GRID3, #0Ah
    mov GRID2, #02h
    mov GRID1, #09h
    ; Initialize the VFD
    lcall VFD_RESET
    ; ===========================

    ; ====== Nixie Variables ======
    ; bytes:
    .equ NIX_EN,    3Ch
    .equ NIX_INDX,  3Dh
    .equ NIX4,      3Eh
    .equ NIX3,      3Fh
    .equ NIX2,      40h
    .equ NIX1,      41h
    ; Fill in with values
    mov NIX4, #00h
    mov NIX3, #00h
    mov NIX2, #00h
    mov NIX1, #00h
    ; Initialize the nixies
    lcall NIX_RESET

    ; Stores the number to be shown when in CYCLE_STATE to prevent cathode poisoning
    .equ CYCLE_NUMBER, 63h
    mov CYCLE_NUMBER, #00h

    ; =============================

    ; ====== Decatron Variables ======
    ; bytes:
    .equ DECA_LOAD_STATE,       42h
    .equ DECATRON,          43h
    .equ DECATRON_BUFFER,   44h
    .equ TIMER_0_POST_SCALER, 5Fh
    .equ TIMER_0_POST_SCALER_RELOAD, 60h
    ; bits:
    .equ DECA_FORWARDS?,        20h.0
    .equ DECA_RESET_CALLED?,    20h.1
    .equ DECA_IN_TRANSITION?,   20h.2
    .equ TO_COUNTDOWN?,         20h.3
    .equ TO_SCROLLING?,         20h.4

    ; Fill in with values
    mov DECATRON, #00h
    mov DECATRON_BUFFER, DECATRON
    mov TIMER_0_POST_SCALER, #01h
    clr DECA_RESET_CALLED?
    clr DECA_IN_TRANSITION?
    clr TO_COUNTDOWN?
    clr TO_SCROLLING?
    ; ===============================

    ; ====== Rotary Encoder Variables ======
    ; A_FLAG: this bit is the A flag, to prevent one CW/CCW turn as registering as more than one turn
    ; B_FLAG: this bit is the B flag, to prevent on CCW/CW turn as registering as more than on turn
    ; BUTTON_FLAG: this bit is the button flag, to prevent going through states "too fast"
    ; bytes:
    .equ UPPER_BOUND,       55h     ; this register holds the max value of whichever value is currently getting set
                                    ; (e.g. decimal 12 for month)
    .equ LOWER_BOUND,       56h     ; this register holds the min value of whichever value is currently getting set
                                    ; (e.g. decimal 1 for month)

    ; bits:
    .equ A_FLAG,               21h.0
    .equ B_FLAG,               21h.1
    .equ BUTTON_FLAG,          21h.2
    .equ INC_LEAP_YEAR?,       21h.3
    .equ ROT_FLAG,             21h.4
    .equ TRANSITION_STATE?,    22h.0
    .equ SETTINGS_BUTTON_FLAG, 22h.1
    .equ REMOTE_BUTTON_FLAG,   22h.2

    ; Fill in with values
    clr A_FLAG
    clr B_FLAG
    clr BUTTON_FLAG
    clr INC_LEAP_YEAR?
    clr ROT_FLAG
    clr TRANSITION_STATE?
    clr SETTINGS_BUTTON_FLAG
    clr REMOTE_BUTTON_FLAG

    ; Setup for rotary enocder pull-up resistors
    setb P3.2                       ; Set P3.2 high to use internal pull-up resistor
    setb P3.3                       ; Set P3.3 high to use internal pull-up resistor
    setb P3.6                       ; Set P3.6 high to use internal pull-up resistor
    ; ======================================

    ; ====== Time Variables ======
    .equ HOURS,   45h
    .equ MINUTES, 46h
    .equ SECONDS, 47h

    .equ HR_TENS,  48h
    .equ HR_ONES,  49h
    .equ MIN_TENS, 4Ah
    .equ MIN_ONES, 4Bh

    mov HOURS,      #00h
    mov MINUTES,    #00h
    mov SECONDS,    #00h

    .equ SET_TIMEZONE_HOURS, 6Bh
    ; ============================

    ; ====== Date Variables ======
    .equ MONTH,     4Ch
    .equ DAY,       4Dh
    .equ YEAR,      4Eh

    .equ MM_TENS,   4Fh
    .equ MM_ONES,   50h

    .equ DD_TENS,   51h
    .equ DD_ONES,   52h

    .equ YY_TENS,   53h
    .equ YY_ONES,   54h

    ; Initialize date as 01-31-20
    mov MONTH,  #01h
    mov DAY,    #1Fh
    mov YEAR,   #14h
    ; ============================

    ; ====== Display Variables ======
    .equ VFD_FLASH_MASK,    57h
    .equ NIX_FLASH_MASK,    58h

    .equ VFD_MASK,          59h
    .equ NIX_MASK,          5Ah

    ; Initialize flash masks
    mov VFD_FLASH_MASK, 00h     ;FIX?? does this need "#"
    mov NIX_FLASH_MASK, 0Fh     ;FIX?? does this need "#"

    mov VFD_MASK, #0FFh
    mov NIX_MASK, #0FFh

    ; bits:
    .equ VFD_PAUSED?, 23h.0

    ; Fill in with values
    clr VFD_PAUSED?
    ; ============================

    ; ====== Alarm Variables ======
    .equ ALARM_HOURS,       5Bh
    .equ ALARM_MINUTES,     5Ch
    ; .equ SNOOZE_MINUTES,  5Dh
    .equ SNOOZE_DURATION,   5Eh
    .equ SNOOZE_COUNT_PER_DECA_PIN, 61h
    .equ SNOOZE_COUNT_PER_DECA_PIN_RELOAD, 62h

    ; Initialize alarm
    mov ALARM_HOURS, #00h
    mov ALARM_MINUTES, #05h
    ; mov SNOOZE_MINUTES, #05h
    mov SNOOZE_DURATION, #01h   ; snooze duration in minutes

    ; The following block initializes two variables to take care of the DECA_COUNTDOWN_STATE behavior.
    ; Since the decatron has 30 pins, to count down from 30 to 0 during ALARM_SNOOZING_STATE, each pin will stay illuminated (in
    ; seconds) for 2 times the SNOOZE_DURATION (in minutes).
    ; E.g., if SNOOZE_DURATION is 1 minute, each of the decatron pins will stay lit for 2 seconds.
    ; Another e.g., if SNOOZE_DURATION is 10 minutes, each of the decatron pins will stay lit for 20 seconds.
    ; SNOOZE_COUNT_PER_DECA_PIN_RELOAD contains this number of seconds, calculated as twice SNOOZE_DURATION.
    ; SNOOZE_COUNT_PER_DECA_PIN initially starts with this reload value, but will be decremented in the TIMER_0_SERVICE with each
    ; second, then reloaded with SNOOZE_COUNT_PER_DECA_PIN_RELOAD when it reaches 0.
    mov a, SNOOZE_DURATION
    add a, SNOOZE_DURATION
    mov SNOOZE_COUNT_PER_DECA_PIN_RELOAD, a
    mov SNOOZE_COUNT_PER_DECA_PIN, SNOOZE_COUNT_PER_DECA_PIN_RELOAD
    ; ============================

    ; Clear the carry flag
    clr c

    ; IE (interrupt enable) register
    ; _____________________________________________
    ; | EA | - | ET2 | ES | ET1 | EX1 | ET0 | EX0 |
    ; |____|___|_____|____|_____|_____|_____|_____|
    ; EA (IE.7): interrupt enable bit (must be set to use interrupts)
    ; IE.6: reserved
    ; ET2 (IE.5): timer 2 overflow interrupt enable bit (only 8052)
    ; ES (IE.4): serial port interrupt enable bit
    ; ET1 (IE.3): timer 1 overflow interrupt enable bit
    ; EX1 (IE.2): external interrupt 1 enable bit
    ; ET0 (IE.1): timer 0 overflow interrupt enable bit
    ; EX0 (IE.0): external interrupt 0 enable bit

    ; Interrupt initialization
    setb EA                 ; enable interrupts
    setb ET0                ; enable timer 0 overflow interrupt
    clr EX0                 ; disable external interrupt 0 (gets enabled when rotary encoder is used)
    setb IT0                ; set external interrupt 0 to be triggered by falling edge
    clr EX1                 ; disable external interrupt 1 (gets enabled when rotary encoder is used)
    setb IT1                ; set external interrupt 1 to be triggered by falling edge

    ; Timer 2 interrupt initialization (for display interrupt)
    setb ET2                ; enable timer 2 interrupt
    mov T2CON, #04h         ; set timer 2 in auto reload
    mov RCAP2H, #0FFh       ; set high byte of timer 2 reload
    mov RCAP2L, #00h        ; set low byte of timer 2 reload

    ; Timer 0 (for seconds interrupt) & 1 (for beep) interrupt initialization
    mov TMOD, #16h          ; set timer0 as a counter for the seconds (0000 0110 bin = 06 hex)
                            ; set timer1 as a timer for the beep duration (0001 0000 bin = 10 hex)
    mov TL0, #0C4h          ; initialize TL0 (#C4h for 60Hz, #CEh for 50Hz)
    mov TH0, #0C4h          ; initialize TH0 (#C4h for 60Hz, #CEh for 50Hz) - reload value
    mov TL1, #00h           ; initialize TL1 for max count (16 bits)
    mov TH1, #00h           ; initialize TH1 for max count (16 bits)
    setb TR0                ; start timer 0
    clr ET1                 ; disable timer 1 overflow interrupt
    clr TR1                 ; keep timer 1 off

    ; IP (interrupt priority) register
    ; ____________________________________________
    ; | - | - | PT2 | PS | PT1 | PX1 | PT0 | PX0 |
    ; |___|___|_____|____|_____|_____|_____|_____|
    ; PT2 (IP.5): timer 2 interrupt priority bit (only 8052)
    ; PS  (IP.4): serial port interrupt priority bit
    ; PT1 (IP.3): timer 1 overflow interrupt priority bit
    ; PX1 (IP.2): external interrupt 1 priority bit
    ; PT0 (IP.1): timer 0 overflow interrupt priority bit
    ; PX0 (IP.0): external interrupt 0 priority bit

    ; Interrupt priority initialization
    mov IP, #22h        ; make timer 0 interrupt (update time) and timer 2 interrupt (update displays) highest priority

    ; Serial port initialization (mode 0 - synchronous serial communication)
    mov SCON, #00h      ; initialize the serial port in mode 0


    lcall ENTER_GPS_SYNC_STATE
sjmp MAIN

MAIN:
    mov a, CLOCK_STATE

    cjne a, #SHOW_TIME_STATE, main_cont0
        lcall SHOW_TIME
        sjmp main_cont6
    main_cont0:

    cjne a, #SET_TIME_STATE, main_cont1
        lcall SET_TIME
        sjmp main_cont6
    main_cont1:

    cjne a, #SHOW_ALARM_STATE, main_cont2
        lcall SHOW_ALARM
        sjmp main_cont6
    main_cont2:

    cjne a, #SET_ALARM_STATE, main_cont3
        lcall SET_ALARM
        sjmp main_cont6
    main_cont3:

    cjne a, #SETTINGS_STATE, main_cont4
        lcall SETTINGS
        sjmp main_cont6
    main_cont4:

    cjne a, #GPS_SYNC_STATE, main_cont5
        lcall GPS_SYNC
        sjmp main_cont6
    main_cont5:

    cjne a, #CYCLE_STATE, main_cont6
        lcall CYCLE
    main_cont6:

    ; ======================================
    mov a, ALARM_STATE

    cjne a, #ALARM_ENABLED_STATE, main_cont7
        lcall ALARM_ENABLED
        sjmp main_cont10
    main_cont7:

    cjne a, #ALARM_DISABLED_STATE, main_cont8
        lcall ALARM_DISABLED
        sjmp main_cont10
    main_cont8:

    cjne a, #ALARM_FIRING_STATE, main_cont9
        lcall ALARM_FIRING
        sjmp main_cont10
    main_cont9:

    cjne a, #ALARM_SNOOZING_STATE, main_cont10
        lcall ALARM_SNOOZING
    main_cont10:
sjmp MAIN


; ========= Clock State Functions ==========
SHOW_TIME:
    ; Split the month
    mov a, MONTH
    mov b, #0Ah
    div ab
    mov MM_TENS, a
    mov MM_ONES, b

    ; Split the day
    mov a, DAY
    mov b, #0Ah
    div ab
    mov DD_TENS, a
    mov DD_ONES, b

    ; Split the year
    mov a, YEAR
    mov b, #0Ah
    div ab
    mov YY_TENS, a
    mov YY_ONES, b

    ; Update the hours if 12/24 hour switch is flipped
    mov R1, #45h        ; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; Split the minutes
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ; Display the numbers
    mov GRID9, #0FFh
    mov GRID8, MM_TENS
    mov GRID7, MM_ONES
    ; mov GRID6, #0Ah --> set in INIT
    mov GRID5, DD_TENS
    mov GRID4, DD_ONES
    ; mov GRID3, #0Ah --> set in INIT
    mov GRID2, YY_TENS
    mov GRID1, YY_ONES

    ;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    ;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; mov DECATRON, SECONDS --> This is taken care of in the decatron state machine

    ; Check if an alarm is currently firing
    mov a, ALARM_STATE
    cjne a, #ALARM_FIRING_STATE, show_time_cont8
        ; alarm is firing, so do not GPS auto sync or register settings button presses
        sjmp show_time_cont5
    show_time_cont8:

    ; Check if there is a GPS
    jnb GPS_PRESENT?, show_time_cont2
        ; GPS is present:
        ; Check if the alarm is currently not snoozing or firing
        ; mov a, ALARM_STATE
        ; cjne a, #ALARM_FIRING_STATE, show_time_cont3
        ;   sjmp show_time_cont2
        ; show_time_cont3:
        cjne a, #ALARM_SNOOZING_STATE, show_time_cont4
            sjmp show_time_cont2
        show_time_cont4:
        ; Alarm is not firing or snoozing
        ; TODO: Check if GPS sync is enabled
        ; Check if time to sync to the GPS
        mov a, GPS_SYNC_TIME_HOURS                                      ; check if time to sync
        cjne a, HOURS, show_time_cont2                                  ; compare sync hours to current hours
            mov a, GPS_SYNC_TIME_MINUTES
            cjne a, MINUTES, show_time_cont2                            ; compare sync minutes to current minutes
                mov a, #02h
                cjne a, SECONDS, show_time_cont2                        ; compare current seconds to 2
                    ; TODO:  turn off the GPS sync light
                    jnb AUTO_SYNC?, show_time_cont2                     ; check if GPS auto sync is enabled
                        lcall ENTER_GPS_SYNC_STATE                      ; transition to GPS_SYNC_STATE
                        sjmp show_time_cont1
    show_time_cont2:

    ; Check if the minutes end in 3, if so, enter CYCLE_STATE
    mov a, #03h                                                         ; check if time to cycle
    cjne a, MIN_ONES, show_time_cont9                                   ; compare cycle minute ones to current minute ones
        mov a, #27h
        cjne a, SECONDS, show_time_cont9                                ; compare current seconds to 39 so it usually won't be
                                                                        ; interrupted by a firing alarm (otherwise arbitrary)
            lcall SHOW_TIME_STATE_TO_CYCLE_STATE                        ; transition to CYCLE_STATE
            ljmp show_time_cont1
    show_time_cont9:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, show_time_cont5
        lcall SHOW_TIME_STATE_TO_SETTINGS_STATE     ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SETTINGS state
        ljmp show_time_cont1
    show_time_cont5:

    ; check for a remote button press
    lcall CHECK_FOR_REMOTE_BUTTON_SHORT_PRESS
    ; CHECK_FOR_REMOTE_BUTTON_SHORT_PRESS will automatically redirect any short remote press to snooze the alarm if
    ; the alarm is currently firing.
    jnb TRANSITION_STATE?, show_time_cont6 
        lcall SHOW_TIME_STATE_TO_SHOW_ALARM_STATE   ; if there was a remote button press (TRANSITION_STATE? bit is set), go to SHOW_ALARM state
        ljmp show_time_cont1
    show_time_cont6:

    ; check for rotary encoder press
    mov NEXT_CLOCK_STATE, #SHOW_TIME_STATE
    lcall CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS
    ; CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS will automatically redirect any short or long rot enc press to snooze the alarm if
    ; the alarm is currently firing.

    ; Check the NEXT_CLOCK_STATE
    mov a, NEXT_CLOCK_STATE
    cjne a, #SHOW_ALARM_STATE, show_time_cont0
        lcall SHOW_TIME_STATE_TO_SHOW_ALARM_STATE
        sjmp show_time_cont1
    show_time_cont0:
    cjne a, #SET_TIME_STATE, show_time_cont1
        lcall SHOW_TIME_STATE_TO_SET_TIME_STATE
    show_time_cont1:
ret

SET_TIME:    ; has a sub-state machine with state variable SET_ALARM_SUB_STATE
    mov a, SET_TIME_SUB_STATE

    cjne a, #SET_MM_STATE, set_time_cont0
        lcall SET_MM
        sjmp set_time_cont4
    set_time_cont0:

    cjne a, #SET_DD_STATE, set_time_cont1
        lcall SET_DD
        sjmp set_time_cont4
    set_time_cont1:

    cjne a, #SET_YY_STATE, set_time_cont2
        lcall SET_YY
        sjmp set_time_cont4
    set_time_cont2:

    cjne a, #SET_HR_STATE, set_time_cont3
        lcall SET_HR
        sjmp set_time_cont4
    set_time_cont3:

    cjne a, #SET_MIN_STATE, set_time_cont4
        lcall SET_MIN
    set_time_cont4:

    ; Update the hours if 12/24 hour switch is flipped
    mov R1, #45h                            ; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; Check for a timeout event
    mov a, TIMEOUT
    cjne a, #00h, set_time_cont5
    ; mov a, SECONDS
    ; cjne a, TIMEOUT, set_time_cont5
        lcall DD_ADJ                        ; check for valid day, given month
        lcall YY_ADJ                        ; check for valid year, given month and day
        clr INC_LEAP_YEAR?                  ; clear the leap year bit
        lcall SET_TIME_STATE_TO_SHOW_TIME_STATE
    set_time_cont5:
ret

SHOW_ALARM:
    ; Update the hours if 12/24 hour switch is flipped
    mov R1, #5Bh        ; move the address of ALARM_HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; Split the minutes
    mov a, ALARM_MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    ;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; mov DECATRON, SECONDS --> This is taken care of in decatron state machine

    ; listen for remote button press
    lcall CHECK_FOR_REMOTE_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, show_alarm_cont3  
        lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE   ; if there was a remote button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
        ljmp show_alarm_cont2
    show_alarm_cont3:
    
    ; listen for rotary encoder press
    mov NEXT_CLOCK_STATE, #SHOW_ALARM_STATE
    lcall CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS

    ; Check the NEXT_CLOCK_STATE
    mov a, NEXT_CLOCK_STATE
    cjne a, #SHOW_TIME_STATE, show_alarm_cont0
        lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE
        sjmp show_alarm_cont2
    show_alarm_cont0:
    cjne a, #SET_ALARM_STATE, show_alarm_cont1
        lcall SHOW_ALARM_STATE_TO_SET_ALARM_STATE
        sjmp show_alarm_cont2
    show_alarm_cont1:

    ; Check for timeout event
    mov a, TIMEOUT
    cjne a, #00h, show_alarm_cont2
    ; mov a, SECONDS
    ; cjne a, TIMEOUT, show_alarm_cont2
        lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE
        ; mov NEXT_CLOCK_STATE, #SHOW_TIME_STATE
    show_alarm_cont2:

    ; change state if needed
    ; mov CLOCK_STATE, NEXT_CLOCK_STATE
ret

SET_ALARM:  ; has a sub-state machine with state variable SET_ALARM_SUB_STATE
    mov a, SET_ALARM_SUB_STATE

    cjne a, #SET_ALARM_HR_STATE, set_alarm_cont0
        lcall SET_ALARM_HR
        sjmp set_alarm_cont1
    set_alarm_cont0:

    cjne a, #SET_ALARM_MIN_STATE, set_alarm_cont1
        lcall SET_ALARM_MIN
    set_alarm_cont1:

    ; Check for timeout event
    mov a, TIMEOUT
    cjne a, #00h, set_alarm_cont2
    ; mov a, SECONDS
    ; cjne a, TIMEOUT, set_alarm_cont2
        lcall SET_ALARM_STATE_TO_SHOW_ALARM_STATE
    set_alarm_cont2:

    mov R1, #5Bh        ; move the address of ALARM_HOURS (*note: not ALARM_MINUTES) into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ
ret

GPS_SYNC:   ; has a sub-state machine with state variable GPS_SYNC_SUB_STATE
    mov a, GPS_SYNC_SUB_STATE

    cjne a, #GPS_OBTAIN_FIX_STATE, gps_sync_cont0
        lcall GPS_OBTAIN_FIX
        sjmp gps_sync_cont2
    gps_sync_cont0:

    cjne a, #GPS_OBTAIN_DATA_STATE, gps_sync_cont1
        lcall GPS_OBTAIN_DATA
        sjmp gps_sync_cont2
    gps_sync_cont1:

    cjne a, #GPS_SET_TIMEZONE_STATE, gps_sync_cont2
        lcall GPS_SET_TIMEZONE
    gps_sync_cont2:

    ; ; check if the alarm is firing
    ; mov a, ALARM_STATE

    ; cjne a, #ALARM_FIRING_STATE, gps_sync_cont3
    ;   ; the alarm is firing:
    ;   lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE     ; exit the syncing state since the alarm has priority
    ; gps_sync_cont3:
ret

SETTINGS:    ; has a sub-state machine with state variable SETTINGS_SUB_STATE
    mov a, SETTINGS_SUB_STATE

    cjne a, #SETTINGS_SHOW_RE_SYNC_STATE, settings_cont0
        lcall SETTINGS_SHOW_RE_SYNC
        sjmp settings_cont11
    settings_cont0:

    cjne a, #SETTINGS_SHOW_TIMEZONE_STATE, settings_cont1
        lcall SETTINGS_SHOW_TIMEZONE    
        sjmp settings_cont11
    settings_cont1:

    cjne a, #SETTINGS_SHOW_SNOOZE_STATE, settings_cont2
        lcall SETTINGS_SHOW_SNOOZE
        sjmp settings_cont11
    settings_cont2:

    cjne a, #SETTINGS_SHOW_DATE_ON_OFF_STATE, settings_cont3
        lcall SETTINGS_SHOW_DATE_ON_OFF
        sjmp settings_cont11
    settings_cont3:

    cjne a, #SETTINGS_SHOW_GPS_SYNC_TIME_STATE, settings_cont4
        lcall SETTINGS_SHOW_GPS_SYNC_TIME
        sjmp settings_cont11
    settings_cont4:

    cjne a, #SETTINGS_SHOW_AUTO_SYNC_STATE, settings_cont5
        lcall SETTINGS_SHOW_AUTO_SYNC
        sjmp settings_cont11
    settings_cont5:

    cjne a, #SETTINGS_SHOW_12_OR_24_HR_MODE_STATE, settings_cont6
        lcall SETTINGS_SHOW_12_OR_24_HR_MODE
        sjmp settings_cont11
    settings_cont6:

    cjne a, #SETTINGS_SHOW_BEEP_ON_OFF_STATE, settings_cont7
        lcall SETTINGS_SHOW_BEEP_ON_OFF
        sjmp settings_cont11
    settings_cont7:

    cjne a, #SETTINGS_SET_TIMEZONE_STATE, settings_cont8
        lcall SETTINGS_SET_TIMEZONE
        sjmp settings_cont11
    settings_cont8:

    cjne a, #SETTINGS_SET_SNOOZE_STATE, settings_cont9
        lcall SETTINGS_SET_SNOOZE
        sjmp settings_cont11
    settings_cont9:

    cjne a, #SETTINGS_SET_GPS_SYNC_HR_STATE, settings_cont10
        lcall SETTINGS_SET_GPS_SYNC_HR
        sjmp settings_cont11
    settings_cont10:

    cjne a, #SETTINGS_SET_GPS_SYNC_MIN_STATE, settings_cont11
        lcall SETTINGS_SET_GPS_SYNC_MIN
    settings_cont11:

    ; Check for a timeout event
    mov a, TIMEOUT
    cjne a, #00h, settings_cont12
        ; transition the decatron state
        mov DECA_STATE, #DECA_COUNTING_SECONDS_STATE

        ; check which settings need to be saved
        mov a, SETTINGS_SUB_STATE
        cjne a, #SETTINGS_SET_TIMEZONE_STATE, settings_cont13   ; check if the user was setting the timezone
            lcall APPLY_TIMEZONE_TO_UTC                         ; apply the timezone offset
            ljmp settings_cont14
        settings_cont13:

        cjne a, #SETTINGS_SET_SNOOZE_STATE, settings_cont14     ; check if the user was setting the snooze duration
            ; recalculate the SNOOZE_COUNT_PER_DECA_PIN
            mov a, SNOOZE_DURATION
            add a, SNOOZE_DURATION
            mov SNOOZE_COUNT_PER_DECA_PIN_RELOAD, a
            mov SNOOZE_COUNT_PER_DECA_PIN, SNOOZE_COUNT_PER_DECA_PIN_RELOAD
        settings_cont14:

        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a timeout, go to SHOW_TIME state
    settings_cont12:
ret

CYCLE:
    ; The accumulator holds the value all the nixies display.
    mov NIX1, CYCLE_NUMBER
    mov NIX2, CYCLE_NUMBER
    mov NIX3, CYCLE_NUMBER
    mov NIX4, CYCLE_NUMBER

    lcall MED_DELAY

    ; Increment and check if CYCLE_NUMBER needs to wrap around from 9 to 0.
    inc CYCLE_NUMBER
    mov a, CYCLE_NUMBER
    cjne a, #0Ah, cycle_cont0
        mov CYCLE_NUMBER, #00h
    cycle_cont0:

    ; Check for timeout event
    mov a, TIMEOUT
    cjne a, #00h, cycle_cont1
        lcall CYCLE_STATE_TO_SHOW_TIME_STATE
    cycle_cont1:
ret

; ===== Set Time Sub-State Functions =======

SET_MM:
    ; Operations to dispay MONTH register in decimal format: MM
    mov a, MONTH
    mov b, #0Ah
    div ab
    mov MM_TENS, a
    mov MM_ONES, b

    ; Display MONTH:
    mov GRID8, MM_TENS
    mov GRID7, MM_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, set_mm_cont0 
        lcall SET_MM_STATE_TO_SET_DD_STATE  ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    set_mm_cont0:
ret

SET_DD:
    ; Operations to dispay DAY register in decimal format: DD
    mov a, DAY
    mov b, #0Ah
    div ab
    mov DD_TENS, a
    mov DD_ONES, b

    ; Display DAY:
    mov GRID5, DD_TENS
    mov GRID4, DD_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, set_dd_cont0
        lcall SET_DD_STATE_TO_SET_YY_STATE          ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    set_dd_cont0:
ret

SET_YY:
    ; Operations to dispay YEAR register in decimal format: YY
    mov a, YEAR
    mov b, #0Ah
    div ab
    mov YY_TENS, a
    mov YY_ONES, b

    ; Display YEAR:
    mov GRID2, YY_TENS
    mov GRID1, YY_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, set_yy_cont0
        lcall SET_YY_STATE_TO_SET_HR_STATE          ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    set_yy_cont0:
ret

SET_HR:
    ; HOURS gets written to display in TWLV_TWFR_HOUR_ADJ function, called in SET_TIME

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, set_hr_cont0
        lcall SET_HR_STATE_TO_SET_MIN_STATE         ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    set_hr_cont0:
ret

SET_MIN:
    ; Operations to dispay MINUTES register in decimal format: MIN
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ; Display MINUTES:
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, set_min_cont0
        lcall SET_TIME_STATE_TO_SHOW_TIME_STATE     ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    set_min_cont0:
ret

; ===== Set Alarm Sub-State Functions ======

SET_ALARM_HR:
    ; ALARM_HOURS gets written to display in TWLV_TWFR_HOUR_ADJ function, called in SET_ALARM

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, set_alarm_hr_cont0
        lcall SET_ALARM_HR_STATE_TO_SET_ALARM_MIN_STATE         ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    set_alarm_hr_cont0:
ret

SET_ALARM_MIN:
    ; Operations to dispay ALARM_MINUTES register in decimal format: MIN
    mov a, ALARM_MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ; Display ALARM_MINUTES:
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, set_alarm_min_cont0
        lcall SET_ALARM_STATE_TO_SHOW_ALARM_STATE       ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    set_alarm_min_cont0:
ret

; ===== Settings Sub-State Functions ======
SETTINGS_SHOW_RE_SYNC:
    ; Have VFD display "re-Sync"
    mov GRID9, #0FFh    ; BLANK
    mov GRID8, #0FFh    ; BLANK
    mov GRID7, #0Fh     ; "r"
    mov GRID6, #18h     ; "e"
    mov GRID5, #0Ah     ; "-"
    mov GRID4, #15h     ; "S"
    mov GRID3, #1Ah     ; "y"       
    mov GRID2, #11h     ; "n"
    mov GRID1, #14h     ; "c"

    ; Have nixies display the current time
    ; Update the hours if 12/24 hour switch is flipped
    mov R1, #45h        ; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; Split the minutes
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    ;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_re_sync_cont0
        lcall ENTER_GPS_SYNC_STATE              ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
        ljmp settings_show_re_sync_cont1
    settings_show_re_sync_cont0:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_re_sync_cont1
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_re_sync_cont1:
ret

SETTINGS_SHOW_TIMEZONE:
    ; Have VFD display "Utc Zone"
    mov GRID9, #0Bh     ; "*" since this has a sub-menu
    mov GRID8, #12h     ; "U"
    mov GRID7, #13h     ; "t"
    mov GRID6, #14h     ; "c"
    mov GRID5, #0FFh    ; BLANK
    mov GRID4, #16h     ; "Z"
    mov GRID3, #17h     ; "o"       
    mov GRID2, #11h     ; "n"
    mov GRID1, #18h     ; "e"

    ; Have nixies display the current time
    ; Update the hours if 12/24 hour switch is flipped
    mov R1, #45h        ; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; Split the minutes
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    ;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_timezone_cont0
        lcall ENTER_SETTINGS_SET_TIMEZONE_STATE         ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
        ljmp settings_show_timezone_cont1
    settings_show_timezone_cont0:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_timezone_cont1
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_timezone_cont1:
ret

SETTINGS_SHOW_SNOOZE:
    ; Have VFD display "SnooZe"
    mov GRID9, #0Bh     ; "*" since this has a sub-menu
    mov GRID8, #0FFh    ; BLANK
    mov GRID7, #0FFh    ; BLANK
    mov GRID6, #15h     ; "S"
    mov GRID5, #11h     ; "n"
    mov GRID4, #17h     ; "o"
    mov GRID3, #17h     ; "o"       
    mov GRID2, #16h     ; "Z"
    mov GRID1, #18h     ; "e"

    ; Have nixies display the snooze duration
    ; Split the minutes
    mov a, SNOOZE_DURATION
    mov b, #0Ah
    div ab
    mov NIX2, a
    mov NIX1, b

    ; blank NIX4 & NIX3 (if using 74141 nixie driver -- OUR CASE)
    ; display 0 on NIX4 & NIX3 (if using 7441A nixie driver)
    mov NIX4, #0Ah
    mov NIX3, #0Ah

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_snooze_cont0
        lcall ENTER_SETTINGS_SET_SNOOZE_STATE       ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
        ljmp settings_show_snooze_cont1
    settings_show_snooze_cont0:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_snooze_cont1
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_snooze_cont1:
ret

SETTINGS_SHOW_DATE_ON_OFF:
    ; Have VFD display "date on"
    mov GRID9, #0FFh    ; BLANK
    mov GRID8, #0FFh    ; BLANK
    mov GRID7, #19h     ; "d"
    mov GRID6, #0Eh     ; "a"
    mov GRID5, #13h     ; "t"
    mov GRID4, #18h     ; "e"
    mov GRID3, #0FFh    ; BLANK     
    mov GRID2, #17h     ; "o"
    mov GRID1, #11h     ; "n"

    ; Have nixies display the state of the DATE_ON? bit
    jb DATE_ON?, settings_show_date_on_off_cont0
        mov NIX1, #00h
        ljmp settings_show_date_on_off_cont1
    settings_show_date_on_off_cont0:
        mov NIX1, #01h
    settings_show_date_on_off_cont1:

    ; blank NIX4, NIX3, & NIX2 (if using 74141 nixie driver -- OUR CASE)
    ; display 0 on NIX4, NIX3, & NIX2 (if using 7441A nixie driver)
    mov NIX4, #0Ah
    mov NIX3, #0Ah
    mov NIX2, #0Ah

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_date_on_off_cont2
        cpl DATE_ON?            ; if there was a short press (TRANSITION_STATE? bit is set), toggle DATE_ON? bit
        ljmp settings_show_date_on_off_cont3
    settings_show_date_on_off_cont2:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_date_on_off_cont3
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_date_on_off_cont3:
ret

SETTINGS_SHOW_GPS_SYNC_TIME:
    ; Have VFD display "Sync at"
    mov GRID9, #0Bh     ; "*" since this has a sub-menu
    mov GRID8, #0FFh    ; BLANK
    mov GRID7, #15h     ; "S"
    mov GRID6, #1Ah     ; "y"
    mov GRID5, #11h     ; "n"
    mov GRID4, #14h     ; "c"
    mov GRID3, #0FFh    ; BLANK     
    mov GRID2, #0Eh     ; "a"
    mov GRID1, #13h     ; "t"

    ; Have nixies display the GPS sync time
    ; Split the minutes
    mov a, GPS_SYNC_TIME_MINUTES
    mov b, #0Ah
    div ab
    mov NIX2, a
    mov NIX1, b
    
    ; Update the hours if 12/24 hour switch is flipped
    mov R1, #6Dh        ; move the address of GPS_SYNC_TIME_HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; ; Split the hours
    ; mov a, GPS_SYNC_TIME_HOURS
    ; mov b, #0Ah
    ; div ab
    ; mov NIX4, a
    ; mov NIX3, b

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_gps_sync_time_cont0
        lcall ENTER_SETTINGS_SET_GPS_SYNC_HR_STATE      ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
        ljmp settings_show_gps_sync_time_cont1
    settings_show_gps_sync_time_cont0:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_gps_sync_time_cont1
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE         ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_gps_sync_time_cont1:
ret

SETTINGS_SHOW_AUTO_SYNC:
    ; Have VFD display "AutoSync"
    mov GRID9, #0FFh    ; BLANK
    mov GRID8, #0Ch     ; "A"
    mov GRID7, #1Bh     ; "u"
    mov GRID6, #13h     ; "t"
    mov GRID5, #17h     ; "o"
    mov GRID4, #15h     ; "S"
    mov GRID3, #1Ah     ; "y"       
    mov GRID2, #11h     ; "n"
    mov GRID1, #14h     ; "c"

    ; Have nixies display the state of the AUTO_SYNC? bit
    jb AUTO_SYNC?, settings_show_auto_sync_cont0
        mov NIX1, #00h
        ljmp settings_show_auto_sync_cont1
    settings_show_auto_sync_cont0:
        mov NIX1, #01h
    settings_show_auto_sync_cont1:

    ; blank NIX4, NIX3, & NIX2 (if using 74141 nixie driver -- OUR CASE)
    ; display 0 on NIX4, NIX3, & NIX2 (if using 7441A nixie driver)
    mov NIX4, #0Ah
    mov NIX3, #0Ah
    mov NIX2, #0Ah

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_auto_sync_cont2
        cpl AUTO_SYNC?          ; if there was a short press (TRANSITION_STATE? bit is set), toggle AUTO_SYNC? bit

        ; change available settings menu options
        jb AUTO_SYNC?, settings_show_auto_sync_cont4
            ; auto-sync was just disabled
            mov NUMBER_OF_ACTIVE_SETTINGS, #07h                 ; hide the auto-sync time menu option
            mov UPPER_BOUND, NUMBER_OF_ACTIVE_SETTINGS          ; update the rotary encoder upper bound:  SETTINGS_SUB_STATE can be 
                                                                ; NUMBER_OF_ACTIVE_SETTINGS max
            sjmp settings_show_auto_sync_cont3

        settings_show_auto_sync_cont4:
        ; auto-sync was just enabled
        mov NUMBER_OF_ACTIVE_SETTINGS, #NUMBER_OF_SETTINGS      ; make all settings menu options available
        mov UPPER_BOUND, NUMBER_OF_ACTIVE_SETTINGS              ; update the rotary encoder upper bound:  SETTINGS_SUB_STATE can be...
                                                                ; NUMBER_OF_ACTIVE_SETTINGS max
        ljmp settings_show_auto_sync_cont3
    settings_show_auto_sync_cont2:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_auto_sync_cont3
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_auto_sync_cont3:
ret

SETTINGS_SHOW_12_OR_24_HR_MODE:
    ; Have VFD display "12 or 24"
    mov GRID9, #0FFh    ; BLANK
    mov GRID8, #01h     ; "1"
    mov GRID7, #02h     ; "2"
    mov GRID6, #0FFh    ; BLANK
    mov GRID5, #17h     ; "o"
    mov GRID4, #0Fh     ; "r"
    mov GRID3, #0FFh    ; BLANK
    mov GRID2, #02h     ; "2"
    mov GRID1, #04h     ; "4"

    ; Have nixies display the state of the TWLV_HR_MODE? bit
    jb TWLV_HR_MODE?, settings_show_12_or_24_hr_mode_cont0
        mov NIX2, #02h
        mov NIX1, #04h
        ljmp settings_show_12_or_24_hr_mode_cont1
    settings_show_12_or_24_hr_mode_cont0:
        mov NIX2, #01h
        mov NIX1, #02h
    settings_show_12_or_24_hr_mode_cont1:

    ; blank NIX4 & NIX3 (if using 74141 nixie driver -- OUR CASE)
    ; display 0 on NIX4 & NIX3 (if using 7441A nixie driver)
    mov NIX4, #0Ah
    mov NIX3, #0Ah

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_12_or_24_hr_mode_cont2
        cpl TWLV_HR_MODE?           ; if there was a short press (TRANSITION_STATE? bit is set), toggle TWLV_HR_MODE? bit
        ljmp settings_show_12_or_24_hr_mode_cont3
    settings_show_12_or_24_hr_mode_cont2:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_12_or_24_hr_mode_cont3
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_12_or_24_hr_mode_cont3:
ret

SETTINGS_SHOW_BEEP_ON_OFF:
    ; Have VFD display "beeP on"
    mov GRID9, #0FFh    ; BLANK
    mov GRID8, #0FFh    ; BLANK
    mov GRID7, #1Eh     ; "b"
    mov GRID6, #18h     ; "e"
    mov GRID5, #18h     ; "e"
    mov GRID4, #1Fh     ; "p"
    mov GRID3, #0FFh    ; BLANK
    mov GRID2, #17h     ; "o"
    mov GRID1, #11h     ; "n"

    ; Have nixies display the state of the BEEP_ON? bit
    jb BEEP_ON?, settings_show_beep_on_off_cont0
        mov NIX1, #00h
        ljmp settings_show_beep_on_off_cont1
    settings_show_beep_on_off_cont0:
        mov NIX1, #01h
    settings_show_beep_on_off_cont1:

    ; blank NIX4, NIX3, & NIX2 (if using 74141 nixie driver -- OUR CASE)
    ; display 0 on NIX4, NIX3, & NIX2 (if using 7441A nixie driver)
    mov NIX4, #0Ah
    mov NIX3, #0Ah
    mov NIX2, #0Ah

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_beep_on_off_cont2
        cpl BEEP_ON?            ; if there was a short press (TRANSITION_STATE? bit is set), toggle BEEP_ON? bit
        ljmp settings_show_beep_on_off_cont3
    settings_show_beep_on_off_cont2:

    ; check for a settings button press
    lcall CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_beep_on_off_cont3
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE ; if there was a settings button press (TRANSITION_STATE? bit is set), go to SHOW_TIME state
    settings_show_beep_on_off_cont3:
ret

SETTINGS_SET_TIMEZONE:
    ; Note:  12/24 hour adjust and displaying is done lower in this function

    ; Split the minutes
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ; Display the timezone offset
    ; grids 4 through 9 are set in ENTER_SETTINGS_SET_TIMEZONE_STATE
    mov a, TIMEZONE
    clr c
    subb a, #0Eh
    jnc settings_set_timezone_cont1
        ; UTC offset is negative, accumulator now holds 256 minus the negative offset
        mov GRID3, #0Ah             ; display '-' as a negative sign on grid 3
        ; get negative offset into accumulator by subtracting in opposite order
        clr c
        mov a, #0Eh
        subb a, TIMEZONE            ; accumulator now holds UTC negative offset
        sjmp settings_set_timezone_cont2
    settings_set_timezone_cont1:
        ; UTC offset is positive, accumulator now holds it
        mov GRID3, #0FFh            ; blank grid 3

    settings_set_timezone_cont2:
    ; the accumulator holds the UTC offset (either positive or negative), and the negative sign is already displayed / not displayed in grid 3
    ; display the UTC offset
    mov b, #0Ah
    div ab
    mov GRID2, a
    mov GRID1, b

    ; display the minutes
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; calculate the hours with the UTC offset applied
    mov a, TIMEZONE
    add a, HOURS                            ; add HOURS to TIMEZONE
    clr c
    subb a, #0Eh                            ; remove the offset of TIMEZONE
    jnc settings_set_timezone_cont3         ; determine if the hours rolled under
        ; the hours rolled under, so wrap it around to 23 again
        add a, #18h                         ; add 24 (dec) to the accumulator to get the result within 0 and 23
        sjmp settings_set_timezone_cont4

    settings_set_timezone_cont3:
    ; the hours did not roll under, so check if the hours rolled over
    clr c
    subb a, #18h                            ; subtract 24 (dec) from the accumulator to determine if a is between 0 and 23 or above 23
    jnc settings_set_timezone_cont4
        ; the hours did not roll over, so add 24 (dec) back to the total to get the proper hours with UTC offset applied
        add a, #18h                         ; add 24 (dec) to the accumulator to get the result within 0 and 23

    settings_set_timezone_cont4:
    ; the hours with the UTC offset applied are in the accumulator and ready to display

    ; Taken care of with TWLV_TWFR_HOUR_ADJ
    ; mov b, #0Ah
    ; div ab
    ; mov NIX4, a
    ; mov NIX3, b

    ; Update the hours if 12/24 hour switch is flipped
    mov SET_TIMEZONE_HOURS, a   ; stage the hours with UTC offset applied
    mov R1, #6Bh                ; move the address of SET_TIMEZONE_HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_set_timezone_cont0
        setb TIMEZONE_SET?                              ; indicate that the timezone has been set
        lcall APPLY_TIMEZONE_TO_UTC                     ; apply the set timezone to the current time registers which are holding UTC time
        lcall EXIT_SETTINGS_SET_TIMEZONE_STATE          ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    settings_set_timezone_cont0:
ret

SETTINGS_SET_SNOOZE:
    ; Have nixies display the snooze duration
    ; Split the minutes
    mov a, SNOOZE_DURATION
    mov b, #0Ah
    div ab
    mov NIX2, a
    mov NIX1, b

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_set_snooze_cont0
        lcall EXIT_SETTINGS_SET_SNOOZE_STATE            ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    settings_set_snooze_cont0:
ret

SETTINGS_SET_GPS_SYNC_HR:
    ; Have nixies display the GPS sync time
    ; Split the minutes
    mov a, GPS_SYNC_TIME_MINUTES
    mov b, #0Ah
    div ab
    mov NIX2, a
    mov NIX1, b
    
    ; Split the hours
    mov a, GPS_SYNC_TIME_HOURS
    mov b, #0Ah
    div ab
    mov NIX4, a
    mov NIX3, b

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_gps_sync_hr_cont0
        lcall ENTER_SETTINGS_SET_GPS_SYNC_MIN_STATE         ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    settings_show_gps_sync_hr_cont0:
ret

SETTINGS_SET_GPS_SYNC_MIN:
    ; Have nixies display the GPS sync time
    ; Split the minutes
    mov a, GPS_SYNC_TIME_MINUTES
    mov b, #0Ah
    div ab
    mov NIX2, a
    mov NIX1, b
    
    ; Split the hours
    mov a, GPS_SYNC_TIME_HOURS
    mov b, #0Ah
    div ab
    mov NIX4, a
    mov NIX3, b

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, settings_show_gps_sync_min_cont0
        lcall EXIT_SETTINGS_SET_GPS_SYNC_TIME_STATE         ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    settings_show_gps_sync_min_cont0:
ret

; ===== GPS Sync Sub-State Functions ======

GPS_OBTAIN_FIX:
    ; Display hours and minutes.  Everything else is taken care of in interrupt-driven code.

    ; ; Update the hours if 12/24 hour switch is flipped
    ; mov R1, #45h      ; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    ; lcall TWLV_TWFR_HOUR_ADJ

    ; Split the minutes
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    ;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; Fix detection occurs in TIMER_1_SERVICE.

    ; check the state of GPS_PRESENT? bit
    ; Note:  the clock is only in GPS_OBTAIN_FIX without a physical GPS present if the clock is just starting up.  GPS_PRESENT? bit is 
    ; initialized to be false.  Thus, if the clock isn't sure if a GPS is present or not at this point, it just hasn't had enough time
    ; to tell if one is there or not.  This can be figured out in less than a couple seconds.  Therefore, if GPS_PRESENT? is not set at
    ; this point, the clock ignores a rotary encoder short press.
    jnb GPS_PRESENT?, gps_obtain_fix_cont1
        ; check for a rotary encoder short press
        lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
        jnb TRANSITION_STATE?, gps_obtain_fix_cont1
            ; if there is a GPS present, check the state of TIMEZONE_SET? bit
            jnb TIMEZONE_SET?, gps_obtain_fix_cont2
                ; TIMEZONE has been set:
                lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE
                sjmp gps_obtain_fix_cont0
            gps_obtain_fix_cont2:
                ; TIMEZONE has not been set AND there is a GPS present:
                lcall ENTER_GPS_SET_TIMEZONE_STATE
                sjmp gps_obtain_fix_cont0
    gps_obtain_fix_cont1:

    ; Check for timeout event
    mov a, TIMEOUT
    cjne a, #00h, gps_obtain_fix_cont0
        ; check if timezone has been set yet
        jnb TIMEZONE_SET?, gps_obtain_fix_cont3
            ; TIMEZONE_SET? bit is set:
            lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE         ; go to SHOW_TIME_STATE
            sjmp gps_obtain_fix_cont0
        gps_obtain_fix_cont3:
            ; TIMEZONE_SET? bit is not set:
            lcall ENTER_GPS_SET_TIMEZONE_STATE              ; go to GPS_SET_TIMEZONE_STATE
    gps_obtain_fix_cont0:
ret

GPS_OBTAIN_DATA:
    ; Display hours and minutes.  Everything else is taken care of in interrupt-driven code.

    ; ; Update the hours if 12/24 hour switch is flipped
    ; mov R1, #45h      ; move the address of HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    ; lcall TWLV_TWFR_HOUR_ADJ

    ; Split the minutes
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ;mov NIX4, HR_TENS --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    ;mov NIX3, HR_ONES --> This is taken care of in TWLV_TWFR_HOUR_ADJ
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, gps_obtain_data_cont1
        ; check the state of TIMZONE_SET? bit
        jnb TIMEZONE_SET?, gps_obtain_data_cont2
            ; TIMEZONE has been set:
            lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE
            sjmp gps_obtain_data_cont0
        gps_obtain_data_cont2:
            ; TIMEZONE has not been set AND there is a GPS present:
            lcall ENTER_GPS_SET_TIMEZONE_STATE
            sjmp gps_obtain_data_cont0
    gps_obtain_data_cont1:


    ; ADDED BELOW BLOCK AS TEST ========== 7/31/2020 TO FIX GETTING STUCK AFTER OBTAINING FIX AND DISPLAYING '-29' ON VFD
    ; check if syncing occurred and need to go to GPS_SET_TIMEZONE_STATE
    jnb P1.7, gps_obtain_data_cont4
        ; check TIMEZONE_SET? bit
        jb TIMEZONE_SET?, gps_obtain_data_cont5                     
            ; if TIMEZONE_SET? bit is not set, let user input timezone
            lcall ENTER_GPS_SET_TIMEZONE_STATE                      ; update GPS_SYNC_SUB_STATE
            sjmp gps_obtain_data_cont0
        gps_obtain_data_cont5:
            ; if TIMEZONE_SET? bit is set, user has already set timezone, so go directly to SHOW_TIME_STATE
            lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE
            sjmp gps_obtain_data_cont0                              ; jump to end
    gps_obtain_data_cont4:
    ; ====================================


    ; Check for timeout event
    mov a, TIMEOUT
    cjne a, #00h, gps_obtain_data_cont0
        ; check if timezone has been set yet
        jnb TIMEZONE_SET?, gps_obtain_data_cont3
            ; TIMEZONE_SET? bit is set:
            lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE         ; go to SHOW_TIME_STATE
            sjmp gps_obtain_data_cont0
        gps_obtain_data_cont3:
            ; TIMEZONE_SET? bit is not set:
            lcall ENTER_GPS_SET_TIMEZONE_STATE              ; go to GPS_SET_TIMEZONE_STATE
    gps_obtain_data_cont0:
ret

GPS_SET_TIMEZONE:
    ; Note:  12/24 hour adjust and displaying is done lower in this function

    ; Split the minutes
    mov a, MINUTES
    mov b, #0Ah
    div ab
    mov MIN_TENS, a
    mov MIN_ONES, b

    ; Display the timezone offset
    ; grids 4 through 9 are set in ENTER_GPS_SET_TIMEZONE_STATE
    mov a, TIMEZONE
    clr c
    subb a, #0Eh
    jnc gps_set_timezone_cont1
        ; UTC offset is negative, accumulator now holds 256 minus the negative offset
        mov GRID3, #0Ah             ; display '-' as a negative sign on grid 3
        ; get negative offset into accumulator by subtracting in opposite order
        clr c
        mov a, #0Eh
        subb a, TIMEZONE            ; accumulator now holds UTC negative offset
        sjmp gps_set_timezone_cont2
    gps_set_timezone_cont1:
        ; UTC offset is positive, accumulator now holds it
        mov GRID3, #0FFh            ; blank grid 3

    gps_set_timezone_cont2:
    ; the accumulator holds the UTC offset (either positive or negative), and the negative sign is already displayed / not displayed in grid 3
    ; display the UTC offset
    mov b, #0Ah
    div ab
    mov GRID2, a
    mov GRID1, b

    ; display the minutes
    mov NIX2, MIN_TENS
    mov NIX1, MIN_ONES

    ; calculate the hours with the UTC offset applied
    mov a, TIMEZONE
    add a, HOURS                    ; add HOURS to TIMEZONE
    clr c
    subb a, #0Eh                    ; remove the offset of TIMEZONE
    jnc gps_set_timezone_cont3      ; determine if the hours rolled under
        ; the hours rolled under, so wrap it around to 23 again
        add a, #18h                 ; add 24 (dec) to the accumulator to get the result within 0 and 23
        sjmp gps_set_timezone_cont4

    gps_set_timezone_cont3:
    ; the hours did not roll under, so check if the hours rolled over
    clr c
    subb a, #18h                    ; subtract 24 (dec) from the accumulator to determine if a is between 0 and 23 or above 23
    jnc gps_set_timezone_cont4
        ; the hours did not roll over, so add 24 (dec) back to the total to get the proper hours with UTC offset applied
        add a, #18h                 ; add 24 (dec) to the accumulator to get the result within 0 and 23

    gps_set_timezone_cont4:
    ; the hours with the UTC offset applied are in the accumulator and ready to display

    ; Taken care of with TWLV_TWFR_HOUR_ADJ
    ; mov b, #0Ah
    ; div ab
    ; mov NIX4, a
    ; mov NIX3, b

    ; Update the hours if 12/24 hour switch is flipped
    mov SET_TIMEZONE_HOURS, a   ; stage the hours with UTC offset applied
    mov R1, #6Bh                ; move the address of SET_TIMEZONE_HOURS into R1 (for TWLV_TWFR_HOUR_ADJ)
    lcall TWLV_TWFR_HOUR_ADJ

    ; check for a rotary encoder short press
    lcall CHECK_FOR_ROT_ENC_SHORT_PRESS
    jnb TRANSITION_STATE?, gps_set_timezone_cont0
        setb TIMEZONE_SET?                              ; indicate that the timezone has been set
        lcall APPLY_TIMEZONE_TO_UTC                     ; apply the set timezone to the current time registers which are holding UTC time
        lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE         ; if there was a short press (TRANSITION_STATE? bit is set), go to next state
    gps_set_timezone_cont0:
ret

; ========= Alarm State Functions ==========

ALARM_ENABLED:
    jnb P1.4, alarm_enabled_cont0                                       ; monitor the state of the alarm on/off switch
                                                                        ; alarm is enabled if P1.4 is high
        mov a, ALARM_HOURS                                              ; check if time to fire the alarm
        cjne a, HOURS, alarm_enabled_cont1                              ; compare alarm hours to current hours
            mov a, ALARM_MINUTES
            cjne a, MINUTES, alarm_enabled_cont1                        ; compare alarm minutes to current minutes
                mov a, #00h
                cjne a, SECONDS, alarm_enabled_cont1                    ; compare current seconds to 0
                    ; it is currently the right time to fire the alarm
                    ; TODO:  check if we are in a set time or set alarm state, in which case don't fire the alarm (jump to alarm_enabled_cont1)

                    lcall ALARM_ENABLED_STATE_TO_ALARM_FIRING_STATE     ; transition to alarm firing state
                    sjmp alarm_enabled_cont1

    alarm_enabled_cont0:                                                ; alarm is disabled if P1.4 is low
        lcall ALARM_ENABLED_STATE_TO_ALARM_DISABLED_STATE               ; transistion to alarm disabled state
    alarm_enabled_cont1:
ret

ALARM_DISABLED:
    jnb P1.4, alarm_disabled_cont0                                      ; monitor the state of the alarm on/off switch
                                                                        ; alarm is enabled if P1.4 is high
        lcall ALARM_DISABLED_STATE_TO_ALARM_ENABLED_STATE               ; transition to alarm enabled state
    alarm_disabled_cont0:
ret

ALARM_FIRING:
    ; snooze events are detected in CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS, which calls ALARM_FIRING_STATE_TO_ALARM_SNOOZING_STATE,
    ; so the only event to detect here is if the alarm switch turns off.

    jb P1.4, alarm_firing_cont0                                         ; monitor the state of the alarm on/off switch
        lcall ALARM_FIRING_STATE_TO_ALARM_DISABLED_STATE                ; alarm is disabled, so transition to alarm disabled state
    alarm_firing_cont0:
ret

ALARM_SNOOZING:
    jb P1.4, alarm_snoozing_cont2
    ; jnb P1.4, alarm_snoozing_cont0                                        ; monitor the state of the alarm on/off switch
    ;                                                                   ; alarm is enabled if P1.4 is high
    ;   mov a, SNOOZE_MINUTES                                           ; check if time to fire the alarm
    ;   cjne a, MINUTES, alarm_snoozing_cont1                           ; compare snooze minutes to current minutes
    ;       mov a, #00h
    ;       cjne a, SECONDS, alarm_snoozing_cont1                       ; compare current seconds to 0
    ;           ; TODO:  don't actually fire the alarm if the clock is in SET_TIME_STATE or SET_ALARM_STATE
    ;           lcall ALARM_SNOOZING_STATE_TO_ALARM_FIRING_STATE        ; transition to alarm firing state
    ;           sjmp alarm_snoozing_cont2

    alarm_snoozing_cont0:                                               ; alarm is disabled if P1.4 is low
        lcall ALARM_SNOOZING_STATE_TO_ALARM_DISABLED_STATE              ; transistion to alarm disabled state
        sjmp alarm_snoozing_cont2

    ; alarm_snoozing_cont1:                                                 ; check if alarm or time has changed
    ; ; TODO:  FILL THIS IN -- if no time or alarm change, jump to alarm_snoozing_cont2 to keep snoozing
    ;   ; lcall ALARM_SNOOZING_STATE_TO_ALARM_ENABLED_STATE

    alarm_snoozing_cont2:
ret

; ==========================================

TIMER_0_SERVICE:
    ; push any used SFRs onto the stack to preserve their values
    push acc
    push PSW
    push 6

    ; ===========================================================
    ; Check if DECA_STATE = DECA_FILL_UP_STATE
    mov a, DECA_STATE
    cjne a, #DECA_FILL_UP_STATE, timer_0_service_cont4
        ; ; check if transition is into DECA_SCROLLING_STATE
        ; jb TO_SCROLLING?, timer_0_service_cont15
            ; transition is into DECA_COUNTING_SECONDS_STATE
            mov a, SECONDS                                      ; check if finished with the transition (DECATRON = SECONDS)
            cjne a, DECATRON, timer_0_service_cont5             ; check if decatron is displaying current seconds
                lcall ENTER_DECA_COUNTING_SECONDS_STATE         ; transition to DECA_COUNTING_SECONDS_STATE
                clr DECA_IN_TRANSITION?                         ; clear the transition bit
                ljmp timer_0_service_cont5

        ; timer_0_service_cont15:
        ;   ; transition is into DECA_SCROLLING_STATE
        ;   ; check if finished with the transition (DECATRON = number of pins to light up in this menu)
        ;   mov a, NUMBER_OF_ACTIVE_SETTINGS

        ;   cjne a, #08h, timer_0_service_cont20
        ;       ; NUMBER_OF_ACTIVE_SETTINGS is 8
        ;       mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_8_SETTINGS      ; DPTR points to the start of the lookup table
        ;       sjmp timer_0_service_cont21

        ;   timer_0_service_cont20:
        ;   cjne a, #07h, timer_0_service_cont22
        ;       ; NUMBER_OF_ACTIVE_SETTINGS is 7
        ;       mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_7_SETTINGS      ; DPTR points to the start of the lookup table
        ;       sjmp timer_0_service_cont21

        ;   timer_0_service_cont22:
        ;       ; NUMBER_OF_ACTIVE_SETTINGS is 5
        ;       mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_5_SETTINGS      ; DPTR points to the start of the lookup table

        ;   timer_0_service_cont21:
        ;   mov a, SETTINGS_SUB_STATE                               ; SETTINGS_SUB_STATE is the offset from the start of the lookup table
        ;   dec a                                                   ; decrement a such that lookup table offset is right (NOTE: lookup tables
        ;                                                           ; load (a+1)th item in lookup table)
        ;   movc a, @a + DPTR                                       ; moves the (a+1)th lookup table item into the accumulator
        ;   cjne a, DECATRON, timer_0_service_cont5                 ; check if decatron is displaying the number of pins for this menu item
        ;       lcall ENTER_DECA_SCROLLING_STATE                    ; transition to DECA_SCROLLING_STATE
        ;       clr DECA_IN_TRANSITION?                             ; clear the transition bit
        ;       clr TO_SCROLLING?                                   ; clear the transition to scrolling bit

        timer_0_service_cont5:
        ; if DECA_STATE is DECA_FILL_UP_STATE, increment DECATRON with every 30Hz interrupt
        inc DECATRON
        ; it is possible for DECATRON to wrap around 60 before it matches SECONDS, so roll over DECATRON if needed
        mov a, DECATRON
        cjne a, #3Ch, timer_0_service_cont4                     ; check if DECATRON = 60 (dec)
            mov DECATRON, #00h                                  ; move 0 into DECATRON

    timer_0_service_cont4:

    ; ===========================================================
    ; Check if DECA_STATE = DECA_FAST_STATE
    mov a, DECA_STATE
    cjne a, #DECA_FAST_STATE, timer_0_service_cont7
        ; check if transitioning
        jnb DECA_IN_TRANSITION?, timer_0_service_cont6
            jb TO_COUNTDOWN?, timer_0_service_cont10                ; check if transition is into DECA_COUNTING_SECONDS_STATE
                jb TO_SCROLLING?, timer_0_service_cont15            ; check if transition is into DECA_SCROLLING_STATE
                    ; check if finished with the transition (DECATRON = SECONDS)
                    mov a, SECONDS
                    cjne a, DECATRON, timer_0_service_cont6         ; check if decatron is displaying current seconds
                        lcall ENTER_DECA_COUNTING_SECONDS_STATE     ; transition to DECA_COUNTING_SECONDS_STATE
                        clr DECA_IN_TRANSITION?                     ; clear the transition bit
                        ljmp timer_0_service_cont7

            timer_0_service_cont10:                                 ; transition is into DECA_COUNTDOWN_STATE
                ; check if finished with the transition (DECATRON = 30 dec)
                mov a, #1Eh
                cjne a, DECATRON, timer_0_service_cont6             ; check if decatron is displaying 30
                    lcall ENTER_DECA_COUNTDOWN_STATE                ; transition to DECA_COUNTDOWN_STATE
                    clr DECA_IN_TRANSITION?                         ; clear the transition bit
                    clr TO_COUNTDOWN?                               ; clear the transition to countdown bit
                    ljmp timer_0_service_cont7

            timer_0_service_cont15:                                 ; transition is into DECA_SCROLLING_STATE
                ; check if finished with the transition (DECATRON = number of pins to light up in this menu)
                mov a, NUMBER_OF_ACTIVE_SETTINGS

                cjne a, #08h, timer_0_service_cont20
                    ; NUMBER_OF_ACTIVE_SETTINGS is 8
                    mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_8_SETTINGS      ; DPTR points to the start of the lookup table
                    sjmp timer_0_service_cont21

                timer_0_service_cont20:
                cjne a, #07h, timer_0_service_cont22
                    ; NUMBER_OF_ACTIVE_SETTINGS is 7
                    mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_7_SETTINGS      ; DPTR points to the start of the lookup table
                    sjmp timer_0_service_cont21

                timer_0_service_cont22:
                    ; NUMBER_OF_ACTIVE_SETTINGS is 5
                    mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_5_SETTINGS      ; DPTR points to the start of the lookup table

                timer_0_service_cont21:
                mov a, SETTINGS_SUB_STATE                               ; SETTINGS_SUB_STATE is the offset from the start of the lookup table
                dec a                                                   ; decrement a such that lookup table offset is right (NOTE: lookup tables
                                                                        ; load (a+1)th item in lookup table)
                movc a, @a + DPTR                                       ; moves the (a+1)th lookup table item into the accumulator
                cjne a, DECATRON, timer_0_service_cont6                 ; check if decatron is displaying the number of pins for this menu item
                    lcall ENTER_DECA_SCROLLING_STATE                    ; transition to DECA_SCROLLING_STATE
                    clr DECA_IN_TRANSITION?                             ; clear the transition bit
                    clr TO_SCROLLING?                                   ; clear the transition to scrolling bit
                    sjmp timer_0_service_cont7

        timer_0_service_cont6:
        ; if DECA_STATE is DECA_FAST_STATE, increment DECATRON with every 60Hz interrupt
        inc DECATRON
        ; check if we need to wrap DECATRON around 60
        mov a, DECATRON
        cjne a, #3Ch, timer_0_service_cont7                     ; check if DECATRON = 60 (dec)
            mov DECATRON, #00h                                  ; move 0 into DECATRON

    timer_0_service_cont7:

    ; ===========================================================
    ; Check if DECA_STATE = DECA_COUNTDOWN_STATE
    mov a, DECA_STATE
    cjne a, #DECA_COUNTDOWN_STATE, timer_0_service_cont8
        ; if DECA_STATE is DECA_COUNTDOWN_STATE, decrement SNOOZE_COUNT_PER_DECA_PIN each second
        djnz SNOOZE_COUNT_PER_DECA_PIN, timer_0_service_cont8
            mov SNOOZE_COUNT_PER_DECA_PIN, SNOOZE_COUNT_PER_DECA_PIN_RELOAD     ; reload SNOOZE_COUNT_PER_DECA_PIN
            djnz DECATRON, timer_0_service_cont8                                ; decrement DECATRON and check if reached zero
                ; mov DECATRON, #01h                                                ; to prevent decatron from blanking
                lcall ALARM_SNOOZING_STATE_TO_ALARM_FIRING_STATE                ; fire alarm
                ; At this point, the seconds should be incremented, but the above alarm transition overwrites TIMER_0_POST_SCALER
                ; before we have the chance to decrement and check if it is zero.  Thus, jump directly into the 1Hz portion of
                ; this function to avoid the bug of unintentionally delaying the time by a second.
                ljmp timer_0_service_cont16
        timer_0_service_cont8:

    ; ===========================================================
    ; Check if DECA_STATE = DECA_RADAR_STATE
    mov a, DECA_STATE
    cjne a, #DECA_RADAR_STATE, timer_0_service_cont9
        ; if DECA_STATE is DECA_RADAR_STATE, increment DECA_LOAD_STATE, or reset to 0 if it equals 2
        mov a, DECA_LOAD_STATE
        cjne a, #02h, timer_0_service_cont13
            mov DECA_LOAD_STATE, #00h
            sjmp timer_0_service_cont9
        timer_0_service_cont13:
        inc DECA_LOAD_STATE
    timer_0_service_cont9:

    ; ===========================================================
    ; Normal TIMER_0_ISR:
    djnz TIMER_0_POST_SCALER, timer_0_service_cont1
        timer_0_service_cont16:
        ; --- the following code is called at 1Hz ---
        mov TIMER_0_POST_SCALER, TIMER_0_POST_SCALER_RELOAD     ; reload TIMER_0_POST_SCALER

        ; check if CLOCK_STATE = SHOW_TIME_STATE, in which case timeouts are inactive
        mov a, CLOCK_STATE
        cjne a, #SHOW_TIME_STATE, timer_0_serivce_cont11
            sjmp timer_0_service_cont12
        timer_0_serivce_cont11:
        ; check if CLOCK_STATE = GPS_SYNC_STATE and if GPS_SYNC_SUB_STATE = GPS_SET_TIMEZONE_STATE, in which case timeouts are inactive
        cjne a, #GPS_SYNC_STATE, timer_0_service_cont14
            mov a, GPS_SYNC_SUB_STATE
            cjne a, #GPS_SET_TIMEZONE_STATE, timer_0_service_cont14
                sjmp timer_0_service_cont12
        timer_0_service_cont14:
        dec TIMEOUT             ; decrement TIMEOUT (will check if TIMEOUT = 0 in the respective state)
        timer_0_service_cont12:

        ; check if ALARM_STATE = ALARM_FIRING_STATE
        mov a, ALARM_STATE
        cjne a, #ALARM_FIRING_STATE, timer_0_service_cont3
            cpl P1.1            ; toggle buzzer
        timer_0_service_cont3:

        inc SECONDS             ; increment the seconds
        mov R6, SECONDS
        cjne R6, #3Ch, timer_0_service_cont1
            mov SECONDS, #00h

            ; check if in SET_TIME_STATE, in which case, don't roll the seconds over into the minutes
            mov a, CLOCK_STATE
            cjne a, #SET_TIME_STATE, timer_0_service_cont2
                ljmp timer_0_service_cont1
            timer_0_service_cont2:

            inc MINUTES
            mov R6, MINUTES
            cjne R6, #3Ch, timer_0_service_cont1
                mov MINUTES, #00h
                inc HOURS
                mov R6, HOURS
                cjne R6, #18h, timer_0_service_cont1  ; if hours is 24 decimal, new day
                    mov HOURS, #00h
                    lcall INCREMENT_DAY
    timer_0_service_cont1:

    ; pop the original SFR values back into their place and restore their values
    pop 6
    pop PSW
    pop acc
ret

TIMER_1_SERVICE:
    push acc
    push PSW

    ; Reset timer 1
    ; Initialize TL1 and TH1 for timer 1 16 bit timing for maximum count
    mov TL1, #00h
    mov TH1, #00h

    setb P1.1           ; regardless of state, turn off the buzzer

    mov a, CLOCK_STATE
    ; check if CLOCK_STATE is GPS_SYNC_STATE
    cjne a, #GPS_SYNC_STATE, timer_1_service_cont2
        mov a, GPS_SYNC_SUB_STATE
        ; check if GPS_SYNC_SUB_STATE is GPS_OBTAIN_FIX_STATE
        cjne a, #GPS_OBTAIN_FIX_STATE, timer_1_service_cont2
            jnb P1.3, timer_1_service_cont0                         ; check if GPS fix is HIGH/LOW
                ; if GPS fix is high
                mov GPS_FIX_LPF, #14h                               ; if GPS fix is HIGH (i.e. no GPS fix), reload GPS_FIX_LPF with 20 (decimal)
                djnz GPS_FIX_HIGH_TIMEOUT, timer_1_service_cont1
                    ; if GPS fix stays high for ~2.5 seconds, assume there is no GPS connected and transition state:
                    clr GPS_PRESENT?
                    lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE
                    ljmp timer_1_service_cont1                      ; jump to the end of the ISR
            timer_1_service_cont0:
                ; if GPS fix is low:
                setb GPS_PRESENT?                                   ; since GPS fix went low, we know there is a GPS present
                mov GPS_FIX_HIGH_TIMEOUT, #020h                     ; re-load 32 (dec) into GPS_FIX_HIGH_TIMEOUT
                djnz GPS_FIX_LPF, timer_1_service_cont1
                    ; GPS fix has been low for more than ~1.3 seconds
                    lcall ENTER_GPS_OBTAIN_DATA_STATE
                    ljmp timer_1_service_cont1

    timer_1_service_cont2:
        ; for beep mode:
        clr TR1             ; turn off timer 1
        clr ET1             ; disable timer 1 overflow interrupt

    timer_1_service_cont1:

    pop PSW
    pop acc
ret

SERIAL_SERVICE:
    ; Uses a to store the received SBUF data
    ; Uses R3 to store the GPS_OBTAIN_DATA_SUB_STATE
    ; Uses R6 as a counter (for loops)
    ; Uses R1 as a data pointer
    
    ; push registers/accumulator
    push acc
    push PSW        ; necessary because cjne commands affect the carry bit
    ; push 0
    push 1
    push 3
    ; do NOT push or pop R6 -- this value needs to be retained between serial interrupts

    ; NMEA $GPRMC sentence after fix:
    ; $GPRMC,hhmmss.sss,A,llll.llll,a,yyyyy.yyyy,a,v.vv,ttt.tt,ddmmyy,,,A*77
    ; $GPRMC,040555.000,A,3725.4817,N,12209.5683,W,0.42,201.93,070320,,,D*78

    mov a, SBUF                                                             ; move SBUF into a
    mov R3, GPS_OBTAIN_DATA_SUB_STATE                                       ; move GPS_OBTAIN_DATA_SUB_STATE into R3

    ; We use the GPS_WAIT state for information not needed, like commas, speed, or magnetic variation
    ; Wait uses GPS_WAIT_TIME to determine how many received bytes to wait out
    ; GPS_WAIT:
    cjne R3, #GPS_WAIT, serial_service_cont0
        mov R6, #00h                                                        ; R6 keeps track of how many times things loop (like how long to loop
                                                                            ; in the GPS_WAIT_FOR_TIME state)   
        xrl CALCULATED_GPS_CHECKSUM, a                                      ; keep updating the CALCULATED_GPS_CHECKSUM
        djnz GPS_WAIT_TIME, gps_wait_cont0                                  ; decrement until done waiting
            mov GPS_OBTAIN_DATA_SUB_STATE, GPS_OBTAIN_DATA_NEXT_SUB_STATE   ; if wait is over, load GPS_OBTAIN_DATA_SUB_STATE with the next state.
        gps_wait_cont0:
            ljmp serial_service_end                                         ; jump to end
    serial_service_cont0:

    ; "$"
    ; GPS_WAIT_FOR_DOLLAR:
    cjne R3, #GPS_WAIT_FOR_DOLLAR, serial_service_cont1
        cjne a, #24h, gps_wait_for_dollar_cont0                             ; check if received serial data is "$"
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_G                  ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
        gps_wait_for_dollar_cont0:
            ljmp serial_service_end                                         ; jump to end
    serial_service_cont1:

    ; "G"
    ; GPS_WAIT_FOR_G:
    cjne R3, #GPS_WAIT_FOR_G, serial_service_cont2
        cjne a, #47h, gps_wait_for_g_cont0                                  ; check if received serial data is "G"
            mov CALCULATED_GPS_CHECKSUM, a                                  ; initialize the CALCULATED_GPS_CHECKSUM (check sum does NOT include
                                                                            ; the "$" or "*" delimiters)
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_P                  ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
        gps_wait_for_g_cont0:
            ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE                     ; reset GPS_OBTAIN_DATA_SUB_STATE
    serial_service_cont2:

    ; "P"
    ; GPS_WAIT_FOR_P:
    cjne R3, #GPS_WAIT_FOR_P, serial_service_cont3
        cjne a, #50h, gps_wait_for_p_cont0                                  ; check if received serial data is "P"
            xrl CALCULATED_GPS_CHECKSUM, a                                  ; update the CALCULATED_GPS_CHECKSUM
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_R                  ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
        gps_wait_for_p_cont0:
            ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE                     ; reset GPS_OBTAIN_DATA_SUB_STATE
    serial_service_cont3:

    ; "R"
    ; GPS_WAIT_FOR_R:
    cjne R3, #GPS_WAIT_FOR_R, serial_service_cont4
        cjne a, #52h, gps_wait_for_r_cont0                                  ; check if received serial data is "R"
            xrl CALCULATED_GPS_CHECKSUM, a                                  ; update the CALCULATED_GPS_CHECKSUM
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_M                  ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
        gps_wait_for_r_cont0:
            ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE                     ; reset GPS_OBTAIN_DATA_SUB_STATE
    serial_service_cont4:

    ; "M"
    ; GPS_WAIT_FOR_M:
    cjne R3, #GPS_WAIT_FOR_M, serial_service_cont5
        cjne a, #4Dh, gps_wait_for_m_cont0                                  ; check if received serial data is "M"
            xrl CALCULATED_GPS_CHECKSUM, a                                  ; update the CALCULATED_GPS_CHECKSUM
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_C                  ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
        gps_wait_for_m_cont0:
            ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE                     ; reset GPS_OBTAIN_DATA_SUB_STATE
    serial_service_cont5:

    ; "C"
    ; GPS_WAIT_FOR_C:
    cjne R3, #GPS_WAIT_FOR_C, serial_service_cont6
        cjne a, #43h, gps_wait_for_c_cont0                                  ; check if received serial data is "C"
            xrl CALCULATED_GPS_CHECKSUM, a                                  ; update the CALCULATED_GPS_CHECKSUM
            mov GPS_WAIT_TIME, #01h                                         ; wait out "," (one byte)
            mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_TIME          ; load next state for after un-needed byte(s) are received
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT                        ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
        gps_wait_for_c_cont0:
            ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE                     ; reset GPS_OBTAIN_DATA_SUB_STATE
    serial_service_cont6:

    ; Time
    ; GPS_WAIT_FOR_TIME:
    cjne R3, #GPS_WAIT_FOR_TIME, serial_service_cont7
        ; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
        ; ascii code for 0: #30h -> hex code for 0: #00h
        ; ascii code for 1: #31h -> hex code for 1: #01h
        ; ascii code for 2: #32h -> hex code for 1: #02h
        ; etc....
        xrl CALCULATED_GPS_CHECKSUM, a                                      ; update the CALCULATED_GPS_CHECKSUM
        inc R6                                                              ; increment R6
        anl a, #0Fh                                                         ; bitwise AND received ascii with 00001111 (result is stored in a)
        mov R1, GPS_POINTER
        mov @R1, a                                                          ; move the data in a into location GPS_POINTER is pointing
        inc GPS_POINTER                                                     ; update GPS_POINTER pointer to next memory location
        cjne R6, #06h, gps_wait_for_time_cont0                              ; check if R6 (number of times we have looped) is equal to 6 (6 =
                                                                            ; number of received bytes for HH MM SS)
            mov GPS_WAIT_TIME, #05h                                         ; wait out ".000," (5 bytes)
            mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_A             ; load next state for after un-needed byte(s) are received
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT                        ; update GPS_OBTAIN_DATA_SUB_STATE
        gps_wait_for_time_cont0:
            ljmp serial_service_end                                         ; jump to end
    serial_service_cont7:

    ; "A"
    ; GPS_WAIT_FOR_A:
    cjne R3, #GPS_WAIT_FOR_A, serial_service_cont8
        cjne a, #41h, gps_wait_for_a_cont0                                  ; check if received serial data is "A"
            xrl CALCULATED_GPS_CHECKSUM, a                                  ; update the CALCULATED_GPS_CHECKSUM
            ; mov GPS_WAIT_TIME, #01h                                       ; wait out "," (one byte)
            mov GPS_WAIT_TIME, #26h                                         ; wait out ",llll.llll,a,yyyyy.yyyy,a,v.vv,ttt.tt," (38 bytes)
                                                                            ; we are NOT saving latitude and longitude data from GPS
            ; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_LATITUDE    ; load next state for after un-needed byte(s) are received
            mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_DATE          ; load next state for after un-needed byte(s) are received
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT                        ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
        gps_wait_for_a_cont0:
            ljmp serial_reset_GPS_OBTAIN_DATA_SUB_STATE                     ; reset GPS_OBTAIN_DATA_SUB_STATE
    serial_service_cont8:

    ; DO NOT SAVE LATITUDE OR LONGITUDE DATA
    ; ; Latitude
    ; ; GPS_WAIT_FOR_LATITUDE:
    ; cjne R3, #GPS_WAIT_FOR_LATITUDE, serial_service_cont9
    ;   ; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
    ;   ; ascii code for 0: #30h -> hex code for 0: #00h
    ;   ; ascii code for 1: #31h -> hex code for 1: #01h
    ;   ; ascii code for 2: #32h -> hex code for 1: #02h 
    ;   ; etc....
    ;   xrl CALCULATED_GPS_CHECKSUM, a                                      ; update the CALCULATED_GPS_CHECKSUM
    ;   inc R6                                                              ; increment R6
    ;   cjne a, #2Eh, check_lat_for_comma                                   ; check if "." was received
    ;       ljmp serial_service_end                                         ; if we receive a ".", we don't want to store it - jump to end
    ;   check_lat_for_comma:
    ;   cjne a, #2Ch, load_lat_data                                         ; check if "," was received
    ;       ljmp serial_service_end                                         ; if we receive a ",", we don't want to store it - jump to end
    ;   load_lat_data:                                                      ; keep loading data
    ;   anl a, #0Fh                                                         ; bitwise AND received ascii with 00001111 (result is stored in a)
    ;   mov R1, GPS_POINTER
    ;   mov @R1, a                                                          ; move the data in a into location GPS_POINTER is pointing
    ;   inc GPS_POINTER                                                     ; update GPS_POINTER pointer to next memory location
    ;   cjne R6, #0Bh, serial_service_end                                   ; check if R6 (number of times we have looped) is equal to 11 (11 =
    ;                                                                       ; number of received bytes for llll.llll,a)
    ;       ; on the last latitude byte, we actually don't want to apply the 00001111 mask (the last byte is a letter), so re-write the final byte
    ;       dec GPS_POINTER                                                 ; decrement pointer
    ;       mov R1, GPS_POINTER
    ;       mov @R1, SBUF                                                   ; re-write ascii data (letter) into @R1
    ;       inc GPS_POINTER                                                 ; update pointer
    ;       mov GPS_WAIT_TIME, #01h                                         ; wait out "," (1 byte)
    ;       mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_LONGITUDE     ; load next state for after un-needed byte(s) are received
    ;       ; mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #0Bh                      ; load next state for after un-needed byte(s) are received
    ;       mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT                        ; update GPS_OBTAIN_DATA_SUB_STATE
    ;       ; mov GPS_OBTAIN_DATA_SUB_STATE, #01h                           ; update GPS_OBTAIN_DATA_SUB_STATE
    ;       ljmp serial_service_end                                         ; jump to end
    ; serial_service_cont9:

    ; ; Longitude
    ; ; GPS_WAIT_FOR_LONGITUDE:
    ; cjne R3, #GPS_WAIT_FOR_LONGITUDE, serial_service_cont10
    ;   ; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
    ;   ; ascii code for 0: #30h -> hex code for 0: #00h
    ;   ; ascii code for 1: #31h -> hex code for 1: #01h
    ;   ; ascii code for 2: #32h -> hex code for 1: #02h 
    ;   ; etc....
    ;   xrl CALCULATED_GPS_CHECKSUM, a                                      ; update the CALCULATED_GPS_CHECKSUM
    ;   inc R6                                                              ; increment R6
    ;   cjne a, #2Eh, check_long_for_comma                                  ; check if "." was received
    ;       ljmp serial_service_end                                         ; if we receive a ".", we don't want to store it - jump to end
    ;   check_long_for_comma:
    ;   cjne a, #2Ch, load_long_data                                        ; check if "," was received
    ;       ljmp serial_service_end                                         ; if we receive a ",", we don't want to store it - jump to end
    ;   load_long_data:                                                     ; keep loading data
    ;   anl a, #0Fh                                                         ; bitwise AND received ascii with 00001111 (result is stored in a)
    ;   mov R1, GPS_POINTER
    ;   mov @R1, a                                                          ; move the data in a into location GPS_POINTER is pointing
    ;   inc GPS_POINTER                                                     ; update GPS_POINTER pointer to next memory location
    ;   cjne R6, #0Ch, serial_service_end                                   ; check if R6 (number of times we have looped) is equal to 12 (12 =
    ;                                                                       ; number of received bytes for yyyyy.yyyy,a)
    ;       ; on the last longitude byte, we actually don't want to apply the 00001111 mask (the last byte is a letter), so re-write the final byte
    ;       dec GPS_POINTER                                                 ; decrement pointer
    ;       mov R1, GPS_POINTER
    ;       mov @R1, SBUF                                                   ; re-write ascii data (letter) into @R1
    ;       inc GPS_POINTER                                                 ; update pointer                                            
    ;       mov GPS_WAIT_TIME, #0Dh                                         ; wait out ",v.vv,ttt.tt," (13 bytes)
    ;       mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_DATE          ; load next state for after un-needed byte(s) are received
    ;       mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT                        ; update GPS_OBTAIN_DATA_SUB_STATE
    ;       ljmp serial_service_end                                         ; jump to end
    ; serial_service_cont10:

    ; Date
    ; GPS_WAIT_FOR_DATE:
    cjne R3, #GPS_WAIT_FOR_DATE, serial_service_cont11
        ; NOTE: in this state, we change received ascii code to hex code by bitwise AND with mask: 00001111 = #0Fh.
        ; ascii code for 0: #30h -> hex code for 0: #00h
        ; ascii code for 1: #31h -> hex code for 1: #01h
        ; ascii code for 2: #32h -> hex code for 2: #02h 
        ; etc....
        xrl CALCULATED_GPS_CHECKSUM, a                                      ; update the CALCULATED_GPS_CHECKSUM
        inc R6                                                              ; increment R6
        anl a, #0Fh                                                         ; bitwise AND received ascii with 00001111 (result is stored in a)
        mov R1, GPS_POINTER
        mov @R1, a                                                          ; move the data in a into location GPS_POINTER is pointing
        inc GPS_POINTER                                                     ; update GPS_POINTER pointer to next memory location
        cjne R6, #06h, serial_service_end                                   ; check if R6 (number of times we have looped) is equal to 6 (6 =
                                                                            ; number of received bytes for ddmmyy)
            mov GPS_WAIT_TIME, #04h                                         ; wait out ",,,A" (4 bytes)
            mov GPS_OBTAIN_DATA_NEXT_SUB_STATE, #GPS_WAIT_FOR_STAR          ; load next state for after un-needed byte(s) are received
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT                        ; update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
    serial_service_cont11:

    ; "*"
    ; GPS_WAIT_FOR_STAR:
    cjne R3, #GPS_WAIT_FOR_STAR, serial_service_cont12
        cjne a, #2Ah, serial_reset_GPS_OBTAIN_DATA_SUB_STATE                ; check if received serial data is "*"
            mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_CHECKSUM           ; if received correct character, update GPS_OBTAIN_DATA_SUB_STATE
            ljmp serial_service_end                                         ; jump to end
    serial_service_cont12:

    ; Checksum
    ; GPS_WAIT_FOR_CHECKSUM:
    cjne R3, #GPS_WAIT_FOR_CHECKSUM, serial_service_cont13
        inc R6                                                              ; increment R6
        lcall ASCII_TO_HEX                                                  ; convert ascii to hex
        cjne R6, #01h, append_low_nibble                                    ; check if we received our first checksum byte
            swap a                                                          ; if this is our first checksum byte, we want to swap accumulator
                                                                            ; nibbles (i.e. #01h -> #10h)
            mov RECEIVED_GPS_CHECKSUM, a                                    ; move partial result into RECEIVED_GPS_CHECKSUM
            ljmp serial_service_end                                         ; jump to end
        append_low_nibble:
            orl a, RECEIVED_GPS_CHECKSUM                                    ; append the low nibble by bitwise OR (NOTE: the lower nibble of
                                                                            ; RECEIVED_GPS_CHECKSUM should be 0)!
            mov RECEIVED_GPS_CHECKSUM, a                                    ; move the final result into RECEIVED_GPS_CHECKSUM
            cjne a, CALCULATED_GPS_CHECKSUM, serial_reset_GPS_OBTAIN_DATA_SUB_STATE     ; compare RECEIVED_GPS_CHECKSUM (which should still be
                                                                                        ; in a) with the CALCULATED_GPS_CHECKSUM
                ; HAVE RECEIVED COMPLETE GPS NMEA $GPRMC SENTENCE
                setb P1.7                                                   ; turn on GPS SYNC light
                lcall LOAD_GPS_DATA                                         ; load values into SECONDS, MINUTES, HOURS, DAY, MONTH, and YEAR

                ; Block below may be causing bug, so moved into a function (GPS_OBTAIN_DATA) called by MAIN 7/31/2020
                ; ; check TIMEZONE_SET? bit
                ; jb TIMEZONE_SET?, serial_service_cont14                   
                ;   ; if TIMEZONE_SET? bit is not set, let user input timezone
                ;   lcall ENTER_GPS_SET_TIMEZONE_STATE                      ; update GPS_SYNC_SUB_STATE
                ;   sjmp serial_service_end
                ; serial_service_cont14:
                ;   ; if TIMEZONE_SET? bit is set, user has already set timezone, so go directly to SHOW_TIME_STATE
                ;   lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE
                ;   sjmp serial_service_end                                 ; jump to end

    serial_service_cont13:

    ; Reset
    serial_reset_GPS_OBTAIN_DATA_SUB_STATE:
        mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_DOLLAR                 ; Reset GPS_OBTAIN_DATA_SUB_STATE
        mov GPS_POINTER, #08h                                               ; load GPS_POINTER with memory address of RECEIVED_GPS_HRS_TENS

    ; End
    serial_service_end:

    ; pop registers/accumulator
    ; do NOT push or pop R6
    pop 3
    pop 1
    ; pop 0
    pop PSW
    pop acc 
ret

; ====== State Transition Functions ======
; Hardware button events =================
CHECK_FOR_ROT_ENC_SHORT_PRESS:
    ; This function is used to transition between sub-states, such as SET_MM, SET_DD, etc. in SET_TIME_STATE
    clr TRANSITION_STATE?                           ; clear the TRANSITION_STATE? bit

    jnb P3.6, check_short_press_cont0               ; check if rotary encoder is still pressed
        clr BUTTON_FLAG                             ; if not, clear the encoder button flag
    check_short_press_cont0:

    jb BUTTON_FLAG, check_short_press_cont1         ; check to make sure BUTTON_FLAG is cleared
        jb P3.6, check_short_press_cont1            ; check if rotary encoder button is pressed
            ; mov R2, #28h                          ; load R2 for 40 counts
            ; mov R2, #14h                          ; load R2 for 20 counts
            mov R2, #0Ah
            mov R3, #0FFh                           ; load R3 for 255 counts
            check_short_press_loop0:                ; rotary encoder button must be depressed for ~20ms before time/date can be
                                                    ; changed (also acts as debounce)
                jb P3.6, check_short_press_cont1    ; check if rotary encoder button is still pressed
                djnz R3, check_short_press_loop0    ; decrement count in R3
            mov R3, #0FFh                           ; reload R3 in case loop is needed again
            djnz R2, check_short_press_loop0        ; count R3 down again until R2 counts down
            setb BUTTON_FLAG                        ; set the BUTTON_FLAG
            setb TRANSITION_STATE?                  ; set the TRANSITION_STATE? bit
            lcall BEEP                              ; beep
    check_short_press_cont1:
ret

CHECK_FOR_ROT_ENC_SHORT_OR_LONG_PRESS:
    ; This function is used to transition between states, such as SET_TIME_STATE, SHOW_ALARM_STATE, etc.
    ; This function listens for a rotary encoder short or long button press and determines which state to
    ; go to next based on the current CLOCK_STATE

    jnb P3.6, cont14                    ; check if rotary encoder is still pressed
        clr BUTTON_FLAG                 ; if not, clear the encoder button flag
    cont14:

    jb BUTTON_FLAG, cont15                  ; check to make sure BUTTON_FLAG is cleared
        jb P3.6, cont15                     ; check if rotary encoder button is pressed
            ; mov R2, #0FFh                 ; load R2 for 255 counts
            mov R2, #0B0h                   ; load R2 for 176 counts
            mov R3, #0FFh                   ; load R3 for 255 counts
            loop3:                          ; rotary encoder button must be depressed for ~130ms before time/date can be changed
                                            ; (also acts as debounce)
                jb P3.6, cont15             ; check if rotary encoder button is still pressed
                djnz R3, loop3              ; decrement count in R3
            mov R3, #0FFh                   ; reload R3 in case loop is needed again
            ; cjne R2, #0E1h, cont16            ; check if R2 has been decrement enough for a "short press"
            cjne R2, #0A6h, cont16          ; check if R2 has been decrement enough for a "short press"

                mov a, ALARM_STATE                                      ; check if alarm is firing
                cjne a, #ALARM_FIRING_STATE, cont20
                    ; if ALARM_STATE = ALARM_FIRING_STATE:
                    lcall ALARM_FIRING_STATE_TO_ALARM_SNOOZING_STATE    ; snooze the alarm
                    ljmp cont19             ; jump to end and set BUTTON_FLAG
                cont20:                     ; alarm is not firing, so interpret rotary encoder activity for CLOCK_STATE transitions
                
                ; if there has been a rot enc short press, determine next state based on current state
                mov a, CLOCK_STATE                  ; move the CLOCK_STATE into the accumulator
                cjne a, #SHOW_TIME_STATE, cont17
                    ; if CLOCK_STATE = SHOW_TIME_STATE:
                    lcall BEEP
                    mov NEXT_CLOCK_STATE, #SHOW_ALARM_STATE
                    ljmp cont16
                cont17:
                ; only other possibility is that we are in SHOW_ALARM_STATE
                lcall BEEP
                mov NEXT_CLOCK_STATE, #SHOW_TIME_STATE      
            cont16:
            djnz R2, loop3                  ; count R3 down again until R2 counts down
            ; if there has been a rot enc long press, determine next state based on current state
            cjne a, #SHOW_TIME_STATE, cont18 
                ;if CLOCK_STATE = SHOW_TIME_STATE
                mov NEXT_CLOCK_STATE, #SET_TIME_STATE
                ljmp cont19
            cont18:
            ; only other possibility is that we are in SHOW_ALARM_STATE
            mov NEXT_CLOCK_STATE, #SET_ALARM_STATE
            cont19:
            setb BUTTON_FLAG                ; set the rotary encoder button flag
    cont15:
ret

CHECK_FOR_SETTINGS_BUTTON_SHORT_PRESS:
    ; This function is used to transition between SHOW_TIME and SETTINGS states
    clr TRANSITION_STATE?                           ; clear the TRANSITION_STATE? bit

    jnb P3.7, check_settings_short_press_cont0                  ; check if settings button is still pressed
        clr SETTINGS_BUTTON_FLAG                                ; if not, clear the settings button flag
    check_settings_short_press_cont0:

    jb SETTINGS_BUTTON_FLAG, check_settings_short_press_cont1   ; check to make sure SETTINGS_BUTTON_FLAG is cleared
        jb P3.7, check_settings_short_press_cont1               ; check if settings button is pressed
            ;mov R2, #14h                                       ; load R2 for 20 counts
            mov R2, #0Ah
            mov R3, #0FFh                                       ; load R3 for 255 counts
            check_settings_short_press_loop0:                   ; settings button must be depressed for ~20ms before settings state can be
                                                                ; changed (also acts as debounce)
                jb P3.7, check_settings_short_press_cont1       ; check if settings button is still pressed
                djnz R3, check_settings_short_press_loop0       ; decrement count in R3
            mov R3, #0FFh                                       ; reload R3 in case loop is needed again
            djnz R2, check_settings_short_press_loop0           ; count R3 down again until R2 counts down
            setb SETTINGS_BUTTON_FLAG                           ; set the SETTINGS_BUTTON_FLAG
            setb TRANSITION_STATE?                              ; set the TRANSITION_STATE? bit
            lcall BEEP
    check_settings_short_press_cont1:
ret

CHECK_FOR_REMOTE_BUTTON_SHORT_PRESS:
    ; This function is used to transition between SHOW_TIME and SHOW_ALARM states, and also activate snoozing
    clr TRANSITION_STATE?                                   ; clear the TRANSITION_STATE? bit

    jnb P0.5, check_remote_short_press_cont0                ; check if remote is still pressed
        clr REMOTE_BUTTON_FLAG                              ; if not, clear the remote button flag
    check_remote_short_press_cont0:

    jb REMOTE_BUTTON_FLAG, check_remote_short_press_cont1   ; check to make sure REMOTE_BUTTON_FLAG is cleared
        jb P0.5, check_remote_short_press_cont1             ; check if remote button is pressed
            ; mov R2, #28h                                  ; load R2 for 40 counts
            ; mov R2, #14h                                  ; load R2 for 20 counts
            mov R2, #0Ah
            mov R3, #0FFh                                   ; load R3 for 255 counts
            check_remote_short_press_loop0:                 ; remote button must be depressed for ~20ms before state
                                                            ; changed (also acts as debounce)
                jb P0.5, check_remote_short_press_cont1     ; check if remote button is still pressed
                djnz R3, check_remote_short_press_loop0     ; decrement count in R3
            mov R3, #0FFh                                   ; reload R3 in case loop is needed again
            djnz R2, check_remote_short_press_loop0         ; count R3 down again until R2 counts down

            ; Check if the alarm is firing
            mov a, ALARM_STATE
            cjne a, #ALARM_FIRING_STATE, check_remote_short_press_cont2
                ; if ALARM_STATE = ALARM_FIRING_STATE:
                lcall ALARM_FIRING_STATE_TO_ALARM_SNOOZING_STATE    ; snooze the alarm
                setb REMOTE_BUTTON_FLAG                             ; set the REMOTE_BUTTON_FLAG
                ljmp check_remote_short_press_cont1                 ; jump to end
            check_remote_short_press_cont2:                         ; alarm is not firing, so interpret rotary encoder activity for CLOCK_STATE transitions
            setb REMOTE_BUTTON_FLAG                                 ; set the REMOTE_BUTTON_FLAG    
            setb TRANSITION_STATE?                                  ; set the TRANSITION_STATE? bit
            lcall BEEP                                              ; beep
    check_remote_short_press_cont1:
ret

; Clock state machine transitions ========
SET_TIME_STATE_TO_SHOW_TIME_STATE:
    clr EX0                     ; disable external interrupt 0
    clr EX1                     ; disable external interrupt 1

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    mov SECONDS, #00h                           ; set seconds back to 0

    ; Turn off the VFD if DATE_ON? is not set
    jb DATE_ON?, set_time_state_to_show_time_state_cont0
        ; VFD should be off
        setb P1.0
    set_time_state_to_show_time_state_cont0:

    ; Update DECA_STATE
    lcall ENTER_DECA_COUNTING_SECONDS_STATE

    ; Change the clock state
    mov CLOCK_STATE, #SHOW_TIME_STATE           ; change state to SHOW_TIME_STATE
    ; lcall DECA_TRANSITION                         ; transition the decatron (MUST HAPPEN AFTER STATE CHANGE, 
    ;                                           ; OR FLASHING WILL CONTINUE IN DECA_TRANSITION)
ret

SHOW_TIME_STATE_TO_SHOW_ALARM_STATE:
    ; set timeout (10 seconds)
    ; mov TIMEOUT_LENGTH, #0Ah
    ; lcall ADJUST_TIMEOUT
    mov TIMEOUT_LENGTH, #0Ah
    mov TIMEOUT, TIMEOUT_LENGTH

    ; Have VFD display "ALarnn"
    mov GRID9, #0FFh    ; BLANK
    mov GRID8, #0FFh    ; BLANK
    mov GRID7, #0FFh    ; BLANK
    mov GRID6, #0Ch     ; "A"
    mov GRID5, #0Dh     ; "L"
    mov GRID4, #0Eh     ; "a"
    mov GRID3, #0Fh     ; "r"       
    mov GRID2, #011h    ; "n"
    mov GRID1, #011h    ; "n"

    ; turn on the VFD (always on when not in SHOW_TIME or GPS_SYNC)
    clr P1.0

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SHOW_ALARM_STATE
ret

SHOW_TIME_STATE_TO_SET_TIME_STATE:
    ; set timeout (60 seconds)
    mov TIMEOUT_LENGTH, #3Ch
    mov TIMEOUT, TIMEOUT_LENGTH

    clr ROT_FLAG                    ; clear the ROT_FLAG

    clr P1.7                        ; turn off GPS sync indicator

    ; initalize external interrupts for rotary encoder
    clr IE1                         ; clear any "built up" hardware interrupt flags for external interrupt 1
    clr IE0                         ; clear any "built up" hardware interrupt flags for external interrupt 0
    setb EX0                        ; enable external interrupt 0
    setb EX1                        ; enable external interrupt 1

    ; Update SET_TIME_SUB_STATE
    mov SET_TIME_SUB_STATE, #SET_MM_STATE

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Move in mask values
    mov VFD_FLASH_MASK, #0FCh
    mov NIX_FLASH_MASK, #0FFh

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #0Ch                   ; months can be 12 max
    mov LOWER_BOUND, #01h                   ; months can be 1 min

    mov R0, #4Ch                            ; corresponds to memory address of MONTH

    ; turn on the VFD (always on when not in SHOW_TIME or GPS_SYNC)
    clr P1.0

    ; Update DECA_STATE
    lcall ENTER_DECA_FLASHING_STATE

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SET_TIME_STATE
ret

SHOW_ALARM_STATE_TO_SET_ALARM_STATE:
    ; set timeout (10 seconds)
    ; mov TIMEOUT_LENGTH, #0Ah
    ; lcall ADJUST_TIMEOUT
    mov TIMEOUT_LENGTH, #0Ah
    mov TIMEOUT, TIMEOUT_LENGTH

    ; initalize external interrupts for rotary encoder
    clr IE1                         ; clear any "built up" hardware interrupt flags for external interrupt 1
    clr IE0                         ; clear any "built up" hardware interrupt flags for external interrupt 0
    setb EX0                        ; enable external interrupt 0
    setb EX1                        ; enable external interrupt 1

    ; Update SET_ALARM_SUB_STATE
    mov SET_ALARM_SUB_STATE, #SET_ALARM_HR_STATE

    clr ROT_FLAG                    ; clear the ROT_FLAG
    clr INC_LEAP_YEAR?              ; clear the INC_LEAP_YEAR? flag

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Move in mask values
    mov VFD_FLASH_MASK, #0FFh
    mov NIX_FLASH_MASK, #0CFh

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #17h                   ; hours can be 23 max
    mov LOWER_BOUND, #00h                   ; hours can be 0 min

    mov R0, #5Bh                            ; corresponds to memory address of ALARM_HOURS

    ; Update DECA_STATE
    lcall ENTER_DECA_FLASHING_STATE

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SET_ALARM_STATE
ret

SET_ALARM_STATE_TO_SHOW_ALARM_STATE:
    ; set timeout (10 seconds)
    mov TIMEOUT_LENGTH, #0Ah
    ; lcall ADJUST_TIMEOUT
    mov TIMEOUT, TIMEOUT_LENGTH

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    clr EX0                     ; disable external interrupt 0
    clr EX1                     ; disable external interrupt 1

    ; Update DECA_STATE
    lcall ENTER_DECA_FILL_UP_STATE

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SHOW_ALARM_STATE
    ; lcall DECA_TRANSITION                         ; transition the decatron (MUST HAPPEN AFTER STATE CHANGE, 
    ;                                           ; OR FLASHING WILL CONTINUE IN DECA_TRANSITION)
ret

SHOW_ALARM_STATE_TO_SHOW_TIME_STATE:
    ; Display "-" in grids 3 & 6
    mov GRID6, #0Ah     ; write dash to grid 6 for date
    mov GRID3, #0Ah     ; write dash to grid 3 for date

    ; Turn off the VFD if DATE_ON? is not set
    jb DATE_ON?, show_alarm_state_to_show_time_state_cont0
        ; VFD should be off
        setb P1.0
    show_alarm_state_to_show_time_state_cont0:

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SHOW_TIME_STATE
ret

SETTINGS_STATE_TO_SHOW_TIME_STATE:
    ; Display "-" in grids 3 & 6
    mov GRID9, #0FFh    ; blank grid 9
    mov GRID6, #0Ah     ; write dash to grid 6 for date
    mov GRID3, #0Ah     ; write dash to grid 3 for date

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    clr EX0                     ; disable external interrupt 0
    clr EX1                     ; disable external interrupt 1

    ; Update DECA_STATE
    lcall ENTER_DECA_FILL_UP_STATE

    ; Turn off the VFD if DATE_ON? is not set
    jb DATE_ON?, settings_state_to_show_time_state_cont0
        ; VFD should be off
        setb P1.0
    settings_state_to_show_time_state_cont0:

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SHOW_TIME_STATE
    ; lcall DECA_TRANSITION                         ; transition the decatron (MUST HAPPEN AFTER STATE CHANGE, 
    ;                                               ; OR FLASHING WILL CONTINUE IN DECA_TRANSITION)
ret

SHOW_TIME_STATE_TO_SETTINGS_STATE:
    ; set timeout (60 seconds)
    mov TIMEOUT_LENGTH, #3Ch
    mov TIMEOUT, TIMEOUT_LENGTH

    ; initalize external interrupts for rotary encoder
    clr IE1                         ; clear any "built up" hardware interrupt flags for external interrupt 1
    clr IE0                         ; clear any "built up" hardware interrupt flags for external interrupt 0
    setb EX0                        ; enable external interrupt 0
    setb EX1                        ; enable external interrupt 1

    ; Configure settings menu options based on GPS present and/or auto-sync enabled
    jb GPS_PRESENT?, show_time_state_to_settings_state_cont0    ; check if GPS is present
        ; GPS is not present
        mov NUMBER_OF_ACTIVE_SETTINGS, #05h                     ; hide all GPS-related settings if no GPS is present
        sjmp show_time_state_to_settings_state_cont2
    show_time_state_to_settings_state_cont0:
    ; GPS is present
    jb AUTO_SYNC?, show_time_state_to_settings_state_cont1      ; check if GPS auto-sync is enabled
        ; GPS is present but auto-sync is disabled
        mov NUMBER_OF_ACTIVE_SETTINGS, #07h                     ; hide the auto-sync time setting
        sjmp show_time_state_to_settings_state_cont2

    show_time_state_to_settings_state_cont1:
    ; GPS is present and auto-sync is enabled
    mov NUMBER_OF_ACTIVE_SETTINGS, #NUMBER_OF_SETTINGS          ; show all GPS-related settings

    show_time_state_to_settings_state_cont2:

    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SHOW_DATE_ON_OFF_STATE    ; Note:  this should correspond with the expected first settings menu item

    clr ROT_FLAG                                ; clear the ROT_FLAG

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Set the upper and lower bounds
    mov UPPER_BOUND, NUMBER_OF_ACTIVE_SETTINGS  ; SETTINGS_SUB_STATE can be NUMBER_OF_ACTIVE_SETTINGS max
    mov LOWER_BOUND, #01h                       ; SETTINGS_SUB_STATE can be 1 min

    mov R0, #6Ch                                ; corresponds to memory address of SETTINGS_SUB_STATE

    ; turn on the VFD (always on when not in SHOW_TIME or GPS_SYNC)
    clr P1.0

    ; Cancel snooze, leaving alarm enabled
    mov a, ALARM_STATE
    cjne a, #ALARM_SNOOZING_STATE, show_time_state_to_settings_state_cont3
        lcall ALARM_SNOOZING_STATE_TO_ALARM_ENABLED_STATE                   ; if in ALARM_SNOOZING_STATE, cancel snooze by going to
                                                                            ; ALARM_ENABLED_STATE
    show_time_state_to_settings_state_cont3:

    ; Update DECA_STATE
    lcall ENTER_DECA_SCROLLING_STATE
    setb TO_SCROLLING?                          ; prepare to transition decatron to DECA_SCROLLING_STATE
    lcall ENTER_DECA_FAST_STATE                 ; go into DECA_FAST_STATE as transition to DECA_SCROLLING_STATE
    setb DECA_IN_TRANSITION?                    ; prepare to transition decatron to DECA_SCROLLING_STATE

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SETTINGS_STATE
ret

GPS_SYNC_STATE_TO_SHOW_TIME_STATE:
    ; disable the GPS   
    clr P1.2

    clr EX0                     ; disable external interrupt 0
    clr EX1                     ; disable external interrupt 1

    ; == This is how to configure timers going into GPS_SET_TIMEZONE_STATE:
    ; [x] Timer 0 keeps track of time (for timeout) and decatron flashes
    ; [x] Timer 1 not used
    ; [x] Timer 2 does update displays
    ; Timer 0 (for seconds interrupt) & 1 (for beep) interrupt initialization
    mov TMOD, #16h          ; set timer0 as a counter for the seconds (0000 0110 bin = 06 hex)
                            ; set timer1 as a timer for the beep duration (0001 0000 bin = 10 hex)
    ; Disable timer 1 only if a beep is not in progress (P1.1 is low if beep is in progress)
    ; jnb P1.1, gps_sync_state_to_show_time_state_cont0
    jb BEEP_ON?, gps_sync_state_to_show_time_state_cont0
        clr TR1                 ; stop timer 1
        ; clr ET1                               ; disable timer 1 overflow interrupt <-- commented out and replaced with...
    gps_sync_state_to_show_time_state_cont0:
    setb ET1                                    ; ^... this line -- otherwise beep never terminates coming out of GPS_SET_TIMEZONE_STATE
                                                ; when there is a successful sync

    ; Serial port initialization (mode 0 - synchronous serial communication)
    mov SCON, #00h          ; initialize the serial port in mode 0

    ; Display "-" in grids 3 & 6
    mov GRID6, #0Ah     ; write dash to grid 6 for date
    mov GRID3, #0Ah     ; write dash to grid 3 for date

    ; Turn on the VFD
    clr VFD_PAUSED?

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; make timer 0 and timer 2 interrupts highest priority
    mov IP, #22h

    ; update DECA_STATE
    lcall ENTER_DECA_FILL_UP_STATE

    ; update CLOCK_STATE
    mov CLOCK_STATE, #SHOW_TIME_STATE
ret

ENTER_GPS_SYNC_STATE:
    ; set timeout (255 seconds)
    mov TIMEOUT_LENGTH, #0FFh
    ; mov TIMEOUT_LENGTH, #0Ah
    mov TIMEOUT, TIMEOUT_LENGTH

    clr EX0                     ; disable external interrupt 0
    clr EX1                     ; disable external interrupt 1

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?
    
    ; have VFD display all dashes
    setb VFD_PAUSED?            ; pause the VFD
    ; Byte 1 (GRID_EN_1):
    ; | grid 9 | 0 | 0 | 0 | lost | lost | lost | lost |
    ; Byte 2 (GRID_EN_2):
    ; | grid 1 | grid 2 | grid 3 | grid 4 | grid 5 | grid 6 | grid 7 | grid 8 |
    ; Byte 3:
    ; | a | b | c | d | e | f | g | dp |
    ; The first two bytes of serial data enable VFD grids (keep grid 9 off)
    ; Send the first byte (blank grid 9)
    mov SBUF, #00h              ; send the first byte down the serial line
    jnb TI, $                   ; wait for the entire byte to be sent
    clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
    ; Send the second byte (turn on grids 1-8)
    mov SBUF, #0FFh             ; send the second byte down the serial line
    jnb TI, $                   ; wait for the entire byte to be sent
    clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
    ; Write "-" to all the displays that are enabled
    mov SBUF, #02h              ; send the third byte down the serial line
    jnb TI, $                   ; wait for the entire byte to be sent
    clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
    ; Load and latch the data
    setb P3.5                       ; load the MAX6921
    clr P3.5                        ; latch the MAX6921

    ; update DECA_STATE
    lcall ENTER_DECA_RADAR_STATE

    ; make serial ISR highest priority
    ; DO THIS IN OBTAIN DATA INIT

    ; == This is how to configure timers going into GPS_OBTAIN_FIX_STATE:
    ; [x] Timer 0 keeps track of time (for timeout) and also does radar mode
    ; [x] Timer 1 is configured to LPF GPS fix signal to detect when a fix is found
    ; [x] Timer 2 does update displays

    ; Configure timer 1 in 16 bit mode (NOT auto-reload) - For counting GPS fix LOW level duration (when GPS has a fix, GPS fix pin is constantly low)
    ; Interrupt initialization
    setb ET1                ; enable timer 1 overflow Interrupt
    ; Do not change timer 0 settings (still used for keeping track of time (for timeout) and radar mode)
    ; NOTE: high nibble of TMOD is for timer 1, low nibble is for timer 0
    mov TMOD, #16h
    ; Initialize TL1 and TH1 for timer 1 16 bit timing for maximum count
    ; mov TL1, #00h
    ; mov TH1, #00h
    ; Start timer 1
    setb TR1
    ; Initialize GPS_FIX_LPF to keep track of how many times timer 1 has counted to 65536 (for LPF of GPS fix)
    mov GPS_FIX_LPF, #14h   ; move 20 (decimal) into GPS_FIX_LPF (20 * 0.065536 seconds = ~1.31 seconds)

    ; Reset timeout for if there is no GPS
    mov GPS_FIX_HIGH_TIMEOUT, #020h                     ; re-load 32 (dec) into GPS_FIX_HIGH_TIMEOUT

    ; turn off GPS sync indicator
    clr P1.7

    ; enable the GPS
    setb P1.2

    ; Turn off the VFD if DATE_ON? is not set
    jb DATE_ON?, enter_gps_sync_state_cont0
        ; VFD should be off
        setb P1.0
    enter_gps_sync_state_cont0:

    ; update GPS_SYNC_SUB_STATE
    mov GPS_SYNC_SUB_STATE, #GPS_OBTAIN_FIX_STATE

    ; update CLOCK_STATE
    mov CLOCK_STATE, #GPS_SYNC_STATE
ret

SHOW_TIME_STATE_TO_CYCLE_STATE:
    ; set timeout (10 seconds)
    mov TIMEOUT_LENGTH, #0Ah
    mov TIMEOUT, TIMEOUT_LENGTH

    ; Start the cycle with the nixies all displaying 0s.
    mov CYCLE_NUMBER, #00h

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #CYCLE_STATE
ret

CYCLE_STATE_TO_SHOW_TIME_STATE:
    ; Have the nixies display the time.  <-- Taken care of in SHOW_TIME

    ; Update CLOCK_STATE
    mov CLOCK_STATE, #SHOW_TIME_STATE
ret

; Alarm state machine transitions ========
ALARM_DISABLED_STATE_TO_ALARM_ENABLED_STATE:
    setb P1.6                                   ; turn on alarm light
    mov ALARM_STATE, #ALARM_ENABLED_STATE       ; update ALARM_STATE
ret

ALARM_ENABLED_STATE_TO_ALARM_DISABLED_STATE:
    clr P1.6                                    ; turn off alarm light
    mov ALARM_STATE, #ALARM_DISABLED_STATE      ; update ALARM_STATE
ret

ALARM_ENABLED_STATE_TO_ALARM_FIRING_STATE:
    ; Alarm firing should send the clock in certain states back to SHOW_TIME.
    ; check if CLOCK_STATE is GPS_SYNC_STATE
    mov a, CLOCK_STATE
    cjne a, #GPS_SYNC_STATE, alarm_enabled_to_firing_cont2
        ; clock is currently syncing
        lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE         ; abort the sync since the alarm has priority
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_enabled_to_firing_cont2:
    ; check if CLOCK_STATE is SHOW_ALARM_STATE
    cjne a, #SHOW_ALARM_STATE, alarm_enabled_to_firing_cont3
        ; clock is currently showing the alarm
        lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE       ; move to show the time (which now matches the alarm time, so this might
                                                        ; not matter)
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_enabled_to_firing_cont3:
    ; check if CLOCK_STATE is SETTINGS_STATE
    cjne a, #SETTINGS_STATE, alarm_enabled_to_firing_cont4
        ; clock is currently in the settings menu
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE         ; abort any settings changes since the alarm has priority
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_enabled_to_firing_cont4:
    ; check if CLOCK_STATE is CYCLE_STATE
    cjne a, #CYCLE_STATE, alarm_enabled_to_firing_cont5
        ; clock is currently cycling the nixies
        lcall CYCLE_STATE_TO_SHOW_TIME_STATE            ; exit the nixie cycling early since the alarm has priority
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_enabled_to_firing_cont5:

    clr P1.1                                            ; this turns ON the buzzer. NOTE: inverter between pin and buzzer (low = buzzing)
                                                        ; the above line is DIFFERENT (as it should) than in ALARM_SNOOZING_STATE_TO_ALARM_FIRING_STATE
    lcall ENTER_DECA_FAST_STATE                         ; update DECA_STATE
    mov ALARM_STATE, #ALARM_FIRING_STATE                ; update ALARM_STATE
ret

ALARM_FIRING_STATE_TO_ALARM_DISABLED_STATE:
    setb P1.1                                   ; turn off buzzer.  NOTE: inverter between pin and buzzer (high = off)
    clr P1.6                                    ; turn off alarm light
    setb DECA_IN_TRANSITION?                    ; stay in DECA_FAST_STATE until DECATRON matches SECONDS
    mov ALARM_STATE, #ALARM_DISABLED_STATE      ; update ALARM_STATE
ret

ALARM_FIRING_STATE_TO_ALARM_SNOOZING_STATE:
    setb P1.1                                                           ; turn off buzzer.  NOTE: inverter between pin and buzzer (high = off)
    mov SNOOZE_COUNT_PER_DECA_PIN, SNOOZE_COUNT_PER_DECA_PIN_RELOAD     ; reload SNOOZE_COUNT_PER_DECA_PIN
    setb DECA_IN_TRANSITION?                                            ; prepare to transition decatron to DECA_COUNTDOWN_STATE
    setb TO_COUNTDOWN?                                                  ; prepare to transition decatron to DECA_COUNTDOWN_STATE
    ; lcall ENTER_DECA_COUNTDOWN_STATE                                  ; update DECA_STATE
    mov ALARM_STATE, #ALARM_SNOOZING_STATE                              ; update ALARM_STATE
ret

ALARM_SNOOZING_STATE_TO_ALARM_DISABLED_STATE:
    clr P1.6                                    ; turn off alarm light
    lcall ENTER_DECA_FILL_UP_STATE              ; update DECA_STATE
    mov ALARM_STATE, #ALARM_DISABLED_STATE      ; update ALARM_STATE
ret

ALARM_SNOOZING_STATE_TO_ALARM_FIRING_STATE:
    ; Alarm firing should send the clock in certain states back to SHOW_TIME.
    ; check if CLOCK_STATE is GPS_SYNC_STATE
    mov a, CLOCK_STATE
    cjne a, #GPS_SYNC_STATE, alarm_snoozing_to_firing_cont2
        ; clock is currently syncing
        lcall GPS_SYNC_STATE_TO_SHOW_TIME_STATE         ; abort the sync since the alarm has priority
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_snoozing_to_firing_cont2:
    ; check if CLOCK_STATE is SHOW_ALARM_STATE
    cjne a, #SHOW_ALARM_STATE, alarm_snoozing_to_firing_cont3
        ; clock is currently showing the alarm
        lcall SHOW_ALARM_STATE_TO_SHOW_TIME_STATE       ; move to show the time (which now matches the alarm time, so this might
                                                        ; not matter)
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_snoozing_to_firing_cont3:
    ; check if CLOCK_STATE is SETTINGS_STATE
    cjne a, #SETTINGS_STATE, alarm_snoozing_to_firing_cont4
        ; clock is currently in the settings menu
        lcall SETTINGS_STATE_TO_SHOW_TIME_STATE         ; abort any settings changes since the alarm has priority
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_snoozing_to_firing_cont4:
    ; check if CLOCK_STATE is CYCLE_STATE
    cjne a, #CYCLE_STATE, alarm_snoozing_to_firing_cont5
        ; clock is currently cycling the nixies
        lcall CYCLE_STATE_TO_SHOW_TIME_STATE            ; exit the nixie cycling early since the alarm has priority
        clr DECA_IN_TRANSITION?                         ; the previous line's clock transition puts the decatron in a temporary
                                                        ; fill-up state, which we want to override with the below line's alarm
                                                        ; transition, which puts the decatron in fast mode
    alarm_snoozing_to_firing_cont5:

    setb P1.1                                   ; this turns OFF the buzzer, but will get immediately turned on at the buzzer toggle
                                                ; in TIMER_0_SERVICE.  NOTE: inverter between pin and buzzer (low = buzzing)
    lcall ENTER_DECA_FAST_STATE                 ; update DECA_STATE
    mov ALARM_STATE, #ALARM_FIRING_STATE        ; update ALARM_STATE
ret

ALARM_SNOOZING_STATE_TO_ALARM_ENABLED_STATE:
    setb P1.6                                   ; turn on alarm light
    mov ALARM_STATE, #ALARM_ENABLED_STATE       ; update ALARM_STATE
ret

; ========================================

; ==== Sub-State Transition Functions ====
; SET_TIME sub-state transitions =========
SET_MM_STATE_TO_SET_DD_STATE:
    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Move in mask values
    mov VFD_FLASH_MASK, #0E7h
    mov NIX_FLASH_MASK, #0FFh

    ; Upper and lower bounds set in DD_ADJ
    lcall DD_ADJ                            ; adjust bounds so you can't set invalid date

    mov R0, #4Dh                            ; corresponds to memory address of DAY

    mov SET_TIME_SUB_STATE, #SET_DD_STATE   ; update SET_TIME_SUB_STATE
ret

SET_DD_STATE_TO_SET_YY_STATE:
    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Move in mask values
    mov VFD_FLASH_MASK, #3Fh
    mov NIX_FLASH_MASK, #0FFh

    ; Upper and lower bounds set in YY_ADJ
    lcall YY_ADJ                            ; adjust bounds so you can't set invalid date

    mov R0, #4Eh                            ; corresponds to memory address of YEAR
    
    mov SET_TIME_SUB_STATE, #SET_YY_STATE   ; update SET_TIME_SUB_STATE
ret

SET_YY_STATE_TO_SET_HR_STATE:
    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Move in mask values
    mov VFD_FLASH_MASK, #0FFh
    mov NIX_FLASH_MASK, #0CFh

    ; clear the leap year bit
    clr INC_LEAP_YEAR?

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #17h                   ; hours can be 23 max
    mov LOWER_BOUND, #00h                   ; hours can be 0 min

    mov R0, #45h                            ; corresponds to memory address of HOURS
    
    mov SET_TIME_SUB_STATE, #SET_HR_STATE   ; update SET_TIME_SUB_STATE
ret

SET_HR_STATE_TO_SET_MIN_STATE:
    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Move in mask values
    mov VFD_FLASH_MASK, #0FFh
    mov NIX_FLASH_MASK, #3Fh

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #3Bh                   ; minutes can be 59 max
    mov LOWER_BOUND, #00h                   ; minutes can be 0 min

    mov R0, #46h                            ; corresponds to memory address of MINUTES
    
    mov SET_TIME_SUB_STATE, #SET_MIN_STATE  ; update SET_TIME_SUB_STATE
ret

; SET_ALARM sub-state transitions ========
SET_ALARM_HR_STATE_TO_SET_ALARM_MIN_STATE:
    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; Move in mask values
    mov VFD_FLASH_MASK, #0FFh
    mov NIX_FLASH_MASK, #3Fh

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #3Bh                   ; minutes can be 59 max
    mov LOWER_BOUND, #00h                   ; minutes can be 0 min

    mov R0, #5Ch                            ; corresponds to memory address of ALARM_MINUTES

    mov SET_ALARM_SUB_STATE, #SET_ALARM_MIN_STATE   ; update SET_TIME_SUB_STATE
ret

; GPS_SYNC sub-state transitions =========
ENTER_GPS_OBTAIN_DATA_STATE:
    ; set timeout (120 seconds)
    mov TIMEOUT_LENGTH, #78h
    mov TIMEOUT, TIMEOUT_LENGTH

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; make serial port interrupt highest priority
    mov IP, #10h

    ; Stop timer 1
    clr TR1             ; stop timer 1
    clr ET1             ; clear timer 1 overflow Interrupt

    ; == This is how to configure timers going into GPS_OBTAIN_DATA_STATE: 
    ; [x] Timer 0 keeps track of time (for timeout) and also does radar mode
    ; [x] Timer 1 is used to set baud rate
    ; [x] Timer 2 does update displays

    ; Configure timer 1 in auto-reload mode (mode 2) - For baud rate generation.
    ; Keep timer 0 counting seconds
    ; NOTE: high nibble of TMOD is for timer 1, low nibble is for timer 0
    mov TMOD, #26h
    ; Initialize TH1 for 9600 baud
    mov TH1, #0FDh
    ; Start timer 1
    setb TR1

    ; Configure serial port to operate in mode 1 (8 bit UART with baud rate set by timer 1), with receive enabled
    mov SCON, #50h      ; mode 1, receive enabled
    ; Clear RI and TI flags
    ; clr RI                ; clear recieve interrupt flag
    ; clr TI                ; clear transmit interrupt flag
    ; Enable serial interrupt
    setb ES

    ; Initialize data pointer
    mov GPS_POINTER, #08h                       ; load GPS_POINTER with memory address of RECEIVED_GPS_HRS_TENS

    ; update GPS_OBTAIN_DATA_SUB_STATE
    mov GPS_OBTAIN_DATA_SUB_STATE, #GPS_WAIT_FOR_DOLLAR

    ; update GPS_SYNC_SUB_STATE
    mov GPS_SYNC_SUB_STATE, #GPS_OBTAIN_DATA_STATE
ret

ENTER_GPS_SET_TIMEZONE_STATE:
    ; no timeout in this state so the user must input a timezone

    ; ; Clear the TRANSITION_STATE? bit
    ; clr TRANSITION_STATE?

    ; disable the GPS
    clr P1.2

    ; Added the two lines below to see if this was the cause of flickering, but still saw flickering.
    ; Disable the serial interrupt
    clr ES

    ; Serial port initialization (mode 0 - synchronous serial communication)
    mov SCON, #00h                          ; initialize the serial port in mode 0

    ; == This is how to configure timers going into GPS_SET_TIMEZONE_STATE:
    ; [x] Timer 0 keeps track of time (for timeout) and decatron flashes
    ; [x] Timer 1 used for beep
    ; [x] Timer 2 does update displays
    ; Timer 0 (for seconds interrupt) & 1 (for beep) interrupt initialization
    mov TMOD, #16h          ; set timer0 as a counter for the seconds (0000 0110 bin = 06 hex)
                            ; set timer1 as a timer for the beep duration (0001 0000 bin = 10 hex)
    ; Disable timer 1 only if a beep is not in progress (P1.1 is low if beep is in progress)
    ; jnb P1.1, enter_gps_set_timezone_state_cont0
    jb BEEP_ON?, enter_gps_set_timezone_state_cont0
        clr TR1                                 ; stop timer 1
        ; clr ET1                               ; disable timer 1 overflow interrupt <-- commented out and replaced with...
    enter_gps_set_timezone_state_cont0:
    setb ET1                                    ; ^... this line -- otherwise beep never terminates coming out of GPS_SET_TIMEZONE_STATE
                                                ; when there is a successful sync


    ; Move in mask values
    mov VFD_FLASH_MASK, #1Fh                ; flash grids 1, 2, and 3
    mov NIX_FLASH_MASK, #0FFh

    ; Display "Utc" on the VFD
    mov GRID9, #0FFh                        ; blank grid 9
    mov GRID8, #12h                         ; display 'U' on grid 8
    mov GRID7, #13h                         ; display 't' on grid 7
    mov GRID6, #14h                         ; display 'c' on grid 6
    mov GRID5, #0FFh                        ; blank grid 5
    mov GRID4, #0FFh                        ; blank grid 4
    ; grids 1, 2, and 3 are set in GPS_SET_TIMEZONE function

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #TIMEZONE_MAX          ; TIMEZONE can be 28 (dec) max
    mov LOWER_BOUND, #TIMEZONE_MIN          ; TIMEZONE can be 3 min

    mov R0, #70h                            ; corresponds to memory address of TIMEZONE

    ; Turn on the VFD
    clr VFD_PAUSED?

    ; make timer 0 and timer 2 interrupts highest priority
    mov IP, #22h

    ; enable external interrupts for rotary encoder
    ; initalize external interrupts for rotary encoder
    clr IE1                                 ; clear any "built up" hardware interrupt flags for external interrupt 1
    clr IE0                                 ; clear any "built up" hardware interrupt flags for external interrupt 0
    setb EX0                                ; enable external interrupt 0
    setb EX1                                ; enable external interrupt 1

    clr ROT_FLAG                            ; clear the ROT_FLAG

    ; update DECA_STATE
    lcall ENTER_DECA_FLASHING_STATE

    ; update GPS_SYNC_SUB_STATE
    mov GPS_SYNC_SUB_STATE, #GPS_SET_TIMEZONE_STATE
ret

; SETTINGS sub-state transitions =========
ENTER_SETTINGS_SET_TIMEZONE_STATE:
    ; Move in mask values
    mov VFD_FLASH_MASK, #1Fh                ; flash grids 1, 2, and 3
    mov NIX_FLASH_MASK, #0FFh

    ; Display "Utc" on the VFD
    ; mov GRID9, #0Bh                       ; display '*' on grid 9     <-- already done in SETTINGS_SHOW_TIMEZONE_STATE
    ; mov GRID8, #12h                       ; display 'U' on grid 8     <-- already done in SETTINGS_SHOW_TIMEZONE_STATE
    ; mov GRID7, #13h                       ; display 't' on grid 7     <-- already done in SETTINGS_SHOW_TIMEZONE_STATE
    ; mov GRID6, #14h                       ; display 'c' on grid 6     <-- already done in SETTINGS_SHOW_TIMEZONE_STATE
    ; mov GRID5, #0FFh                      ; blank grid 5              <-- already done in SETTINGS_SHOW_TIMEZONE_STATE
    mov GRID4, #0FFh                        ; blank grid 4
    ; grids 1, 2, and 3 are set in SETTINGS_SET_TIMEZONE function

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #TIMEZONE_MAX          ; TIMEZONE can be 28 (dec) max
    mov LOWER_BOUND, #TIMEZONE_MIN          ; TIMEZONE can be 3 min

    mov R0, #70h                            ; corresponds to memory address of TIMEZONE

    ; Remove the current timezone offset from the HOURS, DAY, MONTH, YEAR registers to revert them back to UTC
    lcall UNAPPLY_TIMEZONE_TO_GET_UTC

    ; update DECA_STATE
    lcall ENTER_DECA_FLASHING_STATE

    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SET_TIMEZONE_STATE
ret

EXIT_SETTINGS_SET_TIMEZONE_STATE:
    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SHOW_TIMEZONE_STATE

    ; Update DECA_STATE
    ; lcall ENTER_DECA_SCROLLING_STATE
    setb TO_SCROLLING?                              ; prepare to transition decatron to DECA_SCROLLING_STATE
    lcall ENTER_DECA_FAST_STATE                     ; go into DECA_FAST_STATE as transition to DECA_SCROLLING_STATE
    setb DECA_IN_TRANSITION?                        ; prepare to transition decatron to DECA_SCROLLING_STATE

    ; Set the upper and lower bounds
    mov UPPER_BOUND, NUMBER_OF_ACTIVE_SETTINGS      ; SETTINGS_SUB_STATE can be NUMBER_OF_ACTIVE_SETTINGS max
    mov LOWER_BOUND, #01h                           ; SETTINGS_SUB_STATE can be 1 min

    mov R0, #6Ch                                    ; corresponds to memory address of SETTINGS_SUB_STATE
ret

ENTER_SETTINGS_SET_SNOOZE_STATE:
    ; Move in mask values
    mov VFD_FLASH_MASK, #0FFh
    mov NIX_FLASH_MASK, #3Fh

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #SNOOZE_DURATION_MAX   ; SNOOZE_DURATION can be 90 (dec) max
    mov LOWER_BOUND, #SNOOZE_DURATION_MIN   ; SNOOZE_DURATION can be 1 min

    mov R0, #5Eh                            ; corresponds to memory address of SNOOZE_DURATION

    ; update DECA_STATE
    lcall ENTER_DECA_FLASHING_STATE

    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SET_SNOOZE_STATE
ret

EXIT_SETTINGS_SET_SNOOZE_STATE:
    ; Recalculate the SNOOZE_COUNT_PER_DECA_PIN
    mov a, SNOOZE_DURATION
    add a, SNOOZE_DURATION
    mov SNOOZE_COUNT_PER_DECA_PIN_RELOAD, a
    mov SNOOZE_COUNT_PER_DECA_PIN, SNOOZE_COUNT_PER_DECA_PIN_RELOAD

    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SHOW_SNOOZE_STATE

    ; Update DECA_STATE
    ; lcall ENTER_DECA_SCROLLING_STATE
    setb TO_SCROLLING?                              ; prepare to transition decatron to DECA_SCROLLING_STATE
    lcall ENTER_DECA_FAST_STATE                     ; go into DECA_FAST_STATE as transition to DECA_SCROLLING_STATE
    setb DECA_IN_TRANSITION?                        ; prepare to transition decatron to DECA_SCROLLING_STATE

    ; Set the upper and lower bounds
    mov UPPER_BOUND, NUMBER_OF_ACTIVE_SETTINGS      ; SETTINGS_SUB_STATE can be NUMBER_OF_ACTIVE_SETTINGS max
    mov LOWER_BOUND, #01h                           ; SETTINGS_SUB_STATE can be 1 min

    mov R0, #6Ch                                    ; corresponds to memory address of SETTINGS_SUB_STATE
ret

ENTER_SETTINGS_SET_GPS_SYNC_HR_STATE:
    ; Move in mask values
    mov VFD_FLASH_MASK, #0FFh
    mov NIX_FLASH_MASK, #0CFh

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #GPS_SYNC_TIME_HOURS_MAX   ; GPS_SYNC_TIME_HOURS can be 23 (dec) max
    mov LOWER_BOUND, #GPS_SYNC_TIME_HOURS_MIN   ; GPS_SYNC_TIME_HOURS can be 0 min

    mov R0, #6Dh                                ; corresponds to memory address of GPS_SYNC_TIME_HOURS

    ; update DECA_STATE
    lcall ENTER_DECA_FLASHING_STATE

    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SET_GPS_SYNC_HR_STATE
ret

ENTER_SETTINGS_SET_GPS_SYNC_MIN_STATE:
    ; Move in mask values
    mov VFD_FLASH_MASK, #0FFh
    mov NIX_FLASH_MASK, #3Fh

    ; Set the upper and lower bounds
    mov UPPER_BOUND, #GPS_SYNC_TIME_MINUTES_MAX     ; GPS_SYNC_TIME_MINUTES can be 59 (dec) max
    mov LOWER_BOUND, #GPS_SYNC_TIME_MINUTES_MIN     ; GPS_SYNC_TIME_MINUTES can be 0 min

    mov R0, #6Eh                                    ; corresponds to memory address of GPS_SYNC_TIME_MINUTES

    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SET_GPS_SYNC_MIN_STATE
ret

EXIT_SETTINGS_SET_GPS_SYNC_TIME_STATE:
    ; Update SETTINGS_SUB_STATE
    mov SETTINGS_SUB_STATE, #SETTINGS_SHOW_GPS_SYNC_TIME_STATE

    ; Update DECA_STATE
    ; lcall ENTER_DECA_SCROLLING_STATE
    setb TO_SCROLLING?                              ; prepare to transition decatron to DECA_SCROLLING_STATE
    lcall ENTER_DECA_FAST_STATE                     ; go into DECA_FAST_STATE as transition to DECA_SCROLLING_STATE
    setb DECA_IN_TRANSITION?                        ; prepare to transition decatron to DECA_SCROLLING_STATE

    ; Set the upper and lower bounds
    mov UPPER_BOUND, NUMBER_OF_ACTIVE_SETTINGS      ; SETTINGS_SUB_STATE can be NUMBER_OF_ACTIVE_SETTINGS max
    mov LOWER_BOUND, #01h                           ; SETTINGS_SUB_STATE can be 1 min

    mov R0, #6Ch                                    ; corresponds to memory address of SETTINGS_SUB_STATE
ret

; ========================================

; =========== Display Functions ==========
UPDATE_DISPLAYS:
    ; push PSW -- Note:  this seems to have fixed some glitchy flashing in the VFD during the GPS_SET_TIMEZONE state
    push PSW

    lcall UPDATE_DECA                       ; update the decatron
    jb VFD_PAUSED?, update_displays_cont1   ; if VFD_PAUSED? = 1, do not update VFD
        lcall UPDATE_VFD                    ; update the VFD
    update_displays_cont1:

    ; ISSUE?
    djnz R5, update_displays_cont0      ; decrement the display update count, if it is zero, update the nixies
        lcall UPDATE_NIX                ; update the nixies
        lcall CHECK_TO_FLASH_DISPLAYS   ; flash displays for set modes
        mov R5, #0Ch                    ; reset R5 with a value of 12
    update_displays_cont0:

    pop PSW
ret

CHECK_TO_FLASH_DISPLAYS:
    push acc

    mov a, DECA_STATE                                           ; move DECA_STATE into the accumulator
    cjne a, #DECA_FLASHING_STATE, check_to_flash_displays_cont0 ; check if in DECA_FLASHING_STATE, otherwise skip this
        ; jb DECA_IN_TRANSITION?, check_to_flash_displays_cont0
        lcall FLASH_DISPLAYS
        ljmp check_to_flash_displays_cont3
    check_to_flash_displays_cont0:

    ; mov a, CLOCK_STATE                                        ; move CLOCK_STATE into the accumulator
    ; cjne a, #SET_TIME_STATE, check_to_flash_displays_cont0    ; check if in SET_TIME_STATE, otherwise skip this
    ;   lcall FLASH_DISPLAYS
    ;   ljmp check_to_flash_displays_cont3
    ; check_to_flash_displays_cont0:

    ; cjne a, #SET_ALARM_STATE, check_to_flash_displays_cont1   ; check if in SET_ALARM_STATE, otherwise skip this
    ;   lcall FLASH_DISPLAYS
    ;   ljmp check_to_flash_displays_cont3
    ; check_to_flash_displays_cont1:

    check_to_flash_displays_cont2:
        ; if P0.4 is high (decatron is on), turn on all grids/nixies
        mov VFD_MASK, #0FFh
        mov NIX_MASK, #0FFh

        clr ROT_FLAG                ; clear the rotation flag (gets set in ENC_A or ENC_B ISR)

    check_to_flash_displays_cont3:
    pop acc
ret

FLASH_DISPLAYS:

    djnz R7, flash_displays_cont1                       ; decrement the flash display count, if it is zero, toggle mask
        mov R7, #090h                                   ; reset R7 for next interrupt
        cpl P0.4                                        ; if CLOCK_STATE is SET_TIME_STATE or SET_ALARM_STATE, flash the decatron
        mov DECATRON, #1Eh                              ; move 30 (dec) into decatron (to light up full)

        jb P0.4, flash_displays_cont0
            ; if P0.4 is low (decatron is off), check if we should flash displays (i.e. if ROT_FLAG is not set)
            jb ROT_FLAG, flash_displays_cont0
                ; if P0.4 is low (decatron is off) and ROT_FLAG is not set, blink the display being set
                mov VFD_MASK, VFD_FLASH_MASK
                mov NIX_MASK, NIX_FLASH_MASK
                ljmp flash_displays_cont1                   ; jump to the end of routine

    flash_displays_cont0:
        ; if P0.4 is high (decatron is on), turn on all grids/nixies
        mov VFD_MASK, #0FFh
        mov NIX_MASK, #0FFh

        clr ROT_FLAG                ; clear the rotation flag (gets set in ENC_A or ENC_B ISR)

    flash_displays_cont1:
ret

UPDATE_NIX:
    ; This function sequentially cycles through each nixie bulb and applies the appropriate
    ; signal to display the correct number (illuminate the correct cathode) for each bulb.
    ; For each bulb, one byte of data is sent:
    ; Byte 1:
    ; |<- High Nibble ->|<- Low Nibble ->|
    ; |      NIX_EN     |     number     |
    ; NIX_EN:
    ;   1000 - NIX1 displays number
    ;   0100 - NIX2 displays number
    ;   0010 - NIX3 displays number
    ;   0001 - NIX4 displays number

    ; R1 stores NIX_INDX.

    ; push any used SFRs onto the stack to preserve their values
    push 1
    push acc
    push PSW

    clr c                       ; clear the carry flag

    mov R1, NIX_INDX            ; move NIX_INDX into R1
    inc NIX_INDX                ; increment NIX_INDX (to access next nixie bulb memory location)

    mov a, NIX_EN               ; move NIX_EN into accumulator
    orl a, @R1                  ; bitwise OR the accumulator (NIX_EN) with @R1 (@NIX_INDX)
    anl a, NIX_MASK             ; bitwise AND the accumulator with NIX_MASK
    mov P2, #00h                ; clear all nixies
    mov P2, a                   ; light up the appropriate nixie

    ; prepare for the next cycle
    mov a, NIX_EN               ; move NIX_EN into accumulator
    rlc a                       ; rotate the accumulator left through carry (NOTE! the carry flag gets rotated into bit 0)
    mov NIX_EN, a               ; move the rotated result back into NIX_EN
    jnc update_nix_cont1        ; check if a complete nixie cycle has finished (the carry flag has been set)
        clr c                   ; clear the carry flag
        lcall NIX_RESET         ; reset the nixie cycle
    update_nix_cont1:

    ; pop the original SFR values back into their place and restore their values
    pop PSW
    pop acc
    pop 1
ret

NIX_RESET:
    ; This function resets the nixie registers after a complete cycle
    mov NIX_EN, #10h            ; initialize nixie enable nibble
    mov NIX_INDX, #3Eh          ; initalize nixie index (start with nixie 4). This should reflect the memory location of NIX4.
ret

UPDATE_VFD:
    ; This function squentially cycles through each VFD grid and applies the appropriate
    ; signal to display the correct number (illuminate the correct segments) for each grid.
    ; For each numeral/grid, three bytes of data are sent:
    ; Byte 1 (GRID_EN_1):
    ; | grid 9 | 0 | 0 | 0 | lost | lost | lost | lost |
    ; Byte 2 (GRID_EN_2):
    ; | grid 1 | grid 2 | grid 3 | grid 4 | grid 5 | grid 6 | grid 7 | grid 8 |
    ; Byte 3:
    ; | a | b | c | d | e | f | g | dp |
    ; A VFD_NUM (@R1) value of #0Ah corresponds to a "-" for grids 1-9
    ; A VFD_NUM (@R1) value of #0Bh corresponds to a "*" for grid 9
    ; A VFD_NUM (@R1) value of #FFh corresponds to a BLANK for grids 1-9
    ; A VFD_NUM (@R1) value of #0Ch corresponds to a "A" for grids 1-8
    ; A VFD_NUM (@R1) value of #0Dh corresponds to a "L" for grids 1-8
    ; A VFD_NUM (@R1) value of #0Eh corresponds to a "a" for grids 1-8
    ; A VFD_NUM (@R1) value of #0Fh corresponds to a "r" for grids 1-8
    ; A VFD_NUM (@R1) value of #10h bugs out (flickers "-" in grid 9)
    ; A VFD_NUM (@R1) value of #11h corresponds to a "n" for grids 1-8
    ; A VFD_NUM (@R1) value of #12h corresponds to a "U" for grids 1-8
    ; A VFD_NUM (@R1) value of #13h corresponds to a "t" for grids 1-8
    ; A VFD_NUM (@R1) value of #14h corresponds to a "c" for grids 1-8
    ; A VFD_NUM (@R1) value of #15h corresponds to a "S" for grids 1-8
    ; A VFD_NUM (@R1) value of #16h corresponds to a "Z" for grids 1-8
    ; A VFD_NUM (@R1) value of #17h corresponds to a "o" for grids 1-8
    ; A VFD_NUM (@R1) value of #18h corresponds to a "e" for grids 1-8
    ; A VFD_NUM (@R1) value of #19h corresponds to a "d" for grids 1-8
    ; A VFD_NUM (@R1) value of #1Ah corresponds to a "y" for grids 1-8
    ; A VFD_NUM (@R1) value of #1Bh corresponds to a "u" for grids 1-8
    ; A VFD_NUM (@R1) value of #1Ch corresponds to a "H" for grids 1-8
    ; A VFD_NUM (@R1) value of #1Dh corresponds to half of a "M" for grids 1-8
    ; A VFD_NUM (@R1) value of #1Eh corresponds to a "b" for grids 1-8
    ; A VFD_NUM (@R1) value of #1Fh corresponds to a "P" for grids 1-8

    push 1                          ; push R1 onto the stack to preserve its value
    push acc                        ; push a onto the stack to preserve its value
    push PSW

    ; move the contents of the respective grid into VFD_NUM (the number to be displayed - @R1)
    mov R1, GRID_INDX           ; move GRID_INX into R1
    inc GRID_INDX               ; increment the grid index (to access next grid memory location)


    ; The first two bytes of serial data are the independent of the numeral
    mov SBUF, GRID_EN_1         ; send the first byte down the serial line
    jnb TI, $                   ; wait for the entire byte to be sent
    clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software

    mov a, GRID_EN_2            ; move GRID_EN_2 into the accumulator for bitwise AND operation
    anl a, VFD_MASK             ; bitwise AND accumutor (which stores GRID_END_2) with VFD_MASK (result is stored in the accumulator)
    mov SBUF, a                 ; send the second byte down the serial line
    jnb TI, $                   ; wait for the entire byte to be sent
    clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software

    ; The third byte of serial data depends on the numeral to be shown
    
    ; "0" numeral
    cjne @R1, #00h, vfd_cont0
        mov SBUF, #0FCh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont0:

    ; "1" numeral
    cjne @R1, #01h, vfd_cont1
        mov SBUF, #060h             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont1:

    ; "2" numeral
    cjne @R1, #02h, vfd_cont2
        mov SBUF, #0DAh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont2:

    ; "3" numeral
    cjne @R1, #03h, vfd_cont3
        mov SBUF, #0F2h             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont3:

    ; "4" numeral
    cjne @R1, #04h, vfd_cont4
        mov SBUF, #66h              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont4:

    ; "5" numeral
    cjne @R1, #05h, vfd_cont5
        mov SBUF, #0B6h             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont5:

    ; "6" numeral
    cjne @R1, #06h, vfd_cont6
        mov SBUF, #0BEh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont6:

    ; "7" numeral
    cjne @R1, #07h, vfd_cont7
        mov SBUF, #0E0h             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont7:

    ; "8" numeral
    cjne @R1, #08h, vfd_cont8
        mov SBUF, #0FEh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont8:

    ; "9" numeral
    cjne @R1, #09h, vfd_cont9
        mov SBUF, #0E6h             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont9:

    ; "-" numeral
    cjne @R1, #0Ah, vfd_cont10
        mov SBUF, #02h              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont10:

    ; "*" numeral
    cjne @R1, #0Bh, vfd_cont11
        mov SBUF, #01h              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont11:

    ; "BLANK" numeral
    cjne @R1, #0FFh, vfd_cont12
        mov SBUF, #00h              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont12:

    ; "A" numeral
    cjne @R1, #0Ch, vfd_cont13
        mov SBUF, #0EEh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont13:

    ; "L" numeral
    cjne @R1, #0Dh, vfd_cont14
        mov SBUF, #1Ch              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont14:

    ; "a" numeral
    cjne @R1, #0Eh, vfd_cont15
        mov SBUF, #0FAh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont15:

    ; "r" numeral
    cjne @R1, #0Fh, vfd_cont16
        mov SBUF, #0Ah              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont16:

    ; "n" numeral
    cjne @R1, #11h, vfd_cont17
        mov SBUF, #2Ah              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont17:

    ; "U" numeral
    cjne @R1, #12h, vfd_cont18
        mov SBUF, #7Ch              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont18:

    ; "t" numeral
    cjne @R1, #13h, vfd_cont19
        mov SBUF, #1Eh              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont19:

    ; "c" numeral
    cjne @R1, #14h, vfd_cont20
        mov SBUF, #1Ah              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont20:

    ; "S" numeral
    cjne @R1, #15h, vfd_cont21
        mov SBUF, #0B6h             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont21:

    ; "Z" numeral
    cjne @R1, #16h, vfd_cont22
        mov SBUF, #0DAh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont22:

    ; "o" numeral
    cjne @R1, #17h, vfd_cont23
        mov SBUF, #3Ah              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont23:

    ; "e" numeral
    cjne @R1, #18h, vfd_cont24
        mov SBUF, #0DEh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont24:

    ; "d" numeral
    cjne @R1, #19h, vfd_cont25
        mov SBUF, #7Ah              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont25:

    ; "y" numeral
    cjne @R1, #1Ah, vfd_cont26
        mov SBUF, #76h              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont26:

    ; "u" numeral
    cjne @R1, #1Bh, vfd_cont27
        mov SBUF, #38h              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont27:

    ; "H" numeral
    cjne @R1, #1Ch, vfd_cont28
        mov SBUF, #6Eh              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont28:

    ; half of "M" numeral
    cjne @R1, #1Dh, vfd_cont29
        mov SBUF, #0ECh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont29:

    ; "b" numeral
    cjne @R1, #1Eh, vfd_cont30
        mov SBUF, #3Eh              ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont30:

    ; "P" numeral
    cjne @R1, #1Fh, vfd_cont31
        mov SBUF, #0CEh             ; send the third byte down the serial line
        jnb TI, $                   ; wait for the entire byte to be sent
        clr TI                      ; the transmit interrupt flag is set by hardware but must be cleared by software
        ljmp vfd_load_and_latch     ; jump to end
    vfd_cont31:

    vfd_load_and_latch:

    setb P3.5                       ; load the MAX6921
    clr P3.5                        ; latch the MAX6921

    ; Now we prepare for the next cycle
    clr c                               ; clear carry bit
    mov a, GRID_EN_1                    ; move GRID_EN_1 into accumulator
    rlc a                               ; rotate the accumlator left through carry (NOTE! the carry flag gets rotated into bit 0)
    mov GRID_EN_1, a                    ; move the rotated result back into GRID_EN_1
    mov a, GRID_EN_2                    ; move GRID_EN_2 into the accumlator
    rlc a                               ; rotate the acculator left through carry (NOTE! the carry flag gest rotated into bit 0)
    mov GRID_EN_2, a                    ; move the rotated result back into GRID_EN_2
    ; clr c                                 ; clear the carry flag
    cjne R1, #3Ch, vfd_cont32           ; check if a complete grid cycle has finished (GRID_INDX == #3Ch)
        lcall VFD_RESET                 ; reset the VFD cycle
    vfd_cont32:

    pop PSW
    pop acc                 ; restore value of a to value before UPDATE_VFD was called
    pop 1                   ; restore value of R1 to value before UPDATE_VFD was called
ret

VFD_RESET:
    ; This function resets the VFD registers after a complete cycle

    ; Initalize grid index (start with grid 9)
    mov GRID_EN_1, #80h
    mov GRID_EN_2, #00h
    mov GRID_INDX, #33h     ; corresponds to memory location of GRID9
ret

DECA_LOAD:
    ; This function sequentially cycles through any active (as dictated by DECATRON)
    ; decatron cathodes to ravel and unravel the appropriate number of seconds.
    ; DECA_LOAD_STATE points to the next cathode (Kx, G1, or G2) that is to be illuminated.
    ; DECA_TOGGLE is called when the direction of the cathode swiping is to be flipped (R4 = 0).
    ; On a change of direction, the end cathode remains illuminated for the next cycle.
    ; DECA_FORWARDS? keeps track of the direction of the cathode swiping.
    ; DECATRON_BUFFER ensures the correct direction of raveling/unraveling.

    ; R4 stores the count of how many cathodes need to be lit up before switching directions.
    ; R3 stores DECA_LOAD_STATE.

    ; push any used SFRs onto the stack to preserve their values
    push 3
    ; push 4
    push acc
    push PSW

    mov R3, DECA_LOAD_STATE                     ; move DECA_LOAD_STATE to R3

    ; ==========================================
    mov a, DECATRON                             ; move DECATRON into the accumulator
    cjne a, #00h, deca_test_cont0               ; if DECATRON = 0, then no need to toggle, blank the decatron and skip to the end,
                                                ; otherwise, continue
        ; don't blank decatron if in DECA_FAST_STATE
        mov a, DECA_STATE
        cjne a, #DECA_FAST_STATE, deca_load_cont8
            sjmp deca_load_display_decatron_equals_1    ; treat DECATRON as if it equals 1 instead of 0, but don't increment DECATRON
        deca_load_cont8:
        mov a, DECATRON                         ; move DECATRON into the accumulator

        clr P0.4                                ; turn off the decatron
        clr P0.0                                ; turn off K0
        clr P0.1                                ; turn off G1
        clr P0.2                                ; turn off G2
        clr P0.3                                ; turn off Kx
        ljmp deca_load_cont6                    ; exit (NOTE: "ret" DOES NOT work for some reason...)
    deca_test_cont0:

    cjne a, #01h, deca_test_cont1               ; if DECATRON = 1, then no need to toggle, skip to the end, otherwise, continue
        deca_load_display_decatron_equals_1:
        lcall DECA_RESET                        ; reset the decatron (light up K0)
        ljmp deca_load_cont6                    ; exit (NOTE: "ret" DOES NOT work for some reason...)
    deca_test_cont1:
    ; ==========================================

    ; mov a, DECA_STATE
    ; cjne a, #DECA_FLASHING_STATE, deca_load_cont10
    ;   ljmp deca_load_cont9                    ; don't turn decatron on if in DECA_FLASHING_STATE
    ; deca_load_cont10:
    ;   setb P0.4                               ; make sure the decatron is on if not in DECA_FLASHING_STATE
    ; deca_load_cont9:

    djnz R4, deca_load_cont1                    ; decrement R4 by 1, and check if it is zero
        lcall DECA_TOGGLE                       ; if R4 is zero, toggle the deca (call DECA_TOGGLE)
        sjmp deca_load_cont6                    ; exit
    deca_load_cont1:

    cjne R3, #00h, deca_load_cont2          ; if we are in DECA_LOAD_STATE 0, jump the arc to G1
        jb DECA_FORWARDS?, deca_load_cont3  ; check direction of swiping
            ; if swiping counter-clockwise
            setb P0.1                           ; pull G1 low (note inverter between 8051 pin and decatron)
            clr P0.2                            ; pull G2 high (note inverter between 8051 pin and decatron)
            mov DECA_LOAD_STATE, #02h           ; DECA_LOAD_STATE: 0 --> 2
            sjmp deca_load_cont6                ; exit
        deca_load_cont3:
        ; if swiping clockwise
        setb P0.1                               ; pull G1 low (note inverter between 8051 pin and decatron)
        clr P0.3                                ; pull Kx high (note inverter between 8051 pin and decatron)
        clr P0.0                                ; pull K0 high (note inverter between 8051 pin and decatron)
        inc DECA_LOAD_STATE                     ; DECA_LOAD_STATE:  0 --> 1
        sjmp deca_load_cont6                    ; exit
    deca_load_cont2:

    cjne R3, #01h, deca_load_cont4          ; if we are in DECA_LOAD_STATE 1, jump the arc to G2
        jb DECA_FORWARDS?, deca_load_cont5  ; check direction of swiping
            ; if swiping counter-clockwise
            setb P0.2                           ; pull G2 low (note inverter between 8051 pin and decatron)
            clr P0.3                            ; pull Kx high (note inverter between 8051 pin and decatron)
            clr P0.0                            ; pull K0 high (note inverter between 8051 pin and decatron)
            dec DECA_LOAD_STATE                 ; DECA_LOAD_STATE:  1 --> 0
            sjmp deca_load_cont6                ; exit
        deca_load_cont5:
        ; if swiping clockwise
        setb P0.2                               ; pull G2 low (note inverter between 8051 pin and decatron)
        clr P0.1                                ; pull G1 high (note inverter between 8051 pin and decatron)
        inc DECA_LOAD_STATE                     ; DECA_LOAD_STATE:  1 --> 2
        sjmp deca_load_cont6                    ; exit
    deca_load_cont4:

    cjne R3, #02h, deca_load_cont6          ; if we are in DECA_LOAD_STATE 2, jump the arc to Kx
        jb DECA_FORWARDS?, deca_load_cont7  ; check direction of swiping
            ; if swiping counter-clockwise
            ; if R4 = 1 & DECATRON is less than or equal to 30, pull K0 low, else pull Kx low.
            cjne R4, #01h, deca_load_cont11
                ; see if DECATRON is greater than or less than (or equal to) 30
                clr c                           ; clear the carry bit
                mov a, #1Eh                     ; move 30 into the accumulator
                subb a, DECATRON                ; perform 30-DECATRON.  if DECATRON is greater than 30, the carry flag (c) will be set
                jc deca_load_cont11
                    ; R4 = 1 & DECATRON is less than or equal to 30, so we should be pulling K0 low:
                    setb P0.0                   ; pull K0 low (note inverter between 8051 pin and decatron)
                    clr P0.1                    ; pull G1 high (note inverter between 8051 pin and decatron)
                    dec DECA_LOAD_STATE         ; DECA_LOAD_STATE:  2 --> 1
                    sjmp deca_load_cont6
            deca_load_cont11:
            ; if NOT at K0:
            setb P0.3                           ; pull Kx low (note inverter between 8051 pin and decatron)
            clr P0.1                            ; pull G1 high (note inverter between 8051 pin and decatron)
            dec DECA_LOAD_STATE                 ; DECA_LOAD_STATE:  2 --> 1
            sjmp deca_load_cont6                ; exit
        deca_load_cont7:
        ; if swiping clockwise
        ; NO NEED TO EVER PULL K0 LOW SWIPING CLOCKWISE:
        ; setb P0.0                             ; pull K0 low (note inverter between 8051 pin and decatron)
        setb P0.3                               ; pull Kx low (note inverter between 8051 pin and decatron)
        clr P0.2                                ; pull G2 high (note inverter between 8051 pin and decatron)
        mov DECA_LOAD_STATE, #00h               ; DECA_LOAD_STATE:  2 --> 0
        sjmp deca_load_cont6                    ; exit
    deca_load_cont6:

    ; pop the original SFR values back into their place and restore their values
    pop PSW
    pop acc
    ; pop 4
    pop 3
ret

UPDATE_DECA:
    push acc
    push PSW

    mov a, DECA_STATE
    ; COUNTING_SECONDS =================================================
    cjne a, #DECA_COUNTING_SECONDS_STATE, update_deca_cont0
        ; on transition to this state:
            ; Timer 0 interrupt should be configured to tigger @ 1Hz
        lcall DECA_COUNTING_SECONDS
        ljmp update_deca_cont6
    update_deca_cont0:
    ; FAST_MODE ========================================================
    cjne a, #DECA_FAST_STATE, update_deca_cont1
        ; on transition to this state:
            ; Timer 0 interrupt should be configured to tigger @ 60Hz
        lcall DECA_FAST
        ljmp update_deca_cont6
    update_deca_cont1:
    ; SCROLLING ========================================================
    cjne a, #DECA_SCROLLING_STATE, update_deca_cont2
        lcall DECA_SCROLLING
        ljmp update_deca_cont6
    update_deca_cont2:
    ; RADAR_MODE =======================================================
    cjne a, #DECA_RADAR_STATE, update_deca_cont3
        ; on transition to this state:
            ; call DECA_RESET (to position decatron at K0)
            ; Timer 0 interrupt should be configured to tigger @ 60Hz
        lcall DECA_RADAR
        ljmp update_deca_cont6
    update_deca_cont3:
    ; COUNTDOWN ========================================================
    cjne a, #DECA_COUNTDOWN_STATE, update_deca_cont4
        lcall DECA_COUNTDOWN
        ljmp update_deca_cont6
    update_deca_cont4:
    ; FLASHING =========================================================
    cjne a, #DECA_FLASHING_STATE, update_deca_cont5
        lcall DECA_FLASHING
        ljmp update_deca_cont6
    update_deca_cont5:
    ; FILL UP ==========================================================
    cjne a, #DECA_FILL_UP_STATE, update_deca_cont6
        lcall DECA_FILL_UP
    update_deca_cont6:

    pop PSW
    pop acc
ret

DECA_TOGGLE:
    ; This function is called from UPDATE_LOAD whenever the swiping direction has to change.
    ; If going from forward to backwards, DECA_LOAD_STATE is decremented by 2 (incremented by 1) (mod 3).
    ; If going from backwards to forward, DECA_LOAD_STATE is incremented by 2 (decremented by 1) (mod 3).
    ; DECA_FORWARDS? is a bit that keeps track of swiping direction.
    ; DECA_FORWARDS? = 1 when swiping is clockwise, = 0 when swiping is counter-clockwise.
    ; DECATRON_BUFFER is loaded with the latest DECATRON count when swiping in the appropriate direction.
    ; This prevents erratic raveling/unraveling patterns.

    ; R4 stores the count of how many cathodes need to be lit up before switching directions.
    ; R3 stores DECA_LOAD_STATE.

    ; No need to push SFRs onto the stack because this function is called only from DECA_LOAD, which
    ; does the pushing/popping.


    cpl DECA_FORWARDS?                          ; toggle the swiping direction

    ; mov a, DECATRON                               ; move DECATRON into the accumulator
    ; cjne a, #00h, deca_toggle_cont8               ; if DECATRON = 0, then no need to toggle, blank the decatron and skip to the end,
                                                    ; otherwise, continue
        
    ;   ; FIX -- FOR FAST MODE
    ;   ;mov DECATRON, #01                      ; move 1 into decatron (don't blank in fast mode, so the decatron always starts in the same spot)
    ;   ;lcall DECA_RESET                       ; reset the decatron (light up K0)
    ;   ;sjmp deca_toggle_cont1                 ; exit (NOTE: "ret" DOES NOT work for some reason...)

    ;   clr P0.4                                ; turn off the decatron
    ;   clr P0.0                                ; turn off K0
    ;   clr P0.1                                ; turn off G1
    ;   clr P0.2                                ; turn off G2
    ;   clr P0.3                                ; turn off Kx
    ;   sjmp deca_toggle_cont1                  ; exit (NOTE: "ret" DOES NOT work for some reason...)
    ; deca_toggle_cont8:

    ; ; mov a, DECATRON                             ; move DECATRON into the accumulator
    ; cjne a, #01h, deca_toggle_cont0               ; if DECATRON = 1, then no need to toggle, skip to the end, otherwise, continue
    ;   ;mov R4, DECATRON                       ; reload R4
    ;   lcall DECA_RESET                        ; reset the decatron (light up K0)
    ;   sjmp deca_toggle_cont1                  ; exit (NOTE: "ret" DOES NOT work for some reason...)
    ; deca_toggle_cont0:

    ; see if DECATRON is greater than or less than (or equal to) 30
    clr c                                       ; clear the carry bit
    mov a, #1Eh                                 ; move 30 into the accumulator
    subb a, DECATRON                            ; perform 30-DECATRON.  if DECATRON is greater than 30, the carry flag (c) will be set

    jb DECA_FORWARDS?, deca_toggle_cont2
        ; if going from forwards to backwards
        jnc deca_toggle_cont3                   ; if the carry flag is set, DECATRON > 30
            ; if seconds are greater than 30:
            clr c                               ; clear the carry flag
            mov a, #3Ch                         ; move 60 into the accumulator
            subb a, DECATRON                    ; perform 60-DECATRON.
            mov DECATRON_BUFFER, a              ; move the result into DECATRON_BUFFER
        deca_toggle_cont3:
        ; if seconds are less than or equal to 30:
        mov R4, DECATRON_BUFFER                 ; reload R4 with DECATRON_BUFFER  (this prevents erratic raveling)

        ; update the DECA_LOAD_STATE
        mov R3, DECA_LOAD_STATE                 ; move DECA_LOAD_STATE into R3
        inc R3                                  ; increment R3 (same as decrementing twice after mod 3)
        cjne R3, #03h, deca_toggle_cont4        ; check if DECA_LOAD_STATE needs to roll over from 3 to 0
            mov R3, #00h                        ; if DECA_LOAD_STATE = 3, set it to 0
        deca_toggle_cont4:
        mov DECA_LOAD_STATE, R3                 ; update DECA_LOAD_STATE
        sjmp deca_toggle_cont1                  ; exit ("ret" did work here, but changed to sjmp in case of monkey business...)

    deca_toggle_cont2:
    ; if going from backwards to forwards
    jnc deca_toggle_cont5                       ; if the carry flag is set, DECATRON > 30
        ; if seconds are greater than 30
        mov R4, DECATRON_BUFFER                 ; move DECATRON_BUFFER into R4 (this prevents erratic unraveling)
        sjmp deca_toggle_cont6                  ; jump to update DECA_LOAD_STATE

    deca_toggle_cont5:
    ; if seconds are less than or equal to 30:
    mov R4, DECATRON                            ; move DECATRON into R4
    mov DECATRON_BUFFER, DECATRON               ; update the DECATRON_BUFFER with DECATRON

    deca_toggle_cont6:
    ; update the DECA_LOAD_STATE
    mov R3, DECA_LOAD_STATE                     ; move DECA_LOAD_STATE into R3
    dec R3                                      ; decrement R3 (same as incrementing twice after mod 3)
    cjne R3, #0FFh, deca_toggle_cont7           ; check if DECA_LOAD_STATE needs to wrap around from 255 to 2
        mov R3, #02h                            ; if DECA_LOAD_STATE = 255, set it to 2
    deca_toggle_cont7:

    mov DECA_LOAD_STATE, R3                     ; update DECA_LOAD_STATE

    deca_toggle_cont1:
ret

DECA_RESET:
    mov DECA_LOAD_STATE, #00h               ; initialize the decatron
    mov DECATRON, #01h

    mov R4, DECATRON                ; initialize R4
    mov DECATRON_BUFFER, DECATRON   ; reset the decatron DECATRON_BUFFER (!!! Important or the decatron will flash - reason for decatron bug after
                                    ; coming out of the SET_TIME state)

    setb P0.0                       ; turn on K0
    clr P0.1                        ; turn off G1
    clr P0.2                        ; turn off G2
    clr P0.3                        ; turn off Kx
    
    setb P0.4                       ; turn on the decatron

    setb DECA_FORWARDS?             ; set the direction of the decatron
ret

; ==========================================

; ======= Decatron State Functions =========
DECA_COUNTING_SECONDS:
    mov DECATRON, SECONDS
    lcall DECA_LOAD
ret

DECA_FAST:
    lcall DECA_LOAD
ret

DECA_SCROLLING:
    ; determine value to load into DECATRON based on number of settings items and current index
    ; look up NUMBER_OF_ACTIVE_SETTINGS to pick the address of which lookup table to use in the data pointer (DPTR)
    mov a, NUMBER_OF_ACTIVE_SETTINGS

    cjne a, #08h, deca_scrolling_cont0
        ; NUMBER_OF_ACTIVE_SETTINGS is 8
        mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_8_SETTINGS      ; DPTR points to the start of the lookup table
        sjmp deca_scrolling_cont1

    deca_scrolling_cont0:
    cjne a, #07h, deca_scrolling_cont2
        ; NUMBER_OF_ACTIVE_SETTINGS is 7
        mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_7_SETTINGS      ; DPTR points to the start of the lookup table
        sjmp deca_scrolling_cont1

    deca_scrolling_cont2:
        ; NUMBER_OF_ACTIVE_SETTINGS is 5
        mov DPTR, #DECA_SCROLL_LOOKUP_TABLE_5_SETTINGS      ; DPTR points to the start of the lookup table

    deca_scrolling_cont1:
    mov a, SETTINGS_SUB_STATE                               ; SETTINGS_SUB_STATE is the offset from the start of the lookup table
    dec a                                                   ; decrement a such that lookup table offset is right (NOTE: lookup tables loads
                                                            ; (a+1)th item in lookup table)
    movc a, @a + DPTR                                       ; moves the (a+1)th lookup table item into the accumulator
    mov DECATRON, a                                         ; accumulator should now hold how many decatron pins to light up

    lcall DECA_LOAD
ret

DECA_RADAR:
    push acc

    mov a, DECA_LOAD_STATE
    
    cjne a, #00h, deca_radar_cont0
        setb P0.0                               ; turn on K0
        setb P0.3                               ; turn on Kx
        clr P0.1                                ; turn off G1
        clr P0.2                                ; turn off G2
        ; inc DECA_LOAD_STATE
        ljmp deca_radar_cont2
    deca_radar_cont0:

    cjne a, #01h, deca_radar_cont1
        setb P0.1                               ; turn on G1
        clr P0.0                                ; turn off K0
        clr P0.3                                ; turn off Kx
        clr P0.2                                ; turn off G2
        ; inc DECA_LOAD_STATE
        ljmp deca_radar_cont2
    deca_radar_cont1:

    cjne a, #02h, deca_radar_cont2
        setb P0.2                               ; turn on G2
        clr P0.1                                ; turn off G1
        clr P0.0                                ; turn off K0
        clr P0.3                                ; turn off Kx
        ; mov DECA_LOAD_STATE, #00h
        ljmp deca_radar_cont2
    deca_radar_cont2:

    pop acc
ret

DECA_COUNTDOWN:
    lcall DECA_LOAD
ret

DECA_FLASHING:
    ; NOTE: Flashing logic is performed in FLASH_DISPLAYS function
    lcall DECA_LOAD
ret

DECA_FILL_UP:
    lcall DECA_LOAD
ret

; === Decatron State Transition Functions ==

ENTER_DECA_COUNTING_SECONDS_STATE:
    ; Make Timer 0 ISR fire at 1Hz
    mov TL0, #0C4h                          ; initialize TL0 (#C4h for 60Hz, #CEh for 50Hz)
    mov TH0, #0C4h                          ; initialize TH0 (#C4h for 60Hz, #CEh for 50Hz) - reload value
    mov TIMER_0_POST_SCALER, #01h           ; update TIMER_0_POST_SCALER
    mov TIMER_0_POST_SCALER_RELOAD, #01h    ; update TIMER_0_POST_SCALER_RELOAD
    ; setb TR0                              ; start timer 0

    mov DECA_STATE, #DECA_COUNTING_SECONDS_STATE        ; update decatron state variable

    ; lcall DECA_TRANSITION     ; transition the decatron (MUST HAPPEN AFTER STATE CHANGE OR FLASHING WILL CONTINUE IN DECA_TRANSITION)
ret

ENTER_DECA_FAST_STATE:
    ; Make Timer 0 ISR fire at 60Hz (or 50Hz depending on AC mains frequency)
    mov TL0, #0FFh
    mov TH0, #0FFh
    mov TIMER_0_POST_SCALER, #3Ch           ; update TIMER_0_POST_SCALER (60 dec)
    mov TIMER_0_POST_SCALER_RELOAD, #3Ch    ; update TIMER_0_POST_SCALER_RELOAD
    
    mov DECA_STATE, #DECA_FAST_STATE        ; update decatron state variable
    mov DECATRON, #00h                      ; start DECATRON at zero
ret

ENTER_DECA_SCROLLING_STATE:
    mov DECA_STATE, #DECA_SCROLLING_STATE               ; update decatron state variable
    ; lcall DECA_RESET                                  ; call DECA_RESET (to position decatron at K0)
    ; mov DECATRON, #00h                                    ; start with the decatron empty
ret

ENTER_DECA_RADAR_STATE:
    ; Make Timer 0 ISR fire at 60Hz (or 50Hz depending on AC mains frequency)
    mov TL0, #0FFh
    mov TH0, #0FFh
    mov TIMER_0_POST_SCALER, #3Ch           ; update TIMER_0_POST_SCALER (60 dec)
    mov TIMER_0_POST_SCALER_RELOAD, #3Ch    ; update TIMER_0_POST_SCALER_RELOAD

    mov DECA_STATE, #DECA_RADAR_STATE       ; update decatron state variable
    lcall DECA_RESET                        ; call DECA_RESET (to position decatron at K0)
ret

ENTER_DECA_COUNTDOWN_STATE:
    ; Make Timer 0 ISR fire at 1Hz
    mov TL0, #0C4h                              ; initialize TL0 (#C4h for 60Hz, #CEh for 50Hz)
    mov TH0, #0C4h                              ; initialize TH0 (#C4h for 60Hz, #CEh for 50Hz) - reload value
    mov TIMER_0_POST_SCALER, #01h               ; update TIMER_0_POST_SCALER
    mov TIMER_0_POST_SCALER_RELOAD, #01h        ; update TIMER_0_POST_SCALER_RELOAD
    ; setb TR0                                  ; start timer 0

    mov DECA_STATE, #DECA_COUNTDOWN_STATE       ; update decatron state variable
    mov DECATRON, #1Eh                          ; move 30 (dec) into DECATRON to light up full
ret

ENTER_DECA_FLASHING_STATE:
    ; The following lines are done in FLASH_DISPLAYS function so displays flash together
    ; clr P0.4                                          ; blank the decatron
    ; mov DECATRON, #1Eh                                ; move 30 (dec) into DECATRON to light up full

    ; check if the alarm is currently enabled, in which case, keep it enabled
    ; NOTE:  this ensures a snoozing alarm gets canceled
    jnb P1.4, enter_deca_flashing_state_cont0
        ; TODO:  the alarm might actually be in snoozing or enabled states, so the below call doesn't really make full sense,
        ;        consider doing entry functions if possible for the alarm and clock state transitions
        lcall ALARM_SNOOZING_STATE_TO_ALARM_ENABLED_STATE   ; alarm is enabled if P1.4 is high
    enter_deca_flashing_state_cont0:

    mov DECA_STATE, #DECA_FLASHING_STATE                ; update decatron state variable
ret

ENTER_DECA_FILL_UP_STATE:
    setb DECA_IN_TRANSITION?                ; DECA_FILL_UP_STATE is a temporary state

    ; Make Timer 0 ISR fire at 30Hz (or 25Hz depending on AC mains frequency)
    mov TL0, #0FEh
    mov TH0, #0FEh
    mov TIMER_0_POST_SCALER, #1Eh           ; update TIMER_0_POST_SCALER (30 dec)
    mov TIMER_0_POST_SCALER_RELOAD, #1Eh    ; update TIMER_0_POST_SCALER_RELOAD
    
    mov DECA_STATE, #DECA_FILL_UP_STATE     ; update decatron state variable
    mov DECATRON, #00h                      ; start DECATRON at zero
ret

; ==========================================

ENC_A:
    ; push any used SFRs onto the stack to preserve their values
    push acc
    push PSW

    clr c                                           ; clear the carry bit

    jnb P3.3, enc_a_cont0
        setb A_FLAG
        clr B_FLAG
        ljmp enc_a_cont2
    enc_a_cont0:
    jb A_FLAG, enc_a_cont2
        lcall BEEP                                  ; beep
        inc @R0
        setb ROT_FLAG                               ; set the rotation flag
        ; lcall ADJUST_TIMEOUT                      ; adjust any timeouts that may be active
        mov TIMEOUT, TIMEOUT_LENGTH
        mov VFD_MASK, #0FFh                         ; make all displays visible
        mov NIX_MASK, #0FFh                         ; make all displays visible
        setb A_FLAG
    enc_a_cont1:

    jnb INC_LEAP_YEAR?, enc_a_cont2                 ; check if INC_LEAP_YEAR? bit is set
        ;if INC_LEAP_YEAR? bit is set, increment @R0 (YEAR) three more times (for a total of 4 times) 
        inc @R0
        inc @R0
        inc @R0
    enc_a_cont2:

    ; check if @R0 is greater than UPPER_BOUND
    mov a, UPPER_BOUND                              ; move UPPER_BOUND into accumulator
    subb a, @R0                                     ; subtract a - @R0
    jnc enc_a_cont3                                 ; jump to end if carry is not set
        ; if @R0 is greater than UPPER_BOUND:
        mov @R0, LOWER_BOUND                        ; rollover @R0
    enc_a_cont3:

    ; pop the original SFR values back into their place and restore their values
    pop PSW
    pop acc
ret

ENC_B:
    ; push any used SFRs onto the stack to preserve their values
    push acc
    push PSW

    clr c                                           ; clear the carry bit

    jnb P3.2, enc_b_cont0
        setb B_FLAG
        clr A_FLAG
        ljmp enc_b_cont2
    enc_b_cont0:
    jb B_FLAG, enc_b_cont2
        lcall BEEP                                  ; beep
        dec @R0
        setb ROT_FLAG                               ; set the rotation flag
        ; lcall ADJUST_TIMEOUT                      ; adjust any timeouts that may be active
        mov TIMEOUT, TIMEOUT_LENGTH
        mov VFD_MASK, #0FFh                         ; make all displays visible
        mov NIX_MASK, #0FFh                         ; make all displays visible
        setb B_FLAG
    enc_b_cont1:

    jnb INC_LEAP_YEAR?, enc_b_cont2                 ; check if INC_LEAP_YEAR? bit is set
        ;if INC_LEAP_YEAR? bit is set, decrement @R0 (YEAR) three more times (for a total of 4 times) 
        dec @R0
        dec @R0
        dec @R0
    enc_b_cont2:

    ; check if @R0 is less than LOWER_BOUND
    mov a, @R0                                      ; move @R0 into accumulator
    subb a, LOWER_BOUND                             ; subtract a - LOWER_BOUND
    jnc enc_b_cont4                                 ; jump to end if carry is not set
        ; if @R0 is less than LOWER_BOUND:
        mov @R0, UPPER_BOUND                        ; rollover @R0
    enc_b_cont4:

    ; !! EDGE CASE: if the lower bound is zero, dec @R0 will rollover to 255, which still looks larger than LOWER_BOUND.
    ; check if @R0 is greater than UPPER_BOUND
    mov a, UPPER_BOUND                              ; move UPPER_BOUND into accumulator
    subb a, @R0                                     ; subtract a - @R0
    jnc enc_b_cont3                                 ; jump to end if carry is not set
        ; if @R0 is greater than UPPER_BOUND:
        mov @R0, UPPER_BOUND                        ; rollover @R0
    enc_b_cont3:

    ; pop the original SFR values back into their place and restore their values
    pop PSW
    pop acc
ret

TWLV_TWFR_HOUR_ADJ:
    ; push any used SFRs onto the stack to preserve their values
    push acc
    push PSW
    push b

    ;mov a, HOURS
    mov a, @R1                                  ; move @R1 (i.e. HOURS, or ALARM_HOURS, etc.)
    jnb TWLV_HR_MODE?, twlv_twfr_hour_adj_cont1         ; check if 12 or 24 hour time

    ; Handle the 12-hour mode case
    cjne a, #00h, twlv_twfr_hour_adj_cont4      ; check if time is 00:xx
        mov a, #0Ch                             ; if hours are 00, 00 --> 12
        sjmp twlv_twfr_hour_adj_cont1
    twlv_twfr_hour_adj_cont4:
    cjne a, #0Ch, twlv_twfr_hour_adj_cont5      ; check if time is 12:xx
        setb P1.5                               ; turn on the PM light, and don't change the hours
        sjmp twlv_twfr_hour_adj_cont3
    twlv_twfr_hour_adj_cont5:
    subb a, #0Ch                                ; check if current hour is > 12
    jc twlv_twfr_hour_adj_cont2
        setb P1.5                               ; turn on the PM light
        sjmp twlv_twfr_hour_adj_cont3

    twlv_twfr_hour_adj_cont2:
    mov a, @R1

    twlv_twfr_hour_adj_cont1:
    clr P1.5                                    ; turn off PM light

    twlv_twfr_hour_adj_cont3:
    ; Operations to dispay HOURS register in decimal format: HR
    mov b, #0Ah
    div ab
    mov HR_TENS, a
    mov HR_ONES, b

    ; Display HOURS:
    mov NIX4, HR_TENS
    mov NIX3, HR_ONES

    pop b
    pop PSW
    pop acc
ret

DD_ADJ:
    ; This function adjust the day (DD) of the date such that the user cannot input an impossible date (i.e. 2/31/2019)
    ; Set the upper and lower bounds
    mov R2, MONTH
    mov LOWER_BOUND, #01h                   ; days can be 1 min

    January:
    cjne R2, #01h, February
        mov UPPER_BOUND, #1Fh               ; days can be 31 max
        ljmp dd_adj_cont0                   ; no need to check the day, continue

    February:
    cjne R2, #02h, March
        mov UPPER_BOUND, #1Dh               ; days can be 29 max
        ljmp dd_adj_cont1                   ; jump to check that the day is legal

    March:
    cjne R2, #03h, April
        mov UPPER_BOUND, #1Fh               ; days can be 31 max
        ljmp dd_adj_cont0                   ; no need to check the day, continue

    April:
    cjne R2, #04h, May
        mov UPPER_BOUND, #1Eh               ; days can be 30 max
        ljmp dd_adj_cont1                   ; jump to check that the day is legal

    May:
    cjne R2, #05h, June
        mov UPPER_BOUND, #1Fh               ; days can be 31 max
        ljmp dd_adj_cont0                   ; no need to check the day, continue

    June:
    cjne R2, #06h, July
        mov UPPER_BOUND, #1Eh               ; days can be 30 max
        ljmp dd_adj_cont1                   ; jump to check that the day is legal

    July:
    cjne R2, #07h, August
        mov UPPER_BOUND, #1Fh               ; days can be 31 max
        ljmp dd_adj_cont0                   ; no need to check the day, continue

    August:
    cjne R2, #08h, September
        mov UPPER_BOUND, #1Fh               ; days can be 31 max
        ljmp dd_adj_cont0                   ; no need to check the day, continue

    September:
    cjne R2, #09h, October
        mov UPPER_BOUND, #1Eh               ; days can be 30 max
        ljmp dd_adj_cont1                   ; jump to check that the day is legal

    October:
    cjne R2, #0Ah, November
        mov UPPER_BOUND, #1Fh               ; days can be 31 max
        ljmp dd_adj_cont0                   ; no need to check the day, continue

    November:
    cjne R2, #0Bh, December
        mov UPPER_BOUND, #1Eh               ; days can be 30 max
        ljmp dd_adj_cont1                   ; jump to check that the day is legal

    December:
    mov UPPER_BOUND, #1Fh                   ; days can be 31 max
    ljmp dd_adj_cont0                       ; no need to check the day, continue

    dd_adj_cont1:
    ; check if DAY is greater than UPPER_BOUND
    mov a, UPPER_BOUND                      ; move UPPER_BOUND into accumulator
    clr c                                   ; clear the carry bit
    subb a, DAY                             ; subtract a - DAY
    jnc dd_adj_cont0                        ; jump to end if carry is not set
        ; if DAY is greater than UPPER_BOUND:
        mov DAY, UPPER_BOUND                ; set the day to the max value
    dd_adj_cont0:
ret

YY_ADJ:
    ; This function adjust the day (DD) of the date such that the user cannot input an impossible date (i.e. 2/29/2019)
    ; check for leap day condition

    ; Set the upper and lower bounds
    mov LOWER_BOUND, #00h                   ; years can be 00 min
    mov UPPER_BOUND, #63h                   ; years can be 99 max

    mov R2, MONTH

    cjne R2, #02h, yy_adj_cont0             ; if the month is february
        mov R2, DAY                         ; move DAY into R2
        cjne R2, #1Dh, yy_adj_cont0         ; and if the day is the 29th 
            setb INC_LEAP_YEAR?             ; set the INC_LEAP_YEAR? flag
            mov UPPER_BOUND, #60h           ; move 96 into UPPER_BOUND for leap day condition (don't want rollover to be 99)
            ; adjust the year if it's not a multiple of 4
            mov a, YEAR                     ; move the YEAR into the accumulator
            mov b, #04h                     ; move 4 into b
            div ab                          ; divide: a/b with the quotient in a and remainder in b
            mov a, b                        ; move b into accumulator
            ; decrement the YEAR until it is a multiple of 4
            yy_adj_loop0:
            jz yy_adj_cont0                 ; jump to yy_adj_cont0 if the accumulator is zero (valid leap year)
                dec YEAR                    ; decrement the YEAR
                dec a                       ; decrement the accumulator
                sjmp yy_adj_loop0           ; loop

    yy_adj_cont0:
ret

ASCII_TO_HEX:
    ; this routine is used for the GPS checksum
    ; this routine takes a received ascii number/letter: 0 through F, and turns it into its hex equivalent:
    ; (in)  ------- (out)
    ; (acc) ------- (acc)
    ; ASCII ------- HEX 
    ; #30h  ....... #00h
    ; #31h  ....... #01h
    ; #32h  ....... #02h
    ; #33h  ....... #03h
    ; #34h  ....... #04h
    ; #35h  ....... #05h
    ; #36h  ....... #06h
    ; #37h  ....... #07h
    ; #38h  ....... #08h
    ; #39h  ....... #09h
    ; #41h  ....... #0Ah
    ; #42h  ....... #0Bh
    ; #43h  ....... #0Ch
    ; #44h  ....... #0Dh
    ; #45h  ....... #0Eh
    ; #46h  ....... #0Fh
    push 0
    push PSW

    mov R0, a                   ; save orignial a value in R0
    clr c                       ; clear the carry flag
    subb a, #39h                ; compare the received SBUF (ascii) with #39h.  if the received data is less than #39h, then the carry flag is set
    jnc convert_alpha           ; if the carry flag is NOT set, we are dealing with A, B, C, D, E, or F
        mov a, R0               ; restore original a value
        anl a, #0Fh             ; convert numeric ascii to hex code
        ljmp ascii_to_hex_end   ; jump to end
    convert_alpha:              
        mov a, R0               ; restore original a value
        ;subb a, #37h           ; convert alpha ascii to hex code

    ascii_to_hex_end:

    pop PSW
    pop 0
ret

LOAD_GPS_DATA:
    ; this function is used to load the received GPS data into the SECONDS, MINUTES, HOURS, DAY, MONTH, and YEAR registers.
    
    ; push registers (note: this function is called in an ISR)
    ; not pushing acc because it is pushed earlier
    push b
    push PSW

    ; load seconds
    mov b, #0Ah                         ; move 10 (dec) into b
    mov a, RECEIVED_GPS_SECS_TENS       ; move GPS data into accumulator
    mul ab                              ; multiply the xxx_TENS by 10
    add a, RECEIVED_GPS_SECS_ONES       ; add the xxx_ONES to the product
    mov SECONDS, a                      ; load SECONDS with GPS data

    ; load minutes
    mov b, #0Ah                         ; move 10 (dec) into b
    mov a, RECEIVED_GPS_MINS_TENS       ; move GPS data into accumulator
    mul ab                              ; multiply the xxx_TENS by 10
    add a, RECEIVED_GPS_MINS_ONES       ; add the xxx_ONES to the product
    mov MINUTES, a                      ; load MINUTES with GPS data

    ; load hours
    mov b, #0Ah                         ; move 10 (dec) into b
    mov a, RECEIVED_GPS_HRS_TENS        ; move GPS data into accumulator
    mul ab                              ; multiply the xxx_TENS by 10
    add a, RECEIVED_GPS_HRS_ONES        ; add the xxx_ONES to the product
    mov HOURS, a                        ; load HOURS with GPS data

    ; load day
    mov b, #0Ah                         ; move 10 (dec) into b
    mov a, RECEIVED_GPS_DAY_TENS        ; move GPS data into accumulator
    mul ab                              ; multiply the xxx_TENS by 10
    add a, RECEIVED_GPS_DAY_ONES        ; add the xxx_ONES to the product
    mov DAY, a                          ; load DAY with GPS data

    ; load month
    mov b, #0Ah                         ; move 10 (dec) into b
    mov a, RECEIVED_GPS_MONTH_TENS      ; move GPS data into accumulator
    mul ab                              ; multiply the xxx_TENS by 10
    add a, RECEIVED_GPS_MONTH_ONES      ; add the xxx_ONES to the product
    mov MONTH, a                        ; load MONTH with GPS data

    ; load year
    mov b, #0Ah                         ; move 10 (dec) into b
    mov a, RECEIVED_GPS_YEAR_TENS       ; move GPS data into accumulator
    mul ab                              ; multiply the xxx_TENS by 10
    add a, RECEIVED_GPS_YEAR_ONES       ; add the xxx_ONES to the product
    mov YEAR, a                         ; load YEAR with GPS data

    ; apply timezone offset
    lcall APPLY_TIMEZONE_TO_UTC

    pop PSW
    pop b
ret

APPLY_TIMEZONE_TO_UTC:
    ; This function applies the timezone offset stored in TIMEZONE to the HOURS, MONTH, DAY, and YEAR registers.
    ; NOTE:  Be careful when calling this function -- what is in HOURS, MONTH, DAY, YEAR should be UTC before calling this.
    push acc
    push PSW

    mov a, TIMEZONE
    add a, HOURS                            ; add HOURS to TIMEZONE
    clr c
    subb a, #0Eh                            ; remove the offset of TIMEZONE

    jnc apply_timezone_to_utc_cont0         ; determine if the hours rolled under
        ; the hours rolled under (HOURS < 0), so wrap it around to 23 again
        add a, #18h                         ; add 24 (dec) to the accumulator to get the result within 0 and 23
        lcall DECREMENT_DAY                 ; decrement the day (helper function takes care of DAY, MONTH, and YEAR)
        sjmp apply_timezone_to_utc_cont2

    apply_timezone_to_utc_cont0:
    ; the hours did not roll under (HOURS are not < 0), so check if the hours rolled over (if HOURS > 23)
    clr c
    subb a, #18h                            ; subtract 24 (dec) from the accumulator to determine if a is between 0 and 23 or above 23
    jnc apply_timezone_to_utc_cont1
        ; the hours did not roll over or under (0 <= HOURS <= 23)
        add a, #18h                         ; add 24 (dec) to the accumulator to get the result within 0 and 23
        sjmp apply_timezone_to_utc_cont2

    apply_timezone_to_utc_cont1:
    ; the hours rolled over (HOURS > 23), and already subtracted 24 (dec) from it
    lcall INCREMENT_DAY                     ; increment the day (helper function takes care of DAY, MONTH, and YEAR)

    apply_timezone_to_utc_cont2:
    ; the hours with the UTC offset applied are in the accumulator and ready to display
    mov HOURS, a                            ; move the calculated value into HOURS

    pop PSW
    pop acc
ret

UNAPPLY_TIMEZONE_TO_GET_UTC:
    ; This function unapplies the timezone offset stored in TIMEZONE to the HOURS, MONTH, DAY, and YEAR registers.
    ; NOTE:  Be careful when calling this function -- this function is intended to strip the HOURS, etc. registers from their applied
    ; timezone offsets such that what remains in HOURS, etc. registers is UTC time.

    ; flip the current value in TIMEZONE about its offset (dec 14, hex #0Eh)
    mov a, #1Ch             ; move 28 (dec) into the accumulator
    subb a, TIMEZONE        ; subtract the current TIMEZONE offset from 28
    mov TIMEZONE, a         ; put the result into TIMEZONE

    ; call APPLY_TIMEZONE_TO_UTC, noting that what is currently stored in TIMEZONE is reversed
    lcall APPLY_TIMEZONE_TO_UTC

    ; flip the TIMEZONE again so it holds the original timezone offset
    mov a, #1Ch             ; move 28 (dec) into the accumulator
    subb a, TIMEZONE        ; subtract the current TIMEZONE offset from 28
    mov TIMEZONE, a         ; put the result into TIMEZONE
ret

INCREMENT_DAY:
    ; This function is used to increment DAY, including making changes to MONTH and YEAR if necessary.

    ; push used registers
    push acc
    push b
    push PSW

    inc DAY         ; increment the DAY
    
    ; == Check if we need to increment the MONTH ===============
    mov a, DAY

    ; if DAY is 29, check if MONTH is February
    cjne a, #1Dh, increment_day_cont0
        mov a, MONTH
        cjne a, #02h, increment_day_done            ; check if MONTH is February
            ; check if it is a leap year, in which case the MONTH does not need to change
            mov a, YEAR
            mov b, #04h
            div ab                                  ; check if the year is a multiple of 4 (leap year)
            mov a, b                                ; put the remainder into the accumulator
            jz increment_day_done                   ; if it is a leap year, the accumulator is zero, so jump to end of routine
                ; it is not a leap year, so increment the month
                inc MONTH
                mov DAY, #01h                       ; roll over the DAY
                sjmp increment_day_done             ; we know the MONTH is March, so no need to check to increment the year

    increment_day_cont0:
    ; if DAY is 30, check if MONTH is February
    cjne a, #1Eh, increment_day_cont1
        mov a, MONTH
        cjne a, #02h, increment_day_done            ; check if MONTH is February
            inc MONTH                               ; increment the month
            mov DAY, #01h                           ; roll over the day
            sjmp increment_day_done                 ; we know the MONTH is March, so no need to check to increment the year

    increment_day_cont1:
    ; if DAY is 31, check if MONTH is April, June, September, or November
    cjne a, #1Fh, increment_day_cont2
        mov a, MONTH
        cjne a, #04h, increment_day_cont3           ; check if MONTH is April
            inc MONTH
            mov DAY, #01h
            sjmp increment_day_done
        increment_day_cont3:
        cjne a, #06h, increment_day_cont4           ; check if MONTH is June
            inc MONTH
            mov DAY, #01h
            sjmp increment_day_done
        increment_day_cont4:
        cjne a, #09h, increment_day_cont5           ; check if MONTH is September
            inc MONTH
            mov DAY, #01h
            sjmp increment_day_done
        increment_day_cont5:
        cjne a, #0Bh, increment_day_done            ; check if MONTH is November
            inc MONTH
            mov DAY, #01h
            sjmp increment_day_done

    increment_day_cont2:
    ; if DAY is 32, we will have to roll over MONTH regardless
    cjne a, #20h, increment_day_done
        inc MONTH
        mov DAY, #01h

    ; == Check if we need to increment the YEAR ================
    mov a, MONTH 
    ; if MONTH is 13, increment the YEAR
    cjne a, #0Dh, increment_day_done
        inc YEAR
        mov MONTH, #01h

    ; == Check if we need to increment the century =============
    mov a, YEAR
    ; if YEAR is 100, change YEAR -> 0
    cjne a, #64h, increment_day_done
        mov YEAR, #00h

    increment_day_done:

    ; pop registers
    pop PSW
    pop b
    pop acc
ret

DECREMENT_DAY:
    ; This function is used to decrement DAY, including making changes to MONTH and YEAR if necessary.

    ; push used registers
    push acc
    push b
    push PSW

    ; decrement the DAY
    djnz DAY, decrement_day_done
    
        ; If we are still here, the day has gone to 0, so decrementing the month is needed
        djnz MONTH, decrement_day_cont0
            ; the month has also gone to zero, so decrementing the year is needed
            mov a, YEAR
            jz decrement_day_cont1
                ; if YEAR is not 0:
                dec YEAR                    ; decrement the year
                mov MONTH, #0Ch             ; move 12 (dec) into MONTH for December
                mov DAY, #1Fh               ; move 31 (dec) into DAY since December has 31 days
                sjmp decrement_day_done
            decrement_day_cont1:
                ; the year is currently 0 and has to be decremented, so move in 99
                mov YEAR, #63h              ; move 99 (dec) into YEAR
                mov MONTH, #0Ch             ; move 12 (dec) into MONTH for December
                mov DAY, #1Fh               ; move 31 (dec) into DAY since December has 31 days
                sjmp decrement_day_done

        decrement_day_cont0:
            ; the month was decremented and is a valid month -- check which month to know what to put into DAY
            mov a, MONTH

            ; check if MONTH is February
            cjne a, #02h, decrement_day_cont2
                ; MONTH is February, so check if it is a leap year
                mov a, YEAR
                mov b, #04h
                div ab                                  ; check if the year is a multiple of 4 (leap year)
                mov a, b                                ; put the remainder into the accumulator
                jz decrement_day_cont3                  ; if it is a leap year, the accumulator is zero
                    ; it is not a leap year:
                    mov DAY, #1Ch                       ; move 28 (dec) into DAY since February has 28 days on a non leap year
                    sjmp decrement_day_done

                decrement_day_cont3:
                    ; it is a leap year:
                    mov DAY, #1Dh                       ; move 29 (dec) into DAY since February has 29 days on a leap year
                    sjmp decrement_day_done

            decrement_day_cont2:

            ; check if MONTH is April
            cjne a, #04h, decrement_day_cont4
                ; the MONTH is one with 30 days:
                mov DAY, #1Eh
                sjmp decrement_day_done
            decrement_day_cont4:
            
            ; check if MONTH is June
            cjne a, #06h, decrement_day_cont5
                ; the MONTH is one with 30 days:
                mov DAY, #1Eh
                sjmp decrement_day_done
            decrement_day_cont5:
            
            ; check if MONTH is September
            cjne a, #09h, decrement_day_cont6
                ; the MONTH is one with 30 days:
                mov DAY, #1Eh
                sjmp decrement_day_done
            decrement_day_cont6:
            
            ; check if MONTH is November
            cjne a, #0Bh, decrement_day_cont7
                ; the MONTH is one with 30 days:
                mov DAY, #1Eh
                sjmp decrement_day_done
            decrement_day_cont7:
            
            ; the MONTH is one with 31 days:
            mov DAY, #1Fh

    decrement_day_done:

    ; pop registers
    pop PSW
    pop b
    pop acc
ret

BEEP:
    ; check if beep is activated
    jnb BEEP_ON?, beep_cont0
        mov TL1, #00h           ; initialize TL1 for max count (16 bits)
        ; mov TH1, #80h             ; initialize TH1 for max count (16 bits)
        mov TH1, #0E0h          ; initialize TH1 for max count (16 bits)
        setb ET1                ; enable timer 1 overflow interrupt
        setb TR1                ; start timer 1
        clr P1.1                ; turn on the buzzer 
    beep_cont0:
ret

SHORT_DELAY:
    push 0                  ; push R0 onto the stack to preserve its value
    
    mov R0, #0FFh           ; load R0 for 255 counts
    short_delay_loop:
    djnz R0, short_delay_loop
    
    pop 0                   ; restore value of R0 to value before DELAY was called
ret

MED_DELAY:
    push 0
    push 1

    mov R0, #08h                    ; load R0 for 8 counts
    mov R1, #0FFh                   ; load R1 for 255 counts        

    med_delay_loop:
        djnz R1, med_delay_loop     ; decrement count in R1
    mov R1, #0FFh                   ; reload R1 in case loop is needed again
    
    djnz R0, med_delay_loop         ; count R1 down again until R0 counts down

    pop 1
    pop 0
ret

LONG_DELAY:
    push 0
    push 1

    mov R0, #0FFh                       ; load R0 for 255 counts
    mov R1, #0FFh                       ; load R1 for 255 counts        

    long_delay_loop:
        djnz R1, long_delay_loop        ; decrement count in R1
    mov R1, #0FFh                       ; reload R1 in case loop is needed again
    
    djnz R0, long_delay_loop            ; count R1 down again until R0 counts down

    pop 1
    pop 0
ret

DECA_SCROLL_LOOKUP_TABLE_5_SETTINGS:
    ; Lookup table to fill up decatron for five settings menu items -- used in DECA_SCROLLING_STATE.
    ; These numbers give evenly-spaced decatron pin settings for five increments.
    db 6d, 12d, 18d, 24d, 30d                       ; numbers in decimal
ret

DECA_SCROLL_LOOKUP_TABLE_7_SETTINGS:
    ; Lookup table to fill up decatron for seven settings menu items -- used in DECA_SCROLLING_STATE.
    ; These numbers give (roughly) evenly-spaced decatron pin settings for seven increments.
    db 5d, 9d, 13d, 18d, 22d, 26d, 30d              ; numbers in decimal
ret

DECA_SCROLL_LOOKUP_TABLE_8_SETTINGS:
    ; Lookup table to fill up decatron for eight settings menu items -- used in DECA_SCROLLING_STATE.
    ; These numbers give (roughly) evenly-spaced decatron pin settings for eight increments.
    db 4d, 8d, 11d, 15d, 19d, 23d, 26d, 30d         ; numbers in decimal
ret


end
