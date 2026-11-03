; =====================================================================
; ICS Electronics Model 4883 Instrument Coupler
; disassembly heavily supported by Gemini AI
; =====================================================================
        CPU	8080
        ORG	0000h

; Memory map:
; 0000 - 03FF : ROM
; 0400 - 04FF : RAM and STACK
; 0500 - 05FF : Input and Output registers (needs more detailing)
; 0600 - 06FF : Input and Output registers (needs more detailing)
; 0700 - 07FF : GPIB connector control
; 0800 and above - unused

SRAM_START     EQU  0400h       ; start of RAM space
STACK_BASE     EQU  0500h       ; start value for stack pointer

; "VER" at EQU comments means "verified", I am sure that the name of EQU fits to reality

; ==============================================================================
; 0000 - 03FF : ROM constants and table addresses
; ==============================================================================
ROM_DATA_START   EQU  038Ah     ; Startbereich der Datentabellen im ROM
ROM_CONST_CMP    EQU  0390h     ; Kontroll-Konstanten für den Zeichenvergleich
GPIB_CMD_JUMPTABLE EQU  0393h   ; VER jump table for GPIB commands
ROM_TAB_SRAM_INI EQU  03B3h     ; Initialisierungs-Tabelle für den RAM-Puffer
ROM_CFG_FLAGS    EQU  03C4h     ; System-Konfigurations-Flags im ROM
ROM_CFG_LIMITS   EQU  03CEh     ; Maskierungs- und Fehler-Grenzwerte
ROM_TLK_CHAR_TABLE EQU 03D4h    ; VER Talker Character Table (tranlates HEX input values to ICS4883 chars) ('0123...')
ROM_PROT_LIMITS  EQU  03E4h     ; Status- und Protokoll-Grenzwerte
ROM_STR_TERMS    EQU  03EEh     ; String-Terminatoren und Kontroll-Codes (CR/LF)
SEPARATOR_JUMP_TABLE  EQU  03F5h  ; VER jump table for separator bytes ( CR, LF, comma)

; ==============================================================================
; 0400 -04FF : RAM variables
; ==============================================================================
REG_BUFFER_STS EQU  0400h       ; Puffer-Status / Aktivitäts-Flag
REG_IO_STATE   EQU  0401h       ; Letztes empfangenes oder gesendetes E/A-Zeichen
REG_MODE_SEL   EQU  0402h       ; Modus-Selektor (wird durch 'p'/'q' geschaltet)
REG_SYS_STATE  EQU  0403h       ; Globaler Systemzustand (Handshake / I/O)
REG_BCD_DATA   EQU  0404h       ; Speicher für validierte BCD-Ziffern
REG_GPIB_CTRL  EQU  0405h       ; GPIB Kontroll-Flag (z. B. 80h für Reset/Status)
REG_SYS_STATUS EQU  0407h       ; Zentrales Statusregister (Remote/Local, Bit 3 LEDs)
REG_INIT_FLAG  EQU  0408h       ; Initialisierungs- und Reset-Steuerflag
REG_PENDING_CMD EQU  040Bh      ; Zwischenspeicher für anstehende Handshake-Befehle
REG_CMD_LOCK   EQU  040Ch       ; Sperrregister für eingehende Bus-Befehle
REG_CMD_SERIALPOLL  EQU  040Dh       ; VER Befehls-Statusregister (Steuerflag für Modus/Fehler)
REG_BUS_STATUS EQU  040Eh       ; VER GPIB status register (Talker, is 41h if data available)
REG_EOS_FLAG   EQU  040Fh       ; End-Of-Sequence / EOI Status-Register
REG_BUFF_PTR   EQU  041Dh       ; Letzter Tabellenzeiger / Puffer-Pointer
REG_BUFF_IDX   EQU  041Fh       ; Index-Zähler für den Zeichenpuffer (Max 10)
REG_ARRAY_PTR  EQU  042Eh       ; Zeiger auf das aktuelle Zeichen im indizierten Array
RAM_ASCII_BUFF EQU  0430h       ; Startadresse für den übersetzten ASCII-Datenpuffer

; ==============================================================================
; 0500 - 05FF : HARDWARE-MAPPED I/O REGISTERS (Eingabe & Ausgabe) and Configuration RAM
; Hardware Input Section and Hardware Output Section
; ==============================================================================
RAM_HW_CONFIG1 EQU  0505h       ; Hardware-Konfigurationsbyte 1 (z. B. Pegelsteuerung)
RAM_HW_CONFIG2 EQU  0506h       ; configuration byte (created by L_0006 during boot; value is 1010)

; ==============================================================================
; 0600 - 06FF : HARDWARE-MAPPED I/O REGISTERS (Eingabe & Ausgabe)
; Hardware Input Section and Hardware Output Section
; ==============================================================================
IO_HW_INPUT    EQU  0604h       ; Primäres Hardware-Eingangsregister (Datenstrom)
IO_GPIB_CTRL_1  EQU  0605h      ; Control byte related to GPIB connector
IO_SRAM_FLAG1  EQU  0607h       ; Status-Flag im I/O-SRAM (Eingangs-Bestätigung)

; ==============================================================================
; 0700 - 07FF : HARDWARE-MAPPED I/O REGISTERS (Eingabe & Ausgabe)
; GPIB connector control (no special chip used, just 74xx chips)
; ==============================================================================
IO_TALK_STATUS EQU  0701h       ; Status des Talker-Interfaces (Eingang/Ausgang)
IO_TALK_CTRLBUS  EQU  0702h     ; Synchronisationsregister 02h für Talker-Schnittstelle
IO_TALK_DATABUS  EQU  0703h     ; Synchronisationsregister 03h für Talker-Schnittstelle
IO_TALK_CTRL   EQU  0704h       ; Kontrollregister für IEEE-488 Buschip
IO_TALK_DATA   EQU  0705h       ; Datenpuffer-Register des Talker-Interfaces
IO_DIP_SWITCH  EQU  0706h       ; VER DIP Switch byte
IO_HW_OUTPUT   EQU  0707h       ; Zentrales Hardware-Ausgangsregister (z. B. LEDs/Latch)

; 0706h IO_DIP_SWITCH bits:
; bit 7 ONLY
; bit 6 TALKER
; bit 5 LISTENER
; bit 4-0 is GPIB ADDRESS

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
        LDA     ROM_CFG_FLAGS   ; 3A C4 03 -> read config value from ROM 03C4 (value there is: 6=0110)
        XRI     0Ch             ; EE 0C    -> XOR with C=1100 (result: 1010)
        STA     RAM_HW_CONFIG2  ; 32 06 05 -> put result to RAM 0506
        LXI     H, ROM_TAB_SRAM_INI ; 21 B3 03 -> put pointer to ROM table to H
        CALL    L_007B          ; CD 7B 00 -> copy ROM tables to RAM/memory mapped regs
        JMP     L_02C8          ; C3 C8 02 -> Further init code; at its end, main IO polling loop L_MAINLOOP is jumped to.

; ------------------------------------------------------------------------------
; main IO polling loop
; L_MAINLOOP is also Default Handler in L_GPIB_CMD_JUMPTABLE table
; ------------------------------------------------------------------------------
L_MAINLOOP:                     ; was: L_0017
        DI                      ; F3
        LDA     REG_IO_STATE    ; 3A 01 04 -> load 0401h from RAM to A - Status von GPIB / I/O Interface-Chip laden
        ORA     A               ; B7       -> is it = 0 ?
        JNZ     L_0355          ; C2 55 03 -> if no, then handle state change in L_0355; DD: maybe a pending command is handled there

L_001F:
        LDA     IO_TALK_STATUS  ; 3A 01 07 -> load 0701h to A
        ANI     0C0h            ; E6 C0    -> mask 2 upper bits of 0701h
        CPI     80h             ; FE 80    -> is masked value equal to 80h (so bit7 was 1 and bit6 was 0)
        JZ      L_00CE          ; CA CE 00 -> on equality, continue at L_00CE (supposed Listener handling)

        CALL    L_00AD          ; CD AD 00 -> calls 00ADh;
        MVI     C, 0FEh         ; 0E FE    -> loads 0FEh to C (looks like a mask 1111.1110) - bit 0 is in focus
        CALL    L_00A1          ; CD A1 00 -> calls 00A1h; seem to write both RAM 0407h and GPIB hardware 0707h
        LDA     IO_DIP_SWITCH   ; 3A 06 07 -> Loads 0706h to A
        RLC                     ; 07       -> rotate left, move highest bit ("ONLY" switch) to carry flag
        JMP     L_003C          ; C3 3C 00 -> continue at L_003C, with bits 6..0 from 0706h in A; "TL43.210x"
        POP     H               ; E1       -> Registerpaar HL vom Stack holen (Stack aufräumen)
        JMP     L_00CE          ; C3 CE 00 -> Sprung zur Service-Routine L_00CE

L_003C:
        CC      L_009C          ; DC 9C 00 -> if carry flag ist set ("ONLY" switch on), continue at L_009C; in A we have 0706h content shiftet left by 1
        LXI     H, REG_SYS_STATUS  ; 21 07 04 -> Register HL mit Adresse 0407h laden
    	MOV     A,M             ; 7E
    	RRC                     ; 0F
    	RRC                     ; 0F
        JC      L_029D          ; DA 9D 02 -> Wenn Carry=1, springe zu Adresse 029Dh
        RRC                     ; 0F       -> Akkumulator nach rechts rotieren
        JC      L_01AD          ; DA AD 01 -> Wenn Carry=1, springe zu Adresse 01ADh - talker handling
        LXI     B,01000h        ; 01 00 10 -> lade 01000h in BC
        LDA     IO_GPIB_CTRL_1  ; 3A 05 06 -> Holt das Daten-Byte vom I/O-Schnittstellenregister
    	CMA                     ; 2F       -> Akkumulator invertieren (Low-Aktive Signale)
    	RRC                     ; 0F       -> put lowest bit into carry flag
    	JNC     L_0060          ; D2 60 00 -> if no carry (lowest bit was 0) then continue at 0060h, which will return from there to main loop
    	CALL    L_00C7          ; CD C7 00 -> if we had carry at lowest bit, puts bit 5 of IO_TALK_DATA into carry flag
        JC      L_SET_DATA_AVAILABLE ; DA 6D 00 -> if carry, jump to L_SET_DATA_AVAILABLE = L_SET_DATA_AVAILABLE - Wenn Carry=1, springe zu Adresse 006Dh
        STA     IO_SRAM_FLAG1   ; 32 07 06 -> no carry, no data available, put A to 0607h

; ------------------------------------------------------------------------------
; Some cleanup at end of talker handling
; ------------------------------------------------------------------------------
L_0060:
    	LXI     H, REG_SYS_STATE ; 21 03 04 -> HL points to 0403h
    	MOV     A,M             ; 7E       -> load [0403h] to A
    	ANA     B               ; A0       -> AND A with B
    	ORA     C               ; B1       -> OR A with C
    	MOV     M,A             ; 77       -> move A to [0403h]
    	STA     IO_TALK_DATABUS ; 32 03 07 -> write result to 0703h (GPIB connector)
    	JMP     L_MAINLOOP      ; C3 17 00 -> back to loop start

; ------------------------------------------------------------------------------
; Set GPIB Status Byte (Talker) to 41h, which means "data available"
; ------------------------------------------------------------------------------
L_SET_DATA_AVAILABLE:           ; was L_006D
        LXI     H, REG_BUS_STATUS ; 21 0E 04 -> HL points to 040Eh (GPIB status reg)
        MOV     A, M            ; 7E       -> load GPIB status reg to A
        RRC                     ; 0F       -> check if lowest bit is set
        JC      L_0060          ; DA 60 00 -> if yes, handle that at 0060h (will not return here, but go to main loop)
        MVI     M, 41h          ; 36 41    -> put 41h (ASCII 'A') to 040Eh, means "data available"
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
; ram initialization
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
; We enter L_009C with A filled by value of IO_DIP_SWITCH, already shifted left by one. So content is
; TL43.210x
; the three shifts at L_009C move lower 4 bits of GPIB address to upper nibble. bit5 is lost. Strange.
; ------------------------------------------------------------------------------
L_009C:
        RLC                     ; 07       -> shift 3 bits left result is L43.210xx
        RLC                     ; 07       -> "                           4321.0xxx
        RLC                     ; 07       -> "                           3210.xxxx
L_009F:
    	MVI     C, 0F9h         ; 0E F9    -> loads mask value 0F9h (mask 1111.1001b) into C
;
; L_00A1 updates systen state register RAM 0407h and also writes changes out to hardware register 0707h.
; It applies a mask value in C
; mask is either 0F9h (called via L_009F) or 0FDh (called by L_010E)
; A - new bits to set
; C - mask, which bits of old value should stay (1<=> stay, 0 don't stay)
L_00A1:
        LXI     H, REG_SYS_STATUS ; 21 07 04 -> HL points to 0407h
        MOV     B, A            ; 47       -> copy A to B
        MOV     A, M            ; 7E       -> load [HL] (0407h) into A
        ANA     C               ; A1       -> AND with C (apply mask) , means switch of bits to be new defined
        ORA     B               ; B0       -> OR with B, means all new bits are set correctly after that
        MOV     M, A            ; 77       -> write new value to [HL] (0407h)
        MVI     H, 07h          ; 26 07    -> set H of HL to 07h (HL points now to 0707h)
        MOV     M, A            ; 77       -> write A to 0707h
        RET                     ; C9       -> back to caller

L_00AD:
        LXI     H, 0391h        ; 21 91 03 -> HL-Zeiger auf ROM-Tabelle/String 0391h ausrichten
    	LDA     IO_GPIB_CTRL_1  ; 3A 05 06 -> Holt das aktuelle I/O-Datenbyte vom Talker
        CMA                     ; 2F       -> Akkumulator invertieren (Low-Aktiv Pegel)
        ANI     02h             ; E6 02    -> Bit 1 maskieren (Prüfung eines bestimmten Bus-Signals)
        CMP     M               ; BE       -> Vergleiche das Ergebnis mit dem Wert im ROM [HL]
        JNZ     L_00C5          ; C2 C5 00 -> Wenn ungleich, springe vor zu Adresse 00C5h
        INX     H               ; 23       -> HL-Zeiger auf das nächste Tabellenbyte erhöhen
        LDA     RAM_HW_CONFIG1  ; 3A 05 05 -> weiteres I/O-Datenbyte einlesen
        CMA                     ; 2F       -> Invertieren
        ANI     07h             ; E6 07    -> Die untersten 3 Bits maskieren
        CMP     M               ; BE       -> Mit dem nächsten Tabellenwert im ROM vergleichen
        MVI     A, 01h          ; 3E 01    -> Lade Konstante 01h in den Akkumulator
        RZ                      ; C8       -> Bedingter Rücksprung, wenn der Vergleich gleich war (Zero-Flag = 1)
L_00C5:
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
    	RET                     ; C9

L_00C7:
    	LDA     IO_TALK_DATA    ; 3A 07 05 -> load 0507h to A
        RLC                     ; 07       -> put bit 5 to carry flag by rotating 3x
        RLC                     ; 07       ->
        RLC                     ; 07       ->
    	RET                     ; C9       -> return to caller

; ------------------------------------------------------------------------------
; Supposed Listener handling main entry point
; ------------------------------------------------------------------------------
L_00CE:
        MVI     A, 80h          ; 3E 80    -> load 80h to A
        STA     REG_GPIB_CTRL   ; 32 05 04 -> write A to RAM location 0405
        XRA     A               ; AF       -> A:=0
        STA     IO_TALK_CTRLBUS ; 32 02 07 -> write A which is 0 to 0702h
        CALL    L_0163          ; CD 63 01 -> call L_0163 DD seems to read a byte from GPIB, result in B
        LDA     IO_DIP_SWITCH   ; 3A 06 07 -> load 0706h to A
        RLC                     ; 07       -> check ONLY bit of dip switch
        JC      L_MAINLOOP      ; DA 17 00 -> if ONLY=1, then carry=1, we are finished and jump to L_MAINLOOP
        MOV     A, B            ; 78       -> load B to A
        ANI     07Fh            ; E6 7F    -> mask to 7 bits (only 7 bits are used)
        MOV     B,A             ; 47       -> save to B
        ANI     060h            ; E6 60    -> isolate bits 6 and 5
        CPI     060h            ; FE 60    -> Check against 0110.0000
        JZ      L_00F7          ; CA F7 00 -> if equality (bits 5 and 6 are set) continue at 00F7h (there a handler address is determined and handler code executed)
        XRA     A               ; AF       -> A := 0
        STA     REG_CMD_LOCK    ; 32 0C 04 -> writes A, which is 0, to 040Ch, i.e. clear REG_CMD_LOCK
        MOV     A, B            ; 78       -> load B to A
        ANI     060h            ; E6 60    -> isolate bits 6 and 5
        JNZ     L_00F7          ; C2 F7 00 -> if bit 5 or 6 are set, call again L_00F7 (there a handler address is determined and handler code executed)
        MOV     A, B            ; 78       -> load B to A
L_00F7:
        LXI     H, GPIB_CMD_JUMPTABLE ; 21 93 03 -> Load handler jump table at 0393h
        MVI     C, 0Ah          ; 0E 0A    -> loop counter C := 10
        CALL    L_FIND_HANDLER_ADDRESS ; CD 4E 01 -> handle chars by determining correct handling routine address
        PCHL                    ; E9       -> jump to handler found

; ------------------------------------------------------------------------------
; Handler for GPIB command 20h - MLA Listener Addresses
; address value is in B.
; checks if address in B equals address defined at DIP switches.
; ------------------------------------------------------------------------------
L_0100:
        CALL    L_0131          ; CD 31 01 -> Compare GPIB address received with own address
        MVI     A, 02h          ; 3E 02    -> load 02h into A
        JNZ     L_010E          ; C2 0E 01 -> if value of last cmp (address compare) !=0, jump to 010Eh; so: nout our address
L_0108:
        ; address equals our address
        CALL    L_009F          ; CD 9F 00 -> call 009Fh, which seems to write out a byte to 0707h (maybe GPIB talker write)
        JMP     L_MAINLOOP      ; C3 17 00 -> jump to main loop

L_010E:
        ; address is not our address
        MOV     A, B            ; 78       -> copy B to A
        CPI     03Fh            ; FE 3F    -> is command UNL Universal Unlisten (3Fh / '?')?
        JNZ     L_MAINLOOP      ; C2 17 00 -> if not an UNL, jump to main polling loop L_MAINLOOP
    	XRA     A               ; AF       -> XOR A mit A <=> A:=0
    	STA     REG_BUFF_IDX    ; 32 1F 04 -> write 0 to 041F
    	MVI     C, 0FDh         ; 0E FD    -> loads 0FDh into C (output mask?)
    	CALL    L_00A1          ; CD A1 00 -> L_00A1 writes value from RAM 0407h to 0707h (maybe GPIB talker write)
        JMP     L_MAINLOOP      ; C3 17 00 -> jump back to main loop

; ------------------------------------------------------------------------------
; Handler for GPIB command 40h - MTA Talker Addresses
; ------------------------------------------------------------------------------
L_0120:
        CALL    L_0131          ; CD 31 01 -> Compare GPIB address received with own address
        MVI     A, 04h          ; 3E 04    -> load 04h into A
        JZ      L_0108          ; CA 08 01 -> if value of last cmp (address compare) ==0, jump to L_0108
        MVI     C, 0FBh         ; 0E FB    -> loads mask 0FBh 1111.1100 to C
        XRA     A               ; AF       -> clear A
        CALL    L_00A1          ; CD A1 00 -> Ruft die I/O-Ausgabestufe auf
    	JMP     L_MAINLOOP      ; C3 17 00 -> jump back to main loop

; Comparison if GPIB address just received with address set at dip switch
L_GPIB_ADDRESS_CMP:
L_0131:
    	LDA     IO_DIP_SWITCH   ; 3A 06 07 -> loads 0706h into A
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
    	LDA     REG_SYS_STATUS  ; 3A 07 04 -> load 0407 into A
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
; writes A value into register REG_CMD_SERIALPOLL
; A is 0, for SPD command, and !=0 for serial poll start SPE
; ------------------------------------------------------------------------------
L_0148:
    	STA     REG_CMD_SERIALPOLL ; 32 0D 04  -> store A to 040Dh (in serial poll start case, A is something != 0)
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
; L_0163 waits for bit0 = 1 in REG_GPIB_CTRL
; HL points to 0701 IO_TALK_STATUS
; DE points to 0703 IO_TALK_DATABUS
; several bytes are written to [DE], i.e. IO_TALK_DATABUS. I count 4 bytes, "STAX D"
; ------------------------------------------------------------------------------
L_0163:
        LDA     REG_SYS_STATE   ; 3A 03 04 -> load 0403h to A
        ANI     10h             ; E6 10    -> and with bit 4, isolate bit 4
        MOV     C, A            ; 4F       -> copy A to C
        LXI     D, IO_TALK_DATABUS ; 11 03 07 -> DE points to 0703h
        MVI     A, 04h          ; 3E 04    -> load 04h to A
        ORA     C               ; B1       -> OR with C: now bit 4 from 0403h is set in A
        STAX    D               ; 12       -> write A to [DE] ausgeben
        MVI     A, 80h          ; 3E 80    -> load 80h  to A
        STA     IO_TALK_CTRL    ; 32 04 07 -> write A to 0704h
        LXI     H, IO_TALK_STATUS ; 21 01 07 ->HL points to 0701h
WAIT_FOR_BIT0_REG_GPIB_CTRL:
L_0178:
        LDA     REG_GPIB_CTRL   ; 3A 05 04 -> load RAM 0405h to A
    	XRA     M               ; AE       -> XOR A with [HL], i.e. [0405h]
    	JM      L_01A9          ; FA A9 01 -> if sign flag==1, continue at 01A9h (do nothing)
        MOV     A, M            ; 7E       -> read from [HL], which is 0701h
        ANI     01h             ; E6 01    -> and with bit 0, isolate bit 0
        JZ      L_0178          ; CA 78 01 -> if bit0==0, jump back to 0178h (we are waiting for bit0 becoming 1)
        LDA     REG_GPIB_CTRL   ; 3A 05 04 -> load RAM 0405h to A
    	XRA     M               ; AE       -> XOR A with [HL], i.e. [0405h]
    	JM      L_01A9          ; FA A9 01 -> if sign flag==1, continue at 01A9h (do nothing)
        MVI     A, 06h          ; 3E 06    -> sign flag is 0, load 06h to A
        ORA     C               ; B1       -> OR with C: now bit 4 from 0403h is set in A
        STAX    D               ; 12       -> write A to [DE] ausgeben
        MOV     A, M            ; 7E       -> read from [HL], which is 0701h
        STA     REG_EOS_FLAG    ; 32 0F 04 -> save A to RAM 040Fh
        DCX     H               ; 2B       -> HL-- (now 0700h)
        MOV     B, M            ; 46       -> read from [HL], which is 0700h, to B
        INX     H               ; 23       -> HL++ (now again 0701h)
        MVI     A, 02h          ; 3E 02    -> load 02h to A
        ORA     C               ; B1       -> OR with C: now bit 4 from 0403h is set in A
        STAX    D               ; 12       -> write A to [DE]
L_019B:
        MOV     A, M            ; 7E       -> read from [HL], which is 0701h
        ANI     01h             ; E6 01    -> and with bit 0, isolate bit 0
        JNZ     L_019B          ; C2 9B 01 -> if bit0 is set, jump to 019Bh
        MVI     A, 06h          ; 3E 06    -> load 06h to A
        ORA     C               ; B1       -> OR with C: now bit 4 from 0403h is set in A
        STAX    D               ; 12       -> write A to [DE]
        STA     REG_SYS_STATE   ; 32 03 04 -> write A back to RAM 0403h
        RET                     ; C9       -> return to caller
L_01A9:
        POP     H               ; E1       -> restore HL
        JMP     L_MAINLOOP      ; C3 17 00 -> jump to mainloop

; ------------------------------------------------------------------------------
; Talker code
; Handle input from instrument and write to GPIB bus
; these bytes seem to have following meaning
; 0605h also called IO_GPIB_CTRL_1
;   bit0=1 no input data, bit0=0 we have input data at input pins. Seems to be set by IOBoard and is maybe controlled by an input pin.
;   bit2 checked by convert_out_char,
;
; 0604h-0608h 5 bytes corresponding to 10 nibbles corresponding to 40 input pins
; 0604
; 0605
; 0606
; 0607
; 0608
; BUT somehow in 0605h we also have non-data-pins, looking like handshake signals. Or internal signals between IOBoard and mainboard. Needs more analysis.
;
; 10 nibbles are processed, converted by using the Talker Character Table (ROM_TLK_CHAR_TABLE) and written
; to 10 bytes in RAM starting at location 0430h.
;
; All GPIB line handshake (NDAC, DAV, ...) is done in the code.
;
; Note: code starting at L_01F1 is also used for sending status byte during serial poll.
; ------------------------------------------------------------------------------
L_01AD:
    	EI                      ; FB       -> enable interrupts
    	LDA     REG_CMD_SERIALPOLL   ; 3A 0D 04 -> loads 040Dh into A
    	ORA     A               ; B7       -> is 040Dh == 0 ? this means: are we in a serial poll process?
    	JNZ     L_0232          ; C2 32 02 -> if in serial poll, jump to 0232h
        LXI     H, IO_GPIB_CTRL_1 ; 21 05 06 -> HL points to 0605h
WAIT_FOR_BIT0_SET:
; we do busy waiting until bit0 from 0605h is cleared
; bit0 will be cleared externally by some interrupt-driven action (not code)
L_01B8:
        MOV     A, M            ; 7E       -> load [HL] to A
    	RRC                     ; 0F       -> bit 0 to Carry flag
        JC      L_01B8          ; DA B8 01 -> if Carry set, loop back to 01B8h WAIT_FOR_BIT0_SET
        DI                      ; F3       -> Disable Interrupts
        LXI     D, RAM_ASCII_BUFF ; 11 30 04 -> load 0430h to DE (target pointer)
        LXI     H, IO_HW_INPUT  ; 21 04 06 -> load 0604h to HL; DD: h := 0x0604 = start address of bytes read from input (5 bytes containing 10 nibbles)
    	CALL    L_0242          ; CD 42 02 -> read in and convert 5 input bytes
    	MVI     A, 0Fh          ; 3E 0F    -> load 0fh to A
        STA     SRAM_START      ; 32 00 04 -> Akkumulator-Inhalt direkt in RAM SRAM_START sichern
        EI                      ; FB       -> Interrupts wieder freigeben (Enable Interrupts)
        LXI     H, RAM_ASCII_BUFF ; 21 30 04 -> HL-Zeiger auf SRAM-Adresse 0430h laden DD: h := address of created 10 bytes
        SHLD    REG_ARRAY_PTR   ; 22 2E 04 -> Speicherinhalt von HL nach SRAM 042Eh sichern
        LXI     H, ROM_PROT_LIMITS ; 21 E4 03 -> HL-Zeiger auf Übersetzungstabelle im ROM ausrichten
L_01D6:
        MOV     A, M            ; 7E       -> Byte via HL laden
        INX     H               ; 23       -> HL-Zeiger um 1 erhöhen
        SHLD    REG_BUFF_PTR    ; 22 1D 04 -> Aktuellen HL-Zeiger im RAM 041Dh sichern
        CPI     19h             ; FE 19    -> Akkumulator mit Konstante 19h vergleichen

        JZ      L_MAINLOOP      ; CA 17 00 -> if A==19, jump to mainloop
        ORA     A               ; B7       -> Flags aktualisieren (Prüfen auf Null/Vorzeichen)
        JP      L_01F0          ; F2 F0 01 -> Wenn positiv (Bit 7 = 0), springe vor zu Adresse 01F0h
        ANI     040h            ; E6 40    -> Bit 6 maskieren
        ORA     C               ; B1       -> Logisches ODER mit Register C verknüpfen
        MOV     C, A            ; 4F       -> In Register C sichern (AS-Syntax für MOV C,A)
        LHLD    REG_ARRAY_PTR   ; 2A 2E 04 -> HL-Registerinhalt im SRAM 042Ah sichern
        MOV     A, M            ; 7E       -> Byte erneut via HL laden
        INX     H               ; 23       -> HL-Zeiger um 1 erhöhen
        SHLD    REG_ARRAY_PTR   ; 22 2E 04 -> HL-Registerinhalt im SRAM 042Eh sichern
L_01F0:
        MOV     B, A            ; 47       -> Byte in Register B sichern
L_01F1:
        LDA     REG_SYS_STATE   ; 3A 03 04 -> load [0403h] to A
        ANI     10h             ; E6 10    -> isolate bit 4
        MOV     C, A            ; 4F       -> save to C
        LXI     D,IO_TALK_DATABUS ; 11 03 07 -> loads byte from [DE] - Lädt Byte von der Hardware-Adresse [DE] (0703h)
        STAX    D               ; 12       -> write A to [DE]
        LXI     H, IO_TALK_CTRLBUS ; 21 02 07 -> HL points to 0702h
        MOV     M,B             ; 70       -> write B to [HL]
        DCX     H               ; 2B       -> HL-- (now 0701h)
; loop waits for 0701h, bit 1 becomes 0 (NDAC / NRFD)
L_0200:
        MOV     A, M            ; 7E       -> load from 0701h to A
        RRC                     ; 0F       -> rotate right
        RRC                     ; 0F       -> rotate right
        JC      L_0200          ; DA 00 02 -> if carry=1, loop back at L_0200
        MVI     A, 01h          ; 3E 01    -> load 01h to A (DAV signal)
        ORA     C               ; B1       -> OR A with C
        STAX    D               ; 12       -> write A to [DE]
; byte is written out, DAV was set. Now wait for ack from controller.
; loop waits for 0701h, bit 2 becomes 0 ()
L_020A:
        MOV     A, M            ; 7E       -> load from 0701h to A
        RRC                     ; 0F       --> shift right 3x
        RRC                     ; 0F
        RRC                     ; 0F
        JC      L_020A          ; DA 0A 02 -> if carry==1 loop back to L_020A
        DI                      ; F3       -> disable interrupts
        XRA     A               ; AF       -> A:=0
        STAX    D               ; 12       -> [DE] := A i.e. 0 (DAV becomes inactive)
        STA     REG_SYS_STATE   ; 32 03 04 -> clear REG_SYS_STATE (becomes 0)
        LXI     H, SRAM_START   ; 21 00 04 -> HL points to SRAM_START
        MOV     A, M            ; 7E       -> load [HL] to A (HL points to SRAM_START)
        MVI     M, 00h          ; 36 00    -> [HL] := 0
        ORA     A               ; B7       -> (update CPU flags)
        JM      L_MAINLOOP      ; FA 17 00 -> if A<0 (bit 7=1), jump to L_MAINLOOP
        JZ      L_022B          ; CA 2B 02 -> if A==0, jump to L_022B
        XRA     A               ; AF       -> A:=0
        STA     IO_SRAM_FLAG1   ; 32 07 06 -> clear IO_SRAM_FLAG1
        STA     REG_BUS_STATUS  ; 32 0E 04 -> clear REG_BUS_STATUS
L_022B:
        EI                      ; FB       -> enable interrupts
        LHLD    REG_BUFF_PTR    ; 2A 1D 04 -> HL := 041D
        JMP     L_01D6          ; C3 D6 01 -> jump back to outer loop (maybe more chars to send)
; ------------------------------------------------------------------------------
; Handle a serial poll. The coupler is addressed as talker, and must present its status byte.
; Called from more general talker routine at L_01AD, which can also respond to a read with data bytes.
; L_0232 only prepares status byte and then let L_01F1 write out the code.
; ------------------------------------------------------------------------------
L_0232:
        MVI     A, 0FFh         ; 3E FF    -> load 0FFh to A
        STA     SRAM_START      ; 32 00 04 -> write A to SRAM_START
        LXI     H, REG_BUS_STATUS ; 21 0E 04 -> HL points to GPIB status byte of coupler
        MOV     B, M            ; 46       -> load status byte to B
        MOV     A, M            ; 7E       -> and load it to A
        ANI     0BFh            ; E6 BF    -> clear bit 6 in A (mask 1011.1111)
        MOV     M, A            ; 77       -> write A back to REG_BUS_STATUS
        JMP     L_01F1          ; C3 F1 01 -> Sprung zu RAM/ROM-Adresse 01F1h

; ------------------------------------------------------------------------------
; convert all 5 bytes from input IO connector
; convert bytes from input IO connector
; d is index for created output string
; h,l points to start address to convert
; b is num of bytes to convert (5)
; h,l point to memory location for input byte (is decremented in a loop)
; it looks that two 4-bit values are in 1 byte as HI/LO nibble
;
; we load from 0604 up to 0608h (5 bytes).
; ------------------------------------------------------------------------------
convert_5input_bytes:
L_0242:
        MVI     B, 05h          ; 06 05    -> set loop counter B to 5: num of bytes to convert (5 bytes = 10 nibbles)
L_0244:
        MOV     A, M            ; 7E       -> load byte from HL (0604h) to A
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
; convert hex value read from instrument via conversion table ROM_TLK_CHAR_TABLE
; lookup, store it (0x26c)  to somewhere
; (in RAM or register?), increment index in d, and keep h in original state
;
; Sie entscheidet anhand eines Hardware-Statusbits, ob ein Datenwert invertiert
; und über eine Zeichentabelle im ROM übersetzt wird, oder ob es sich um ein
; Steuersignal handelt, das das System beeinflusst.
;
; ------------------------------------------------------------------------------
convert_out_char:
L_0256:
        MOV     C, A            ; 4F       -> save A to C
        LDA     IO_GPIB_CTRL_1  ; 3A 05 06 -> read byte from 0605h
        ANI     04h             ; E6 04    -> isolate bit 2 to check bit 2 (maybe "do we have valid data?)"
        CPI     04h             ; FE 04    -> is bit 2 set?
        MOV     A, C            ; 79       -> restore A from C
        JZ      L_0263          ; CA 63 02 -> if not set(?) jump to 0263h
        CMA                     ; 2F       -> bit invert A
L_0263:
        ANI     0Fh             ; E6 0F    -> mask lower 4 bit in A
        PUSH    H               ; E5       -> save HL
        LXI     H, ROM_TLK_CHAR_TABLE ; 21 D4 03 -> HL points to ROM table
        ADD     L               ; 85       -> Add L to A (now A contains byte offset in table)
        MOV     L, A            ; 6F       -> L := A
        MOV     A, M            ; 7E       -> read translated char from char table
        STAX    D               ; 12       -> store char to [DE] (0430h ff)
        INX     D               ; 13       -> inc DE
        POP     H               ; E1       -> restore HL
        RET                     ; C9       -> return to caller

; Steuerzeichen Filter
        LXI     H, ROM_CONST_CMP ; 21 90 03 -> HL auf alternative Tabelle/String im ROM ausrichten
        MOV     A, B            ; 78       -> Register B (04h) nach A holen
        ANI     01Fh            ; E6 1F    -> 5-Bit-Maskierung
        CMP     M               ; BE       -> Mit Speicherwert [HL] vergleichen
        JNZ     L_MAINLOOP      ; C2 17 00 -> Bei Ungleichheit harter Sprung zurück zu L_MAINLOOP
        LXI     H, REG_SYS_STATUS ; 21 07 04 -> HL auf RAM-Adresse 0407h setzen
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
; ------------------------------------------------------------------------------
L_028A:
        LDA     REG_SYS_STATUS  ; 3A 07 04 -> Lädt den Gerätestatus aus dem RAM
        ANI     02h             ; E6 02    -> Bit 1 maskieren (z. B. Remote/Local oder ein Bus-Flag)
        JZ      L_MAINLOOP      ; CA 17 00 -> Wenn Bit 0 ist, Schleife abbrechen und zurück zu L_MAINLOOP
        LXI     H, IO_SRAM_FLAG1 ; 21 07 06 -> HL auf Ausgangs-Datenregister ausrichten
        MOV     M, A            ; 77       -> Den maskierten Statuswert direkt dorthin schreiben
        DCX     H               ; 2B       -> HL dekrementieren auf 0606h
        LDA     03C8h           ; 3A C8 03 -> Einen Konfigurations- oder Initialisierungswert aus dem ROM laden
        JMP     L_02F9          ; C3 F9 02 -> Sprung zur weiteren Registerverarbeitung an Adresse 02F9h

; Daten-Empfang und Indizierung: Dieser Block verarbeitet ankommende Bus-Zeichen. Er nutzt die RAM-Zelle 041Fh als Index-Zähler (limitiert auf maximal 10 Zeichen, CPI 00Ah).
; Dynamische Puffer-Adressierung: Durch ADI 020h und MOV L, A berechnet der Code zur Laufzeit eine Zieladresse im RAM (ein sogenanntes indiziertes Array), um die eingehenden Zeichen nacheinander geordnet abzuspeichern.
; Protokoll-Validierung: Am Ende wird über das RAM-Register 040Fh ausgewertet, ob der Bus ein Übertragungsende signalisiert (CPI 040h).
L_029D:
        XRA     A               ; AF       -> Akkumulator nullen
        STA     REG_GPIB_CTRL   ; 32 05 04 -> Systemregister 0405h im RAM zurücksetzen
        STA     IO_TALK_CTRLBUS ; 32 02 07 -> Interface-Register 0702h löschen
        DI                      ; F3       -> Interrupts global sperren

; ------------------------------------------------------------------------------
; L_02A5 is also Default Handler in separator table
; ------------------------------------------------------------------------------
L_BUFF_LOOP:
L_02A5:
        CALL    L_0163          ; CD 63 01 -> Aufruf der Puffer-/Schnittstellenroutine L_0163
        MOV     A, B            ; 78       -> Das in Register B befindliche Zeichen nach A holen
        ANI     070h            ; E6 70    -> Die Bits 4, 5 und 6 maskieren
        CPI     030h            ; FE 30    -> Prüfen, ob das obere Halbnibble dem ASCII-Bereich '3' entspricht
        JNZ     L_0305          ; C2 05 03 -> if not, do additional parsing (we may have a separator)
        LXI     H, REG_BUFF_IDX ; 21 1F 04 -> HL auf RAM-Adresse 041Fh (Zähler/Index) setzen
        MOV     A, M            ; 7E       -> Aktuellen Index-Wert laden
        CPI     00Ah            ; FE 0A    -> Prüfen, ob die Obergrenze von 10 Elementen erreicht ist
        JNC     L_02BE          ; D2 BE 02 -> Wenn der Index >= 10 ist, direkt vor zu 02BEh springen
        INR     M               ; 34       -> Ansonsten den Index im RAM [HL] um 1 erhöhen
        ADI     020h            ; C6 20    -> Offset 20h zum Akkumulator addieren
        MOV     L, A            ; 6F       -> Berechneten Offset nach Register L übertragen
        MOV     M, B            ; 70       -> Das originale Zeichen aus B an die berechnete RAM-Adresse schreiben
L_BUFF_OVERFLOW:
L_02BE:
        LDA     REG_EOS_FLAG    ; 3A 0F 04 -> Empfangenes Datenbyte aus RAM 040Fh holen
        ANI     0C0h            ; E6 C0    -> Die obersten zwei Bits maskieren
        CPI     040h            ; FE 40    -> Prüfen auf das End-Of-Sequence / EOI Flag (40h)
        JNZ     L_02A5          ; C2 A5 02 -> Sprung wenn != 0

; ------------------------------------------------------------------------------
; Handler for characters received via GPIB bus for  0D/CR, LF/0A, comma/2C
; which are considered 'special' by ICS4883 (i.e. these are separators)
; ------------------------------------------------------------------------------
; ------------------------------------------------------------------------------
; Nibble-Packing Routine: Der Code ab Adresse 02DBh ist ein hocheffizienter Packer. Er nimmt
; zwei aufeinanderfolgende Bytes, isoliert jeweils deren untere 4 Bits (ANI 00Fh), schiebt das zweite Nibble
; per Rotation nach oben (RLC) und fügt sie mit ORA B zu einem einzigen, kompakten Daten-Byte zusammen.
; SRAM-Transfer: Diese gepackten Daten werden sequenziell direkt in den System-SRAM ab Adresse STACK_BASE
; übertragen (STAX D).
; ------------------------------------------------------------------------------
L_02C8:
        LXI     H, REG_BUFF_IDX ; 21 1F 04 -> set HL to RAM address 041Fh (counter value)
        MOV     C, M            ; 4E       -> load counter value to C
        MOV     A, M            ; 7E       -> load also to A
        ORA     A               ; B7       -> is counter zero?
        JZ      L_MAINLOOP      ; CA 17 00 -> if counter==0, jump back to main polling loop
        MVI     M, 00h          ; 36 00    -> if counter>0, set M to 0
        PUSH    B               ; C5       -> push B to stack
        CALL    0311h           ; CD 11 03 -> Depending on bit 3 in 0505h, C bytes in memory at HL are inverted or not (L_CHECK_INVERT)
        POP     B               ; C1       -> restore BC
        LXI     D, STACK_BASE   ; 11 00 05 -> DE points to STACK_BASE
L_PACK_LOOP:
L_02DB:
        INX     H               ; 23       -> inc HL
        MOV     A, M            ; 7E       -> read byte from [HL]
        ANI     00Fh            ; E6 0F    -> mask lower nibble
        MOV     B, A            ; 47       -> save in B
        DCR     C               ; 0D       -> dec loop count
        JM      L_02F3          ; FA F3 02 -> if <0 continue at L_02F3
        INX     H               ; 23       -> inc HL
        MOV     A, M            ; 7E       -> read byte from [HL]
        ANI     00Fh            ; E6 0F    -> mask lower nibble
        RLC                     ; 07       -> rotate (4 times) left
        RLC                     ; 07
        RLC                     ; 07
        RLC                     ; 07       ; ... now (lower) nibble is in upper nibble
        ORA     B               ; B0       -> add nibble saved before to have complete byte with two nibbles
        DCR     C               ; 0D       -> dec loop count
        STAX    D               ; 12       -> write completed byte to target address in RAM [DE]
        INX     D               ; 13       -> inc target address pointer
        JNZ     L_02DB          ; C2 DB 02 -> if loop count is larger 0, repeat loop
L_PACK_DONE:
L_02F3:
        LXI     H, RAM_HW_CONFIG2 ; 21 06 05 -> HL points to 0506h
        LDA     ROM_CFG_FLAGS   ; 3A C4 03 -> load [03C4h] into A
L_02F9:
        MOV     B, A            ; 47       -> save A in B
        XRI     03h             ; EE 03    -> mask A with 0000.0011
        MOV     M, A            ; 77       -> write new A to memory mapped register [0506h]
        PUSH    H               ; E5       -> is this a timing op?
        PUSH    H               ; E5       ->
        POP     H               ; E1       ->
        POP     H               ; E1       ->
        MOV     M, B            ; 70        -> A value, that was saved in B, back to M (so first masked A, then A is written to M, which looks like a strobe signal is generated)
        JMP     L_MAINLOOP      ; C3 17 00 -> back to main polling loop
; ------------------------------------------------------------------------------
; line above is end of boot code; everything else is done in main polling loop L_MAINLOOP
; ------------------------------------------------------------------------------

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
        LXI     H, SEPARATOR_JUMP_TABLE ; 21 F5 03 -> HL points to table GPIB_CMD_JUMPTABLE
        CALL    L_FIND_HANDLER_ADDRESS ; CD 4E 01 -> find handler for separator
        PCHL                    ; E9       -> execute separator

; depending on a flag value (bit 3 from address 0505h), a block in memory is inverted or not.
; number of bytes to invert controlled by value in C, start address in HL.
; if bit is set, inversion takes place.
; called from 02D4h
L_CHECK_INVERT:
L_0311:
        LDA     RAM_HW_CONFIG1  ; 3A 05 05 -> load 0505h to A
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
        LDA     REG_CMD_LOCK    ; 3A 0C 04 -> Lädt den Inhalt der RAM-Adresse 040Ch in den Akkumulator
        ORA     A               ; B7       -> Setzt die Flags (Zero/Sign) basierend auf dem Akkumulator
        JZ      L_MAINLOOP      ; CA 17 00 -> Wenn der Wert Null ist, Sprung zurück zum Haupt-Polling L_MAINLOOP
        MOV     A, B            ; 78       -> Holt den Wert aus Register B zurück nach A
        CPI     070h            ; FE 70    -> Prüfen, ob das Zeichen im Akkumulator 70h entspricht (70h = 'p')
    	JZ      L_036D          ; CA 6D 03 -> Wenn ja, Sprung nach vorne zu Adresse 036Dh
        STA     REG_IO_STATE    ; 32 01 04 -> Speichert den Akkumulator in RAM-Adresse REG_IO_STATE
        ANI     007h            ; E6 07    -> Maskiert die unteren 3 Bits (Bit 0-2) des Akkumulators
        MOV     C, A            ; 4F       -> Das maskierte Ergebnis nach Register C retten
        MOV     A, B            ; 78       -> Holt das originale Zeichen aus Register B zurück nach A
        ANI     008h            ; E6 08    -> Bit 3 des Akkumulators isolieren
        LDA     REG_SYS_STATUS  ; 3A 07 04 -> Systemstatus aus RAM 0407h laden
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
        STA     REG_PENDING_CMD ; 32 0B 04 -> Akkumulator in RAM-Zelle 040Bh sichern
        LXI     H, REG_SYS_STATUS ; 21 07 04 -> HL auf RAM-Adresse 0407h ausrichten
        MOV     A, M            ; 7E       -> Wert laden
        ORI     008h            ; F6 08    -> Bit 3 gezielt setzen
        MOV     M, A            ; 77       -> Aktualisierten Wert zurückschreiben
; 0704h, 0703h are set to 0.
; value of [040B] REG_PENDING_CMD is written to 0702h IO_TALK_CTRLBUS
; value of [0407] REG_SYS_STATUS is written to 0707h
L_0355:
        LXI     H, IO_TALK_CTRL ; 21 04 07 -> HL points to 0704h (GPIB connector related)
        MVI     M, 00h          ; 36 00    -> clear [0704h]
        LXI     H, IO_TALK_CTRLBUS ; 21 02 07 -> HL points to 0702h
        LDA     REG_PENDING_CMD ; 3A 0B 04 -> load content of RAM 040Bh to A
        MOV     M, A            ; 77       -> copy A to [0702h]
        INX     H               ; 23       -> inc HL (now 0703h)
        MVI     M, 00h          ; 36 00    -> clear [0703h]
        MVI     L, 07h          ; 2E 07    -> set lower byte of HL to 07h (HL now is 0707h)
        LDA     REG_SYS_STATUS  ; 3A 07 04 -> load content of RAM 0407h to A
        MOV     M, A            ; 77       -> copy A to [0707h]
        JMP     L_001F          ; C3 1F 00 -> continue at L_001F inside main polling loop

; ------------------------------------------------------------------------------
; Handler for GPIB command 15h - LLO Local Lockout
; prevents local control; control is only possible via remote (GPIB commands)
; bit 3 of 0407 seems to represent "LOCAL_ENABLED"
; ------------------------------------------------------------------------------
L_036D:
        XRA     A               ; AF       -> A:=0
        STA     REG_IO_STATE    ; 32 01 04 -> writes A i.e. 0 to REG_IO_STATE 0401
        LXI     H, REG_SYS_STATUS ; 21 07 04 -> HL points to 0407h
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
        LDA     REG_SYS_STATUS  ; 3A 07 04 -> load status byte from RAM 0407h
        ANI     002h            ; E6 02    -> isolate bit 1
        JZ      L_MAINLOOP      ; CA 17 00 -> if bit 1==0, continue in L_MAINLOOP (nothing to do it seems)
        MOV     A, B            ; 78       -> copy B to A (B seems to contain command character 05h)
        STA     REG_CMD_LOCK    ; 32 0C 04 -> write A to 040Ch
        JMP     L_MAINLOOP      ; C3 17 00 -> start over in mainloop

; 038Ah - 038Fh: Padding / Unused ROM-Space (Füllbytes)
    	DB 0FFh	; 0FFh, from address 38ah
    	DB 0FFh	; 0FFh, from address 38bh
    	DB 0FFh	; 0FFh, from address 38ch
    	DB 0FFh	; 0FFh, from address 38dh
    	DB 0FFh	; 0FFh, from address 38eh
    	DB 0FFh	; 0FFh, from address 38fh

; 0390h: Einzelne Kontroll-Konstanten für Vergleiche
    	DB 000h	; 000h, from address 390h
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
        DB 00Bh, 01Fh, 004h, 00Ah
        DB 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h, 000h

 ; [length 01h] [target address 0506h] . data is below at 03C4h [06h]
        DB 001h, 006h, 005h

; 03C4h - 03CDh: system config values
; 6,2,6,6,2,0,6,2,7,0
    	DB 006h, 002h, 006h, 006h, 002h, 000h, 006h, 002h, 007h, 000h

; 03CEh - 03D3h: Maskierungs- und Fehler-Grenzwerte
    	DB 000h, 080h, 000h, 000h, 000h, 000h

; 03D4h - 03E3h: IEEE-488 Bus ASCII-Übersetzungstabelle
TALK_CHAR_TABLE:
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
        DB 00Dh, L_02C8 & 0FFh, L_02C8 >> 8 ; 0Dh (CR)     -> jump to L_02C8 (Haupt-Init)
        DB 00Ah, L_02C8 & 0FFh, L_02C8 >> 8 ; 0Ah (LF)     -> jump to L_02C8 (Haupt-Init)
        DB 02Ch, L_02C8 & 0FFh, L_02C8 >> 8 ; 2Ch (Komma)  -> jump to L_02C8 (Haupt-Init)
        DB L_02A5 & 0FFh, L_02A5 >> 8       ; Default      -> jump to L_02A5