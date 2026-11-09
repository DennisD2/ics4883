; =====================================================================
; ICS Electronics Model 4883 Instrument Coupler
; disassembly heavily supported by Gemini AI
; =====================================================================
        CPU	8080
        ORG	0000h

; Memory map:
; 0000 - 03FF : ROM
; 0400 - 04FF : RAM and STACK
; 0500 - 05FF : Listener registers - 0500-0507h controlled by U34 74LS138
; 0600 - 06FF : Talker registers (Input from Instrument) - 0600-0607h controlled by U63 74LS138
; 0700 - 07FF : GPIB connector control, chips on mainboard - 0700-0707h controlled by U17 74LS138
; 0800 and above - unused

SRAM_START     EQU  0400h       ; start of RAM space
STACK_BASE     EQU  0500h       ; start value for stack pointer (last valid stack memory address + 1)

; "VER" at EQU comments means "verified", I am sure that the name of EQU fits to reality

; ==============================================================================
; 0400 -04FF : RAM variables
; ==============================================================================
VAR_BUFFER_STS EQU  0400h       ; Puffer-Status / Aktivitäts-Flag
VAR_IO_STATE   EQU  0401h       ; Letztes empfangenes oder gesendetes E/A-Zeichen
VAR_MODE_SEL   EQU  0402h       ; Modus-Selektor (wird durch 'p'/'q' geschaltet)
VAR_SYS_STATE  EQU  0403h       ; Globaler Systemzustand (Handshake / I/O)
VAR_BCD_DATA   EQU  0404h       ; Speicher für validierte BCD-Ziffern
VAR_GPIB_CTRL  EQU  0405h       ; GPIB Kontroll-Flag (z. B. 80h für Reset/Status)
VAR_SYS_STATUS EQU  0407h       ; Zentrales Statusregister (Remote/Local, Bit 3 LEDs)
; bit 0
; 407 bit 1 used to decide warmstart or mainloop after gpib command SDC
; bit 2
; bit 3 1=only local , bit3 = 0 remote
VAR_INIT_FLAG  EQU  0408h       ; Initialisierungs- und Reset-Steuerflag
VAR_PENDING_CMD EQU  040Bh      ; Zwischenspeicher für anstehende Handshake-Befehle
VAR_CMD_LOCK   EQU  040Ch       ; Sperrregister für eingehende Bus-Befehle
VAR_CMD_SERIALPOLL  EQU  040Dh  ; VER control register for serial poll handling
VAR_DATA_AVAILABLE EQU  040Eh   ; VER variable for 'data available' status (Talker, is 41h if data available)
VAR_EOS_FLAG   EQU  040Fh       ; End-Of-Sequence / EOI Status-Register
VAR_BUFF_PTR   EQU  041Dh       ; Letzter Tabellenzeiger / Puffer-Pointer
VAR_BUFF_IDX   EQU  041Fh       ; Index-Zähler für den Zeichenpuffer (Max 10)
VAR_ARRAY_PTR  EQU  042Eh       ; Zeiger auf das aktuelle Zeichen im indizierten Array
VAR_ASCII_BUFF EQU  0430h       ; Startadresse für den übersetzten ASCII-Datenpuffer

STATUS_DATA_AVAILABLE   EQU     041h ; status byte value

; ==============================================================================
; 0500 - 05FF : Memory mapped IO registers for Listener section (Output, Write to instrument)
;   500 8 bit output pins
;   501 8 bit output pins
;   502 8 bit output pins
;   503 8 bit output pins
;   504 8 bit output pins
;   505
;       Bit 3 in 0505 decides if values read are inverted or not
;   506
;   507
; ==============================================================================
IO_LST_DATA     EQU  0500h       ; VER start of data registers for writing to instrument
IO_LST_CTRL_1   EQU  0505h       ; VER control byte for Listener hardware
IO_LST_CTRL_2   EQU  0506h       ; VER control byte for Listener hardware (created by L_0006 during boot; value is 1010)

; ==============================================================================
; 0600 - 06FF :  Memory mapped IO registers for Talker section (Input, Read from instrument)
;   600 8 bits input pins digit1 and digit2
;   601 8 bits input pins digit3 and digit4
;   602 8 bits input pins digit5 and digit6
;   603 8 bits input pins digit7 and digit8
;   604 8 bits input pins digit9 and digit10
;   605 control input handshake pins pin 47 and pin 48 (bit 1, bit 2, ...) via U74
;       Bit 1 is checked in L_00AD
;   606 controls output handshake pins 49 and 50 via U64
;   607 control
; ==============================================================================
IO_TALK_DATA    EQU  0604h     ; VER end of data registers for reading from instrument. 0604h down to 0600h contain 5 bytes = 10 nibbles correspond to 40 data pins J2
IO_TALK_CTRL_1  EQU  0605h     ; VER Control byte related to Talker section, contains bit for handshake pins
IO_TALK_CTRL_2  EQU  0607h     ; Status-Flag im I/O-SRAM (Eingangs-Bestätigung)

; ==============================================================================
; 0700 - 07FF :   Memory mapped IO registers for GPIB connector, DIP Switch and front panel LEDs+switches
; GPIB connector control uses no special chip, just 74xx chips)
; depending on Listener or Talker state, the registers and bits are used in different ways:
;
; Used the same for both cases:
;   705
;       bit5 maybe "SRQ INHIBIT" front panel switch
;   706 DIP switch
;   707 Front panel LEDs (only writes, no reads on that address; so assumed LED only)
;       bit0 ? maybe Ready LED? This is supported by L_00AD and its use, which sets bit0 if L_00AD returns 1
;       bit1 Listening LED
;       bit2 Talking LED
;
; 1. Listener
;   700 data byte (D0-D7 from GPIB bus) for listener
;   701
;       bit0 DAV Data AVailable
;       bit1 R NDAC
;       bit2 NRFD line Not Ready For Data
;   702 not used
;   703
;       bit1 NDAC line Not Data Accepted
;       bit2 NRFD line Not Ready For Data
;   704
;       bit7 ? NDAC related?!
;
; 2. Talker
;   700 not used
;   701
;       bit1 NRFD line Not Ready For Data
;       bit2  NDAC line Not Data Accepted
;   702 data byte (data lines d0-d7)
;   703
;       bit0 DAV Data AVailable
;       bit4 - used when writing to GPIB, see L_01F1
;   704 not used
; ==============================================================================
GPIB_STATUS    EQU  0701h      ; GPIB status register
GPIB_CTRL_1    EQU  0702h      ; GPIB handshake control register 1
GPIB_CTRL_2    EQU  0703h      ; GPIB handshake control register 2
GPIB_CTRL_3    EQU  0704h      ; GPIB handshake control register 3
FRONT_SWITCHES EQU  0705h      ; only 1 read opcode in firmware; maybe this is "SRQ inhibit" frontpanel switch
DIP_SWITCH      EQU  0706h      ; VER DIP Switch byte
; 0706h DIP_SWITCH bits:
; bit 7 ONLY
; bit 6 TALKER
; bit 5 LISTENER
; bit 4-0 is GPIB ADDRESS

; bit positions for 70x GPIB control registers
; Listener bits
BIT_LIS_NRFD        EQU     04h     ; W 0000.0100 in 703
BIT_LIS_DAV         EQU     01h     ; R 0000.0001 in 701
BIT_LIS_NDAC        EQU     02h     ; W 0000.0010 in 703
; uses also 80h, bit 7 in 0704h
; talker bits
BIT_TLK_DAV     EQU     01h         ; W 0000.0001 in 703
;BIT_TLK_NDAC    EQU     04h        ; R in 701 in equ not used, is done by rotate opcodes in code
;BIT_TLK_NRFD    EQU     02h        ; R in 701 equ not used, is done by rotate opcodes in code
; uses also 10h, bit 4 in 0703h

; ---------------------------------------------------------------------
; 0000h - 0016h: boot vector and initialization
; ---------------------------------------------------------------------
L_0000:
        LXI     SP, STACK_BASE  ; 31 00 05 -> set stack pointer
        CALL    L_008F          ; CD 8F 00 -> clear 64 bytes of memory from start of RAM
; ------------------------------------------------------------------------------
; Looks like a warm start entry point.
; Is also Handler for GPIB command 14h - DCL Device Clear
; ------------------------------------------------------------------------------
L_0006:
        LDA     L_03C4          ; 3A C4 03 -> read config value from ROM 03C4 (value there is: 6=0110)
        XRI     0Ch             ; EE 0C    -> XOR with C=1100 (result: 1010)
        STA     IO_LST_CTRL_2  ; 32 06 05 -> put result to RAM 0506, Listerner hardware control byte
        LXI     H, L_03B3       ; 21 B3 03 -> put pointer to ROM table to H
        CALL    L_007B          ; CD 7B 00 -> copy ROM tables to RAM/memory mapped regs
        JMP     L_02C8          ; C3 C8 02 -> jump into Listener handling code, if nothing is incoming, this continues to main loop

; ------------------------------------------------------------------------------
; main IO polling loop
; L_MAINLOOP is also Default Handler in L_GPIB_CMD_JUMPTABLE table
; ------------------------------------------------------------------------------
L_MAINLOOP:                     ; was: L_0017
        DI                      ; F3
        LDA     VAR_IO_STATE    ; 3A 01 04 -> load 0401h from RAM to A - coupler state
        ORA     A               ; B7       -> is it = 0 ?
        JNZ     L_0355          ; C2 55 03 -> if no, then handle state change in L_0355; DD: maybe a pending command is handled there

L_001F:
        LDA     GPIB_STATUS  ; 3A 01 07    -> load 0701h to A
        ANI     0C0h            ; E6 C0    -> mask 2 upper bits of 0701h 1100.0000
        CPI     80h             ; FE 80    -> is masked value equal to 80h (so bit7 was 1 and bit6 was 0)
        JZ      L_00CE          ; CA CE 00 -> on equality, continue at L_00CE (supposed Listener handling)

        CALL    L_00AD          ; CD AD 00 -> calls 00ADh; checks talker and listener status bytes; returns 0 or 1 in A
        MVI     C, 0FEh         ; 0E FE    -> loads 0FEh to C (looks like a mask 1111.1110) - bit 0 is in focus
        CALL    L_00A1          ; CD A1 00 -> calls 00A1h; seem to write both RAM 0407h and GPIB hardware 0707h (=front panel LEDs)
        LDA     DIP_SWITCH   ; 3A 06 07 -> Loads 0706h to A
        RLC                     ; 07       -> rotate left, move highest bit ("ONLY" switch) to carry flag
        JMP     L_003C          ; C3 3C 00 -> continue at L_003C, with bits 6..0 from 0706h in A; "TL43.210x"
        POP     H               ; E1       -> pop HL (cleans stack)
        JMP     L_00CE          ; C3 CE 00 -> continue at L_00CE

L_003C:
        CC      L_009C          ; DC 9C 00 -> if carry flag ist set ("ONLY" switch on), continue at L_009C; in A we have 0706h content shiftet left by 1
        LXI     H, VAR_SYS_STATUS  ; 21 07 04 -> Register HL mit Adresse 0407h laden
    	MOV     A,M             ; 7E
    	RRC                     ; 0F
    	RRC                     ; 0F
        JC      L_029D          ; DA 9D 02 -> Wenn Carry=1, springe zu Adresse 029Dh
        RRC                     ; 0F       -> Akkumulator nach rechts rotieren
        JC      L_01AD          ; DA AD 01 -> Wenn Carry=1, springe zu Adresse 01ADh - talker handling
        LXI     B,01000h        ; 01 00 10 -> lade 01000h in BC
        LDA     IO_TALK_CTRL_1  ; 3A 05 06 -> load talker control byte
    	CMA                     ; 2F       -> invert (low active signals)
    	RRC                     ; 0F       -> put lowest bit from control byte into carry flag
    	JNC     L_0060          ; D2 60 00 -> if no carry (lowest bit was 0) then continue at 0060h, which will return from there to main loop
    	CALL    L_00C7          ; CD C7 00 -> if we had carry at lowest bit, puts bit 5 of FRONT_SWITCHES in Carry. This is maybe "SRQ INHIBIT" switch.
        JC      L_SET_DATA_AVAILABLE ; DA 6D 00 -> if carry, jump to L_SET_DATA_AVAILABLE = 006Dh ; we update status register
        STA     IO_TALK_CTRL_2   ; 32 07 06 -> no carry, no data available, put A to 0607h
        ; ------------------------------------------------------------------------------
        ; Reads byte from 0403 VAR_SYS_STATE, uses B anc C values to do bitwise update and writes resulting byte to 0703 GPIB_CTRL_2
        ; B - bit mask
        ; C - bit value to OR with
        ; ------------------------------------------------------------------------------
L_0060:
    	LXI     H, VAR_SYS_STATE ; 21 03 04 -> HL points to 0403h
    	MOV     A,M             ; 7E       -> load [0403h] to A
    	ANA     B               ; A0       -> AND A with B
    	ORA     C               ; B1       -> OR A with C
    	MOV     M,A             ; 77       -> move A to [0403h]
    	STA     GPIB_CTRL_2    ; 32 03 07 -> write result to 0703h (GPIB connector)
    	JMP     L_MAINLOOP      ; C3 17 00 -> back to loop start

; ------------------------------------------------------------------------------
; Set GPIB Status Byte (Talker) to 41h, which means "data available"
; ------------------------------------------------------------------------------
L_SET_DATA_AVAILABLE:           ; was L_006D
        LXI     H, VAR_DATA_AVAILABLE ; 21 0E 04 -> HL points to 040Eh (GPIB status reg)
        MOV     A, M            ; 7E       -> load GPIB status reg to A
        RRC                     ; 0F       -> check if lowest bit is set
        JC      L_0060          ; DA 60 00 -> if yes, handle that at 0060h (will not return here, but go to main loop)
        MVI     M, STATUS_DATA_AVAILABLE ; 36 41    -> put 41h (ASCII 'A') to 040Eh, means "data available"
        MOV     C, B            ; 48       -> copy B to C
        JMP     L_0060          ; C3 60 00 -> continue at 0060h, which will return from there to main loop

; ------------------------------------------------------------------------------
; 007Bh - 008Eh: copy a block of ROM into RAM based on control data in a table, pointed to by address in HL (Data Dispatcher)
; Called during boot (line 18)
; Expects in HL a pointer to ROM table with following format:
; [length C] [target address DE] [data byte 1] ... [data byte "length"] ...
; A length of 0 ends execution
; ------------------------------------------------------------------------------
L_007B:
        MOV     A, M            ; 7E       -> loads length value from table in ROM
        ORA     A               ; B7       -> is A=0?
        RZ                      ; C8       -> if yes, return, we are finished
        MOV     C, A            ; 4F       -> puts block length to C (loop count)
        INX     H               ; 23       -> inc H to point to next element in table
        MOV     E, M            ; 5E       -> loads target address (low byte) to E
        INX     H               ; 23       -> inc H to next element in table
        MOV     D, M            ; 56       -> loads target address (hi byte) to D
        INX     H               ; 23       -> inc H to point to first data byte in ROM
L_0084:
        MOV     A, M            ; 7E       -> get data byte from ROM table
        STAX    D               ; 12       -> write to target address in [DE]
        INX     H               ; 23       -> inc ROM pointer (source)
        INX     D               ; 13       -> inc RAM pointer (target)
        DCR     C               ; 0D       -> dec loop count
        JNZ     L_0084          ; C2 84 00 -> if C>0 (still bytes to copy), repeat inner loop for next byte
        JMP     L_007B          ; C3 7B 00 -> if C==0, block is finished. go to outer loop to read next table entry

; ------------------------------------------------------------------------------
; RAM initialization
; Called from boot code
; fills 64 bytes ab SRAM_START mit 0 bytes
; ------------------------------------------------------------------------------
L_008F:
        MVI     C, 040h         ; 0E 40    -> loop count to C
        LXI     H, SRAM_START   ; 21 00 04 -> set HL to address SRAM_START
L_0094:
        MVI     M, 00h          ; 36 00    -> set byte pointed to by [HL] to 0
        INX     H               ; 23       -> HL++ (increase HL address pointer)
        DCR     C               ; 0D       -> C-- (decrease loop count)
        JNZ     L_0094          ; C2 94 00 -> repeat, as long as C=0 is not reached
        RET                     ; C9       -> back to caller (boot code)

; ------------------------------------------------------------------------------
; We enter L_009C with A filled by value of DIP_SWITCH, already shifted left by one. So content is
; TL43.210x
; the three shifts at L_009C move lower 4 bits of GPIB address to upper nibble. bit5 is lost. Strange.
; ------------------------------------------------------------------------------
L_009C:
        RLC                     ; 07       -> shift 3 bits left result is L43.210xx
        RLC                     ; 07       -> "                           4321.0xxx
        RLC                     ; 07       -> "                           3210.xxxx
; ------------------------------------------------------------------------------
; Frontpanel LED control and update of VAR_SYS_STATUS
; 0707
;   bit1 Listener LED
;   bit2 Talker LED
; ------------------------------------------------------------------------------
L_009F:
    	MVI     C, 0F9h         ; 0E F9    -> loads mask value 0F9h (mask 1111.1001b) into C; switch of LEDs bit pos 1 and 2
;
; L_00A1 updates systen state register RAM 0407h and also writes changes out to hardware register 0707h (front panel LEDs).
; It applies a mask value in C
; mask is either 0F9h (called via L_009F) or 0FDh (called by L_010E)
; A - new bits to set
; C - mask, which bits of old value should stay (1<=> stay, 0 don't stay)
L_00A1:
        LXI     H, VAR_SYS_STATUS ; 21 07 04 -> HL points to 0407h
        MOV     B, A            ; 47       -> copy A to B
        MOV     A, M            ; 7E       -> load [HL] (0407h) into A
        ANA     C               ; A1       -> AND with C (apply mask) , means switch of bits to be new defined
        ORA     B               ; B0       -> OR with B, means all new bits are set correctly after that
        MOV     M, A            ; 77       -> write new value to [HL] (0407h)
        MVI     H, 07h          ; 26 07    -> set H of HL to 07h (HL points now to 0707h, front panel LEDs)
        MOV     M, A            ; 77       -> write A to 0707h
        RET                     ; C9       -> back to caller

; ------------------------------------------------------------------------------
; Supposed: Check for "Coupler Ready" state, coupler is healthy, and can receive GPIB commands
; ------------------------------------------------------------------------------
; compares talker handshake byte with value in ROM (location 0391h = 02h)
; if not equal, return 0 in A
; after that, compare listener control byte in ROM (location 0392h = 02h)
; if equal, return 1 in A
;  return 0 in A
; maybe result is "Ready State Ok" if 1, 0 if not ready.
L_00AD:
        LXI     H, L_0391       ; 21 91 03 -> HL points to 0391h
    	LDA     IO_TALK_CTRL_1  ; 3A 05 06 -> load talker handshake byte 0605h to A
        CMA                     ; 2F       -> invert A
        ANI     02h             ; E6 02    -> and with 0000.0010, so we check bit 1
        CMP     M               ; BE       -> compare with value addressed by [HL], so [0391], which is 02h
        JNZ     L_00C5          ; C2 C5 00 -> if not equal, continue at 00C5h
        INX     H               ; 23       -> it is equal, inc HL
        LDA     IO_LST_CTRL_1   ; 3A 05 05 -> load listener control byte 0505 to A
        CMA                     ; 2F       -> invert A
        ANI     07h             ; E6 07    -> and with 0000.0111, so we check bit 0,1,2
        CMP     M               ; BE       -> compare with value addressed by [HL], so [0392], which is 02h again
        MVI     A, 01h          ; 3E 01    -> A := 1
        RZ                      ; C8       -> return if last CMP was equal (Zero-Flag == 1)
L_00C5:
        XRA     A               ; AF       -> A := 0
    	RET                     ; C9       -> return to caller

L_00C7:
    	LDA     FRONT_SWITCHES       ; 3A 05 07 -> load 0705h to A; maybe "SRQ INHIBIT" front panel switch
        RLC                     ; 07       -> put bit 5 to carry flag by rotating 3x
        RLC                     ; 07       ->
        RLC                     ; 07       ->
    	RET                     ; C9       -> return to caller

; ------------------------------------------------------------------------------
; Handle incoming GPIB bytes and call handler function to handle byte.
; byte may be a command byte or an address or a data byte.
; The low level byte_ready function is L_0163, which is doing bit handling/GPIB lines control
;
; Byte read from GPIB is stripped to 7 bits.
; Then it is checked if both bits 5 and 6 are set. if yes, the byte seems to be a GPIB command and its handler is executed (via  L_00F7)
;  bit 5 means byte is like 0x1x.xxxx. This is like 0x0x.xxxx + 0x20, so it is a MLA (Listener address). We are addressed to listen!
;  bit 6 means byte is like 01xx.xxxx. This is like 00xx.xxxx + 0x40, so it is a MTA (Talker address). We are addressed to talk!
;  both bits 5&6 means (maybe) PPE command, parallel poll.
; if bits are not set, VAR_CMD_LOCK is set to 0. This means maybe "we are not processing a GPIB command byte".
; again bit 5 and 6 are checked and L_00F7 is called if bits are set (this is strange).
; finally we enter L_00F7 without any condition. From there a handler is executed and we return to mainloop.
; note that L_00F7 is doing a PCHL, which means we will never return here but end in mainloop after handlers were executed.
; ------------------------------------------------------------------------------
HANDLE_GPIB_BYTE_RECEIVED:
L_00CE:
        MVI     A, 80h          ; 3E 80    -> load 80h to A
        STA     VAR_GPIB_CTRL   ; 32 05 04 -> write A, which is 080h, to RAM location 0405
        XRA     A               ; AF       -> A:=0
        STA     GPIB_CTRL_1    ; 32 02 07 -> write A which is 0 to 0702h
        CALL    L_0163          ; CD 63 01 -> call L_0163, seems to read a byte from GPIB, result in B
        LDA     DIP_SWITCH      ; 3A 06 07 -> load 0706h to A
        RLC                     ; 07       -> check "ONLY" bit of dip switch
        JC      L_MAINLOOP      ; DA 17 00 -> if ONLY=1, then carry=1, we are finished and jump to L_MAINLOOP
        MOV     A, B            ; 78       -> load B to A, B is byte read from GPIB bus
        ANI     07Fh            ; E6 7F    -> mask to 7 bits (only 7 bits are used)
        MOV     B,A             ; 47       -> save to B (B contains now byte from GPIB bus, 7 bits)
        ANI     060h            ; E6 60    -> isolate bits 6 and 5
        CPI     060h            ; FE 60    -> Check against 0110.0000 (this could mean we check if byte received is PPE=060h command)
        JZ      L_00F7          ; CA F7 00 -> if equality (bits 5 and 6 are set) continue at 00F7h (there a handler address is determined and handler code executed and returned to mainloop)
        XRA     A               ; AF       -> bits are not equal, A := 0
        STA     VAR_CMD_LOCK    ; 32 0C 04 -> writes A, which is 0, to 040Ch, i.e. clear VAR_CMD_LOCK
        MOV     A, B            ; 78       -> load B to A, B = the byte read from GPIB
        ANI     060h            ; E6 60    -> isolate bits 6 and 5
        ; in next line, jump is done if neither bit6 nor bit 5 is 1. This means maybe we jump iff byte is not a MLA/MTA.
        JNZ     L_00F7          ; C2 F7 00 -> if bit 5 or 6 are set, continue again L_00F7 (there a handler address is determined and handler code executed and returned to mainloop)
        MOV     A, B            ; 78       -> bits are not equal, load B to A, B = the byte read from GPIB
L_00F7:
        LXI     H, L_GPIB_CMD_JUMPTABLE ; 21 93 03 -> Load handler jump table at 0393h
        MVI     C, 0Ah          ; 0E 0A    -> loop counter C := 10
        CALL    L_FIND_HANDLER_ADDRESS ; CD 4E 01 -> handle chars by determining correct handling routine address
        PCHL                    ; E9       -> jump to handler found

; ------------------------------------------------------------------------------
; Handler for GPIB command 20h - MLA Listener Addresses
; address value is in B.
; checks if address in B equals address defined at DIP switches.
; ------------------------------------------------------------------------------
L_0100:
        CALL    L_0131          ; CD 31 01 -> Compare GPIB address received with own address; result is in flag Z
        MVI     A, 02h          ; 3E 02    -> load 02h into A
        JNZ     L_010E          ; C2 0E 01 -> if value of last cmp (address compare) !=0, jump to 010Eh; so: not our address
L_0108:
        ; address equals our address
        ; next call seems to switch on byte 1 (02h) in LED control byte; this should be Listener LED
        CALL    L_009F          ; CD 9F 00 -> call 009Fh, which seems to write out a byte to 0707h(front panel LEDs)
        JMP     L_MAINLOOP      ; C3 17 00 -> jump to main loop

L_010E:
        ; address is not our address
        MOV     A, B            ; 78       -> copy B to A
        CPI     03Fh            ; FE 3F    -> is command UNL Universal Unlisten (3Fh / '?')?
        JNZ     L_MAINLOOP      ; C2 17 00 -> if not an UNL, jump to main polling loop L_MAINLOOP
    	XRA     A               ; AF       -> XOR A mit A <=> A:=0
    	STA     VAR_BUFF_IDX    ; 32 1F 04 -> write 0 to 041F; clear incoming character data buffer
    	MVI     C, 0FDh         ; 0E FD    -> loads 0FDh into C (output mask?)
    	CALL    L_00A1          ; CD A1 00 -> L_00A1 writes value from RAM 0407h to 0707h(front panel LEDs)
        JMP     L_MAINLOOP      ; C3 17 00 -> jump back to main loop

; ------------------------------------------------------------------------------
; Handler for GPIB command 40h - MTA Talker Addresses
; ------------------------------------------------------------------------------
L_0120:
        CALL    L_0131          ; CD 31 01 -> Compare GPIB address received with own address
        MVI     A, 04h          ; 3E 04    -> load 04h into A
        JZ      L_0108          ; CA 08 01 -> if value of last cmp (address compare) ==0, jump to L_0108; switch on bit pos 2 (Talker LED?)
        MVI     C, 0FBh         ; 0E FB    -> loads mask 0FBh 1111.1100 to C; switch off bit pos 0 and 1
        XRA     A               ; AF       -> clear A
        ; next call seems to switch off LED control byte; but maybe I am wrong...
        CALL    L_00A1          ; CD A1 00 -> call L_00A1, which seems to write out a byte to 0707h(front panel LEDs)
    	JMP     L_MAINLOOP      ; C3 17 00 -> jump back to main loop

; Comparison if GPIB address just received with address set at dip switch
L_GPIB_ADDRESS_CMP:
L_0131:
    	LDA     DIP_SWITCH   ; 3A 06 07 -> loads 0706h into A
    	ANI     01Fh            ; E6       -> mask with 1F, so lower 5 bits (GPIB address)
        MOV     C, A            ; 4F       -> save in C
    	MOV     A,B             ; 78       -> load B to A
    	ANI     01Fh            ; E6       -> mask with 1F, lower 5 bits
        CMP     C               ; B9       -> A=C ?
        RET                     ; C9       -> result of comparison is in status, return to caller

; ------------------------------------------------------------------------------
; Handler for GPIB command 04h - SDC Selected Device Clear
; ------------------------------------------------------------------------------
L_013C:
    	LDA     VAR_SYS_STATUS  ; 3A 07 04 -> load 0407 into A
    	ANI     02h             ; E6 02    -> isolate bit 1
    	JZ      L_MAINLOOP      ; CA 17 00 -> if bit is 0, continue at mainloop (looks like nothing to do then)
    	JMP     L_0006          ; C3 06 00 -> if bit is 1, continue at L_0006 (looks like a warmstart)

; ------------------------------------------------------------------------------
; Handler for GPIB command 19h - SPD Serial Poll Disable
; ------------------------------------------------------------------------------
L_0147:
    	XRA     A               ; AF        -> A:=0
; ------------------------------------------------------------------------------
; Handler for GPIB command 18h - SPE - Serial Poll Enable
; writes A value into register VAR_CMD_SERIALPOLL
; A is 0, for SPD command, and !=0 for serial poll start SPE
; ------------------------------------------------------------------------------
L_0148:
    	STA     VAR_CMD_SERIALPOLL ; 32 0D 04  -> store A to 040Dh (in serial poll start case, A is something != 0)
    	JMP     L_MAINLOOP      ; C3 17 00  -> continue at mainloop

; ------------------------------------------------------------------------------
; based on input byte value, a handling routine address in ROM is selected and returned in HL.
; Calling code will jump directly to the address returned by using opcode PCHL.
;
; iterates though a table (L_GPIB_CMD_JUMPTABLE, L_SEPARATOR_JUMP_TABLE), searches an entry. If found, return value in HL.
; if not found, last table entry is returned (default)
;
; HL points to a table
; C seems loop count (number of table items)
; HL contains result (2 byte value).
; ------------------------------------------------------------------------------
L_FIND_HANDLER_ADDRESS:  ; was L_014E
        PUSH    D               ; D5       -> save DE to stack
        LXI     D, 0003h        ; 11 03 00 -> load 3h to DE
L_0152:
        CMP     M               ; BE       -> compare A with value at [HL]
        JZ      L_015C          ; CA 5C 01 -> if A==[HL] continue at 015Ch (value found)
        DAD     D               ; 19       -> Add DE register pair to HL (HL := HL + DE)
        DCR     C               ; 0D       -> dec loop count
        JNZ     L_0152          ; C2 52 01 -> if C>0, repeat loop
        DCX     H               ; 2B       -> dec HL
L_015C:
        INX     H               ; 23       -> inc HL
        MOV     E, M            ; 5E       -> load lower byte from [HL] to E
        INX     H               ; 23       -> inc HL
        MOV     D, M            ; 56       -> load upper byte from [HL] to D
        XCHG                    ; EB       -> switch reg pairs HL and DE
        POP     D               ; D1       -> restore saved value of DE
        RET                     ; C9       -> return to caller

; ------------------------------------------------------------------------------
; Code reads in one byte from GPIB. Byte result in B.
; All GPIB line handshaking during reading a byte is done here.
;
; L_0163 waits for bit0 = 1 in VAR_GPIB_CTRL = DAV line.
; HL points to 0701 GPIB_STATUS
; DE points to 0703 GPIB_CTRL_2
;
; NDAC Not DAta aCcepted
; NRFD Not Ready For Data
;
; bit indices count from 0
; depending on output hardware, a 0 means assign or release.
; depending on output hardware, a 1 means assign or release.
;
;   700 data byte (D0-D7 from GPIB bus) for listener
;   701
;       bit0 DAV Data AVailable
;       bit1 R NDAC
;       bit2 NRFD line Not Ready For Data
;   702 not used
;   703
;       bit1 NDAC line Not Data Accepted
;       bit2 NRFD line Not Ready For Data
;   704
;       bit7 ? NDAC related?!
; ------------------------------------------------------------------------------
READ_BYTE_FROM_GPIB:
L_0163:
        LDA     VAR_SYS_STATE   ; 3A 03 04 -> load 0403h to A
        ANI     10h             ; E6 10    -> and with bit 4, isolate bit 4
        MOV     C, A            ; 4F       -> copy A to C
        LXI     D, GPIB_CTRL_2  ; 11 03 07 -> DE points to 0703h
        MVI     A, BIT_LIS_NRFD ; 3E 04    -> load 04h to A bit2
        ORA     C               ; B1       -> OR with C: now bit 2 from 0403h is set in A
        STAX    D               ; 12       -> write A to [DE] ausgeben ; NRFD release (I am ready to receive data)
        MVI     A, 80h          ; 3E 80    -> load 80h  to A 1000.0000, set bit 7
        STA     GPIB_CTRL_3     ; 32 04 07 -> write A to 0704h; NDAC assign (part of) (really?)
        LXI     H, GPIB_STATUS  ; 21 01 07 -> HL points to 0701h
WAIT_FOR_DAV_ASSIGNED:          ; was L_0178
        LDA     VAR_GPIB_CTRL   ; 3A 05 04 -> load RAM 0405h to A
    	XRA     M               ; AE       -> XOR A with [HL], i.e. [0405h]
    	JM      L_01A9          ; FA A9 01 -> if sign flag==1, continue at 01A9h (do nothing)
        MOV     A, M            ; 7E       -> read from [HL], which is 0701h
        ANI     BIT_LIS_DAV     ; E6 01    -> and with bit 0, isolate bit 0
        JZ      WAIT_FOR_DAV_ASSIGNED ; CA 78 01 -> if bit0==0, jump back to 0178h (we are waiting for bit0 becoming 1)
; now bit0=1, DAV is assigned
        LDA     VAR_GPIB_CTRL   ; 3A 05 04 -> load RAM 0405h to A
    	XRA     M               ; AE       -> XOR A with [HL], i.e. [0405h]
    	JM      L_01A9          ; FA A9 01 -> if sign flag==1, continue at 01A9h (do nothing)
        MVI     A, BIT_LIS_NRFD|BIT_LIS_NDAC ; 3E 06    -> sign flag is 0, load 06h to A, 0000.0110
        ORA     C               ; B1       -> OR with C: now bit 1 AND bit 2 from 0403h is set in A
        STAX    D               ; 12       -> write A to [DE] ausgeben (to 0703h) ; we do assign NDAC and NRFD
        MOV     A, M            ; 7E       -> read from [HL], which is 0701h
        STA     VAR_EOS_FLAG    ; 32 0F 04 -> save A to RAM 040Fh
        DCX     H               ; 2B       -> HL-- (now 0700h)
        MOV     B, M            ; 46       -> read from [HL], which is 0700h, to B ; read data byte?
        INX     H               ; 23       -> HL++ (now again 0701h)
        MVI     A, BIT_LIS_NDAC ; 3E 02    -> load 02h to A NDAC release bit1
        ORA     C               ; B1       -> OR with C: now bit 4 from 0403h is set in A NDAC release?
        STAX    D               ; 12       -> write A to [DE] = 703 NDAC release
WAIT_FOR_DAV_RELEASE:           ; was L_019B
        MOV     A, M            ; 7E       -> read from [HL], which is 0701h
        ANI     BIT_LIS_DAV     ; E6 01    -> and with bit 0, isolate bit 0 DAV
        JNZ     WAIT_FOR_DAV_RELEASE ; C2 9B 01 -> if bit0 is set, jump to 019Bh
; now bit0=0, DAV is released
        MVI     A,  BIT_LIS_NRFD|BIT_LIS_NDAC ; 3E 06    -> load 06h to A
        ORA     C               ; B1       -> OR with C: now bit 4 from 0403h is set in A
        STAX    D               ; 12       -> write A to [DE]  (to 0703h) Release NDAC and NRFD
        STA     VAR_SYS_STATE   ; 32 03 04 -> write A back to RAM 0403h ; VAR_... mirrors some of the GPIB handshake lines
        RET                     ; C9       -> return to caller
L_01A9:
        POP     H               ; E1       -> restore HL
        JMP     L_MAINLOOP      ; C3 17 00 -> jump to mainloop

; ------------------------------------------------------------------------------
; Talker code
; Handle input from instrument and write to GPIB bus
; these bytes seem to have following meaning
; 0605h also called IO_TALK_CTRL_1
;   bit0=1 no input data, bit0=0 we have input data at input pins. Seems to be set by IOBoard and is maybe controlled by an input pin.
;   bit2 checked by convert_out_char,
;
; 0604h-0600h 5 bytes corresponding to 10 nibbles corresponding to 40 input pins
; 0604
; 0603
; 0602
; 0601
; 0600
; In 0605h we have non-data-pins, looking like handshake signals. Or internal signals between IOBoard and mainboard. Needs more analysis.
;
; 10 nibbles are processed, converted by using the Talker Character Table (L_TLK_CHAR_TABLE) and written
; to 10 bytes in RAM starting at location 0430h.
;
; All GPIB line handshake (NDAC, DAV, ...) is done in the code.
;
; used regs and bits
;   700 not used
;   701
;       bit1 NDAC line Not Data Accepted
;       bit2  NDAC line Not Data Accepted
;   702 data byte (data lines d0-d7)
;   703
;       bit0 DAV Data AVailable
;       bit4 - used when writing to GPIB, see L_01F1
;   704 not used
;
; Note: code starting at L_01F1 is also used for sending status byte during serial poll.
; ------------------------------------------------------------------------------
L_01AD:
    	EI                      ; FB       -> enable interrupts
    	LDA     VAR_CMD_SERIALPOLL   ; 3A 0D 04 -> loads 040Dh into A
    	ORA     A               ; B7       -> is 040Dh == 0 ? this means: are we in a serial poll process?
    	JNZ     L_0232          ; C2 32 02 -> if in serial poll, jump to 0232h
        LXI     H, IO_TALK_CTRL_1 ; 21 05 06 -> HL points to 0605h
WAIT_FOR_BIT0_SET:
; we do busy waiting until bit0 from 0605h is cleared (this might be: J2_Pin2)
; bit0 will be cleared externally by some interrupt-driven action (not code)
L_01B8:
        MOV     A, M            ; 7E       -> load [HL] to A
    	RRC                     ; 0F       -> bit 0 to Carry flag
        JC      L_01B8          ; DA B8 01 -> if Carry set, loop back to 01B8h WAIT_FOR_BIT0_SET
        DI                      ; F3       -> Disable Interrupts
        LXI     D, VAR_ASCII_BUFF ; 11 30 04 -> load 0430h to DE (target pointer)
        LXI     H, IO_TALK_DATA  ; 21 04 06 -> load 0604h to HL; DD: h := 0x0604 = start address of bytes read from input (5 bytes containing 10 nibbles)
    	CALL    L_0242          ; CD 42 02 -> read in and convert 5 input bytes
    	MVI     A, 0Fh          ; 3E 0F    -> load 0fh to A
        STA     SRAM_START      ; 32 00 04 -> Akkumulator-Inhalt direkt in RAM SRAM_START sichern [0400h] := 0FFh
        EI                      ; FB       -> Interrupts wieder freigeben (Enable Interrupts)
        LXI     H, VAR_ASCII_BUFF ; 21 30 04 -> HL-Zeiger auf SRAM-Adresse 0430h laden DD: h := address of created 10 bytes
        SHLD    VAR_ARRAY_PTR   ; 22 2E 04 -> Speicherinhalt von HL nach SRAM 042Eh sichern
        LXI     H, L_03E4       ; 21 E4 03 -> HL-Zeiger auf Übersetzungstabelle im ROM ausrichten
L_01D6:
        MOV     A, M            ; 7E       -> Byte via HL laden
        INX     H               ; 23       -> HL-Zeiger um 1 erhöhen
        SHLD    VAR_BUFF_PTR    ; 22 1D 04 -> Aktuellen HL-Zeiger im RAM 041Dh sichern
        CPI     19h             ; FE 19    -> Akkumulator mit Konstante 19h vergleichen (19=SPD, but makes no sense here)

        JZ      L_MAINLOOP      ; CA 17 00 -> if A==19, jump to mainloop
        ORA     A               ; B7       -> Flags aktualisieren (Prüfen auf Null/Vorzeichen)
        JP      L_01F0          ; F2 F0 01 -> Wenn positiv (Bit 7 = 0), springe vor zu Adresse 01F0h
        ANI     040h            ; E6 40    -> Bit 6 maskieren
        ORA     C               ; B1       -> Logisches ODER mit Register C verknüpfen
        MOV     C, A            ; 4F       -> In Register C sichern (AS-Syntax für MOV C,A)
        LHLD    VAR_ARRAY_PTR   ; 2A 2E 04 -> HL-Registerinhalt im SRAM 042Ah sichern
        MOV     A, M            ; 7E       -> Byte erneut via HL laden
        INX     H               ; 23       -> HL-Zeiger um 1 erhöhen
        SHLD    VAR_ARRAY_PTR   ; 22 2E 04 -> HL-Registerinhalt im SRAM 042Eh sichern


WRITE_BYTE_TO_GPIB_BUS:
L_01F0:
        MOV     B, A            ; 47       -> Byte in Register B sichern; B contains byte to send to GPIB bus.
L_01F1:
        LDA     VAR_SYS_STATE   ; 3A 03 04 -> load [0403h] to A
        ANI     10h             ; E6 10    -> isolate bit 4 0001.0000
        MOV     C, A            ; 4F       -> save to C
        LXI     D,GPIB_CTRL_2 ; 11 03 07 -> [DE] points to 0703h
        STAX    D               ; 12       -> write A to [DE] = 0703h.
        LXI     H, GPIB_CTRL_1 ; 21 02 07 -> HL points to 0702h
        MOV     M,B             ; 70       -> write B to [HL], to 0702h; writes data byte to GPIB bus
        DCX     H               ; 2B       -> HL-- (now 0701h), GPIB_STATUS byte
; loop waits for 0701h, bit 1 becomes 0 ; NRFD release
L_0200:
        MOV     A, M            ; 7E       -> load from 0701h to A
        RRC                     ; 0F       -> rotate right
        RRC                     ; 0F       -> rotate right
        JC      L_0200          ; DA 00 02 -> if carry=1, loop back at L_0200
; now bit1=0, NRFD is released, all partners are ready for reading data
; set DAV
        MVI     A, BIT_TLK_DAV  ; 3E 01    -> load 01h to A (DAV signal)
        ORA     C               ; B1       -> OR A with C
        STAX    D               ; 12       -> write A to [DE] = 0703h
; byte is written out, DAV was set. Now wait for ack from controller, wait for NDAC release
; loop waits for 0701h, bit 2 becomes 0 ;
L_020A:
        MOV     A, M            ; 7E       -> load from 0701h to A
        RRC                     ; 0F       --> shift right 3x, bit2 is in C flag
        RRC                     ; 0F
        RRC                     ; 0F
        JC      L_020A          ; DA 0A 02 -> if carry==1, i.e. bit2=1, loop back to L_020A
; now bit2=0, NDAC is released. All partners have copied byte written.
        DI                      ; F3       -> disable interrupts
        XRA     A               ; AF       -> A:=0
        STAX    D               ; 12       -> [DE] := A i.e. 0, [0703h]:=0 (DAV is released)
        STA     VAR_SYS_STATE   ; 32 03 04 -> clear VAR_SYS_STATE (becomes 0)
        LXI     H, SRAM_START   ; 21 00 04 -> HL points to SRAM_START
        MOV     A, M            ; 7E       -> load [HL] to A (HL points to SRAM_START)
        MVI     M, 00h          ; 36 00    -> [HL] := 0, i.e. [SRAM_START]:=0
        ORA     A               ; B7       -> (update CPU flags)
        JM      L_MAINLOOP      ; FA 17 00 -> if A<0 (bit 7=1), jump to L_MAINLOOP
        JZ      L_022B          ; CA 2B 02 -> if A==0, jump to L_022B
        XRA     A               ; AF       -> A:=0
        STA     IO_TALK_CTRL_2   ; 32 07 06 -> clear IO_TALK_CTRL_2
        STA     VAR_DATA_AVAILABLE  ; 32 0E 04 -> clear VAR_DATA_AVAILABLE
L_022B:
        EI                      ; FB       -> enable interrupts
        LHLD    VAR_BUFF_PTR    ; 2A 1D 04 -> HL := 041D
        JMP     L_01D6          ; C3 D6 01 -> jump back to outer loop (maybe more chars to send)
; ------------------------------------------------------------------------------
; Handle a serial poll. The coupler is addressed as talker, and must present its status byte.
; Called from more general talker routine at L_01AD, which can also respond to a read with data bytes.
; L_0232 only prepares status byte and then let L_01F1 write out the code.
; ------------------------------------------------------------------------------
L_0232:
        MVI     A, 0FFh         ; 3E FF    -> load 0FFh to A
        STA     SRAM_START      ; 32 00 04 -> write A to SRAM_START
        LXI     H, VAR_DATA_AVAILABLE ; 21 0E 04 -> HL points to GPIB status byte of coupler
        MOV     B, M            ; 46       -> load status byte to B
        MOV     A, M            ; 7E       -> and load it to A
        ANI     0BFh            ; E6 BF    -> clear bit 6 in A (mask 1011.1111)
        MOV     M, A            ; 77       -> write A back to VAR_DATA_AVAILABLE
        JMP     L_01F1          ; C3 F1 01 -> continue at 01F1h

; ------------------------------------------------------------------------------
; convert all 5 bytes from input IO connector
; convert bytes from input IO connector
; d is index for created output string
; h,l points to start address to convert
; b is num of bytes to convert (5)
; h,l point to memory location for input byte (is decremented in a loop)
; it looks that two 4-bit values are in 1 byte as HI/LO nibble
;
; we load from 0604 down to 0600h (5 bytes). The address values 4,3,2,1,0 will
; create Yn signals at U63 in following order: Y4-Y3-Y2-Y1-Y0. This will enable
; two 74LS03 Quad-NAND-chips on IO board to read in 8 bits at once (2 4 bit nibbles).
; ------------------------------------------------------------------------------
convert_5input_bytes:
L_0242:
        MVI     B, 05h          ; 06 05    -> set loop counter B to 5: num of bytes to convert (5 bytes = 10 nibbles)
L_0244:
        MOV     A, M            ; 7E       -> load byte from HL (starting with 0604h) to A
        RRC                     ; 0F       -> isolate HI nibble by rotating 2x
        RRC                     ; 0F
        RRC                     ; 0F
        RRC                     ; 0F
        CALL    L_0256          ; CD 56 02 -> convert HI nibble by call convert_out_char
        MOV     A, M            ; 7E       -> load byte again to A
        CALL    L_0256          ; CD 56 02 -> convert LO nibble by call convert_out_char
        DCX     H               ; 2B       -> dec HL
        DCR     B               ; 05       -> dec loop count
        JNZ     L_0244          ; C2 44 02 -> if loop count > 0, repeat loop for next byte
        RET                     ; C9       -> return to caller

; ------------------------------------------------------------------------------
; convert hex value read from instrument via conversion table L_TLK_CHAR_TABLE
; lookup, store it (0x26c)  to somewhere
; (in RAM or register?), increment index in d, and keep h in original state
;
; one bit (bit 2 from 0605) decides if data is inverted before conversion.
;
; ------------------------------------------------------------------------------
convert_out_char:
L_0256:
        MOV     C, A            ; 4F       -> save A to C
        LDA     IO_TALK_CTRL_1  ; 3A 05 06 -> read byte from 0605h
        ANI     04h             ; E6 04    -> isolate bit 2 to check bit 2 (maybe "DO_INVERT_DATA_READ)"
        CPI     04h             ; FE 04    -> is bit 2 set?
        MOV     A, C            ; 79       -> restore A from C
        JZ      L_0263          ; CA 63 02 -> if not set(?) jump to 0263h, i.e. do no bit invert A
        CMA                     ; 2F       -> bit invert A
L_0263:
        ANI     0Fh             ; E6 0F    -> mask lower 4 bit in A
        PUSH    H               ; E5       -> save HL
        LXI     H, L_TLK_CHAR_TABLE ; 21 D4 03 -> HL points to ROM table
        ADD     L               ; 85       -> Add L to A (now A contains byte offset in table)
        MOV     L, A            ; 6F       -> L := A
        MOV     A, M            ; 7E       -> read translated char from char table
        STAX    D               ; 12       -> store char to [DE] (0430h ff)
        INX     D               ; 13       -> inc DE
        POP     H               ; E1       -> restore HL
        RET                     ; C9       -> return to caller

; WHO CALLS THIS CODE???
; Steuerzeichen Filter
L_0270_UNUSED:
        LXI     H, L_0390       ; 21 90 03 -> HL auf alternative Tabelle/String im ROM ausrichten
        MOV     A, B            ; 78       -> Register B (04h) nach A holen
        ANI     01Fh            ; E6 1F    -> 5-Bit-Maskierung
        CMP     M               ; BE       -> Mit Speicherwert [HL] vergleichen
        JNZ     L_MAINLOOP      ; C2 17 00 -> Bei Ungleichheit harter Sprung zurück zu L_MAINLOOP
        LXI     H, VAR_SYS_STATUS ; 21 07 04 -> HL auf RAM-Adresse 0407h setzen
        MOV     A, M            ; 7E       -> Wert aus 0407h lesen
        ANI     030h            ; E6 30    -> Bits 4 und 5 maskieren
        JZ      L_MAINLOOP      ; CA 17 00 -> Wenn Null, ebenfalls zurück zu L_MAINLOOP
        RRC                     ; 0F       -> Bits rotieren
        RRC                     ; 0F
        RRC                     ; 0F
        MOV     M, A            ; 77       -> Modifizierten Wert zurück nach 0407h schreiben
        JMP     L_MAINLOOP      ; C3 17 00 -> Unbedingter Rücksprung zum Haupt-Polling


; ------------------------------------------------------------------------------
; Handler for GPIB command 08h - GET Group Execution Trigger
; I suppose here J2 pins 49 and 50 are controlled. These are driven by 7474 D-Flip-Flops and thus can keep state.
; pin 50 gives LO pulse on device Trigger command
; pin 49 gives HI pulse on device Trigger command
; maybe IO_TALK_CTRL_2 controls these pins.
;
;
; ------------------------------------------------------------------------------
L_028A:
        LDA     VAR_SYS_STATUS  ; 3A 07 04 -> Lädt den Gerätestatus aus dem RAM
        ANI     02h             ; E6 02    -> Bit 1 maskieren (z. B. Remote/Local oder ein Bus-Flag)
        JZ      L_MAINLOOP      ; CA 17 00 -> Wenn Bit1==0, Schleife abbrechen und zurück zu L_MAINLOOP
        LXI     H, IO_TALK_CTRL_2 ; 21 07 06 -> HL auf register ausrichten
        MOV     M, A            ; 77       -> Den maskierten Statuswert direkt dorthin schreiben
        DCX     H               ; 2B       -> HL dekrementieren auf 0606h
        LDA     03C8h           ; 3A C8 03 -> Einen Konfigurations- oder Initialisierungswert aus dem ROM laden
        JMP     L_02F9          ; C3 F9 02 -> Sprung zur weiteren Registerverarbeitung an Adresse 02F9h

; Daten-Empfang und Indizierung: Dieser Block verarbeitet ankommende Bus-Zeichen. Er nutzt die RAM-Zelle 041Fh als Index-Zähler (limitiert auf maximal 10 Zeichen, CPI 00Ah).
; Dynamische Puffer-Adressierung: Durch ADI 020h und MOV L, A berechnet der Code zur Laufzeit eine Zieladresse im RAM (ein sogenanntes indiziertes Array), um die eingehenden Zeichen nacheinander geordnet abzuspeichern.
; Protokoll-Validierung: Am Ende wird über das RAM-Register 040Fh ausgewertet, ob der Bus ein Übertragungsende signalisiert (CPI 040h).
L_029D:
        XRA     A               ; AF       -> Akkumulator nullen
        STA     VAR_GPIB_CTRL   ; 32 05 04 -> Systemregister 0405h im RAM zurücksetzen
        STA     GPIB_CTRL_1 ; 32 02 07 -> Interface-Register 0702h löschen
        DI                      ; F3       -> Interrupts global sperren

; ------------------------------------------------------------------------------
; L_02A5 is also Default Handler in separator table
; characters are read from GPIB (using L_0163) and added to end of character buffer which
; is located at ??? (should be IO_LST_DATA, but where is this set?).
; Adds character to incoming character buffer (incoming from GPIB)
;
; Open questions:
; - There is some offset 0x20 added to [HL] before storing the char received at [HL]. Why? What does that mean?
; - VAR_BUFF_IDX is considered to be a byte count in range 0..10, which is used to be added to a real memory address.
;   but here, it is used like a real memory address, see line "MOV M,B". I do not understand this.
; ------------------------------------------------------------------------------
L_READ_INTO_BUFF_LOOP:
L_02A5:
        CALL    L_0163          ; CD 63 01 -> Read in 1 byte from GPIB via L_0163, byte is in B after call
        MOV     A, B            ; 78       -> copy B to A
        ANI     070h            ; E6 70    -> mask with 0111.0000. Bits 4,5,6.
        CPI     030h            ; FE 30    -> compare with 0011.0000. Checks if bits 4 and 5 are set and 6 is cleared.
        JNZ     L_0305          ; C2 05 03 -> if not, do additional parsing (we may have a separator)
        LXI     H, VAR_BUFF_IDX ; 21 1F 04 -> HL := VAR_BUFF_IDX,
        MOV     A, M            ; 7E       -> A := [HL] i.e. [VAR_BUFF_IDX], number of characters read in buffer
        CPI     00Ah            ; FE 0A    -> is index == 10? (we cannot handle more than 10 chars)
        JNC     L_02BE          ; D2 BE 02 -> if index >= 10, continue at L_02BE
        INR     M               ; 34       -> index < 10, we increment [HL], i.e. number of characters read in buffer
        ADI     020h            ; C6 20    -> Add 020h to A; 020h is some offset in buffer
        MOV     L, A            ; 6F       -> L := A, now HL points to old_HL+1+020h
        MOV     M, B            ; 70       -> [HL] := B. B is character received.
L_BUFF_OVERFLOW:
L_02BE:
        LDA     VAR_EOS_FLAG    ; 3A 0F 04 -> A := [040Fh]
        ANI     0C0h            ; E6 C0    -> mask with 1100.0000, bits 7 and 6
        CPI     040h            ; FE 40    -> compare with 0100.0000 EOI Flag (40h), i.e. were bits 7 and 6 "01"?
        JNZ     L_02A5          ; C2 A5 02 -> no equality, i.e. not EOI, so repeat loop

; ------------------------------------------------------------------------------
; Listener code
; ------------------------------------------------------------------------------
; This code is called after characters were received from GPIB bus, and a separator was
; received. In that case, received characters are packed to bytes which are written to
; output connector J2. These bytes will set/clear bits at that connector.
;
; Handler for characters received via GPIB bus for  0D/CR, LF/0A, comma/2C
; which are considered 'special' by ICS4883 (i.e. these are separators)
;
; inside loop L_PACK_LOOP, we take two characters received by GPIB, put lower+upper nibble in a
; single byte. This byte is written to output registers 0500h-0504h. Up to 10 input characters
; are processed. It is allowed to process less than 10 characters, and number of chars is not required
; to be multiples of 2.
;
; VAR_BUFF_IDX: number of characters to process
; C is used as loop count (character-wise counting)
; B = ?
; IO_LST_DATA address where received characters to write to J2 connector are stored
;
; Bit 3 in 0505 decides if values read are inverted or not
; Bit 0 and 1 of IO_LST_CTRL_2 0506h are flipped after loop is finished.
; ------------------------------------------------------------------------------
LISTENER_PROCESSING:
L_02C8:
        LXI     H, VAR_BUFF_IDX ; 21 1F 04 -> set HL to VAR_BUFF_IDX 041Fh (counter value)
        MOV     C, M            ; 4E       -> load counter value to C
        MOV     A, M            ; 7E       -> load also to A
        ORA     A               ; B7       -> is counter zero?
        JZ      L_MAINLOOP      ; CA 17 00 -> if counter==0, nothing to do, jump back to main polling loop
        MVI     M, 00h          ; 36 00    -> if counter>0, set M to 0, clear [HL], [VAR_BUFF_IDX]
        PUSH    B               ; C5       -> push B to stack
        CALL    L_0311          ; CD 11 03 -> Depending on bit 3 in 0505h, C bytes in memory at HL are inverted or not (L_CHECK_INVERT)
        POP     B               ; C1       -> restore BC
        LXI     D, IO_LST_DATA   ; 11 00 05 -> DE points to IO_LST_DATA
L_PACK_LOOP:
L_02DB:
        INX     H               ; 23       -> inc HL (points to next source character)
        MOV     A, M            ; 7E       -> read byte from [HL], read character
        ANI     00Fh            ; E6 0F    -> mask lower nibble, we ignore upper nibble in incoming chars
        MOV     B, A            ; 47       -> save in B
        DCR     C               ; 0D       -> dec loop count, reflects that we've processed 1 char more
        JM      L_02F3          ; FA F3 02 -> if <0 continue at L_02F3 loop counter below zero
        INX     H               ; 23       -> inc HL, loop counter still>0
        MOV     A, M            ; 7E       -> read byte from [HL], we read next byte from [HL]
        ANI     00Fh            ; E6 0F    -> mask lower nibble
        RLC                     ; 07       -> rotate (4 times) left; move lower nibble to upper nibble location
        RLC                     ; 07
        RLC                     ; 07
        RLC                     ; 07       ; ... now (lower) nibble is in upper nibble location
        ORA     B               ; B0       -> add nibble saved before to have complete byte with two nibbles
        DCR     C               ; 0D       -> dec loop count, reflects that we've processed 1 char more
        STAX    D               ; 12       -> write completed byte to target address [DE], at output register IO_LST_DATA and behind
        INX     D               ; 13       -> inc target address pointer, next register to write to in loop
        JNZ     L_02DB          ; C2 DB 02 -> if loop count is larger 0, repeat loop
L_PACK_DONE:
L_02F3:
        LXI     H, IO_LST_CTRL_2 ; 21 06 05 -> HL points to 0506h
        LDA     L_03C4          ; 3A C4 03 -> load [03C4h] into A
L_02F9:
        MOV     B, A            ; 47       -> save A in B
        XRI     03h             ; EE 03    -> lowest two bits are flipped (reversed), e.g. ..01 becomes ..10 .
        MOV     M, A            ; 77       -> write new A to memory mapped register [0506h] or, when called via label, 0606h ?!
        PUSH    H               ; E5       -> is this a timing op?
        PUSH    H               ; E5       ->
        POP     H               ; E1       ->
        POP     H               ; E1       ->
        MOV     M, B            ; 70        -> A value, that was saved in B, back to M (so first masked A, then A is written to M, which looks like a strobe signal is generated)
        JMP     L_MAINLOOP      ; C3 17 00 -> back to main polling loop


; ------------------------------------------------------------------------------
; Handle non-data chars, i.e. separators (CR, LF, comma, 'other').
; correct handler routine address is determined by L_FIND_HANDLER_ADDRESS. Opcode PCHL will directly execute then
; the handler.
; ------------------------------------------------------------------------------
L_CMD_PARSE_SEPERATORS:
L_0305:
        MOV     A, B            ; 78       -> copy B to A
        ANI     07Fh            ; E6 7F    -> mask lower 7 bits (pure 7 bit ASCII)
        MVI     C, 03h          ; 0E 03    -> number of items in table (3)
        LXI     H, L_SEPARATOR_JUMP_TABLE ; 21 F5 03 -> HL points to table L_GPIB_CMD_JUMPTABLE
        CALL    L_FIND_HANDLER_ADDRESS ; CD 4E 01 -> find handler for separator
        PCHL                    ; E9       -> execute separator

; depending on a flag value (bit 3 from address 0505h), a block in memory is inverted or not.
; number of bytes to invert controlled by value in C, start address in HL.
; if bit is set, inversion takes place.
; called from 02D4h
L_CHECK_INVERT:
L_0311:
        LDA     IO_LST_CTRL_1  ; 3A 05 05 -> load 0505h to A
        ANI     08h             ; E6 08    -> isolate bit 3
        CPI     08h             ; FE 08    -> is bit set?
        RNZ                     ; C0       -> if bit is not set, simply return
        PUSH    H               ; E5       -> save HL pointer
; invert consecutive bytes
; number of bytes controlled by C. Starting at [HL].
L_DO_INVERT_BYTES_IN_LOOP:
L_031A:
        INX     H               ; 23       -> inc hl
        MOV     A, M            ; 7E       -> load byte at [hl] to A
        CMA                     ; 2F       -> invert bitwise
        MOV     M, A            ; 77       -> write byte back
        DCR     C               ; 0D       -> dec loop count
        JNZ     L_031A          ; C2 1A 03 -> if loop count C > 0, repeat inner loop
        POP     H               ; E1       -> if loop count==0, restore HL pointer
        RET                     ; C9       -> back to caller

; ------------------------------------------------------------------------------
; Handler for GPIB command 60h - PPE Parallel Poll Enable
; ------------------------------------------------------------------------------
L_0324:
        LDA     VAR_CMD_LOCK    ; 3A 0C 04 -> Lädt den Inhalt der RAM-Adresse 040Ch in den Akkumulator
        ORA     A               ; B7       -> Setzt die Flags (Zero/Sign) basierend auf dem Akkumulator
        JZ      L_MAINLOOP      ; CA 17 00 -> Wenn der Wert Null ist, Sprung zurück zum Haupt-Polling L_MAINLOOP
        MOV     A, B            ; 78       -> Holt den Wert aus Register B zurück nach A
        CPI     070h            ; FE 70    -> Prüfen, ob das Zeichen im Akkumulator 70h entspricht (70h = 'p')
    	JZ      L_036D          ; CA 6D 03 -> Wenn ja, Sprung nach vorne zu Adresse 036Dh
        STA     VAR_IO_STATE    ; 32 01 04 -> Speichert den Akkumulator in RAM-Adresse VAR_IO_STATE
        ANI     007h            ; E6 07    -> Maskiert die unteren 3 Bits (Bit 0-2) des Akkumulators
        MOV     C, A            ; 4F       -> Das maskierte Ergebnis nach Register C retten
        MOV     A, B            ; 78       -> Holt das originale Zeichen aus Register B zurück nach A
        ANI     008h            ; E6 08    -> Bit 3 des Akkumulators isolieren
        LDA     VAR_SYS_STATUS  ; 3A 07 04 -> Systemstatus aus RAM 0407h laden
        JZ      L_0342          ; CA 42 03 -> Wenn Ergebnis von ANI Null war, Sprung nach 0342h
        XRI     001h            ; EE 01    -> Akkumulator mit 01h XOR-verknüpfen
L_BIT3_ZERO:
L_0342:
        ANI     001h            ; E6 01    -> Bit 0 isolieren
        RRC                     ; 0F       -> Akkumulator nach rechts rotieren
        INR     C               ; 0C       -> Register C um 1 erhöhen
L_BIT3_SET:
L_0346:
        RLC                     ; 07       -> Akkumulator nach links rotieren
        DCR     C               ; 0D       -> Register C um 1 verringern
    	JNZ     L_0346          ; C2 46 03 -> Wenn nicht Null, Sprung nach 0346h
        STA     VAR_PENDING_CMD ; 32 0B 04 -> Akkumulator in RAM-Zelle 040Bh sichern
        LXI     H, VAR_SYS_STATUS ; 21 07 04 -> HL auf RAM-Adresse 0407h ausrichten
        MOV     A, M            ; 7E       -> Wert laden
        ORI     008h            ; F6 08    -> Bit 3 gezielt setzen
        MOV     M, A            ; 77       -> Aktualisierten Wert zurückschreiben
; 0704h, 0703h are set to 0.
; value of [040B] VAR_PENDING_CMD is written to 0702h GPIB_CTRL_1
; value of [0407] VAR_SYS_STATUS is written to 0707h (LED control)
L_0355:
        LXI     H, GPIB_CTRL_3 ; 21 04 07 -> HL points to 0704h (GPIB connector related)
        MVI     M, 00h          ; 36 00    -> clear [0704h]
        LXI     H, GPIB_CTRL_1 ; 21 02 07 -> HL points to 0702h
        LDA     VAR_PENDING_CMD ; 3A 0B 04 -> load content of RAM 040Bh to A
        MOV     M, A            ; 77       -> copy A to [0702h]
        INX     H               ; 23       -> inc HL (now 0703h)
        MVI     M, 00h          ; 36 00    -> clear [0703h]
        MVI     L, 07h          ; 2E 07    -> set lower byte of HL to 07h (HL now is 0707h), which is LED control
        LDA     VAR_SYS_STATUS  ; 3A 07 04 -> load content of RAM 0407h to A
        MOV     M, A            ; 77       -> copy A to [0707h], switches on/off LEDs
        JMP     L_001F          ; C3 1F 00 -> continue at L_001F inside main polling loop

; ------------------------------------------------------------------------------
; Handler for GPIB command 15h - LLO Local Lockout
; prevents local control; control is only possible via remote (GPIB commands)
; bit 3 of 0407 seems to represent "LOCAL_ENABLED"
; ------------------------------------------------------------------------------
L_036D:
        XRA     A               ; AF       -> A:=0
        STA     VAR_IO_STATE    ; 32 01 04 -> writes A i.e. 0 to VAR_IO_STATE 0401
        LXI     H, VAR_SYS_STATUS ; 21 07 04 -> HL points to 0407h
        MOV     A, M            ; 7E       -> load [HL] to A
        ANI     0F7h            ; E6 F7    -> clear bit 3 (mask 1111 0111)
        MOV     M, A            ; 77       -> write back new value to [HL] i.e. 0407h
        JMP     L_MAINLOOP      ; C3 17 00 -> start over in mainloop

; ------------------------------------------------------------------------------
; Handler for GPIB command 05h - GTL Go To Local
; disconnects from remote control. Only local controls will be possible after this command.
; bit 1 in 0407 seems to represent "REMOTE_ENABLED"
; ------------------------------------------------------------------------------
L_037B:
        LDA     VAR_SYS_STATUS  ; 3A 07 04 -> load status byte from RAM 0407h
        ANI     002h            ; E6 02    -> isolate bit 1
        JZ      L_MAINLOOP      ; CA 17 00 -> if bit 1==0, continue in L_MAINLOOP (nothing to do it seems)
        MOV     A, B            ; 78       -> copy B to A (B seems to contain command character 05h)
        STA     VAR_CMD_LOCK    ; 32 0C 04 -> write A to 040Ch
        JMP     L_MAINLOOP      ; C3 17 00 -> start over in mainloop

; ------------------------------------------------------------------------------
; Table definitions and constants
; ------------------------------------------------------------------------------

; 038Ah - 038Fh: Padding / Unused ROM-Space (Füllbytes)
    	DB 0FFh	; 0FFh, from address 38ah
    	DB 0FFh	; 0FFh, from address 38bh
    	DB 0FFh	; 0FFh, from address 38ch
    	DB 0FFh	; 0FFh, from address 38dh
    	DB 0FFh	; 0FFh, from address 38eh
    	DB 0FFh	; 0FFh, from address 38fh

L_0390:
; 0390h: single byte constants used for comparison
    	DB 000h	; 000h, from address 390h
L_0391:
    	DB 002h	; 002h, from address 391h ROM_BUS_SIG_MASK
    	DB 005h	; 005h, from address 392h

; 0393h - 03B2h: jump table for GPIB commands. Used by code at L_FIND_HANDLER_ADDRESS / L_007B
; for a GPIB command byte, a handler address is defined.
; Format: [command byte] [handler address (Low/High)]
L_GPIB_CMD_JUMPTABLE:
    	DB 004h, L_013C & 0FFh, L_013C >> 8 ; 04h (SDC Selected Device Clear)       -> jump to L_013C ()
    	DB 014h, L_0006 & 0FFh, L_0006 >> 8 ; 14h (DCL Device Clear)                -> jump to L_0006 ()
        DB 015h, L_036D & 0FFh, L_036D >> 8 ; 15h (LLO Local Lockout)               -> jump to L_036D ()
        DB 018h, L_0148 & 0FFh, L_0148 >> 8 ; 18h (SPE Serial Poll Enable)          -> jump to L_0148 ()
        DB 019h, L_0147 & 0FFh, L_0147 >> 8 ; 19h (SPD Serial Poll Disable)         -> jump to L_0147 ()
        DB 008h, L_028A & 0FFh, L_028A >> 8 ; 08h (GET Group Execution Trigger)     -> jump to L_028A ()
        DB 020h, L_0100 & 0FFh, L_0100 >> 8 ; 20h (MLA Listener Addresses)          -> jump to L_0100 ()
        DB 040h, L_0120 & 0FFh, L_0120 >> 8 ; 40h (MTA Talker Addresses)            -> jump to L_0120 ()
        DB 005h, L_037B & 0FFh, L_037B >> 8 ; 05h (GTL Go To Local)                 -> jump to L_037B ()
        DB 060h, L_0324 & 0FFh, L_0324 >> 8 ; 60h (PPE Parallel Poll Enable)        -> jump to L_0324 ()
    	DB L_MAINLOOP & 0FFh, L_MAINLOOP >> 8 ; Default      -> jump to L_MAINLOOP ()

; 03B3h - 03C3h: initialization table for RAM buffer - Initialisierungs-Tabelle für den RAM-Puffer
; values are read by code at L_007B, to prepare buffer starting at location 041Fh
; [length 0Bh] [target address 041Fh] [max-limit 0Ah] [10x buffer zeroes]
L_03B3:
        DB 00Bh, 01Fh, 004h, 00Ah
        DB 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h

 ; [length 01h] [target address 0506h] . data is below at 03C4h [06h]
        DB 001h, 006h, 005h

; 03C4h - 03CDh: system config values
; 6,2,6,6,2,0,6,2,7,0
L_03C4:
    	DB 006h, 002h, 006h, 006h, 002h, 000h, 006h, 002h, 007h, 000h

; 03CEh - 03D3h: Maskierungs- und Fehler-Grenzwerte
    	DB 000h, 080h, 000h, 000h, 000h, 000h

; 03D4h - 03E3h: IEEE-488 Bus Talker Character Table (tranlates HEX input values to ICS4883 chars) ('0123...')
L_TLK_CHAR_TABLE:
        DB '0123456789+-.,E '
                    ;DB 030h	; 030h, from address 3d4h
                    ;DB 031h	; 031h, from address 3d5h
                    ;DB 032h	; 032h, from address 3d6h
                    ;DB 033h	; 033h, from address 3d7h
                    ;DB 034h	; 034h, from address 3d8h
                    ;DB 035h	; 035h, from address 3d9h
                    ;DB 036h	; 036h, from address 3dah
                    ;DB 037h	; 037h, from address 3dbh
                    ;DB 038h	; 038h, from address 3dch
                    ;DB 039h	; 039h, from address 3ddh
                    ;DB 02Bh	; 02Bh, from address 3deh
                    ;DB 02Dh	; 02Dh, from address 3dfh
                    ;DB 02Eh	; 02Eh, from address 3e0h
                    ;DB 02Ch	; 02Ch, from address 3e1h
                    ;DB 045h	; 045h, from address 3e2h
                    ;DB 020h	; 020h, from address 3e3h

L_03E4:
; 03E4h - 03EDh: Status- und Protokoll-Grenzwerte
    	DB 080h, 080h, 080h, 080h, 080h, 080h, 080h, 080h, 080h, 080h

; 03EEh - 03F4h: String-Terminatoren und Kontroll-Codes (CR/LF)
    	DB 00Dh	; 00Dh, from address 3eeh (CR)
    	DB 00Ah	; 00Ah, from address 3efh (LF)
    	DB 019h	; 019h, from address 3f0h
    	DB 000h	; 000h, from address 3f1h
    	DB 000h	; 000h, from address 3f2h
    	DB 000h	; 000h, from address 3f3h
    	DB 019h	; 019h, from address 3f4h

; 03F5h - 03FFh: jump table to handle separator characters. Used by code at L_FIND_HANDLER_ADDRESS / L_007B
; for a separator byte, a handler address is defined.
; Format: [separator byte] [handler address (Low/High)]
L_SEPARATOR_JUMP_TABLE:
        DB 00Dh, L_02C8 & 0FFh, L_02C8 >> 8 ; 0Dh (CR)     -> jump to L_02C8 (Listener processing)
        DB 00Ah, L_02C8 & 0FFh, L_02C8 >> 8 ; 0Ah (LF)     -> jump to L_02C8 (Listener processing)
        DB 02Ch, L_02C8 & 0FFh, L_02C8 >> 8 ; 2Ch (Komma)  -> jump to L_02C8 (Listener processing)
        DB L_02A5 & 0FFh, L_02A5 >> 8       ; Default      -> jump to L_02A5