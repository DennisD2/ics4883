; =====================================================================
; ICS Electronics Model 4883 Instrument Coupler
; =====================================================================
        CPU	8080
        ORG	0000h

; ---------------------------------------------------------------------
; 0000h - 0016h: boot vector and initialization
; ---------------------------------------------------------------------
L_0000:
        LXI     SP, 0500h       ; 31 00 05 -> Stack-Pointer setzen
        CALL    L_008F          ; CD 8F 00 -> memory init for variables
        LDA     03C4h           ; 3A C4 03 -> Konfigurationswert aus dem ROM laden
        XRI     0Ch             ; EE 0C    -> Maskierung (XOR) für Initialisierung
        STA     0506h           ; 32 06 05 -> Im System-SRAM wegsichern
        LXI     H, 03B3h        ; 21 B3 03 -> Zeiger auf ID-String "ICS 4883" laden
        CALL    L_007B          ; CD 7B 00 -> Speicher-Kopierroutine aufrufen
        JMP     L_02C8          ; C3 C8 02 -> Sprung in die Hauptinitialisierung

; ------------------------------------------------------------------------------
; main IO polling loop
; ------------------------------------------------------------------------------
L_0017:
        DI
        LDA     0401h           ; Status von GPIB / I/O Interface-Chip laden
        ORA     A               ; Prüfen, ob der Status 0 ist
        JNZ     L_0355          ; Wenn ungleich Null -> Zur Service-Routine abzweigen

L_001F:
        LDA     0701h           ; Status des Talker-Interfaces einlesen
        ANI     0C0h            ; Die obersten zwei Bits maskieren
        CPI     80h             ; Prüfen auf Status-Flag 80h
        JZ      L_00CE          ; Bei Treffer -> Abzweigen zur Routine L_00CE

        CALL    L_00AD          ; CD AD 00 -> Ruft Subroutine an Adresse 00ADh auf
        MVI     C, 0FEh         ; 0E FE    -> Lädt Konstante 0FEh in Register C
        CALL    L_00A1          ; CD A1 00 -> Ruft Subroutine an Adresse 00A1h auf
        LDA     0706h           ; 3A 06 07 -> Lädt den Status aus dem Talker-Register 0706h
        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        JMP     L_003C          ; C3 3C 00 -> Unbedingter Sprung zur Routine 003Ch
        POP     H               ; E1       -> Registerpaar HL vom Stack holen (Stack aufräumen)
        JMP     L_00CE          ; C3 CE 00 -> Sprung zur Service-Routine L_00CE

L_003C:
        CC      L_009C          ; DC 9C 00 -> Bedingter Unterprogramm-Aufruf, wenn Carry-Flag = 1
        LXI     H, 0407h        ; 21 07 04 -> Register HL mit Adresse 0407h laden
    	MOV     A,M             ; 7E
    	RRC                     ; 0F
    	RRC                     ; 0F
        JC      L_029D          ; DA 9D 02 -> Wenn Carry=1, springe zu Adresse 029Dh
        RRC                     ; 0F       -> Akkumulator nach rechts rotieren
        JC      L_01AD          ; DA AD 01 -> Wenn Carry=1, springe zu Adresse 01ADh
        LXI     B,01000h        ; 01 00 10 -> lade 01000h in B
        LDA     0605h           ; 3A 05 06 -> Holt das Daten-Byte vom I/O-Schnittstellenregister
    	CMA                     ; 2F       -> Akkumulator invertieren (Low-Aktive Signale)
    	RRC                     ; 0F       -> Bit nach rechts rotieren
    	JNC     L_0060          ; D2 60 00 -> Wenn kein Carry, springe vor zu Adresse 0060h
    	CALL    L_00C7          ; CD C7 00 -> Unterfunktion an Adresse 00C7h ausf
        JC      L_006D          ; DA 6D 00 -> Wenn Carry=1, springe zu Adresse 006Dh
        STA     0607h           ; 32 07 06 -> Berechneten Zustand im RAM 0607h sichern
L_0060:
    	LXI     H, 0403h        ; 21 03 04 -> HL-Zeiger auf I/O-Schnittstelle 0403h ausrichten
    	MOV     A,M             ; 7E from address 63h
    	ANA     B               ; A0 from address 64h
    	ORA     C               ; B1 from address 65h
    	MOV     M,A             ; 77 from address 66h
    	STA     00703h          ; Zwischenspeichern des aktuellen I/O-Status
    	JMP     L_0017          ; C3 17 00  back to loop start

; ------------------------------------------------------------------------------
; Ausgelagerter Talker-Status-Handler (Deine Zeilen 68-74)
; ------------------------------------------------------------------------------
L_006D:
        LXI     H, 040Eh        ; 21 0E 04 -> HL auf Register 040Eh (GPIB/Bus-Steuerung) ausrichten
        MOV     A, M            ; 7E       -> Status-Byte aus 040Eh in den Akkumulator laden
        RRC                     ; 0F       -> Nach rechts rotieren (Bit-Prüfung)
        JC      L_0060          ; DA 60 00 -> Wenn Carry=1, springe vor zu Adresse 0060h
        MVI     M, 41h          ; 36 41    -> Schreibe den Wert 41h (ASCII 'A') nach 040Eh
        MOV     C, B            ; 48       -> Kopiere Register B nach C
        JMP     L_0060          ; C3 60 00 -> Unbedingter Sprung vor zu Adresse 0060h

; ------------------------------------------------------------------------------
; 007Bh - 008Eh: Universeller, tabellengesteuerter Block-Kopierer (Data Dispatcher)
; Aufgerufen während des Boot-Vektors (Zeile 18) zur Systeminitialisierung.
; Erwartet in HL einen Zeiger auf eine ROM-Tabelle im Format:
; [Länge C] [Ziel-Adresse DE] [Datenbyte 1] [Datenbyte 2] ...
; Eine Länge von 00h beendet die gesamte Übertragung.
; ------------------------------------------------------------------------------
L_007B:
        MOV     A, M            ; 7E       -> Lädt das erste Byte (Block-Länge) aus der Tabelle
        ORA     A               ; B7       -> Prüft, ob die Länge Null ist
        RZ                      ; C8       -> Wenn Null (End of Table Flag), Unterprogramm beenden
        MOV     C, A            ; 4F       -> Speichert die Block-Länge als Schleifenzähler in C
        INX     H               ; 23       -> Zeiger auf das nächste Tabellenbyte (Zieladresse Low)
        MOV     E, M            ; 5E       -> Lädt die Zieladresse (unteres Byte) nach E
        INX     H               ; 23       -> Zeiger auf das nächste Tabellenbyte (Zieladresse High)
        MOV     D, M            ; 56       -> Lädt die Zieladresse (oberes Byte) nach D
        INX     H               ; 23       -> Zeiger auf das erste tatsächliche Datenbyte im ROM
L_0084:
        MOV     A, M            ; 7E       -> Holt das aktuelle Datenbyte aus der ROM-Tabelle
        STAX    D               ; 12       -> Schreibt es an die physische Zieladresse [DE]
        INX     H               ; 23       -> Erhöhe ROM-Quellzeiger für das nächste Byte
        INX     D               ; 13       -> Erhöhe RAM-Zielzeiger für das nächste Byte
        DCR     C               ; 0D       -> Block-Schleifenzähler um 1 verringern
        JNZ     L_0084          ; C2 84 00 -> Wenn Block noch nicht fertig (C > 0), nächstes Byte holen
        JMP     L_007B          ; C3 7B 00 -> Block fertig! Zurück zum Start, um nächsten Tabelleneintrag zu lesen

; ------------------------------------------------------------------------------
; RAM-Initialisierung / Block-Clear Routine (Deine Zeilen 79-101)
; Aufgerufen via CALL 008Fh im Boot-Vektor
; ------------------------------------------------------------------------------
L_008F:
        MVI     C, 040h         ; 0E 40    -> Lädt Schleifenzähler (64) in Register C
        LXI     H, 0400h        ; 21 00 04 -> HL auf Startadresse 0400h ausrichten
L_0094:
        MVI     M, 00h          ; 36 00    -> Speicherstelle [HL] mit Null loeschen
        INX     H               ; 23       -> HL-Zeiger auf die naechste Adresse erhoehen
        DCR     C               ; 0D       -> Schleifenzaehler C um 1 verringern
        JNZ     L_0094          ; C2 94 00 -> Wenn C noch nicht Null, Schleife wiederholen
        RET                     ; C9       -> Ruecksprung zum Aufrufer (Boot-Vektor)

; ------------------------------------------------------------------------------
; Bit-Manipulation & I/O-Schnittstellen-Ausgabe (Zeile 119 bis 133)
; ------------------------------------------------------------------------------
L_009C:
        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        RLC                     ; 07       -> Nochmals nach links rotieren
        RLC                     ; 07       -> Ein drittes Mal nach links rotieren
L_009F:
    	MVI     C, 0F9h         ; 0E F9    -> Lädt die Konstante 0F9h (mask 11111001b) direkt in Register C
L_00A1:
        LXI     H, 0407h        ; 21 07 04 -> Richtet den HL-Zeiger auf Speicher/Register 0407h aus
        MOV     B, A            ; 47       -> Sichert das bearbeitete Byte in Register B
        MOV     A, M            ; 7E       -> Holt den aktuellen Wert aus [HL] (0407h)
        ANA     C               ; A1       -> Logisches UND mit Register C (Maskierung)
        ORA     B               ; B0       -> Logisches ODER mit Register B (Bits zusammenführen)
        MOV     M, A            ; 77       -> Schreibt das Ergebnis zurück nach [HL] (0407h)
        MVI     H, 07h          ; 26 07    -> Biegt das obere Byte von HL auf 07h um (HL zeigt nun auf 0707h!)
        MOV     M, A            ; 77       -> Feuert das Zeichen direkt auf das I/O-Register 0707h raus!
        RET                     ; C9       -> Unterprogramm beenden (Rücksprung)

L_00AD:
        LXI     H, 0391h        ; 21 91 03 -> HL-Zeiger auf ROM-Tabelle/String 0391h ausrichten
    	LDA     0605h           ; 3A 05 06 -> Holt das aktuelle I/O-Datenbyte vom Talker
        CMA                     ; 2F       -> Akkumulator invertieren (Low-Aktiv Pegel)
        ANI     02h             ; E6 02    -> Bit 1 maskieren (Prüfung eines bestimmten Bus-Signals)
        CMP     M               ; BE       -> Vergleiche das Ergebnis mit dem Wert im ROM [HL]
        JNZ     L_00C5          ; C2 C5 00 -> Wenn ungleich, springe vor zu Adresse 00C5h
        INX     H               ; 23       -> HL-Zeiger auf das nächste Tabellenbyte erhöhen
        LDA     0505h           ; 3A 05 05 -> weiteres I/O-Datenbyte einlesen
        CMA                     ; 2F       -> Invertieren
        ANI     07h             ; E6 07    -> Die untersten 3 Bits maskieren
        CMP     M               ; BE       -> Mit dem nächsten Tabellenwert im ROM vergleichen
        MVI     A, 01h          ; 3E 01    -> Lade Konstante 01h in den Akkumulator
        RZ                      ; C8       -> Bedingter Rücksprung, wenn der Vergleich gleich war (Zero-Flag = 1)
L_00C5:
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
    	RET                     ; C9

L_00C7:
    	LDA     0705h           ; 3A 07 05 -> Statuswert aus dem SRAM-Bereich laden
        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        RLC                     ; 07       -> Nochmals nach links rotieren
        RLC                     ; 07       -> Ein drittes Mal nach links rotieren
    	RET                     ; C9       -> Unterprogramm beenden (Rücksprung)

; ------------------------------------------------------------------------------
; Status-Reset & Polling-Handler (Adresse 00CEh - 00E0h)
; ------------------------------------------------------------------------------
L_00CE:
        MVI     A, 80h          ; 3E 80    -> Lade Status-Flag 80h in den Akkumulator
        STA     0405h           ; 32 05 04 -> Schreibe das Flag in das GPIB-Schnittstellenregister
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
        STA     0702h           ; 32 02 07 -> Lösche das Statusregister 0702h im Talker-Interface
        CALL    L_0163          ; CD 63 01 -> Ruft Unterfunktion an Adresse 0163h auf
        LDA     0706h           ; 3A 06 07 -> Lädt aktuellen Status aus dem Talker-Register
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
        STA     040Ch           ; 32 0C 04 -> Schreibt die Null in das Kontrollregister 040Ch
        MOV     A, B            ; 78       -> Holt das originale Zeichen erneut aus Register B
        ANI     060h            ; E6 60    -> Erneute Bitmaskierung
        JNZ     L_00F7          ; C2 F7 00 -> Wenn ungleich Null, springe vor zur Service-Routine 00F7h
        MOV     A, B            ; 78       -> Holt das Zeichen ein letztes Mal

        ; ------------------------------------------------------------------------------
        ; Indirekte Sprungsteuerung & indir. Funktionsaufrufe (Adresse 00F7h - 0010Dh)
        ; ------------------------------------------------------------------------------
L_00F7:
        LXI     H, 0393h        ; 21 93 03 -> HL-Zeiger auf Adresse 0393h im ROM ausrichten
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
        MOV     A, B            ; 78       -> Holt das aktuelle Zeichen aus Register B
        CPI     03Fh            ; FE 3F    -> Vergleiche mit ASCII '?' (GPIB Talker Query)
        JNZ     L_0017          ; C2 17 00 -> Wenn kein '?', zurück zum Schleifenstart L_0017
    	XRA     A               ; AF from address 114h
    	STA     0041Fh          ; 32 1F 04 from address 115h
    	MVI     C, 0FDh         ; 0E FD    -> Lädt die Ausgabemaske 0FDh in Register C
    	CALL    L_00A1          ; CD A1 00 -> Ruft die I/O-Ausgabestufe auf (Zeichen auf den Bus senden)
        JMP     L_0017          ; C3 17 00 -> Unbedingter Rücksprung zu L_0017
        CALL    L_0131          ; CD 31 01 -> Unterfunktion an Adresse 0131h aufrufen
        MVI     A, 04h          ; 3E 04    -> Konstante 04h in den Akkumulator laden
        JZ      L_0108          ; CA 08 01 -> Wenn Zero-Flag gesetzt, springe zu Adresse 0104h
        MVI     C, 0FBh         ; 0E FB    -> Lädt die nächste Steuermaske 0FBh in Register C
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
        CALL    L_00A1          ; CD A1 00 -> Ruft die I/O-Ausgabestufe auf
    	JMP     L_0017          ; C3 17 00  from address 12eh

L_0131:
    	LDA     0706h           ; 3A 06 07 -> Lädt den Status aus dem Talker-Register 0706h
    	ANI     01Fh            ; E6 1F Bits maskieren
        MOV     C, A            ; 4F       -> Zwischenspeichern in Register C
    	MOV     A,B             ; 78 from address 137h
    	ANI     01Fh            ; E6 1F Bits maskieren
        CMP     C               ; B9       -> Vergleiche das Ergebnis mit Register C
        RET                     ; C9       -> Wenn gleich, Unterprogramm beenden

        ; ------------------------------------------------------------------------------
        ; Talker-Statusprüfung & Bitmaskierungs-Unterprogramm (Adresse 013Ch - 014Fh)
        ; ------------------------------------------------------------------------------
L_013C:
    	LDA     0407h           ; DB 03Ah	; 03Ah, from address 13ch
    	                        ;DB 007h	; 007h, from address 13dh
    	                        ;DB 004h	; 004h, from address 13eh
    	 ANI    02h             ;DB 0E6h	; 0E6h, from address 13fh
    	                        ;DB 002h	; 002h, from address 140h
    	DB 0CAh	; 0CAh, from address 141h
    	DB 017h	; 017h, from address 142h
    	DB 000h	; 000h, from address 143h
    	DB 0C3h	; 0C3h, from address 144h
    	DB 006h	; 006h, from address 145h
    	DB 000h	; 000h, from address 146h
    	DB 0AFh	; 0AFh, from address 147h
    	DB 032h	; 032h, from address 148h
    	DB 00Dh	; 00Dh, from address 149h
    	DB 004h	; 004h, from address 14ah
    	DB 0C3h	; 0C3h, from address 14bh
    	DB 017h	; 017h, from address 14ch
    	DB 000h	; 000h, from address 14dh
L_014E:
    	DB 0D5h	; 0D5h, from address 14eh
    	DB 011h	; 011h, from address 14fh
    	DB 003h	; 003h, from address 150h
    	DB 000h	; 000h, from address 151h
    	DB 0BEh	; 0BEh, from address 152h
    	DB 0CAh	; 0CAh, from address 153h
    	DB 05Ch	; 05Ch, from address 154h
    	DB 001h	; 001h, from address 155h
    	DB 019h	; 019h, from address 156h
    	DB 00Dh	; 00Dh, from address 157h
    	DB 0C2h	; 0C2h, from address 158h
    	DB 052h	; 052h, from address 159h
    	DB 001h	; 001h, from address 15ah
    	DB 02Bh	; 02Bh, from address 15bh
    	DB 023h	; 023h, from address 15ch
    	DB 05Eh	; 05Eh, from address 15dh
    	DB 023h	; 023h, from address 15eh
    	DB 056h	; 056h, from address 15fh
    	DB 0EBh	; 0EBh, from address 160h
    	DB 0D1h	; 0D1h, from address 161h
    	DB 0C9h	; 0C9h, from address 162h
L_0163:
    	DB 03Ah	; 03Ah, from address 163h
    	DB 003h	; 003h, from address 164h
    	DB 004h	; 004h, from address 165h
    	DB 0E6h	; 0E6h, from address 166h
    	DB 010h	; 010h, from address 167h
    	DB 04Fh	; 04Fh, from address 168h
    	DB 011h	; 011h, from address 169h
    	DB 003h	; 003h, from address 16ah
    	DB 007h	; 007h, from address 16bh
    	DB 03Eh	; 03Eh, from address 16ch
    	DB 004h	; 004h, from address 16dh
    	DB 0B1h	; 0B1h, from address 16eh
    	DB 012h	; 012h, from address 16fh
    	DB 03Eh	; 03Eh, from address 170h
    	DB 080h	; 080h, from address 171h
    	DB 032h	; 032h, from address 172h
    	DB 004h	; 004h, from address 173h
    	DB 007h	; 007h, from address 174h
    	DB 021h	; 021h, from address 175h
    	DB 001h	; 001h, from address 176h
    	DB 007h	; 007h, from address 177h
    	DB 03Ah	; 03Ah, from address 178h
    	DB 005h	; 005h, from address 179h
    	DB 004h	; 004h, from address 17ah
    	DB 0AEh	; 0AEh, from address 17bh
    	DB 0FAh	; 0FAh, from address 17ch
    	DB 0A9h	; 0A9h, from address 17dh
    	DB 001h	; 001h, from address 17eh
    	DB 07Eh	; 07Eh, from address 17fh
    	DB 0E6h	; 0E6h, from address 180h
    	DB 001h	; 001h, from address 181h
    	DB 0CAh	; 0CAh, from address 182h
    	DB 078h	; 078h, from address 183h
    	DB 001h	; 001h, from address 184h
    	DB 03Ah	; 03Ah, from address 185h
    	DB 005h	; 005h, from address 186h
    	DB 004h	; 004h, from address 187h
    	DB 0AEh	; 0AEh, from address 188h
    	DB 0FAh	; 0FAh, from address 189h
    	DB 0A9h	; 0A9h, from address 18ah
    	DB 001h	; 001h, from address 18bh
    	DB 03Eh	; 03Eh, from address 18ch
    	DB 006h	; 006h, from address 18dh
    	DB 0B1h	; 0B1h, from address 18eh
    	DB 012h	; 012h, from address 18fh
    	DB 07Eh	; 07Eh, from address 190h
    	DB 032h	; 032h, from address 191h
    	DB 00Fh	; 00Fh, from address 192h
    	DB 004h	; 004h, from address 193h
    	DB 02Bh	; 02Bh, from address 194h
    	DB 046h	; 046h, from address 195h
    	DB 023h	; 023h, from address 196h
    	DB 03Eh	; 03Eh, from address 197h
    	DB 002h	; 002h, from address 198h
    	DB 0B1h	; 0B1h, from address 199h
    	DB 012h	; 012h, from address 19ah
    	DB 07Eh	; 07Eh, from address 19bh
    	DB 0E6h	; 0E6h, from address 19ch
    	DB 001h	; 001h, from address 19dh
    	DB 0C2h	; 0C2h, from address 19eh
    	DB 09Bh	; 09Bh, from address 19fh
    	DB 001h	; 001h, from address 1a0h
    	DB 03Eh	; 03Eh, from address 1a1h
    	DB 006h	; 006h, from address 1a2h
    	DB 0B1h	; 0B1h, from address 1a3h
    	DB 012h	; 012h, from address 1a4h
    	DB 032h	; 032h, from address 1a5h
    	DB 003h	; 003h, from address 1a6h
    	DB 004h	; 004h, from address 1a7h
    	DB 0C9h	; 0C9h, from address 1a8h
    	DB 0E1h	; 0E1h, from address 1a9h
    	DB 0C3h	; 0C3h, from address 1aah
    	DB 017h	; 017h, from address 1abh
    	DB 000h	; 000h, from address 1ach
L_01AD:
    	DB 0FBh	; 0FBh, from address 1adh
    	DB 03Ah	; 03Ah, from address 1aeh
    	DB 00Dh	; 00Dh, from address 1afh
    	DB 004h	; 004h, from address 1b0h
    	DB 0B7h	; 0B7h, from address 1b1h
    	DB 0C2h	; 0C2h, from address 1b2h
    	DB 032h	; 032h, from address 1b3h
    	DB 002h	; 002h, from address 1b4h
    	DB 021h	; 021h, from address 1b5h
    	DB 005h	; 005h, from address 1b6h
    	DB 006h	; 006h, from address 1b7h
    	DB 07Eh	; 07Eh, from address 1b8h
    	DB 00Fh	; 00Fh, from address 1b9h
    	DB 0DAh	; 0DAh, from address 1bah
    	DB 0B8h	; 0B8h, from address 1bbh
    	DB 001h	; 001h, from address 1bch
    	DB 0F3h	; 0F3h, from address 1bdh
    	DB 011h	; 011h, from address 1beh
    	DB 030h	; 030h, from address 1bfh
    	DB 004h	; 004h, from address 1c0h
    	DB 021h	; 021h, from address 1c1h
    	DB 004h	; 004h, from address 1c2h
    	DB 006h	; 006h, from address 1c3h
    	DB 0CDh	; 0CDh, from address 1c4h
    	DB 042h	; 042h, from address 1c5h
    	DB 002h	; 002h, from address 1c6h
    	DB 03Eh	; 03Eh, from address 1c7h
    	DB 00Fh	; 00Fh, from address 1c8h
    	DB 032h	; 032h, from address 1c9h
    	DB 000h	; 000h, from address 1cah
    	DB 004h	; 004h, from address 1cbh
    	DB 0FBh	; 0FBh, from address 1cch
    	DB 021h	; 021h, from address 1cdh
    	DB 030h	; 030h, from address 1ceh
    	DB 004h	; 004h, from address 1cfh
    	DB 022h	; 022h, from address 1d0h
    	DB 02Eh	; 02Eh, from address 1d1h
    	DB 004h	; 004h, from address 1d2h
    	DB 021h	; 021h, from address 1d3h
    	DB 0E4h	; 0E4h, from address 1d4h
    	DB 003h	; 003h, from address 1d5h
    	DB 07Eh	; 07Eh, from address 1d6h
    	DB 023h	; 023h, from address 1d7h
    	DB 022h	; 022h, from address 1d8h
    	DB 01Dh	; 01Dh, from address 1d9h
    	DB 004h	; 004h, from address 1dah
    	DB 0FEh	; 0FEh, from address 1dbh
    	DB 019h	; 019h, from address 1dch
    	DB 0CAh	; 0CAh, from address 1ddh
    	DB 017h	; 017h, from address 1deh
    	DB 000h	; 000h, from address 1dfh
    	DB 0B7h	; 0B7h, from address 1e0h
    	DB 0F2h	; 0F2h, from address 1e1h
    	DB 0F0h	; 0F0h, from address 1e2h
    	DB 001h	; 001h, from address 1e3h
    	DB 0E6h	; 0E6h, from address 1e4h
    	DB 040h	; 040h, from address 1e5h
    	DB 0B1h	; 0B1h, from address 1e6h
    	DB 04Fh	; 04Fh, from address 1e7h
    	DB 02Ah	; 02Ah, from address 1e8h
    	DB 02Eh	; 02Eh, from address 1e9h
    	DB 004h	; 004h, from address 1eah
    	DB 07Eh	; 07Eh, from address 1ebh
    	DB 023h	; 023h, from address 1ech
    	DB 022h	; 022h, from address 1edh
    	DB 02Eh	; 02Eh, from address 1eeh
    	DB 004h	; 004h, from address 1efh
    	DB 047h	; 047h, from address 1f0h
    	DB 03Ah	; 03Ah, from address 1f1h
    	DB 003h	; 003h, from address 1f2h
    	DB 004h	; 004h, from address 1f3h
    	DB 0E6h	; 0E6h, from address 1f4h
    	DB 010h	; 010h, from address 1f5h
    	DB 04Fh	; 04Fh, from address 1f6h
    	DB 011h	; 011h, from address 1f7h
    	DB 003h	; 003h, from address 1f8h
    	DB 007h	; 007h, from address 1f9h
    	DB 012h	; 012h, from address 1fah
    	DB 021h	; 021h, from address 1fbh
    	DB 002h	; 002h, from address 1fch
    	DB 007h	; 007h, from address 1fdh
    	DB 070h	; 070h, from address 1feh
    	DB 02Bh	; 02Bh, from address 1ffh
    	DB 07Eh	; 07Eh, from address 200h
    	DB 00Fh	; 00Fh, from address 201h
    	DB 00Fh	; 00Fh, from address 202h
    	DB 0DAh	; 0DAh, from address 203h
    	DB 000h	; 000h, from address 204h
    	DB 002h	; 002h, from address 205h
    	DB 03Eh	; 03Eh, from address 206h
    	DB 001h	; 001h, from address 207h
    	DB 0B1h	; 0B1h, from address 208h
    	DB 012h	; 012h, from address 209h
    	DB 07Eh	; 07Eh, from address 20ah
    	DB 00Fh	; 00Fh, from address 20bh
    	DB 00Fh	; 00Fh, from address 20ch
    	DB 00Fh	; 00Fh, from address 20dh
    	DB 0DAh	; 0DAh, from address 20eh
    	DB 00Ah	; 00Ah, from address 20fh
    	DB 002h	; 002h, from address 210h
    	DB 0F3h	; 0F3h, from address 211h
    	DB 0AFh	; 0AFh, from address 212h
    	DB 012h	; 012h, from address 213h
    	DB 032h	; 032h, from address 214h
    	DB 003h	; 003h, from address 215h
    	DB 004h	; 004h, from address 216h
    	DB 021h	; 021h, from address 217h
    	DB 000h	; 000h, from address 218h
    	DB 004h	; 004h, from address 219h
    	DB 07Eh	; 07Eh, from address 21ah
    	DB 036h	; 036h, from address 21bh
    	DB 000h	; 000h, from address 21ch
    	DB 0B7h	; 0B7h, from address 21dh
    	DB 0FAh	; 0FAh, from address 21eh
    	DB 017h	; 017h, from address 21fh
    	DB 000h	; 000h, from address 220h
    	DB 0CAh	; 0CAh, from address 221h
    	DB 02Bh	; 02Bh, from address 222h
    	DB 002h	; 002h, from address 223h
    	DB 0AFh	; 0AFh, from address 224h
    	DB 032h	; 032h, from address 225h
    	DB 007h	; 007h, from address 226h
    	DB 006h	; 006h, from address 227h
    	DB 032h	; 032h, from address 228h
    	DB 00Eh	; 00Eh, from address 229h
    	DB 004h	; 004h, from address 22ah
    	DB 0FBh	; 0FBh, from address 22bh
    	DB 02Ah	; 02Ah, from address 22ch
    	DB 01Dh	; 01Dh, from address 22dh
    	DB 004h	; 004h, from address 22eh
    	DB 0C3h	; 0C3h, from address 22fh
    	DB 0D6h	; 0D6h, from address 230h
    	DB 001h	; 001h, from address 231h
    	DB 03Eh	; 03Eh, from address 232h
    	DB 0FFh	; 0FFh, from address 233h
    	DB 032h	; 032h, from address 234h
    	DB 000h	; 000h, from address 235h
    	DB 004h	; 004h, from address 236h
    	DB 021h	; 021h, from address 237h
    	DB 00Eh	; 00Eh, from address 238h
    	DB 004h	; 004h, from address 239h
    	DB 046h	; 046h, from address 23ah
    	DB 07Eh	; 07Eh, from address 23bh
    	DB 0E6h	; 0E6h, from address 23ch
    	DB 0BFh	; 0BFh, from address 23dh
    	DB 077h	; 077h, from address 23eh
    	DB 0C3h	; 0C3h, from address 23fh
    	DB 0F1h	; 0F1h, from address 240h
    	DB 001h	; 001h, from address 241h
    	DB 006h	; 006h, from address 242h
    	DB 005h	; 005h, from address 243h
    	DB 07Eh	; 07Eh, from address 244h
    	DB 00Fh	; 00Fh, from address 245h
    	DB 00Fh	; 00Fh, from address 246h
    	DB 00Fh	; 00Fh, from address 247h
    	DB 00Fh	; 00Fh, from address 248h
    	DB 0CDh	; 0CDh, from address 249h
    	DB 056h	; 056h, from address 24ah
    	DB 002h	; 002h, from address 24bh
    	DB 07Eh	; 07Eh, from address 24ch
    	DB 0CDh	; 0CDh, from address 24dh
    	DB 056h	; 056h, from address 24eh
    	DB 002h	; 002h, from address 24fh
    	DB 02Bh	; 02Bh, from address 250h
    	DB 005h	; 005h, from address 251h
    	DB 0C2h	; 0C2h, from address 252h
    	DB 044h	; 044h, from address 253h
    	DB 002h	; 002h, from address 254h
    	DB 0C9h	; 0C9h, from address 255h
    	DB 04Fh	; 04Fh, from address 256h
    	DB 03Ah	; 03Ah, from address 257h
    	DB 005h	; 005h, from address 258h
    	DB 006h	; 006h, from address 259h
    	DB 0E6h	; 0E6h, from address 25ah
    	DB 004h	; 004h, from address 25bh
    	DB 0FEh	; 0FEh, from address 25ch
    	DB 004h	; 004h, from address 25dh
    	DB 079h	; 079h, from address 25eh
    	DB 0CAh	; 0CAh, from address 25fh
    	DB 063h	; 063h, from address 260h
    	DB 002h	; 002h, from address 261h
    	DB 02Fh	; 02Fh, from address 262h
    	DB 0E6h	; 0E6h, from address 263h
    	DB 00Fh	; 00Fh, from address 264h
    	DB 0E5h	; 0E5h, from address 265h
    	DB 021h	; 021h, from address 266h
    	DB 0D4h	; 0D4h, from address 267h
    	DB 003h	; 003h, from address 268h
    	DB 085h	; 085h, from address 269h
    	DB 06Fh	; 06Fh, from address 26ah
    	DB 07Eh	; 07Eh, from address 26bh
    	DB 012h	; 012h, from address 26ch
    	DB 013h	; 013h, from address 26dh
    	DB 0E1h	; 0E1h, from address 26eh
    	DB 0C9h	; 0C9h, from address 26fh
    	DB 021h	; 021h, from address 270h
    	DB 090h	; 090h, from address 271h
    	DB 003h	; 003h, from address 272h
    	DB 078h	; 078h, from address 273h
    	DB 0E6h	; 0E6h, from address 274h
    	DB 01Fh	; 01Fh, from address 275h
    	DB 0BEh	; 0BEh, from address 276h
    	DB 0C2h	; 0C2h, from address 277h
    	DB 017h	; 017h, from address 278h
    	DB 000h	; 000h, from address 279h
    	DB 021h	; 021h, from address 27ah
    	DB 007h	; 007h, from address 27bh
    	DB 004h	; 004h, from address 27ch
    	DB 07Eh	; 07Eh, from address 27dh
    	DB 0E6h	; 0E6h, from address 27eh
    	DB 030h	; 030h, from address 27fh
    	DB 0CAh	; 0CAh, from address 280h
    	DB 017h	; 017h, from address 281h
    	DB 000h	; 000h, from address 282h
    	DB 00Fh	; 00Fh, from address 283h
    	DB 00Fh	; 00Fh, from address 284h
    	DB 00Fh	; 00Fh, from address 285h
    	DB 077h	; 077h, from address 286h
    	DB 0C3h	; 0C3h, from address 287h
    	DB 017h	; 017h, from address 288h
    	DB 000h	; 000h, from address 289h
    	DB 03Ah	; 03Ah, from address 28ah
    	DB 007h	; 007h, from address 28bh
    	DB 004h	; 004h, from address 28ch
    	DB 0E6h	; 0E6h, from address 28dh
    	DB 002h	; 002h, from address 28eh
    	DB 0CAh	; 0CAh, from address 28fh
    	DB 017h	; 017h, from address 290h
    	DB 000h	; 000h, from address 291h
    	DB 021h	; 021h, from address 292h
    	DB 007h	; 007h, from address 293h
    	DB 006h	; 006h, from address 294h
    	DB 077h	; 077h, from address 295h
    	DB 02Bh	; 02Bh, from address 296h
    	DB 03Ah	; 03Ah, from address 297h
    	DB 0C8h	; 0C8h, from address 298h
    	DB 003h	; 003h, from address 299h
    	DB 0C3h	; 0C3h, from address 29ah
    	DB 0F9h	; 0F9h, from address 29bh
    	DB 002h	; 002h, from address 29ch

L_029D:
    	DB 0AFh	; 0AFh, from address 29dh
    	DB 032h	; 032h, from address 29eh
    	DB 005h	; 005h, from address 29fh
    	DB 004h	; 004h, from address 2a0h
    	DB 032h	; 032h, from address 2a1h
    	DB 002h	; 002h, from address 2a2h
    	DB 007h	; 007h, from address 2a3h
    	DB 0F3h	; 0F3h, from address 2a4h
    	DB 0CDh	; 0CDh, from address 2a5h
    	DB 063h	; 063h, from address 2a6h
    	DB 001h	; 001h, from address 2a7h
    	DB 078h	; 078h, from address 2a8h
    	DB 0E6h	; 0E6h, from address 2a9h
    	DB 070h	; 070h, from address 2aah
    	DB 0FEh	; 0FEh, from address 2abh
    	DB 030h	; 030h, from address 2ach
    	DB 0C2h	; 0C2h, from address 2adh
    	DB 005h	; 005h, from address 2aeh
    	DB 003h	; 003h, from address 2afh
    	DB 021h	; 021h, from address 2b0h
    	DB 01Fh	; 01Fh, from address 2b1h
    	DB 004h	; 004h, from address 2b2h
    	DB 07Eh	; 07Eh, from address 2b3h
    	DB 0FEh	; 0FEh, from address 2b4h
    	DB 00Ah	; 00Ah, from address 2b5h
    	DB 0D2h	; 0D2h, from address 2b6h
    	DB 0BEh	; 0BEh, from address 2b7h
    	DB 002h	; 002h, from address 2b8h
    	DB 034h	; 034h, from address 2b9h
    	DB 0C6h	; 0C6h, from address 2bah
    	DB 020h	; 020h, from address 2bbh
    	DB 06Fh	; 06Fh, from address 2bch
    	DB 070h	; 070h, from address 2bdh
    	DB 03Ah	; 03Ah, from address 2beh
    	DB 00Fh	; 00Fh, from address 2bfh
    	DB 004h	; 004h, from address 2c0h
    	DB 0E6h	; 0E6h, from address 2c1h
    	DB 0C0h	; 0C0h, from address 2c2h
    	DB 0FEh	; 0FEh, from address 2c3h
    	DB 040h	; 040h, from address 2c4h
    	DB 0C2h	; 0C2h, from address 2c5h
    	DB 0A5h	; 0A5h, from address 2c6h
    	DB 002h	; 002h, from address 2c7h

L_02C8:
    	DB 021h	; 021h, from address 2c8h
    	DB 01Fh	; 01Fh, from address 2c9h
    	DB 004h	; 004h, from address 2cah
    	DB 04Eh	; 04Eh, from address 2cbh
    	DB 07Eh	; 07Eh, from address 2cch
    	DB 0B7h	; 0B7h, from address 2cdh
    	DB 0CAh	; 0CAh, from address 2ceh
    	DB 017h	; 017h, from address 2cfh
    	DB 000h	; 000h, from address 2d0h
    	DB 036h	; 036h, from address 2d1h
    	DB 000h	; 000h, from address 2d2h
    	DB 0C5h	; 0C5h, from address 2d3h
    	DB 0CDh	; 0CDh, from address 2d4h
    	DB 011h	; 011h, from address 2d5h
    	DB 003h	; 003h, from address 2d6h
    	DB 0C1h	; 0C1h, from address 2d7h
    	DB 011h	; 011h, from address 2d8h
    	DB 000h	; 000h, from address 2d9h
    	DB 005h	; 005h, from address 2dah
    	DB 023h	; 023h, from address 2dbh
    	DB 07Eh	; 07Eh, from address 2dch
    	DB 0E6h	; 0E6h, from address 2ddh
    	DB 00Fh	; 00Fh, from address 2deh
    	DB 047h	; 047h, from address 2dfh
    	DB 00Dh	; 00Dh, from address 2e0h
    	DB 0FAh	; 0FAh, from address 2e1h
    	DB 0F3h	; 0F3h, from address 2e2h
    	DB 002h	; 002h, from address 2e3h
    	DB 023h	; 023h, from address 2e4h
    	DB 07Eh	; 07Eh, from address 2e5h
    	DB 0E6h	; 0E6h, from address 2e6h
    	DB 00Fh	; 00Fh, from address 2e7h
    	DB 007h	; 007h, from address 2e8h
    	DB 007h	; 007h, from address 2e9h
    	DB 007h	; 007h, from address 2eah
    	DB 007h	; 007h, from address 2ebh
    	DB 0B0h	; 0B0h, from address 2ech
    	DB 00Dh	; 00Dh, from address 2edh
    	DB 012h	; 012h, from address 2eeh
    	DB 013h	; 013h, from address 2efh
    	DB 0C2h	; 0C2h, from address 2f0h
    	DB 0DBh	; 0DBh, from address 2f1h
    	DB 002h	; 002h, from address 2f2h
    	DB 021h	; 021h, from address 2f3h
    	DB 006h	; 006h, from address 2f4h
    	DB 005h	; 005h, from address 2f5h
    	DB 03Ah	; 03Ah, from address 2f6h
    	DB 0C4h	; 0C4h, from address 2f7h
    	DB 003h	; 003h, from address 2f8h
    	DB 047h	; 047h, from address 2f9h
    	DB 0EEh	; 0EEh, from address 2fah
    	DB 003h	; 003h, from address 2fbh
    	DB 077h	; 077h, from address 2fch
    	DB 0E5h	; 0E5h, from address 2fdh
    	DB 0E5h	; 0E5h, from address 2feh
    	DB 0E1h	; 0E1h, from address 2ffh
    	DB 0E1h	; 0E1h, from address 300h
    	DB 070h	; 070h, from address 301h
    	DB 0C3h	; 0C3h, from address 302h
    	DB 017h	; 017h, from address 303h
    	DB 000h	; 000h, from address 304h
    	DB 078h	; 078h, from address 305h
    	DB 0E6h	; 0E6h, from address 306h
    	DB 07Fh	; 07Fh, from address 307h
    	DB 00Eh	; 00Eh, from address 308h
    	DB 003h	; 003h, from address 309h
    	DB 021h	; 021h, from address 30ah
    	DB 0F5h	; 0F5h, from address 30bh
    	DB 003h	; 003h, from address 30ch
    	DB 0CDh	; 0CDh, from address 30dh
    	DB 04Eh	; 04Eh, from address 30eh
    	DB 001h	; 001h, from address 30fh
    	DB 0E9h	; 0E9h, from address 310h
    	DB 03Ah	; 03Ah, from address 311h
    	DB 005h	; 005h, from address 312h
    	DB 005h	; 005h, from address 313h
    	DB 0E6h	; 0E6h, from address 314h
    	DB 008h	; 008h, from address 315h
    	DB 0FEh	; 0FEh, from address 316h
    	DB 008h	; 008h, from address 317h
    	DB 0C0h	; 0C0h, from address 318h
    	DB 0E5h	; 0E5h, from address 319h
    	DB 023h	; 023h, from address 31ah
    	DB 07Eh	; 07Eh, from address 31bh
    	DB 02Fh	; 02Fh, from address 31ch
    	DB 077h	; 077h, from address 31dh
    	DB 00Dh	; 00Dh, from address 31eh
    	DB 0C2h	; 0C2h, from address 31fh
    	DB 01Ah	; 01Ah, from address 320h
    	DB 003h	; 003h, from address 321h
    	DB 0E1h	; 0E1h, from address 322h
    	DB 0C9h	; 0C9h, from address 323h
    	DB 03Ah	; 03Ah, from address 324h
    	DB 00Ch	; 00Ch, from address 325h
    	DB 004h	; 004h, from address 326h
    	DB 0B7h	; 0B7h, from address 327h
    	DB 0CAh	; 0CAh, from address 328h
    	DB 017h	; 017h, from address 329h
    	DB 000h	; 000h, from address 32ah
    	DB 078h	; 078h, from address 32bh
    	DB 0FEh	; 0FEh, from address 32ch
    	DB 070h	; 070h, from address 32dh
    	DB 0CAh	; 0CAh, from address 32eh
    	DB 06Dh	; 06Dh, from address 32fh
    	DB 003h	; 003h, from address 330h
    	DB 032h	; 032h, from address 331h
    	DB 001h	; 001h, from address 332h
    	DB 004h	; 004h, from address 333h
    	DB 0E6h	; 0E6h, from address 334h
    	DB 007h	; 007h, from address 335h
    	DB 04Fh	; 04Fh, from address 336h
    	DB 078h	; 078h, from address 337h
    	DB 0E6h	; 0E6h, from address 338h
    	DB 008h	; 008h, from address 339h
    	DB 03Ah	; 03Ah, from address 33ah
    	DB 007h	; 007h, from address 33bh
    	DB 004h	; 004h, from address 33ch
    	DB 0CAh	; 0CAh, from address 33dh
    	DB 042h	; 042h, from address 33eh
    	DB 003h	; 003h, from address 33fh
    	DB 0EEh	; 0EEh, from address 340h
    	DB 001h	; 001h, from address 341h
    	DB 0E6h	; 0E6h, from address 342h
    	DB 001h	; 001h, from address 343h
    	DB 00Fh	; 00Fh, from address 344h
    	DB 00Ch	; 00Ch, from address 345h
    	DB 007h	; 007h, from address 346h
    	DB 00Dh	; 00Dh, from address 347h
    	DB 0C2h	; 0C2h, from address 348h
    	DB 046h	; 046h, from address 349h
    	DB 003h	; 003h, from address 34ah
    	DB 032h	; 032h, from address 34bh
    	DB 00Bh	; 00Bh, from address 34ch
    	DB 004h	; 004h, from address 34dh
    	DB 021h	; 021h, from address 34eh
    	DB 007h	; 007h, from address 34fh
    	DB 004h	; 004h, from address 350h
    	DB 07Eh	; 07Eh, from address 351h
    	DB 0F6h	; 0F6h, from address 352h
    	DB 008h	; 008h, from address 353h
    	DB 077h	; 077h, from address 354h
L_0355:
    	DB 021h	; 021h, from address 355h
    	DB 004h	; 004h, from address 356h
    	DB 007h	; 007h, from address 357h
    	DB 036h	; 036h, from address 358h
    	DB 000h	; 000h, from address 359h
    	DB 021h	; 021h, from address 35ah
    	DB 002h	; 002h, from address 35bh
    	DB 007h	; 007h, from address 35ch
    	DB 03Ah	; 03Ah, from address 35dh
    	DB 00Bh	; 00Bh, from address 35eh
    	DB 004h	; 004h, from address 35fh
    	DB 077h	; 077h, from address 360h
    	DB 023h	; 023h, from address 361h
    	DB 036h	; 036h, from address 362h
    	DB 000h	; 000h, from address 363h
    	DB 02Eh	; 02Eh, from address 364h
    	DB 007h	; 007h, from address 365h
    	DB 03Ah	; 03Ah, from address 366h
    	DB 007h	; 007h, from address 367h
    	DB 004h	; 004h, from address 368h
    	DB 077h	; 077h, from address 369h
    	DB 0C3h	; 0C3h, from address 36ah
    	DB 01Fh	; 01Fh, from address 36bh
    	DB 000h	; 000h, from address 36ch
    	DB 0AFh	; 0AFh, from address 36dh
    	DB 032h	; 032h, from address 36eh
    	DB 001h	; 001h, from address 36fh
    	DB 004h	; 004h, from address 370h
    	DB 021h	; 021h, from address 371h
    	DB 007h	; 007h, from address 372h
    	DB 004h	; 004h, from address 373h
    	DB 07Eh	; 07Eh, from address 374h
    	DB 0E6h	; 0E6h, from address 375h
    	DB 0F7h	; 0F7h, from address 376h
    	DB 077h	; 077h, from address 377h
    	DB 0C3h	; 0C3h, from address 378h
    	DB 017h	; 017h, from address 379h
    	DB 000h	; 000h, from address 37ah
    	DB 03Ah	; 03Ah, from address 37bh
    	DB 007h	; 007h, from address 37ch
    	DB 004h	; 004h, from address 37dh
    	DB 0E6h	; 0E6h, from address 37eh
    	DB 002h	; 002h, from address 37fh
    	DB 0CAh	; 0CAh, from address 380h
    	DB 017h	; 017h, from address 381h
    	DB 000h	; 000h, from address 382h
    	DB 078h	; 078h, from address 383h
    	DB 032h	; 032h, from address 384h
    	DB 00Ch	; 00Ch, from address 385h
    	DB 004h	; 004h, from address 386h
    	DB 0C3h	; 0C3h, from address 387h
    	DB 017h	; 017h, from address 388h
    	DB 000h	; 000h, from address 389h
    	DB 0FFh	; 0FFh, from address 38ah
    	DB 0FFh	; 0FFh, from address 38bh
    	DB 0FFh	; 0FFh, from address 38ch
    	DB 0FFh	; 0FFh, from address 38dh
    	DB 0FFh	; 0FFh, from address 38eh
    	DB 0FFh	; 0FFh, from address 38fh
    	DB 000h	; 000h, from address 390h
    	DB 002h	; 002h, from address 391h
    	DB 005h	; 005h, from address 392h
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
    	DB 00Bh	; 00Bh, from address 3b3h
    	DB 01Fh	; 01Fh, from address 3b4h
    	DB 004h	; 004h, from address 3b5h
    	DB 00Ah	; 00Ah, from address 3b6h
    	DB 000h	; 000h, from address 3b7h
    	DB 000h	; 000h, from address 3b8h
    	DB 000h	; 000h, from address 3b9h
    	DB 000h	; 000h, from address 3bah
    	DB 000h	; 000h, from address 3bbh
    	DB 000h	; 000h, from address 3bch
    	DB 000h	; 000h, from address 3bdh
    	DB 000h	; 000h, from address 3beh
    	DB 000h	; 000h, from address 3bfh
    	DB 000h	; 000h, from address 3c0h
    	DB 001h	; 001h, from address 3c1h
    	DB 006h	; 006h, from address 3c2h
    	DB 005h	; 005h, from address 3c3h
    	DB 006h	; 006h, from address 3c4h
    	DB 002h	; 002h, from address 3c5h
    	DB 006h	; 006h, from address 3c6h
    	DB 006h	; 006h, from address 3c7h
    	DB 002h	; 002h, from address 3c8h
    	DB 000h	; 000h, from address 3c9h
    	DB 006h	; 006h, from address 3cah
    	DB 002h	; 002h, from address 3cbh
    	DB 007h	; 007h, from address 3cch
    	DB 000h	; 000h, from address 3cdh
    	DB 000h	; 000h, from address 3ceh
    	DB 080h	; 080h, from address 3cfh
    	DB 000h	; 000h, from address 3d0h
    	DB 000h	; 000h, from address 3d1h
    	DB 000h	; 000h, from address 3d2h
    	DB 000h	; 000h, from address 3d3h
    	DB 030h	; 030h, from address 3d4h
    	DB 031h	; 031h, from address 3d5h
    	DB 032h	; 032h, from address 3d6h
    	DB 033h	; 033h, from address 3d7h
    	DB 034h	; 034h, from address 3d8h
    	DB 035h	; 035h, from address 3d9h
    	DB 036h	; 036h, from address 3dah
    	DB 037h	; 037h, from address 3dbh
    	DB 038h	; 038h, from address 3dch
    	DB 039h	; 039h, from address 3ddh
    	DB 02Bh	; 02Bh, from address 3deh
    	DB 02Dh	; 02Dh, from address 3dfh
    	DB 02Eh	; 02Eh, from address 3e0h
    	DB 02Ch	; 02Ch, from address 3e1h
    	DB 045h	; 045h, from address 3e2h
    	DB 020h	; 020h, from address 3e3h
    	DB 080h	; 080h, from address 3e4h
    	DB 080h	; 080h, from address 3e5h
    	DB 080h	; 080h, from address 3e6h
    	DB 080h	; 080h, from address 3e7h
    	DB 080h	; 080h, from address 3e8h
    	DB 080h	; 080h, from address 3e9h
    	DB 080h	; 080h, from address 3eah
    	DB 080h	; 080h, from address 3ebh
    	DB 080h	; 080h, from address 3ech
    	DB 080h	; 080h, from address 3edh
    	DB 00Dh	; 00Dh, from address 3eeh
    	DB 00Ah	; 00Ah, from address 3efh
    	DB 019h	; 019h, from address 3f0h
    	DB 000h	; 000h, from address 3f1h
    	DB 000h	; 000h, from address 3f2h
    	DB 000h	; 000h, from address 3f3h
    	DB 019h	; 019h, from address 3f4h
    	DB 00Dh	; 00Dh, from address 3f5h
    	DB 0C8h	; 0C8h, from address 3f6h
    	DB 002h	; 002h, from address 3f7h
    	DB 00Ah	; 00Ah, from address 3f8h
    	DB 0C8h	; 0C8h, from address 3f9h
    	DB 002h	; 002h, from address 3fah
    	DB 02Ch	; 02Ch, from address 3fbh
    	DB 0C8h	; 0C8h, from address 3fch
    	DB 002h	; 002h, from address 3fdh
    	DB 0A5h	; 0A5h, from address 3feh
    	DB 002h	; 002h, from address 3ffh
