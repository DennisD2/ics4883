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
L_0006:
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
    	LDA     0407h           ; 3A 07 04 from address 13ch
    	ANI     02h             ; E6 02 from address 13fh
    	JZ      L_0017          ; CA 17 00 from address 141h
    	JMP     L_0006          ; C3 06 00 from address 144h
    	XRA     A               ; AF from address 147h
    	STA     040Dh           ; 32 from address 148h
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
        LDA     0403h           ; 3A 03 04 -> Lädt Zustand aus RAM-Zelle 0403h
        ANI     10h             ; E6 10    -> Bit 4 maskieren
        MOV     C, A            ; 4F       -> In Register C zwischenspeichern
        LXI     D, 0703h        ; 11 03 07 -> Richtet DE auf physische Hardwareadresse 0703h aus
        MVI     A, 04h          ; 3E 04    -> Lädt Konstante 04h in den Akkumulator
        ORA     C               ; B1       -> Logisches ODER mit Register C verknüpfen
        STAX    D               ; 12       -> Akkumulator an Hardwareadresse [DE] ausgeben
        MVI     A, 80h          ; 3E 80    -> Status-Flag 80h in den Akkumulator laden
        STA     0704h           ; 32 04 07 -> Zustand direkt im I/O-Register 0704h sichern
        LXI     H, 0701h        ; 21 01 07 -> Richtet HL auf das I/O-Statusregister 0701h aus
L_0178:
        LDA     0405h           ; 3A 05 04 -> Lädt Kontrollwert aus RAM 0405h
    	XRA     M               ; AE from address 17bh
    	JM      L_01A9          ; FA A9 01 -> Wenn negativ (Sign-Flag=1), springe vor zu 0191h
        MOV     A, M            ; 7E       -> Byte direkt aus der Hardware [HL] laden
        ANI     01h             ; E6 01    -> Bit 0 maskieren
        JZ      L_0178          ; CA 78 01 -> Wenn Null, springe zurück zu Adresse 0178h (Schleife!)
        LDA     0405h           ; 3A 05 04 -> Erneut RAM-Wert 0405h laden
    	XRA     M               ; AE from address 188h
    	JM      L_01A9          ; FA A9 01 -> Wenn negativ, springe vor zu Adresse 01A9h
        MVI     A, 06h          ; 3E 06    -> Konstante 06h laden
        ORA     C               ; B1       -> Logisches ODER mit Register C
        STAX    D               ; 12       -> An Hardware [DE] ausgeben
        MOV     A, M            ; 7E       -> Byte aus Hardware [HL] holen
        STA     040Fh           ; 32 0F 04 -> Empfangenes Datenbyte im RAM 040Fh sichern
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
        STA     0403h           ; 32 03 04 -> Finalen Zustand in RAM-Zelle 0403h zurückschreiben
        RET                     ; C9       -> Unterprogramm sauber beenden (Rücksprung)

L_01A9:
        ; ------------------------------------------------------------------------------
        ; Stack aufräumen & Treiber-Rücksprung (Adresse 01A9h - 01ACh)
        ; ------------------------------------------------------------------------------
        POP     H               ; E1       -> Holt das Registerpaar HL vom Stack zurück
        JMP     L_0017          ; C3 17 00 -> Unbedingter Sprung zur Systemadresse 00FBh

L_01AD:
    	EI                      ; FB from address 1adh
    	LDA     040Dh           ; 3A 0D 04 -> Lädt Kontroll-Flag aus RAM-Zelle
    	ORA     A               ; B7       -> Prüft, ob der Wert im Akkumulator Null ist
    	JNZ     L_0232          ; C2 32 02 -> Wenn ungleich Null, springe weit vor zu Adresse 0232h
        LXI     H, 0605h        ; 21 05 06 -> HL-Zeiger auf I/O-Datenregister 0605h ausrichten
L_01B8:
        MOV     A, M            ; 7E       -> Holt das aktuelle Datenbyte via HL
    	RRC                     ; 0F from address 1b9h
        JC      L_01B8          ; DA B8 01 -> Wenn Carry=1, springe zu Adresse 01B8h
        DI                      ; F3       -> Interrupts sperren (Disable Interrupts)
        LXI     D, 0430h        ; 11 30 04 -> Registerpaar DE mit SRAM-Adresse 0430h laden
        LXI     H, 0604h        ; 21 04 06 -> HL-Zeiger auf I/O-Schnittstellenregister 0604h ausrichten
    	CALL    L_0242          ; CD 42 02 -> Ruft Unterfunktion an Adresse 0242h auf
    	MVI     A, 0Fh          ; 3E 0F    -> Lädt die Konstante 0Fh in den Akkumulator
        ; ------------------------------------------------------------------------------
        ; SRAM-Puffer-Verwaltung & Bitmaskierung (Adresse 01C9h - 01F5h)
        ; ------------------------------------------------------------------------------
        STA     0400h           ; 32 00 04 -> Akkumulator-Inhalt direkt in RAM 0400h sichern
        EI                      ; FB       -> Interrupts wieder freigeben (Enable Interrupts)
        LXI     H, 0430h        ; 21 30 04 -> HL-Zeiger auf SRAM-Adresse 0430h laden
        SHLD    042Eh           ; 22 2E 04 -> Speicherinhalt von HL nach SRAM 042Eh sichern
        LXI     H, 03E4h        ; 21 E4 03 -> HL-Zeiger auf Übersetzungstabelle im ROM ausrichten
L_01D6:
        MOV     A, M            ; 7E       -> Byte via HL laden
        INX     H               ; 23       -> HL-Zeiger um 1 erhöhen
        SHLD    041Dh           ; 22 1D 04 -> Aktuellen HL-Zeiger im RAM 041Dh sichern
        CPI     19h             ; FE 19    -> Akkumulator mit Konstante 19h vergleichen

        JZ      L_0017          ; CA 17 00 -> Wenn gleich, springe weit zurück zu Adresse 0017h
        ORA     A               ; B7       -> Flags aktualisieren (Prüfen auf Null/Vorzeichen)
        JP      L_01F0          ; F2 F0 01 -> Wenn positiv (Bit 7 = 0), springe vor zu Adresse 01F0h
        ANI     040h            ; E6 40    -> Bit 6 maskieren
        ORA     C               ; B1       -> Logisches ODER mit Register C verknüpfen
        MOV     C, A            ; 4F       -> In Register C sichern (AS-Syntax für MOV C,A)
        LHLD    042Eh           ; 2A 2E 04 -> HL-Registerinhalt im SRAM 042Ah sichern
        MOV     A, M            ; 7E       -> Byte erneut via HL laden
        INX     H               ; 23       -> HL-Zeiger um 1 erhöhen
        SHLD    042Eh           ; 22 2E 04 -> HL-Registerinhalt im SRAM 042Eh sichern
L_01F0:
        MOV     B, A            ; 47       -> Byte in Register B sichern
L_01F1:
        LDA     0403h           ; 3A 03 04 -> Zustand aus RAM-Zelle 0403h holen
        ANI     10h             ; E6 10    -> Bit 4 maskieren
        MOV     C, A            ; 4F       -> Vorheriges Ergebnis nach Register C retten
        LXI     D,0703h         ; 11 03 07 -> Lädt Byte von der Hardware-Adresse [DE] (0703h)
        STAX    D               ; 12           -> Schreibt den Akkumulator wieder zurück nach [DE]
        LXI     H, 00702h       ; 21 02 07 -> HL auf Adresse 0702h ausrichten
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
        STA     0403h           ; 32 03 04 -> Systemzustand in RAM 0403h löschen
        LXI     H, 0400h        ; 21 00 04 -> HL auf RAM-Start 0400h setzen
        MOV     A, M            ; 7E
        MVI     M, 00h          ; 36 00    -> Speicherzelle mit 00h überschreiben
        ORA     A               ; B7       -> Flags aktualisieren
        JM      L_0017          ; FA 17 00 -> Wenn negativ (Bit 7=1), Sprung zu L_0017
        JZ      L_022B          ; CA 2B 02 -> Wenn Null, Sprung zu RAM/ROM-Adresse 022Bh
        XRA     A               ; AF
        STA     0607h           ; 32 07 06
        STA     040Eh           ; 32 0E 04
L_022B:
        EI                      ; FB       -> Interrupts wieder freigeben
        LHLD    041Dh           ; 2A 1D 04
        JMP     L_01D6          ; C3 D6 01 -> Sprung zu RAM/ROM-Adresse 01D6h
L_0232:
        MVI     A, 0FFh         ; 3E FF
        STA     0400h           ; 32 00 04
        LXI     H, 040Eh        ; 21 0E 04 -> HL auf Kontrollregister setzen
        MOV     B, M            ; 46
        MOV     A, M            ; 7E
        ANI     0BFh            ; E6 BF    -> Bit 6 löschen (Maskierung)
        MOV     M, A            ; 77
        JMP     L_01F1          ; C3 F1 01 -> Sprung zu RAM/ROM-Adresse 01F1h
L_0242:
        MVI     B, 05h          ; 06 05    -> Schleifenzähler (5) in Register B laden
L_0244:
        MOV     A, M            ; 7E       -> Byte über HL-Zeiger (0604h) laden
        RRC                     ; 0F       -> Bit-Verschiebungen / Rotation
        RRC                     ; 0F
        RRC                     ; 0F
        RRC                     ; 0F
        CALL    L_0256          ; CD 56 02 -> Unterfunktion an ROM-Adresse 0256h aufrufen
        MOV     A, M            ; 7E       -> Dasselbe Byte nochmals laden
        CALL    L_0256          ; CD 56 02 -> Unterfunktion an ROM-Adresse 0256h aufrufen
        DCX     H               ; 2B       -> HL-Zeiger dekrementieren
        DCR     B               ; 05       -> Schleifenzähler verringern
        JNZ     L_0244          ; C2 44 02 -> Schleife wiederholen, wenn Register B ungleich Null
        RET                     ; C9       -> Unterprogramm beenden

; Diese Funktion ist eine Konvertierungs- und Filter-Routine für Datenzeichen
; (ASCII/Hex), die von den I/O-Schnittstellen des Geräts eingelesen wurden.
; Sie entscheidet anhand eines Hardware-Statusbits, ob ein Datenwert invertiert
; und über eine Zeichentabelle im ROM übersetzt wird, oder ob es sich um ein
; Steuersignal handelt, das das System beeinflusst.
L_0256:
        MOV     C, A            ; 4F       -> Akkumulator in Register C sichern
        LDA     0605h           ; 3A 05 06 -> Status/Datenbyte aus I/O-SRAM laden
        ANI     04h             ; E6 04    -> Bit 2 isolieren
        CPI     04h             ; FE 04    -> Mit 04h vergleichen
        MOV     A, C            ; 79       -> Gesichertes Byte zurück nach A holen
        JZ      L_0263          ; CA 63 02 -> Wenn Vergleich gleich (Zero=1), Sprung zu 0263h
        CMA                     ; 2F       -> Akkumulator invertieren
L_0263:
        ANI     0Fh             ; E6 0F    -> Die unteren 4 Bits maskieren
        PUSH    H               ; E5       -> HL-Registerpaar auf dem Stack sichern
        LXI     H, 03D4h        ; 21 D4 03 -> HL auf Übersetzungstabelle im ROM ausrichten
        ADD     L               ; 85       -> Offset zu L addieren
        MOV     L, A            ; 6F       -> Ergebnis zurück in L (indirekte Adressierung)
        MOV     A, M            ; 7E       -> Übersetztes Zeichen aus der ROM-Tabelle holen
        STAX    D               ; 12       -> Zeichen an Zieladresse [DE] (0430hff) wegsichern
        INX     D               ; 13       -> Zielzeiger erhöhen
        POP     H               ; E1       -> HL vom Stack wiederherstellen
        RET                     ; C9       -> Unterprogramm beenden

; Steuerzeichen Filter
        LXI     H, 0390h        ; 21 90 03 -> HL auf alternative Tabelle/String im ROM ausrichten
        MOV     A, B            ; 78       -> Register B (04h) nach A holen
        ANI     01Fh            ; E6 1F    -> 5-Bit-Maskierung
        CMP     M               ; BE       -> Mit Speicherwert [HL] vergleichen
        JNZ     L_0017          ; C2 17 00 -> Bei Ungleichheit harter Sprung zurück zu L_0017
        LXI     H, 0407h        ; 21 07 04 -> HL auf RAM-Adresse 0407h setzen
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
        LDA     0407h           ; 3A 07 04 -> Lädt den Gerätestatus aus dem RAM
        ANI     02h             ; E6 02    -> Bit 1 maskieren (z. B. Remote/Local oder ein Bus-Flag)
        JZ      L_0017          ; CA 17 00 -> Wenn Bit 0 ist, Schleife abbrechen und zurück zu L_0017
        LXI     H, 0607h        ; 21 07 06 -> HL auf Ausgangs-Datenregister ausrichten
        MOV     M, A            ; 77       -> Den maskierten Statuswert direkt dorthin schreiben
        DCX     H               ; 2B       -> HL dekrementieren auf 0606h
        LDA     03C8h           ; 3A C8 03 -> Einen Konfigurations- oder Initialisierungswert aus dem ROM laden
        JMP     L_02F9          ; C3 F9 02 -> Sprung zur weiteren Registerverarbeitung an Adresse 02F9h

; Daten-Empfang und Indizierung: Dieser Block verarbeitet ankommende Bus-Zeichen. Er nutzt die RAM-Zelle 041Fh als Index-Zähler (limitiert auf maximal 10 Zeichen, CPI 00Ah).
; Dynamische Puffer-Adressierung: Durch ADI 020h und MOV L, A berechnet der Code zur Laufzeit eine Zieladresse im RAM (ein sogenanntes indiziertes Array), um die eingehenden Zeichen nacheinander geordnet abzuspeichern.
; Protokoll-Validierung: Am Ende wird über das RAM-Register 040Fh ausgewertet, ob der Bus ein Übertragungsende signalisiert (CPI 040h).
L_029D:
        XRA   A           ; AF       -> Akkumulator nullen
        STA   0405h       ; 32 05 04 -> Systemregister 0405h im RAM zurücksetzen
        STA   0702h       ; 32 02 07 -> Interface-Register 0702h löschen
        DI                ; F3       -> Interrupts global sperren
        CALL  L_0163      ; CD 63 01 -> Aufruf der Puffer-/Schnittstellenroutine L_0163
        MOV   A, B        ; 78       -> Das in Register B befindliche Zeichen nach A holen
        ANI   070h        ; E6 70    -> Die Bits 4, 5 und 6 maskieren
        CPI   030h        ; FE 30    -> Prüfen, ob das obere Halbnibble dem ASCII-Bereich '3' entspricht
        JNZ   0305h       ; C2 05 03 -> Wenn ungleich, Sprung nach vorne zur Fehler/Auswertung an 0305h
        LXI   H, 041Fh    ; 21 1F 04 -> HL auf RAM-Adresse 041Fh (Zähler/Index) setzen
        MOV   A, M        ; 7E       -> Aktuellen Index-Wert laden
        CPI   00Ah        ; FE 0A    -> Prüfen, ob die Obergrenze von 10 Elementen erreicht ist
        JNC   02BEh       ; D2 BE 02 -> Wenn der Index >= 10 ist, direkt vor zu 02BEh springen
        INR   M           ; 34       -> Ansonsten den Index im RAM [HL] um 1 erhöhen
        ADI   020h        ; C6 20    -> Offset 20h zum Akkumulator addieren
        MOV   L, A        ; 6F       -> Berechneten Offset nach Register L übertragen
        MOV   M, B        ; 70       -> Das originale Zeichen aus B an die berechnete RAM-Adresse schreiben
        LDA   040Fh       ; 3A 0F 04 -> Empfangenes Datenbyte aus RAM 040Fh holen
        ANI   0C0h        ; E6 C0    -> Die obersten zwei Bits maskieren
        CPI   040h        ; FE 40    -> Prüfen auf das End-Of-Sequence / EOI Flag (40h)
        JNZ   02A5h       ; C2 A5 02 -> Sprung wenn != 0
; ------------------------------------------------------------------------------
; Hauptinitialisierung ab Label L_02C8 (Adresse 02C8h bis 02F8h)
; Nibble-Packing Routine: Der Code ab Adresse 02DBh ist ein hocheffizienter Packer. Er nimmt zwei aufeinanderfolgende Bytes, isoliert jeweils deren untere 4 Bits (ANI 00Fh), schiebt das zweite Nibble per Rotation nach oben (RLC) und fügt sie mit ORA B zu einem einzigen, kompakten Daten-Byte zusammen.
; SRAM-Transfer: Diese gepackten Daten werden sequenziell direkt in den System-SRAM ab Adresse 0500h übertragen (STAX D).
; ------------------------------------------------------------------------------
L_02C8:
        LXI   H, 041Fh    ; 21 1F 04 -> HL auf RAM-Adresse 041Fh (Index-Zähler) setzen
        MOV   C, M        ; 4E       -> Aktuellen Zählerwert nach Register C laden
        MOV   A, M        ; 7E       -> Wert zusätzlich in den Akkumulator laden
        ORA   A           ; B7       -> Prüfen, ob der Zähler Null ist
        JZ    L_0017      ; CA 17 00 -> Wenn Null, keine Daten da -> zurück zum Haupt-Polling
        MVI   M, 00h      ; 36 00    -> Zähler im RAM wieder auf Null zurücksetzen
        PUSH  B           ; C5       -> Registerpaar BC auf dem Stack sichern
        CALL  0311h       ; CD 11 03 -> Unterprogramm an Adresse 0311h aufrufen (Puffer-Check)
        POP   B           ; C1       -> Registerpaar BC wieder herstellen
        LXI   D, 0500h    ; 11 00 05 -> DE auf Zieladresse im SRAM 0500h ausrichten
        INX   H           ; 23       -> HL-Zeiger erhöhen
        MOV   A, M        ; 7E       -> Byte aus dem Quellpuffer laden
        ANI   00Fh        ; E6 0F    -> Die unteren 4 Bits (unteres Nibble) maskieren
        MOV   B, A        ; 47       -> Nibble in Register B zwischenspeichern
        DCR   C           ; 0D       -> Schleifenzähler C dekrementieren
        JM    02F3h       ; FA F3 02 -> Wenn Zähler negativ wird, Schleife abbrechen nach 02F3h
        INX   H           ; 23       -> HL-Zeiger für das nächste Byte erhöhen
        MOV   A, M        ; 7E       -> Nächstes Byte laden
        ANI   00Fh        ; E6 0F    -> Die unteren 4 Bits maskieren
        RLC               ; 07       -> Viermal nach links rotieren, um das Nibble...
        RLC               ; 07
        RLC               ; 07
        RLC               ; 07       ; ...in das obere Halbnibble zu verschieben
        ORA   B           ; B0       -> Die beiden Nibbles zu einem vollen Byte zusammenführen
        DCR   C           ; 0D       -> Schleifenzähler C erneut dekrementieren
        STAX  D           ; 12       -> Das fertige Byte an die SRAM-Zieladresse [DE] schreiben
        INX   D           ; 13       -> SRAM-Zielzeiger DE um 1 erhöhen
        JNZ   02DBh       ; C2 DB 02 -> Wenn Schleifenzähler C noch nicht Null, nächstes Byte holen
        LXI   H, 0506h    ; 21 06 05 -> HL auf SRAM-Adresse 0506h ausrichten
        LDA   03C4h       ; 3A C4 03 -> Konfigurationswert aus dem ROM laden
L_02F9:
; ------------------------------------------------------------------------------
; Fortsetzung ab Adresse 02F9h bis 0323h
; Dynamische Fehlerbehandlung (0305h): Wenn die Daten zuvor nicht den Erwartungen entsprechen, wird hier das fehlerhafte Zeichen isoliert (ANI 07Fh) und über eine separate Befehlstabelle ab ROM-Adresse 03F5h mittels deiner Suchroutine L_014E ausgewertet. Der Befehl PCHL springt dann dynamisch in die passende Behandlung.
; Puffer-Invertierung (0311h): Dieses Unterprogramm prüft ein Hardware-Statusflag an Adresse 0505h. Ist dieses aktiv (CPI 08h), durchläuft der Code eine Schleife (L_031A), die den gesamten Datenstrom im RAM bitweise invertiert (CMA). Dies deutet stark auf eine Pegel-Anpassung für die angeschlossene Hardware hin.
; ------------------------------------------------------------------------------
        MOV   B, A        ; 47       -> Gekoppelt mit LDA 03C4h aus dem Vorblock
        XRI   03h         ; EE 03    -> Maskierung mit 03h
        MOV   M, A        ; 77       -> Zurückschreiben nach RAM [0506h]
        PUSH  H           ; E5       -> Registerpaare sichern/manipulieren
        PUSH  H           ; E5
        POP   H           ; E1
        POP   H           ; E1
        MOV   M, B        ; 70
        JMP   L_0017      ; C3 17 00 -> Unbedingter Rücksprung zum Haupt-Polling

L_0305:
        MOV   A, B        ; 78       -> Hierher wird gesprungen, wenn ASCII-Prüfung bei 02A2h fehlschlägt
        ANI   07Fh        ; E6 7F    -> Auf 7-Bit-ASCII maskieren
        MVI   C, 03h      ; 0E 03    -> Schleifenzähler (3) für die Tabelle setzen
        LXI   H, 03F5h    ; 21 F5 03 -> HL auf Sprungtabelle im ROM ausrichten
        CALL  L_014E      ; CD 4E 01 -> Tabellen-Suchroutine aufrufen
        PCHL              ; E9       -> Indirekter Sprung zur gefundenen Routine

; Unterprogramm ab Adresse 0311h (Puffer-Prüfung, aufgerufen bei 02D4h)
L_0311:
        LDA   0505h       ; 3A 05 05 -> Byte aus dem I/O-SRAM-Status laden
        ANI   08h         ; E6 08    -> Bit 3 isolieren
        CPI   08h         ; FE 08    -> Prüfen, ob Bit gesetzt ist
        RNZ               ; C0       -> Wenn nicht gesetzt, vorzeitig zurückkehren
        PUSH  H           ; E5       -> HL-Zeiger sichern
L_031A:
        INX   H           ; 23       -> Zeiger im Puffer erhöhen
        MOV   A, M        ; 7E       -> Byte laden
        CMA               ; 2F       -> Bitweise invertieren
        MOV   M, A        ; 77       -> Invertiertes Byte zurückschreiben
        DCR   C           ; 0D       -> Schleifenzähler verringern
        JNZ   L_031A      ; C2 1A 03 -> Schleife wiederholen, bis C=0
        POP   H           ; E1       -> HL-Zeiger wiederherstellen
        RET               ; C9       -> Unterprogramm sauber beenden

L_0324:
        LDA   040Ch       ; 3A 0C 04 -> Lädt den Inhalt der RAM-Adresse 040Ch in den Akkumulator
        ORA   A           ; B7       -> Setzt die Flags (Zero/Sign) basierend auf dem Akkumulator
        JZ    L_0017      ; CA 17 00 -> Wenn der Wert Null ist, Sprung zurück zum Haupt-Polling L_0017
        MOV   A, B        ; 78       -> Holt den Wert aus Register B zurück nach A
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
