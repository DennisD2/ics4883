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

; ==============================================================================
; 0000 - 03FF : ROM constants and table addresses
; ==============================================================================
ROM_DATA_START   EQU  038Ah     ; Startbereich der Datentabellen im ROM
ROM_CONST_CMP    EQU  0390h     ; Kontroll-Konstanten für den Zeichenvergleich
ROM_TAB_DISPATCH EQU  0393h     ; Sprung- und Befehlstabelle für den Data Dispatcher
ROM_TAB_SRAM_INI EQU  03B3h     ; Initialisierungs-Tabelle für den RAM-Puffer
ROM_CFG_FLAGS    EQU  03C4h     ; System-Konfigurations-Flags im ROM
ROM_CFG_LIMITS   EQU  03CEh     ; Maskierungs- und Fehler-Grenzwerte
ROM_TAB_ASCII    EQU  03D4h     ; IEEE-488 Bus ASCII-Übersetzungstabelle ('0123...')
ROM_PROT_LIMITS  EQU  03E4h     ; Status- und Protokoll-Grenzwerte
ROM_STR_TERMS    EQU  03EEh     ; String-Terminatoren und Kontroll-Codes (CR/LF)
ROM_TAB_CMD_VEC  EQU  03F5h     ; Primäre Befehls-Sprungtabelle (für CR, LF, Komma)

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
REG_CMD_STATE  EQU  040Dh       ; Befehls-Statusregister (Steuerflag für Modus/Fehler)
REG_BUS_STATUS EQU  040Eh       ; Bus-Zustandsregister (z. B. Talker/Listener)
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
IO_GPIB_CTRL_1  EQU  0605h       ; DIP-Schalter für Bus-Adresse & Modus (Hardware-Eingabe)
IO_SRAM_FLAG1  EQU  0607h       ; Status-Flag im I/O-SRAM (Eingangs-Bestätigung)

; ==============================================================================
; 0700 - 07FF : HARDWARE-MAPPED I/O REGISTERS (Eingabe & Ausgabe)
; GPIB connector control (no special chip used, just 74xx chips)
; ==============================================================================
IO_TALK_STATUS EQU  0701h       ; Status des Talker-Interfaces (Eingang/Ausgang)
IO_TALK_CTRLBUS  EQU  0702h       ; Synchronisationsregister 02h für Talker-Schnittstelle
IO_TALK_DATABUS  EQU  0703h       ; Synchronisationsregister 03h für Talker-Schnittstelle
IO_TALK_CTRL   EQU  0704h       ; Kontrollregister für IEEE-488 Buschip
IO_TALK_DATA   EQU  0705h       ; Datenpuffer-Register des Talker-Interfaces
IO_DIP_SWITCH  EQU  0706h       ; DIP Switch byte
IO_HW_OUTPUT   EQU  0707h       ; Zentrales Hardware-Ausgangsregister (z. B. LEDs/Latch)

; ---------------------------------------------------------------------
; 0000h - 0016h: boot vector and initialization
; ---------------------------------------------------------------------
L_0000:
        LXI     SP, STACK_BASE  ; 31 00 05 -> set stack pointer
        CALL    L_008F          ; CD 8F 00 -> clear 64 bytes of memory from start of RAM
L_0006:
        LDA     ROM_CFG_FLAGS   ; 3A C4 03 -> read config value from ROM 03C4 (value there is: 6=0110)
        XRI     0Ch             ; EE 0C    -> XOR with C=1100 (result: 1010)
        STA     RAM_HW_CONFIG2  ; 32 06 05 -> put result to RAM 0506
        LXI     H, ROM_TAB_SRAM_INI ; 21 B3 03 -> put pointer to ROM table to H
        CALL    L_007B          ; CD 7B 00 -> copy ROM tables to RAM/memory mapped regs
        JMP     L_02C8          ; C3 C8 02 -> Further init code; at its end, main IO polling loop L_0017 is jumped to.

; ------------------------------------------------------------------------------
; main IO polling loop
; ------------------------------------------------------------------------------
L_0017:
        DI                      ; F3
        LDA     REG_IO_STATE    ; 3A 01 04 -> load 0401h from RAM to A - Status von GPIB / I/O Interface-Chip laden
        ORA     A               ; B7       -> is it = 0 ?
        JNZ     L_0355          ; C2 55 03 -> if no, then handle state change in L_0355

L_001F:
        LDA     IO_TALK_STATUS  ; 3A 01 07 -> Status des Talker-Interfaces einlesen
        ANI     0C0h            ; E6 C0    -> Die obersten zwei Bits maskieren
        CPI     80h             ; FE 80    -> Prüfen auf Status-Flag 80h
        JZ      L_00CE          ; CA CE 00 -> Bei Treffer -> Abzweigen zur Routine L_00CE

        CALL    L_00AD          ; CD AD 00 -> Ruft Subroutine an Adresse 00ADh auf
        MVI     C, 0FEh         ; 0E FE    -> Lädt Konstante 0FEh in Register C
        CALL    L_00A1          ; CD A1 00 -> Ruft Subroutine an Adresse 00A1h auf
        LDA     IO_DIP_SWITCH   ; 3A 06 07 -> Lädt 0706h in A
        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        JMP     L_003C          ; C3 3C 00 -> Unbedingter Sprung zur Routine 003Ch
        POP     H               ; E1       -> Registerpaar HL vom Stack holen (Stack aufräumen)
        JMP     L_00CE          ; C3 CE 00 -> Sprung zur Service-Routine L_00CE

L_003C:
        CC      L_009C          ; DC 9C 00 -> Bedingter Unterprogramm-Aufruf, wenn Carry-Flag = 1
        LXI     H, REG_SYS_STATUS  ; 21 07 04 -> Register HL mit Adresse 0407h laden
    	MOV     A,M             ; 7E
    	RRC                     ; 0F
    	RRC                     ; 0F
        JC      L_029D          ; DA 9D 02 -> Wenn Carry=1, springe zu Adresse 029Dh
        RRC                     ; 0F       -> Akkumulator nach rechts rotieren
        JC      L_01AD          ; DA AD 01 -> Wenn Carry=1, springe zu Adresse 01ADh
        LXI     B,01000h        ; 01 00 10 -> lade 01000h in B
        LDA     IO_GPIB_CTRL_1   ; 3A 05 06 -> Holt das Daten-Byte vom I/O-Schnittstellenregister
    	CMA                     ; 2F       -> Akkumulator invertieren (Low-Aktive Signale)
    	RRC                     ; 0F       -> Bit nach rechts rotieren
    	JNC     L_0060          ; D2 60 00 -> Wenn kein Carry, springe vor zu Adresse 0060h
    	CALL    L_00C7          ; CD C7 00 -> Unterfunktion an Adresse 00C7h ausf
        JC      L_006D          ; DA 6D 00 -> Wenn Carry=1, springe zu Adresse 006Dh
        STA     IO_SRAM_FLAG1   ; 32 07 06 -> Berechneten Zustand im RAM 0607h sichern
L_0060:
    	LXI     H, REG_SYS_STATE  ; 21 03 04 -> HL points to 0403h
    	MOV     A,M             ; 7E       -> load [0403h] to A
    	ANA     B               ; A0       -> AND A with B
    	ORA     C               ; B1       -> OR A with C
    	MOV     M,A             ; 77       -> move A to [0403h]
    	STA     IO_TALK_DATABUS ; 32 03 07 -> write result to 0703h (GPIB connector)
    	JMP     L_0017          ; C3 17 00 -> back to loop start

; ------------------------------------------------------------------------------
; Ausgelagerter Talker-Status-Handler (Deine Zeilen 68-74)
; ------------------------------------------------------------------------------
L_006D:
        LXI     H, REG_BUS_STATUS        ; 21 0E 04 -> HL auf Register 040Eh (GPIB/Bus-Steuerung) ausrichten
        MOV     A, M            ; 7E       -> Status-Byte aus 040Eh in den Akkumulator laden
        RRC                     ; 0F       -> Nach rechts rotieren (Bit-Prüfung)
        JC      L_0060          ; DA 60 00 -> Wenn Carry=1, springe vor zu Adresse 0060h
        MVI     M, 41h          ; 36 41    -> Schreibe den Wert 41h (ASCII 'A') nach 040Eh
        MOV     C, B            ; 48       -> Kopiere Register B nach C
        JMP     L_0060          ; C3 60 00 -> Unbedingter Sprung vor zu Adresse 0060h

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
; RAM-Initialisierung / Block-Clear Routine (Deine Zeilen 79-101)
; Aufgerufen via CALL 008Fh im Boot-Vektor
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
; Bit-Manipulation & I/O-Schnittstellen-Ausgabe (Zeile 119 bis 133)
; ------------------------------------------------------------------------------
L_009C:
        RLC                     ; 07       -> shift 3 bits left
        RLC                     ; 07       -> "
        RLC                     ; 07       -> "
L_009F:
    	MVI     C, 0F9h         ; 0E F9    -> loads mask value 0F9h (mask 11111001b) into C
;
; L_00A1 writes value from 0407 to 0707. It applies a mask value in C
;
L_00A1:
        LXI     H, REG_SYS_STATUS ; 21 07 04 -> HL points to 0407h
        MOV     B, A            ; 47       -> copy A to B
        MOV     A, M            ; 7E       -> load [HL] (0407h) into A
        ANA     C               ; A1       -> AND with C (apply mask)
        ORA     B               ; B0       -> OR with B (Bits zusammenführen) (B contains A unchanged...)
        MOV     M, A            ; 77       -> write result to [HL] (0407h)
        MVI     H, 07h          ; 26 07    -> set H of HL to 07h (HL points now to 0707h)
        MOV     M, A            ; 77       -> write A to 0707h
        RET                     ; C9       -> back to caller

L_00AD:
        LXI     H, 0391h        ; 21 91 03 -> HL-Zeiger auf ROM-Tabelle/String 0391h ausrichten
    	LDA     IO_GPIB_CTRL_1   ; 3A 05 06 -> Holt das aktuelle I/O-Datenbyte vom Talker
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
    	LDA     IO_TALK_DATA    ; 3A 07 05 -> Statuswert aus dem SRAM-Bereich laden
        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        RLC                     ; 07       -> Nochmals nach links rotieren
        RLC                     ; 07       -> Ein drittes Mal nach links rotieren
    	RET                     ; C9       -> Unterprogramm beenden (Rücksprung)

; ------------------------------------------------------------------------------
; Status-Reset & Polling-Handler (Adresse 00CEh - 00E0h)
; ------------------------------------------------------------------------------
L_00CE:
        MVI     A, 80h          ; 3E 80    -> Lade Status-Flag 80h in den Akkumulator
        STA     REG_GPIB_CTRL   ; 32 05 04 -> Schreibe das Flag in das GPIB-Schnittstellenregister
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
        STA     IO_TALK_CTRLBUS   ; 32 02 07 -> Lösche das Statusregister 0702h im Talker-Interface
        CALL    L_0163          ; CD 63 01 -> Ruft Unterfunktion an Adresse 0163h auf
        LDA     IO_DIP_SWITCH   ; 3A 06 07 -> Lädt 0607h nach A
        RLC                     ; 07       -> Akkumulator nach links rotieren (Bit-Prüfung)
        JC      L_0017          ; DA 17 00 -> Wenn Carry=1, springe hart zurück zum Schleifenstart L_0017
        ; ------------------------------------------------------------------------------
        ; ASCII-Validierung & Protokoll-Verzweigung (Adresse 00E1h - 00F6h)
        ; ------------------------------------------------------------------------------
        MOV     A, B            ; 78       -> Holt das gesicherte Byte aus Register B in den Akkumulator
        ANI     07Fh            ; E6 7F    -> Auf 7-Bit-ASCII maskieren
        MOV     B,A             ; 47       -> In Register B sichern
        ANI     060h            ; E6 60    -> Prüfe die oberen Kontrollbits des Zeichens
        CPI     060h            ; FE 60    -> Vergleiche mit dem Kontrollwert 60h
        JZ      L_00F7          ; CA F7 00 -> Wenn gleich, springe vor zur Service-Routine 00F7h
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
        STA     REG_CMD_LOCK    ; 32 0C 04 -> Schreibt die Null in das Kontrollregister 040Ch
        MOV     A, B            ; 78       -> Holt das originale Zeichen erneut aus Register B
        ANI     060h            ; E6 60    -> Erneute Bitmaskierung
        JNZ     L_00F7          ; C2 F7 00 -> Wenn ungleich Null, springe vor zur Service-Routine 00F7h
        MOV     A, B            ; 78       -> Holt das Zeichen ein letztes Mal

        ; ------------------------------------------------------------------------------
        ; Indirekte Sprungsteuerung & indir. Funktionsaufrufe (Adresse 00F7h - 0010Dh)
        ; ------------------------------------------------------------------------------
L_00F7:
        LXI     H, ROM_TAB_DISPATCH        ; 21 93 03 -> HL-Zeiger auf Adresse 0393h im ROM ausrichten
        MVI     C, 0Ah          ; 0E 0A    -> Schleifenzähler C auf 10 setzen
        CALL    L_014E          ; CD 4E 01 -> Unterprogramm an Adresse 014Eh aufrufen
        PCHL                    ; E9       -> Indirekter Sprung: Kopiert HL in den Program Counter!
        CALL    L_0131          ; CD 31 01 -> Unterprogramm an Adresse 0131h aufrufen
        MVI     A, 02h          ; 3E 02    -> Konstante 02h in den Akkumulator laden
        JNZ     L_010E          ; C2 0E 01 -> Wenn ungleich Null, springe vor zu Adresse 010Eh
L_0108:
        CALL    L_009F          ; CD 9F 00 -> Unterprogramm an Adresse 009Fh aufrufen
        JMP     L_0017          ; C3 17 00 -> Unbedingter Rücksprung zum Schleifenstart L_0017

        ; ------------------------------------------------------------------------------
        ; GPIB-Protokollprüfung (? Abfrage) & Bus-Handshake (Adresse 010Eh - 0130h)
        ; ------------------------------------------------------------------------------
L_010E:
        MOV     A, B            ; 78       -> copy B to A
        CPI     03Fh            ; FE 3F    -> compare A with ASCII '?' (GPIB Talker Query)
        JNZ     L_0017          ; C2 17 00 -> if not an '?', jump to main polling loop L_0017
    	XRA     A               ; AF       -> XOR A mit A <=> A:=0
    	STA     REG_BUFF_IDX    ; 32 1F 04 -> write 0 to 041F
    	MVI     C, 0FDh         ; 0E FD    -> loads 0FDh into C (output mask?)
    	CALL    L_00A1          ; CD A1 00 -> Ruft die I/O-Ausgabestufe auf (Zeichen auf den Bus senden)
        JMP     L_0017          ; C3 17 00 -> Unbedingter Rücksprung zu L_0017
        CALL    L_0131          ; CD 31 01 -> Unterfunktion an Adresse 0131h aufrufen
        MVI     A, 04h          ; 3E 04    -> Konstante 04h in den Akkumulator laden
        JZ      L_0108          ; CA 08 01 -> Wenn Zero-Flag gesetzt, springe zu Adresse 0104h
        MVI     C, 0FBh         ; 0E FB    -> Lädt die nächste Steuermaske 0FBh in Register C
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
        CALL    L_00A1          ; CD A1 00 -> Ruft die I/O-Ausgabestufe auf
    	JMP     L_0017          ; C3 17 00  from address 12eh

; Comparison if GPIB address just received with address set at dip switch
L_GPIB_ADRESS_CMP:
L_0131:
    	LDA     IO_DIP_SWITCH   ; 3A 06 07 -> loads 0706h into A
    	ANI     01Fh            ; E6       -> mask with 1F, so lower 5 bits (GPIB address)
        MOV     C, A            ; 4F       -> save in C
    	MOV     A,B             ; 78       -> load B to A
    	ANI     01Fh            ; E6       -> mask with 1F, lower 5 bits
        CMP     C               ; B9       -> A=C ?
        RET                     ; C9       -> result of comparison is in status, return to caller

        ; ------------------------------------------------------------------------------
        ; Talker-Statusprüfung & Bitmaskierungs-Unterprogramm (Adresse 013Ch - 014Fh)
        ; ------------------------------------------------------------------------------
L_013C:
    	LDA     REG_SYS_STATUS  ; 3A 07 04 from address 13ch
    	ANI     02h             ; E6 02 from address 13fh
    	JZ      L_0017          ; CA 17 00 from address 141h
    	JMP     L_0006          ; C3 06 00 from address 144h
    	XRA     A               ; AF from address 147h
    	STA     REG_CMD_STATE   ; 32 from address 148h
    	JMP     L_0017          ; C3 17 00

L_014E:
        ; ------------------------------------------------------------------------------
        ; Tabellen-Suchschleife & Register-Sicherung (Adresse 014Eh - 0162h)
        ; ------------------------------------------------------------------------------
        PUSH    D               ; D5       -> Sichert das Registerpaar DE auf dem Stack
        LXI     D, 0003h        ; 11 03 00 -> Lädt Konstante 0003h in das Registerpaar DE
L_0152:
        CMP     M               ; BE       -> Vergleiche Akkumulator mit dem Speicher [HL]
        JZ      L_015C          ; CA 5C 01 -> Wenn gleich (Zero=1), springe vor zu Adresse 015Ch
        DAD     D               ; 19       -> Addiere Registerpaar DE zu HL (HL = HL + DE)
        DCR     C               ; 0D       -> Schleifenzähler C um 1 verringern
        JNZ     L_0152          ; C2 52 01 -> Wenn C noch nicht Null ist, zurück zur Schleife springe
        DCX     H               ; 2B       -> Verringere Registerpaar HL um 1
L_015C:
        INX     H               ; 23       -> Erhöhe Registerpaar HL um 1
        MOV     E, M            ; 5E       -> Lädt das untere Byte der Zieladresse nach E
        INX     H               ; 23       -> Erhöhe Registerpaar HL um 1
        MOV     D, M            ; 56       -> Lädt das obere Byte der Zieladresse nach D
        XCHG                    ; EB       -> Tausche die Registerpaare HL und DE
        POP     D               ; D1       -> Holt das gesicherte Registerpaar DE vom Stack zurück
        RET                     ; C9       -> Unterprogramm beenden (Rücksprung zum Aufrufer)

        ; ------------------------------------------------------------------------------
        ; Schnittstellen- & Pufferverwaltungsroutine (Adresse 0163h - 01A8h)
        ; ------------------------------------------------------------------------------
L_0163:
        LDA     REG_SYS_STATE   ; 3A 03 04 -> Lädt Zustand aus RAM-Zelle 0403h
        ANI     10h             ; E6 10    -> Bit 4 maskieren
        MOV     C, A            ; 4F       -> In Register C zwischenspeichern
        LXI     D, IO_TALK_DATABUS        ; 11 03 07 -> Richtet DE auf physische Hardwareadresse 0703h aus
        MVI     A, 04h          ; 3E 04    -> Lädt Konstante 04h in den Akkumulator
        ORA     C               ; B1       -> Logisches ODER mit Register C verknüpfen
        STAX    D               ; 12       -> Akkumulator an Hardwareadresse [DE] ausgeben
        MVI     A, 80h          ; 3E 80    -> Status-Flag 80h in den Akkumulator laden
        STA     IO_TALK_CTRL    ; 32 04 07 -> Zustand direkt im I/O-Register 0704h sichern
        LXI     H, IO_TALK_STATUS        ; 21 01 07 -> Richtet HL auf das I/O-Statusregister 0701h aus
L_0178:
        LDA     REG_GPIB_CTRL   ; 3A 05 04 -> Lädt Kontrollwert aus RAM 0405h
    	XRA     M               ; AE from address 17bh
    	JM      L_01A9          ; FA A9 01 -> Wenn negativ (Sign-Flag=1), springe vor zu 0191h
        MOV     A, M            ; 7E       -> Byte direkt aus der Hardware [HL] laden
        ANI     01h             ; E6 01    -> Bit 0 maskieren
        JZ      L_0178          ; CA 78 01 -> Wenn Null, springe zurück zu Adresse 0178h (Schleife!)
        LDA     REG_GPIB_CTRL   ; 3A 05 04 -> Erneut RAM-Wert 0405h laden
    	XRA     M               ; AE from address 188h
    	JM      L_01A9          ; FA A9 01 -> Wenn negativ, springe vor zu Adresse 01A9h
        MVI     A, 06h          ; 3E 06    -> Konstante 06h laden
        ORA     C               ; B1       -> Logisches ODER mit Register C
        STAX    D               ; 12       -> An Hardware [DE] ausgeben
        MOV     A, M            ; 7E       -> Byte aus Hardware [HL] holen
        STA     REG_EOS_FLAG    ; 32 0F 04 -> Empfangenes Datenbyte im RAM 040Fh sichern
        DCX     H               ; 2B       -> Adresszeiger HL um 1 verringern (zeigt nun auf 0700h)
        MOV     B, M            ; 46       -> Byte aus Hardware [HL] (0700h) nach Register B laden
        INX     H               ; 23       -> Adresszeiger HL wieder um 1 erhöhen (zurück auf 0701h)
        MVI     A, 02h          ; 3E 02    -> Konstante 02h laden
        ORA     C               ; B1       -> Logisches ODER mit Register C
        STAX    D               ; 12       -> An Hardware [DE] ausgeben
L_019B:
        MOV     A, M            ; 7E       -> Status erneut aus Hardware [HL] lesen
        ANI     01h             ; E6 01    -> Bit 0 maskieren
        JNZ     L_019B          ; C2 9B 01 -> Wenn ungleich Null, springe vor zu Adresse 019Bh
        MVI     A, 06h          ; 3E 06    -> Konstante 06h laden
        ORA     C               ; B1       -> Logisches ODER mit Register C
        STAX    D               ; 12       -> An Hardware [DE] ausgeben
        STA     REG_SYS_STATE   ; 32 03 04 -> Finalen Zustand in RAM-Zelle 0403h zurückschreiben
        RET                     ; C9       -> Unterprogramm sauber beenden (Rücksprung)

L_01A9:
        ; ------------------------------------------------------------------------------
        ; Stack aufräumen & Treiber-Rücksprung (Adresse 01A9h - 01ACh)
        ; ------------------------------------------------------------------------------
        POP     H               ; E1       -> Holt das Registerpaar HL vom Stack zurück
        JMP     L_0017          ; C3 17 00 -> Unbedingter Sprung zur Systemadresse 00FBh

L_01AD:
    	EI                      ; FB from address 1adh
    	LDA     REG_CMD_STATE   ; 3A 0D 04 -> Lädt Kontroll-Flag aus RAM-Zelle
    	ORA     A               ; B7       -> Prüft, ob der Wert im Akkumulator Null ist
    	JNZ     L_0232          ; C2 32 02 -> Wenn ungleich Null, springe weit vor zu Adresse 0232h
        LXI     H, IO_GPIB_CTRL_1        ; 21 05 06 -> HL-Zeiger auf I/O-Datenregister 0605h ausrichten
L_01B8:
        MOV     A, M            ; 7E       -> Holt das aktuelle Datenbyte via HL
    	RRC                     ; 0F from address 1b9h
        JC      L_01B8          ; DA B8 01 -> Wenn Carry=1, springe zu Adresse 01B8h
        DI                      ; F3       -> Interrupts sperren (Disable Interrupts)
        LXI     D, RAM_ASCII_BUFF        ; 11 30 04 -> Registerpaar DE mit SRAM-Adresse 0430h laden
        LXI     H, IO_HW_INPUT  ; 21 04 06 -> HL-Zeiger auf I/O-Schnittstellenregister 0604h ausrichten DD: h := 0x0604 = start address of bytes read from input (5 bytes containing 10 nibbles)
    	CALL    L_0242          ; CD 42 02 -> Ruft Unterfunktion an Adresse 0242h auf DD: konvertiert 5 inpt bytes
    	MVI     A, 0Fh          ; 3E 0F    -> Lädt die Konstante 0Fh in den Akkumulator
        ; ------------------------------------------------------------------------------
        ; SRAM-Puffer-Verwaltung & Bitmaskierung (Adresse 01C9h - 01F5h)
        ; ------------------------------------------------------------------------------
        STA     SRAM_START      ; 32 00 04 -> Akkumulator-Inhalt direkt in RAM SRAM_START sichern
        EI                      ; FB       -> Interrupts wieder freigeben (Enable Interrupts)
        LXI     H, RAM_ASCII_BUFF        ; 21 30 04 -> HL-Zeiger auf SRAM-Adresse 0430h laden DD: h := address of created 10 bytes
        SHLD    REG_ARRAY_PTR   ; 22 2E 04 -> Speicherinhalt von HL nach SRAM 042Eh sichern
        LXI     H, ROM_PROT_LIMITS        ; 21 E4 03 -> HL-Zeiger auf Übersetzungstabelle im ROM ausrichten
L_01D6:
        MOV     A, M            ; 7E       -> Byte via HL laden
        INX     H               ; 23       -> HL-Zeiger um 1 erhöhen
        SHLD    REG_BUFF_PTR    ; 22 1D 04 -> Aktuellen HL-Zeiger im RAM 041Dh sichern
        CPI     19h             ; FE 19    -> Akkumulator mit Konstante 19h vergleichen

        JZ      L_0017          ; CA 17 00 -> Wenn gleich, springe weit zurück zu Adresse 0017h
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
        LDA     REG_SYS_STATE   ; 3A 03 04 -> Zustand aus RAM-Zelle 0403h holen
        ANI     10h             ; E6 10    -> Bit 4 maskieren
        MOV     C, A            ; 4F       -> Vorheriges Ergebnis nach Register C retten
        LXI     D,IO_TALK_DATABUS         ; 11 03 07 -> Lädt Byte von der Hardware-Adresse [DE] (0703h)
        STAX    D               ; 12           -> Schreibt den Akkumulator wieder zurück nach [DE]
        LXI     H, IO_TALK_CTRLBUS       ; 21 02 07 -> HL auf Adresse 0702h ausrichten
        MOV     M,B             ; 70
        DCX     H               ; 2B       -> HL um 1 verringern (zeigt nun auf 0701h)
L_0200:
        MOV     A, M            ; 7E       -> Status-Byte aus 0701h einlesen
        RRC                     ; 0F       -> Nach rechts rotieren
        RRC                     ; 0F       -> Nochmals nach rechts rotieren
        JC      L_0200          ; DA 00 02 -> Wenn Carry=1, Fehler/Abzweig zu L_0002
        MVI     A, 01h          ; 3E 01    -> Konstante 01h laden
        ORA     C               ; B1       -> Mit Maske in Register C verknüpfen
        STAX    D               ; 12       -> An Hardware ausgeben
L_020A:
        MOV     A, M            ; 7E       -> Erneut Status lesen
        RRC                     ; 0F
        RRC                     ; 0F
        RRC                     ; 0F
        JC      L_020A          ; DA 0A 02 -> Wenn Carry=1, Sprung zu RAM/ROM-Adresse 020Ah
        DI                      ; F3       -> Interrupts sperren
        XRA     A               ; AF       -> Akkumulator nullen
        STAX    D               ; 12
        STA     REG_SYS_STATE   ; 32 03 04 -> Systemzustand in RAM 0403h löschen
        LXI     H, SRAM_START   ; 21 00 04 -> HL auf RAM-Start SRAM_START setzen
        MOV     A, M            ; 7E
        MVI     M, 00h          ; 36 00    -> Speicherzelle mit 00h überschreiben
        ORA     A               ; B7       -> Flags aktualisieren
        JM      L_0017          ; FA 17 00 -> Wenn negativ (Bit 7=1), Sprung zu L_0017
        JZ      L_022B          ; CA 2B 02 -> Wenn Null, Sprung zu RAM/ROM-Adresse 022Bh
        XRA     A               ; AF
        STA     IO_SRAM_FLAG1   ; 32 07 06
        STA     REG_BUS_STATUS  ; 32 0E 04
L_022B:
        EI                      ; FB       -> Interrupts wieder freigeben
        LHLD    REG_BUFF_PTR    ; 2A 1D 04
        JMP     L_01D6          ; C3 D6 01 -> Sprung zu RAM/ROM-Adresse 01D6h
L_0232:
        MVI     A, 0FFh         ; 3E FF
        STA     SRAM_START      ; 32 00 04
        LXI     H, REG_BUS_STATUS        ; 21 0E 04 -> HL auf Kontrollregister setzen
        MOV     B, M            ; 46
        MOV     A, M            ; 7E
        ANI     0BFh            ; E6 BF    -> Bit 6 löschen (Maskierung)
        MOV     M, A            ; 77
        JMP     L_01F1          ; C3 F1 01 -> Sprung zu RAM/ROM-Adresse 01F1h

; convert all 5 bytes from input IO connector
; convert bytes from input IO connector
; d is index for created output string
; h,l points to start address to convert
; b is num of bytes to convert (5)
; h,l point to memory location for input byte (is decremented in a loop)
; it looks that two 4-bit values are in 1 byte as HI/LO nibble
convert_5input_bytes:
L_0242:
        MVI     B, 05h          ; 06 05    -> Schleifenzähler (5) in Register B laden DD: num of bytes to convert
L_0244:
        MOV     A, M            ; 7E       -> Byte über HL-Zeiger (0604h) laden
        RRC                     ; 0F       -> Bit-Verschiebungen / Rotation DD:  rotate right, 4 times; LO/HI nibble exchange
        RRC                     ; 0F
        RRC                     ; 0F
        RRC                     ; 0F
        CALL    L_0256          ; CD 56 02 -> Unterfunktion an ROM-Adresse 0256h aufrufen DD: HI nibble is converted call convert_out_char
        MOV     A, M            ; 7E       -> Dasselbe Byte nochmals laden
        CALL    L_0256          ; CD 56 02 -> Unterfunktion an ROM-Adresse 0256h aufrufen DD: LO nibble is converted
        DCX     H               ; 2B       -> HL-Zeiger dekrementieren
        DCR     B               ; 05       -> Schleifenzähler verringern DD: decrease num. of bytes to convert
        JNZ     L_0244          ; C2 44 02 -> Schleife wiederholen, wenn Register B ungleich Null
        RET                     ; C9       -> Unterprogramm beenden

; Diese Funktion ist eine Konvertierungs- und Filter-Routine für Datenzeichen
; (ASCII/Hex), die von den I/O-Schnittstellen des Geräts eingelesen wurden.
; Sie entscheidet anhand eines Hardware-Statusbits, ob ein Datenwert invertiert
; und über eine Zeichentabelle im ROM übersetzt wird, oder ob es sich um ein
; Steuersignal handelt, das das System beeinflusst.
convert_out_char:
; convert value in a via conversion table lookup, store it (0x26c)  to somewhere
; (in RAM or register?), increment index in d, and keep h in original state
L_0256:
        MOV     C, A            ; 4F       -> Akkumulator in Register C sichern
        LDA     IO_GPIB_CTRL_1   ; 3A 05 06 -> Status/Datenbyte aus I/O-SRAM laden
        ANI     04h             ; E6 04    -> Bit 2 isolieren DD: check bit 2 (maybe "do we have valid data?)"
        CPI     04h             ; FE 04    -> Mit 04h vergleichen
        MOV     A, C            ; 79       -> Gesichertes Byte zurück nach A holen
        JZ      L_0263          ; CA 63 02 -> Wenn Vergleich gleich (Zero=1), Sprung zu 0263h
        CMA                     ; 2F       -> Akkumulator invertieren
L_0263:
        ANI     0Fh             ; E6 0F    -> Die unteren 4 Bits maskieren
        PUSH    H               ; E5       -> HL-Registerpaar auf dem Stack sichern
        LXI     H, ROM_TAB_ASCII        ; 21 D4 03 -> HL auf Übersetzungstabelle im ROM ausrichten
        ADD     L               ; 85       -> Offset zu L addieren
        MOV     L, A            ; 6F       -> Ergebnis zurück in L (indirekte Adressierung)
        MOV     A, M            ; 7E       -> Übersetztes Zeichen aus der ROM-Tabelle holen
        STAX    D               ; 12       -> Zeichen an Zieladresse [DE] (0430hff) wegsichern
        INX     D               ; 13       -> Zielzeiger erhöhen
        POP     H               ; E1       -> HL vom Stack wiederherstellen
        RET                     ; C9       -> Unterprogramm beenden

; Steuerzeichen Filter
        LXI     H, ROM_CONST_CMP        ; 21 90 03 -> HL auf alternative Tabelle/String im ROM ausrichten
        MOV     A, B            ; 78       -> Register B (04h) nach A holen
        ANI     01Fh            ; E6 1F    -> 5-Bit-Maskierung
        CMP     M               ; BE       -> Mit Speicherwert [HL] vergleichen
        JNZ     L_0017          ; C2 17 00 -> Bei Ungleichheit harter Sprung zurück zu L_0017
        LXI     H, REG_SYS_STATUS        ; 21 07 04 -> HL auf RAM-Adresse 0407h setzen
        MOV     A, M            ; 7E       -> Wert aus 0407h lesen
        ANI     030h            ; E6 30    -> Bits 4 und 5 maskieren
        JZ      L_0017          ; CA 17 00 -> Wenn Null, ebenfalls zurück zu L_0017
        RRC                     ; 0F       -> Bits rotieren
        RRC                     ; 0F
        RRC                     ; 0F
        MOV     M, A            ; 77       -> Modifizierten Wert zurück nach 0407h schreiben
        JMP     L_0017          ; C3 17 00 -> Unbedingter Rücksprung zum Haupt-Polling

; ------------------------------------------------------------------------------
; Fortsetzung ab Adresse 028Ah bis 029Ch
; ------------------------------------------------------------------------------
        LDA     REG_SYS_STATUS  ; 3A 07 04 -> Lädt den Gerätestatus aus dem RAM
        ANI     02h             ; E6 02    -> Bit 1 maskieren (z. B. Remote/Local oder ein Bus-Flag)
        JZ      L_0017          ; CA 17 00 -> Wenn Bit 0 ist, Schleife abbrechen und zurück zu L_0017
        LXI     H, IO_SRAM_FLAG1        ; 21 07 06 -> HL auf Ausgangs-Datenregister ausrichten
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
        STA     IO_TALK_CTRLBUS   ; 32 02 07 -> Interface-Register 0702h löschen
        DI                      ; F3       -> Interrupts global sperren
L_BUFF_LOOP:
L_02A5:
        CALL    L_0163          ; CD 63 01 -> Aufruf der Puffer-/Schnittstellenroutine L_0163
        MOV     A, B            ; 78       -> Das in Register B befindliche Zeichen nach A holen
        ANI     070h            ; E6 70    -> Die Bits 4, 5 und 6 maskieren
        CPI     030h            ; FE 30    -> Prüfen, ob das obere Halbnibble dem ASCII-Bereich '3' entspricht
        JNZ     0305h           ; C2 05 03 -> Wenn ungleich, Sprung nach vorne zur Fehler/Auswertung an 0305h
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
; Hauptinitialisierung ab Label L_02C8 (Adresse 02C8h bis 02F8h)
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
        JZ      L_0017          ; CA 17 00 -> if counter==0, jump back to main polling loop
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
        JMP     L_0017          ; C3 17 00 -> back to main polling loop
; ------------------------------------------------------------------------------
; line above is end of boot code; everything else is done in main polling loop L_0017
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; Dynamische Fehlerbehandlung (0305h): Wenn die Daten zuvor nicht den Erwartungen entsprechen, wird hier das fehlerhafte
; Zeichen isoliert (ANI 07Fh) und über eine separate Befehlstabelle ab ROM-Adresse 03F5h mittels deiner Suchroutine L_014E
; ausgewertet. Der Befehl PCHL springt dann dynamisch in die passende Behandlung.
; Puffer-Invertierung (0311h): Dieses Unterprogramm prüft ein Hardware-Statusflag an Adresse 0505h. Ist dieses
; aktiv (CPI 08h), durchläuft der Code eine Schleife (L_031A), die den gesamten Datenstrom im RAM bitweise invertiert
; (CMA). Dies deutet stark auf eine Pegel-Anpassung für die angeschlossene Hardware hin.
; ------------------------------------------------------------------------------
L_CMD_PARSE_ERR:
L_0305:
        MOV     A, B            ; 78       -> Hierher wird gesprungen, wenn ASCII-Prüfung bei 02A2h fehlschlägt
        ANI     07Fh            ; E6 7F    -> Auf 7-Bit-ASCII maskieren
        MVI     C, 03h          ; 0E 03    -> Schleifenzähler (3) für die Tabelle setzen
        LXI     H, ROM_TAB_CMD_VEC    ; 21 F5 03 -> HL auf Sprungtabelle im ROM ausrichten
        CALL    L_014E          ; CD 4E 01 -> Tabellen-Suchroutine aufrufen
        PCHL                    ; E9       -> Indirekter Sprung zur gefundenen Routine

; depending on a flag value (bit 3 from address 0505h), a block in memory is inverted or not.
; number of bytes to invert controlled by value in C, start address in HL.
; if bit is set, inversion takes place.
; called from 02D4h
L_CHECK_INVERT:
L_0311:
        LDA     RAM_HW_CONFIG1  ; 3A 05 05 -> read byte from memory mapped HW - Byte aus dem I/O-SRAM-Status laden
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

L_0324:
        LDA     REG_CMD_LOCK    ; 3A 0C 04 -> Lädt den Inhalt der RAM-Adresse 040Ch in den Akkumulator
        ORA     A               ; B7       -> Setzt die Flags (Zero/Sign) basierend auf dem Akkumulator
        JZ      L_0017          ; CA 17 00 -> Wenn der Wert Null ist, Sprung zurück zum Haupt-Polling L_0017
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
        LXI     H, REG_SYS_STATUS    ; 21 07 04 -> HL auf RAM-Adresse 0407h ausrichten
        MOV     A, M            ; 7E       -> Wert laden
        ORI     008h            ; F6 08    -> Bit 3 gezielt setzen
        MOV     M, A            ; 77       -> Aktualisierten Wert zurückschreiben
; 0704h, 0703h are set to 0.
; value of [040B] REG_PENDING_CMD is written to 0702h IO_TALK_CTRLBUS
; value of [0407] REG_SYS_STATUS is written to 0707h
L_0355:
        LXI     H, IO_TALK_CTRL ; 21 04 07 -> HL points to 0704h (GPIB connector related)
        MVI     M, 00h          ; 36 00    -> clear [0704h]
        LXI     H, IO_TALK_CTRLBUS   ; 21 02 07 -> HL points to 0702h
        LDA     REG_PENDING_CMD      ; 3A 0B 04 -> load content of RAM 040Bh to A
        MOV     M, A            ; 77       -> copy A to [0702h]
        INX     H               ; 23       -> inc HL (now 0703h)
        MVI     M, 00h          ; 36 00    -> clear [0703h]
        MVI     L, 07h          ; 2E 07    -> set lower byte of HL to 07h (HL now is 0707h)
        LDA     REG_SYS_STATUS  ; 3A 07 04 -> load content of RAM 0407h to A
        MOV     M, A            ; 77       -> copy A to [0707h]
        JMP     L_001F          ; C3 1F 00 -> continue at L_001F inside main polling loop

; ------------------------------------------------------------------------------
; Behandlungsroutinen für Kommandos (Adresse 036Dh bis 0389h)
; ------------------------------------------------------------------------------
L_CMD_P_HANDLER:
L_036D:
        XRA     A               ; AF       -> Akkumulator nullen (A = 00h)
        STA     REG_IO_STATE    ; 32 01 04 -> Schreibt die Null in die RAM-Zelle REG_IO_STATE
        LXI     H, REG_SYS_STATUS    ; 21 07 04 -> HL auf Kontrollregister 0407h ausrichten
        MOV     A, M            ; 7E       -> Aktuellen Statuswert laden
        ANI     0F7h            ; E6 F7    -> Bit 3 gezielt löschen (Maske 1111 0111)
        MOV     M, A            ; 77       -> Modifizierten Status zurückschreiben
        JMP     L_0017          ; C3 17 00 -> Unbedingter Rücksprung zum Haupt-Polling L_0017

; Dieser Zweig (ab 037Bh) verarbeitet das alternative Szenario ('q')
L_037B:
;;; "Bit-Prüfung und Bedingter Abbruch"
        LDA     REG_SYS_STATUS  ; 3A 07 04 -> Lädt den Systemstatus aus RAM 0407h
        ANI     002h            ; E6 02    -> Isolierte Betrachtung von Bit 1
        JZ      L_0017          ; CA 17 00 -> Wenn Bit 1 Null ist, zurück zum Polling L_0017
        MOV     A, B            ; 78       -> Originales Zeichen aus Register B holen
        STA     REG_CMD_LOCK    ; 32 0C 04 -> Zeichen in Kontrollregister 040Ch wegsichern
        JMP     L_0017          ; C3 17 00 -> Unbedingter Rücksprung zum Haupt-Polling L_0017

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

; 0393h - 03B2h: Sprung- und Befehlstabelle für den Data Dispatcher
; Format des universalen Kopierers (Routine L_014E / L_007B):
; [Block-Länge] [Ziel-Adresse DE (Low/High)] [Daten...]
; Eine Länge von 00h bricht den Suchprozess ab.
    	DB 004h	; 004h, from address 393h
    	DB 03Ch	; 03Ch, from address 394h
    	DB 001h	; 001h, from address 395h
    	DB 014h	; 014h, from address 396h
    	DB 006h	; 006h, from address 397h
    	DB 000h	; 000h, from address 398h
    	DB 015h	; 015h, from address 399h
    	DB 06Dh	; 06Dh, from address 39ah
    	DB 003h	; 003h, from address 39bh
    	DB 018h	; 018h, from address 39ch
    	DB 048h	; 048h, from address 39dh
    	DB 001h	; 001h, from address 39eh
    	DB 019h	; 019h, from address 39fh
    	DB 047h	; 047h, from address 3a0h
    	DB 001h	; 001h, from address 3a1h
    	DB 008h	; 008h, from address 3a2h
    	DB 08Ah	; 08Ah, from address 3a3h
    	DB 002h	; 002h, from address 3a4h
    	DB 020h	; 020h, from address 3a5h
    	DB 000h	; 000h, from address 3a6h
    	DB 001h	; 001h, from address 3a7h
    	DB 040h	; 040h, from address 3a8h
    	DB 020h	; 020h, from address 3a9h
    	DB 001h	; 001h, from address 3aah
    	DB 005h	; 005h, from address 3abh
    	DB 07Bh	; 07Bh, from address 3ach
    	DB 003h	; 003h, from address 3adh
    	DB 060h	; 060h, from address 3aeh
    	DB 024h	; 024h, from address 3afh
    	DB 003h	; 003h, from address 3b0h
    	DB 017h	; 017h, from address 3b1h
    	DB 000h	; 000h, from address 3b2h

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

; 03F5h - 03FFh: Primäre Befehls-Sprungtabelle (wird von L_014E gescannt)
; Format: [ASCII-Kommando] [Sprungadresse (Low/High)]
        DB 00Dh, 0C8h, 002h    ; 0Dh (CR)     -> Springe zu 02C8h (Haupt-Init)
        DB 00Ah, 0C8h, 002h    ; 0Ah (LF)     -> Springe zu 02C8h (Haupt-Init)
        DB 02Ch, 0C8h, 002h    ; 2Ch (Komma)  -> Springe zu 02C8h (Haupt-Init)
        DB 0A5h, 002h          ; Letzter Vektor / Endadresse im ROM-Sektor (02A5h)