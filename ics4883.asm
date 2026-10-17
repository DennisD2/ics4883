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
        JMP     02C8h           ; C3 C8 02 -> Sprung in die Hauptinitialisierung

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

        CALL    00ADh           ; CD AD 00 -> Ruft Subroutine an Adresse 00ADh auf
        MVI     C, 0FEh         ; 0E FE    -> Lädt Konstante 0FEh in Register C
        CALL    00A1h           ; CD A1 00 -> Ruft Subroutine an Adresse 00A1h auf
        LDA     0706h           ; 3A 06 07 -> Lädt den Status aus dem Talker-Register 0706h

        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        JMP     003Ch           ; C3 3C 00 -> Unbedingter Sprung zur Routine 003Ch
        POP     H               ; E1       -> Registerpaar HL vom Stack holen (Stack aufräumen)
        JMP     L_00CE          ; C3 CE 00 -> Sprung zur Service-Routine L_00CE
        CC      009Ch           ; DC 9C 00 -> Bedingter Unterprogramm-Aufruf, wenn Carry-Flag = 1
        LXI     H, 0407h        ; 21 07 04 -> Register HL mit Adresse 0407h laden
    	MOV     A,M             ; 7E
    	RRC                     ; 0F
    	RRC                     ; 0F
        JC      029Dh           ; DA 9D 02 -> Wenn Carry=1, springe zu Adresse 029Dh
        RRC                     ; 0F       -> Akkumulator nach rechts rotieren
        JC      01ADh           ; DA AD 01 -> Wenn Carry=1, springe zu Adresse 01ADh
        LXI     B,01000h        ; 01 00 10 -> lade 01000h in B
        LDA     0605h           ; 3A 05 06 -> Holt das Daten-Byte vom I/O-Schnittstellenregister
    	CMA                     ; 2F       -> Akkumulator invertieren (Low-Aktive Signale)
    	RRC                     ; 0F       -> Bit nach rechts rotieren
    	JNC     0060h           ; D2 60 00 -> Wenn kein Carry, springe vor zu Adresse 0060h
    	CALL    00C7h           ; CD C7 00 -> Unterfunktion an Adresse 00C7h ausf
        JC      006Dh           ; DA 6D 00 -> Wenn Carry=1, springe zu Adresse 006Dh
        STA     0607h           ; 32 07 06 -> Berechneten Zustand im RAM 0607h sichern
    	LXI     H, 0403h        ; 21 03 04 -> HL-Zeiger auf I/O-Schnittstelle 0403h ausrichten
    	MOV     A,M             ; 7E from byte 63h
    	ANA     B               ; A0 from byte 64h
    	ORA     C               ; B1 from byte 65h
    	MOV     M,A             ; 77 from byte 66h
    	STA     00703h          ; Zwischenspeichern des aktuellen I/O-Status
    	JMP     0017h           ; C3 17 00  back to loop start

; ------------------------------------------------------------------------------
; Ausgelagerter Talker-Status-Handler (Deine Zeilen 68-74)
; ------------------------------------------------------------------------------
        LXI     H, 040Eh        ; 21 0E 04 -> HL auf Register 040Eh (GPIB/Bus-Steuerung) ausrichten
        MOV     A, M            ; 7E       -> Status-Byte aus 040Eh in den Akkumulator laden
        RRC                     ; 0F       -> Nach rechts rotieren (Bit-Prüfung)
        JC      0060h           ; DA 60 00 -> Wenn Carry=1, springe vor zu Adresse 0060h
        MVI     M, 41h          ; 36 41    -> Schreibe den Wert 41h (ASCII 'A') nach 040Eh
        MOV     C, B            ; 48       -> Kopiere Register B nach C
        JMP     0060h           ; C3 60 00 -> Unbedingter Sprung vor zu Adresse 0060h

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
L_00C9:
        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        RLC                     ; 07       -> Nochmals nach links rotieren
        RLC                     ; 07       -> Ein drittes Mal nach links rotieren
    	MVI     C, 0F9h         ; 0E F9    -> Lädt die Konstante 0F9h (mask 11111001b) direkt in Register C
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
        JNZ     00C5h           ; C2 C5 00 -> Wenn ungleich, springe vor zu Adresse 00C5h
        INX     H               ; 23       -> HL-Zeiger auf das nächste Tabellenbyte erhöhen
        LDA     0505h           ; 3A 05 05 -> weiteres I/O-Datenbyte einlesen
        CMA                     ; 2F       -> Invertieren
        ANI     07h             ; E6 07    -> Die untersten 3 Bits maskieren
        CMP     M               ; BE       -> Mit dem nächsten Tabellenwert im ROM vergleichen
        MVI     A, 01h          ; 3E 01    -> Lade Konstante 01h in den Akkumulator
        RZ                      ; C8       -> Bedingter Rücksprung, wenn der Vergleich gleich war (Zero-Flag = 1)
        XRA     A               ; AF       -> Akkumulator löschen (A = 0)
    	RET                     ; C9

L_00C7:
    	LDA     0705h           ; 3A 07 05 -> Statuswert aus dem SRAM-Bereich laden
        RLC                     ; 07       -> Akkumulatorinhalt nach links rotieren
        RLC                     ; 07       -> Nochmals nach links rotieren
        RLC                     ; 07       -> Ein drittes Mal nach links rotieren
    	RET                     ; C9       -> Unterprogramm beenden (Rücksprung)

L_00CE:
    	DB 03Eh	; 03Eh, from byte ceh
    	DB 080h	; 080h, from byte cfh
    	DB 032h	; 032h, from byte d0h
    	DB 005h	; 005h, from byte d1h
    	DB 004h	; 004h, from byte d2h
    	DB 0AFh	; 0AFh, from byte d3h
    	DB 032h	; 032h, from byte d4h
    	DB 002h	; 002h, from byte d5h
    	DB 007h	; 007h, from byte d6h
    	DB 0CDh	; 0CDh, from byte d7h
    	DB 063h	; 063h, from byte d8h
    	DB 001h	; 001h, from byte d9h
    	DB 03Ah	; 03Ah, from byte dah
    	DB 006h	; 006h, from byte dbh
    	DB 007h	; 007h, from byte dch
    	DB 007h	; 007h, from byte ddh
    	DB 0DAh	; 0DAh, from byte deh
    	DB 017h	; 017h, from byte dfh
    	DB 000h	; 000h, from byte e0h
    	DB 078h	; 078h, from byte e1h
    	DB 0E6h	; 0E6h, from byte e2h
    	DB 07Fh	; 07Fh, from byte e3h
    	DB 047h	; 047h, from byte e4h
    	DB 0E6h	; 0E6h, from byte e5h
    	DB 060h	; 060h, from byte e6h
    	DB 0FEh	; 0FEh, from byte e7h
    	DB 060h	; 060h, from byte e8h
    	DB 0CAh	; 0CAh, from byte e9h
    	DB 0F7h	; 0F7h, from byte eah
    	DB 000h	; 000h, from byte ebh
    	DB 0AFh	; 0AFh, from byte ech
    	DB 032h	; 032h, from byte edh
    	DB 00Ch	; 00Ch, from byte eeh
    	DB 004h	; 004h, from byte efh
    	DB 078h	; 078h, from byte f0h
    	DB 0E6h	; 0E6h, from byte f1h
    	DB 060h	; 060h, from byte f2h
    	DB 0C2h	; 0C2h, from byte f3h
    	DB 0F7h	; 0F7h, from byte f4h
    	DB 000h	; 000h, from byte f5h
    	DB 078h	; 078h, from byte f6h
    	DB 021h	; 021h, from byte f7h
    	DB 093h	; 093h, from byte f8h
    	DB 003h	; 003h, from byte f9h
    	DB 00Eh	; 00Eh, from byte fah
    	DB 00Ah	; 00Ah, from byte fbh
    	DB 0CDh	; 0CDh, from byte fch
    	DB 04Eh	; 04Eh, from byte fdh
    	DB 001h	; 001h, from byte feh
    	DB 0E9h	; 0E9h, from byte ffh
    	DB 0CDh	; 0CDh, from byte 100h
    	DB 031h	; 031h, from byte 101h
    	DB 001h	; 001h, from byte 102h
    	DB 03Eh	; 03Eh, from byte 103h
    	DB 002h	; 002h, from byte 104h
    	DB 0C2h	; 0C2h, from byte 105h
    	DB 00Eh	; 00Eh, from byte 106h
    	DB 001h	; 001h, from byte 107h
    	DB 0CDh	; 0CDh, from byte 108h
    	DB 09Fh	; 09Fh, from byte 109h
    	DB 000h	; 000h, from byte 10ah
    	DB 0C3h	; 0C3h, from byte 10bh
    	DB 017h	; 017h, from byte 10ch
    	DB 000h	; 000h, from byte 10dh
    	DB 078h	; 078h, from byte 10eh
    	DB 0FEh	; 0FEh, from byte 10fh
    	DB 03Fh	; 03Fh, from byte 110h
    	DB 0C2h	; 0C2h, from byte 111h
    	DB 017h	; 017h, from byte 112h
    	DB 000h	; 000h, from byte 113h
    	DB 0AFh	; 0AFh, from byte 114h
    	DB 032h	; 032h, from byte 115h
    	DB 01Fh	; 01Fh, from byte 116h
    	DB 004h	; 004h, from byte 117h
    	DB 00Eh	; 00Eh, from byte 118h
    	DB 0FDh	; 0FDh, from byte 119h
    	DB 0CDh	; 0CDh, from byte 11ah
    	DB 0A1h	; 0A1h, from byte 11bh
    	DB 000h	; 000h, from byte 11ch
    	DB 0C3h	; 0C3h, from byte 11dh
    	DB 017h	; 017h, from byte 11eh
    	DB 000h	; 000h, from byte 11fh
    	DB 0CDh	; 0CDh, from byte 120h
    	DB 031h	; 031h, from byte 121h
    	DB 001h	; 001h, from byte 122h
    	DB 03Eh	; 03Eh, from byte 123h
    	DB 004h	; 004h, from byte 124h
    	DB 0CAh	; 0CAh, from byte 125h
    	DB 008h	; 008h, from byte 126h
    	DB 001h	; 001h, from byte 127h
    	DB 00Eh	; 00Eh, from byte 128h
    	DB 0FBh	; 0FBh, from byte 129h
    	DB 0AFh	; 0AFh, from byte 12ah
    	DB 0CDh	; 0CDh, from byte 12bh
    	DB 0A1h	; 0A1h, from byte 12ch
    	DB 000h	; 000h, from byte 12dh
    	DB 0C3h	; 0C3h, from byte 12eh
    	DB 017h	; 017h, from byte 12fh
    	DB 000h	; 000h, from byte 130h
    	DB 03Ah	; 03Ah, from byte 131h
    	DB 006h	; 006h, from byte 132h
    	DB 007h	; 007h, from byte 133h
    	DB 0E6h	; 0E6h, from byte 134h
    	DB 01Fh	; 01Fh, from byte 135h
    	DB 04Fh	; 04Fh, from byte 136h
    	DB 078h	; 078h, from byte 137h
    	DB 0E6h	; 0E6h, from byte 138h
    	DB 01Fh	; 01Fh, from byte 139h
    	DB 0B9h	; 0B9h, from byte 13ah
    	DB 0C9h	; 0C9h, from byte 13bh

    	DB 03Ah	; 03Ah, from byte 13ch
    	DB 007h	; 007h, from byte 13dh
    	DB 004h	; 004h, from byte 13eh
    	DB 0E6h	; 0E6h, from byte 13fh
    	DB 002h	; 002h, from byte 140h
    	DB 0CAh	; 0CAh, from byte 141h
    	DB 017h	; 017h, from byte 142h
    	DB 000h	; 000h, from byte 143h
    	DB 0C3h	; 0C3h, from byte 144h
    	DB 006h	; 006h, from byte 145h
    	DB 000h	; 000h, from byte 146h
    	DB 0AFh	; 0AFh, from byte 147h
    	DB 032h	; 032h, from byte 148h
    	DB 00Dh	; 00Dh, from byte 149h
    	DB 004h	; 004h, from byte 14ah
    	DB 0C3h	; 0C3h, from byte 14bh
    	DB 017h	; 017h, from byte 14ch
    	DB 000h	; 000h, from byte 14dh
    	DB 0D5h	; 0D5h, from byte 14eh
    	DB 011h	; 011h, from byte 14fh
    	DB 003h	; 003h, from byte 150h
    	DB 000h	; 000h, from byte 151h
    	DB 0BEh	; 0BEh, from byte 152h
    	DB 0CAh	; 0CAh, from byte 153h
    	DB 05Ch	; 05Ch, from byte 154h
    	DB 001h	; 001h, from byte 155h
    	DB 019h	; 019h, from byte 156h
    	DB 00Dh	; 00Dh, from byte 157h
    	DB 0C2h	; 0C2h, from byte 158h
    	DB 052h	; 052h, from byte 159h
    	DB 001h	; 001h, from byte 15ah
    	DB 02Bh	; 02Bh, from byte 15bh
    	DB 023h	; 023h, from byte 15ch
    	DB 05Eh	; 05Eh, from byte 15dh
    	DB 023h	; 023h, from byte 15eh
    	DB 056h	; 056h, from byte 15fh
    	DB 0EBh	; 0EBh, from byte 160h
    	DB 0D1h	; 0D1h, from byte 161h
    	DB 0C9h	; 0C9h, from byte 162h
    	DB 03Ah	; 03Ah, from byte 163h
    	DB 003h	; 003h, from byte 164h
    	DB 004h	; 004h, from byte 165h
    	DB 0E6h	; 0E6h, from byte 166h
    	DB 010h	; 010h, from byte 167h
    	DB 04Fh	; 04Fh, from byte 168h
    	DB 011h	; 011h, from byte 169h
    	DB 003h	; 003h, from byte 16ah
    	DB 007h	; 007h, from byte 16bh
    	DB 03Eh	; 03Eh, from byte 16ch
    	DB 004h	; 004h, from byte 16dh
    	DB 0B1h	; 0B1h, from byte 16eh
    	DB 012h	; 012h, from byte 16fh
    	DB 03Eh	; 03Eh, from byte 170h
    	DB 080h	; 080h, from byte 171h
    	DB 032h	; 032h, from byte 172h
    	DB 004h	; 004h, from byte 173h
    	DB 007h	; 007h, from byte 174h
    	DB 021h	; 021h, from byte 175h
    	DB 001h	; 001h, from byte 176h
    	DB 007h	; 007h, from byte 177h
    	DB 03Ah	; 03Ah, from byte 178h
    	DB 005h	; 005h, from byte 179h
    	DB 004h	; 004h, from byte 17ah
    	DB 0AEh	; 0AEh, from byte 17bh
    	DB 0FAh	; 0FAh, from byte 17ch
    	DB 0A9h	; 0A9h, from byte 17dh
    	DB 001h	; 001h, from byte 17eh
    	DB 07Eh	; 07Eh, from byte 17fh
    	DB 0E6h	; 0E6h, from byte 180h
    	DB 001h	; 001h, from byte 181h
    	DB 0CAh	; 0CAh, from byte 182h
    	DB 078h	; 078h, from byte 183h
    	DB 001h	; 001h, from byte 184h
    	DB 03Ah	; 03Ah, from byte 185h
    	DB 005h	; 005h, from byte 186h
    	DB 004h	; 004h, from byte 187h
    	DB 0AEh	; 0AEh, from byte 188h
    	DB 0FAh	; 0FAh, from byte 189h
    	DB 0A9h	; 0A9h, from byte 18ah
    	DB 001h	; 001h, from byte 18bh
    	DB 03Eh	; 03Eh, from byte 18ch
    	DB 006h	; 006h, from byte 18dh
    	DB 0B1h	; 0B1h, from byte 18eh
    	DB 012h	; 012h, from byte 18fh
    	DB 07Eh	; 07Eh, from byte 190h
    	DB 032h	; 032h, from byte 191h
    	DB 00Fh	; 00Fh, from byte 192h
    	DB 004h	; 004h, from byte 193h
    	DB 02Bh	; 02Bh, from byte 194h
    	DB 046h	; 046h, from byte 195h
    	DB 023h	; 023h, from byte 196h
    	DB 03Eh	; 03Eh, from byte 197h
    	DB 002h	; 002h, from byte 198h
    	DB 0B1h	; 0B1h, from byte 199h
    	DB 012h	; 012h, from byte 19ah
    	DB 07Eh	; 07Eh, from byte 19bh
    	DB 0E6h	; 0E6h, from byte 19ch
    	DB 001h	; 001h, from byte 19dh
    	DB 0C2h	; 0C2h, from byte 19eh
    	DB 09Bh	; 09Bh, from byte 19fh
    	DB 001h	; 001h, from byte 1a0h
    	DB 03Eh	; 03Eh, from byte 1a1h
    	DB 006h	; 006h, from byte 1a2h
    	DB 0B1h	; 0B1h, from byte 1a3h
    	DB 012h	; 012h, from byte 1a4h
    	DB 032h	; 032h, from byte 1a5h
    	DB 003h	; 003h, from byte 1a6h
    	DB 004h	; 004h, from byte 1a7h
    	DB 0C9h	; 0C9h, from byte 1a8h
    	DB 0E1h	; 0E1h, from byte 1a9h
    	DB 0C3h	; 0C3h, from byte 1aah
    	DB 017h	; 017h, from byte 1abh
    	DB 000h	; 000h, from byte 1ach
    	DB 0FBh	; 0FBh, from byte 1adh
    	DB 03Ah	; 03Ah, from byte 1aeh
    	DB 00Dh	; 00Dh, from byte 1afh
    	DB 004h	; 004h, from byte 1b0h
    	DB 0B7h	; 0B7h, from byte 1b1h
    	DB 0C2h	; 0C2h, from byte 1b2h
    	DB 032h	; 032h, from byte 1b3h
    	DB 002h	; 002h, from byte 1b4h
    	DB 021h	; 021h, from byte 1b5h
    	DB 005h	; 005h, from byte 1b6h
    	DB 006h	; 006h, from byte 1b7h
    	DB 07Eh	; 07Eh, from byte 1b8h
    	DB 00Fh	; 00Fh, from byte 1b9h
    	DB 0DAh	; 0DAh, from byte 1bah
    	DB 0B8h	; 0B8h, from byte 1bbh
    	DB 001h	; 001h, from byte 1bch
    	DB 0F3h	; 0F3h, from byte 1bdh
    	DB 011h	; 011h, from byte 1beh
    	DB 030h	; 030h, from byte 1bfh
    	DB 004h	; 004h, from byte 1c0h
    	DB 021h	; 021h, from byte 1c1h
    	DB 004h	; 004h, from byte 1c2h
    	DB 006h	; 006h, from byte 1c3h
    	DB 0CDh	; 0CDh, from byte 1c4h
    	DB 042h	; 042h, from byte 1c5h
    	DB 002h	; 002h, from byte 1c6h
    	DB 03Eh	; 03Eh, from byte 1c7h
    	DB 00Fh	; 00Fh, from byte 1c8h
    	DB 032h	; 032h, from byte 1c9h
    	DB 000h	; 000h, from byte 1cah
    	DB 004h	; 004h, from byte 1cbh
    	DB 0FBh	; 0FBh, from byte 1cch
    	DB 021h	; 021h, from byte 1cdh
    	DB 030h	; 030h, from byte 1ceh
    	DB 004h	; 004h, from byte 1cfh
    	DB 022h	; 022h, from byte 1d0h
    	DB 02Eh	; 02Eh, from byte 1d1h
    	DB 004h	; 004h, from byte 1d2h
    	DB 021h	; 021h, from byte 1d3h
    	DB 0E4h	; 0E4h, from byte 1d4h
    	DB 003h	; 003h, from byte 1d5h
    	DB 07Eh	; 07Eh, from byte 1d6h
    	DB 023h	; 023h, from byte 1d7h
    	DB 022h	; 022h, from byte 1d8h
    	DB 01Dh	; 01Dh, from byte 1d9h
    	DB 004h	; 004h, from byte 1dah
    	DB 0FEh	; 0FEh, from byte 1dbh
    	DB 019h	; 019h, from byte 1dch
    	DB 0CAh	; 0CAh, from byte 1ddh
    	DB 017h	; 017h, from byte 1deh
    	DB 000h	; 000h, from byte 1dfh
    	DB 0B7h	; 0B7h, from byte 1e0h
    	DB 0F2h	; 0F2h, from byte 1e1h
    	DB 0F0h	; 0F0h, from byte 1e2h
    	DB 001h	; 001h, from byte 1e3h
    	DB 0E6h	; 0E6h, from byte 1e4h
    	DB 040h	; 040h, from byte 1e5h
    	DB 0B1h	; 0B1h, from byte 1e6h
    	DB 04Fh	; 04Fh, from byte 1e7h
    	DB 02Ah	; 02Ah, from byte 1e8h
    	DB 02Eh	; 02Eh, from byte 1e9h
    	DB 004h	; 004h, from byte 1eah
    	DB 07Eh	; 07Eh, from byte 1ebh
    	DB 023h	; 023h, from byte 1ech
    	DB 022h	; 022h, from byte 1edh
    	DB 02Eh	; 02Eh, from byte 1eeh
    	DB 004h	; 004h, from byte 1efh
    	DB 047h	; 047h, from byte 1f0h
    	DB 03Ah	; 03Ah, from byte 1f1h
    	DB 003h	; 003h, from byte 1f2h
    	DB 004h	; 004h, from byte 1f3h
    	DB 0E6h	; 0E6h, from byte 1f4h
    	DB 010h	; 010h, from byte 1f5h
    	DB 04Fh	; 04Fh, from byte 1f6h
    	DB 011h	; 011h, from byte 1f7h
    	DB 003h	; 003h, from byte 1f8h
    	DB 007h	; 007h, from byte 1f9h
    	DB 012h	; 012h, from byte 1fah
    	DB 021h	; 021h, from byte 1fbh
    	DB 002h	; 002h, from byte 1fch
    	DB 007h	; 007h, from byte 1fdh
    	DB 070h	; 070h, from byte 1feh
    	DB 02Bh	; 02Bh, from byte 1ffh
    	DB 07Eh	; 07Eh, from byte 200h
    	DB 00Fh	; 00Fh, from byte 201h
    	DB 00Fh	; 00Fh, from byte 202h
    	DB 0DAh	; 0DAh, from byte 203h
    	DB 000h	; 000h, from byte 204h
    	DB 002h	; 002h, from byte 205h
    	DB 03Eh	; 03Eh, from byte 206h
    	DB 001h	; 001h, from byte 207h
    	DB 0B1h	; 0B1h, from byte 208h
    	DB 012h	; 012h, from byte 209h
    	DB 07Eh	; 07Eh, from byte 20ah
    	DB 00Fh	; 00Fh, from byte 20bh
    	DB 00Fh	; 00Fh, from byte 20ch
    	DB 00Fh	; 00Fh, from byte 20dh
    	DB 0DAh	; 0DAh, from byte 20eh
    	DB 00Ah	; 00Ah, from byte 20fh
    	DB 002h	; 002h, from byte 210h
    	DB 0F3h	; 0F3h, from byte 211h
    	DB 0AFh	; 0AFh, from byte 212h
    	DB 012h	; 012h, from byte 213h
    	DB 032h	; 032h, from byte 214h
    	DB 003h	; 003h, from byte 215h
    	DB 004h	; 004h, from byte 216h
    	DB 021h	; 021h, from byte 217h
    	DB 000h	; 000h, from byte 218h
    	DB 004h	; 004h, from byte 219h
    	DB 07Eh	; 07Eh, from byte 21ah
    	DB 036h	; 036h, from byte 21bh
    	DB 000h	; 000h, from byte 21ch
    	DB 0B7h	; 0B7h, from byte 21dh
    	DB 0FAh	; 0FAh, from byte 21eh
    	DB 017h	; 017h, from byte 21fh
    	DB 000h	; 000h, from byte 220h
    	DB 0CAh	; 0CAh, from byte 221h
    	DB 02Bh	; 02Bh, from byte 222h
    	DB 002h	; 002h, from byte 223h
    	DB 0AFh	; 0AFh, from byte 224h
    	DB 032h	; 032h, from byte 225h
    	DB 007h	; 007h, from byte 226h
    	DB 006h	; 006h, from byte 227h
    	DB 032h	; 032h, from byte 228h
    	DB 00Eh	; 00Eh, from byte 229h
    	DB 004h	; 004h, from byte 22ah
    	DB 0FBh	; 0FBh, from byte 22bh
    	DB 02Ah	; 02Ah, from byte 22ch
    	DB 01Dh	; 01Dh, from byte 22dh
    	DB 004h	; 004h, from byte 22eh
    	DB 0C3h	; 0C3h, from byte 22fh
    	DB 0D6h	; 0D6h, from byte 230h
    	DB 001h	; 001h, from byte 231h
    	DB 03Eh	; 03Eh, from byte 232h
    	DB 0FFh	; 0FFh, from byte 233h
    	DB 032h	; 032h, from byte 234h
    	DB 000h	; 000h, from byte 235h
    	DB 004h	; 004h, from byte 236h
    	DB 021h	; 021h, from byte 237h
    	DB 00Eh	; 00Eh, from byte 238h
    	DB 004h	; 004h, from byte 239h
    	DB 046h	; 046h, from byte 23ah
    	DB 07Eh	; 07Eh, from byte 23bh
    	DB 0E6h	; 0E6h, from byte 23ch
    	DB 0BFh	; 0BFh, from byte 23dh
    	DB 077h	; 077h, from byte 23eh
    	DB 0C3h	; 0C3h, from byte 23fh
    	DB 0F1h	; 0F1h, from byte 240h
    	DB 001h	; 001h, from byte 241h
    	DB 006h	; 006h, from byte 242h
    	DB 005h	; 005h, from byte 243h
    	DB 07Eh	; 07Eh, from byte 244h
    	DB 00Fh	; 00Fh, from byte 245h
    	DB 00Fh	; 00Fh, from byte 246h
    	DB 00Fh	; 00Fh, from byte 247h
    	DB 00Fh	; 00Fh, from byte 248h
    	DB 0CDh	; 0CDh, from byte 249h
    	DB 056h	; 056h, from byte 24ah
    	DB 002h	; 002h, from byte 24bh
    	DB 07Eh	; 07Eh, from byte 24ch
    	DB 0CDh	; 0CDh, from byte 24dh
    	DB 056h	; 056h, from byte 24eh
    	DB 002h	; 002h, from byte 24fh
    	DB 02Bh	; 02Bh, from byte 250h
    	DB 005h	; 005h, from byte 251h
    	DB 0C2h	; 0C2h, from byte 252h
    	DB 044h	; 044h, from byte 253h
    	DB 002h	; 002h, from byte 254h
    	DB 0C9h	; 0C9h, from byte 255h
    	DB 04Fh	; 04Fh, from byte 256h
    	DB 03Ah	; 03Ah, from byte 257h
    	DB 005h	; 005h, from byte 258h
    	DB 006h	; 006h, from byte 259h
    	DB 0E6h	; 0E6h, from byte 25ah
    	DB 004h	; 004h, from byte 25bh
    	DB 0FEh	; 0FEh, from byte 25ch
    	DB 004h	; 004h, from byte 25dh
    	DB 079h	; 079h, from byte 25eh
    	DB 0CAh	; 0CAh, from byte 25fh
    	DB 063h	; 063h, from byte 260h
    	DB 002h	; 002h, from byte 261h
    	DB 02Fh	; 02Fh, from byte 262h
    	DB 0E6h	; 0E6h, from byte 263h
    	DB 00Fh	; 00Fh, from byte 264h
    	DB 0E5h	; 0E5h, from byte 265h
    	DB 021h	; 021h, from byte 266h
    	DB 0D4h	; 0D4h, from byte 267h
    	DB 003h	; 003h, from byte 268h
    	DB 085h	; 085h, from byte 269h
    	DB 06Fh	; 06Fh, from byte 26ah
    	DB 07Eh	; 07Eh, from byte 26bh
    	DB 012h	; 012h, from byte 26ch
    	DB 013h	; 013h, from byte 26dh
    	DB 0E1h	; 0E1h, from byte 26eh
    	DB 0C9h	; 0C9h, from byte 26fh
    	DB 021h	; 021h, from byte 270h
    	DB 090h	; 090h, from byte 271h
    	DB 003h	; 003h, from byte 272h
    	DB 078h	; 078h, from byte 273h
    	DB 0E6h	; 0E6h, from byte 274h
    	DB 01Fh	; 01Fh, from byte 275h
    	DB 0BEh	; 0BEh, from byte 276h
    	DB 0C2h	; 0C2h, from byte 277h
    	DB 017h	; 017h, from byte 278h
    	DB 000h	; 000h, from byte 279h
    	DB 021h	; 021h, from byte 27ah
    	DB 007h	; 007h, from byte 27bh
    	DB 004h	; 004h, from byte 27ch
    	DB 07Eh	; 07Eh, from byte 27dh
    	DB 0E6h	; 0E6h, from byte 27eh
    	DB 030h	; 030h, from byte 27fh
    	DB 0CAh	; 0CAh, from byte 280h
    	DB 017h	; 017h, from byte 281h
    	DB 000h	; 000h, from byte 282h
    	DB 00Fh	; 00Fh, from byte 283h
    	DB 00Fh	; 00Fh, from byte 284h
    	DB 00Fh	; 00Fh, from byte 285h
    	DB 077h	; 077h, from byte 286h
    	DB 0C3h	; 0C3h, from byte 287h
    	DB 017h	; 017h, from byte 288h
    	DB 000h	; 000h, from byte 289h
    	DB 03Ah	; 03Ah, from byte 28ah
    	DB 007h	; 007h, from byte 28bh
    	DB 004h	; 004h, from byte 28ch
    	DB 0E6h	; 0E6h, from byte 28dh
    	DB 002h	; 002h, from byte 28eh
    	DB 0CAh	; 0CAh, from byte 28fh
    	DB 017h	; 017h, from byte 290h
    	DB 000h	; 000h, from byte 291h
    	DB 021h	; 021h, from byte 292h
    	DB 007h	; 007h, from byte 293h
    	DB 006h	; 006h, from byte 294h
    	DB 077h	; 077h, from byte 295h
    	DB 02Bh	; 02Bh, from byte 296h
    	DB 03Ah	; 03Ah, from byte 297h
    	DB 0C8h	; 0C8h, from byte 298h
    	DB 003h	; 003h, from byte 299h
    	DB 0C3h	; 0C3h, from byte 29ah
    	DB 0F9h	; 0F9h, from byte 29bh
    	DB 002h	; 002h, from byte 29ch
    	DB 0AFh	; 0AFh, from byte 29dh
    	DB 032h	; 032h, from byte 29eh
    	DB 005h	; 005h, from byte 29fh
    	DB 004h	; 004h, from byte 2a0h
    	DB 032h	; 032h, from byte 2a1h
    	DB 002h	; 002h, from byte 2a2h
    	DB 007h	; 007h, from byte 2a3h
    	DB 0F3h	; 0F3h, from byte 2a4h
    	DB 0CDh	; 0CDh, from byte 2a5h
    	DB 063h	; 063h, from byte 2a6h
    	DB 001h	; 001h, from byte 2a7h
    	DB 078h	; 078h, from byte 2a8h
    	DB 0E6h	; 0E6h, from byte 2a9h
    	DB 070h	; 070h, from byte 2aah
    	DB 0FEh	; 0FEh, from byte 2abh
    	DB 030h	; 030h, from byte 2ach
    	DB 0C2h	; 0C2h, from byte 2adh
    	DB 005h	; 005h, from byte 2aeh
    	DB 003h	; 003h, from byte 2afh
    	DB 021h	; 021h, from byte 2b0h
    	DB 01Fh	; 01Fh, from byte 2b1h
    	DB 004h	; 004h, from byte 2b2h
    	DB 07Eh	; 07Eh, from byte 2b3h
    	DB 0FEh	; 0FEh, from byte 2b4h
    	DB 00Ah	; 00Ah, from byte 2b5h
    	DB 0D2h	; 0D2h, from byte 2b6h
    	DB 0BEh	; 0BEh, from byte 2b7h
    	DB 002h	; 002h, from byte 2b8h
    	DB 034h	; 034h, from byte 2b9h
    	DB 0C6h	; 0C6h, from byte 2bah
    	DB 020h	; 020h, from byte 2bbh
    	DB 06Fh	; 06Fh, from byte 2bch
    	DB 070h	; 070h, from byte 2bdh
    	DB 03Ah	; 03Ah, from byte 2beh
    	DB 00Fh	; 00Fh, from byte 2bfh
    	DB 004h	; 004h, from byte 2c0h
    	DB 0E6h	; 0E6h, from byte 2c1h
    	DB 0C0h	; 0C0h, from byte 2c2h
    	DB 0FEh	; 0FEh, from byte 2c3h
    	DB 040h	; 040h, from byte 2c4h
    	DB 0C2h	; 0C2h, from byte 2c5h
    	DB 0A5h	; 0A5h, from byte 2c6h
    	DB 002h	; 002h, from byte 2c7h
    	DB 021h	; 021h, from byte 2c8h
    	DB 01Fh	; 01Fh, from byte 2c9h
    	DB 004h	; 004h, from byte 2cah
    	DB 04Eh	; 04Eh, from byte 2cbh
    	DB 07Eh	; 07Eh, from byte 2cch
    	DB 0B7h	; 0B7h, from byte 2cdh
    	DB 0CAh	; 0CAh, from byte 2ceh
    	DB 017h	; 017h, from byte 2cfh
    	DB 000h	; 000h, from byte 2d0h
    	DB 036h	; 036h, from byte 2d1h
    	DB 000h	; 000h, from byte 2d2h
    	DB 0C5h	; 0C5h, from byte 2d3h
    	DB 0CDh	; 0CDh, from byte 2d4h
    	DB 011h	; 011h, from byte 2d5h
    	DB 003h	; 003h, from byte 2d6h
    	DB 0C1h	; 0C1h, from byte 2d7h
    	DB 011h	; 011h, from byte 2d8h
    	DB 000h	; 000h, from byte 2d9h
    	DB 005h	; 005h, from byte 2dah
    	DB 023h	; 023h, from byte 2dbh
    	DB 07Eh	; 07Eh, from byte 2dch
    	DB 0E6h	; 0E6h, from byte 2ddh
    	DB 00Fh	; 00Fh, from byte 2deh
    	DB 047h	; 047h, from byte 2dfh
    	DB 00Dh	; 00Dh, from byte 2e0h
    	DB 0FAh	; 0FAh, from byte 2e1h
    	DB 0F3h	; 0F3h, from byte 2e2h
    	DB 002h	; 002h, from byte 2e3h
    	DB 023h	; 023h, from byte 2e4h
    	DB 07Eh	; 07Eh, from byte 2e5h
    	DB 0E6h	; 0E6h, from byte 2e6h
    	DB 00Fh	; 00Fh, from byte 2e7h
    	DB 007h	; 007h, from byte 2e8h
    	DB 007h	; 007h, from byte 2e9h
    	DB 007h	; 007h, from byte 2eah
    	DB 007h	; 007h, from byte 2ebh
    	DB 0B0h	; 0B0h, from byte 2ech
    	DB 00Dh	; 00Dh, from byte 2edh
    	DB 012h	; 012h, from byte 2eeh
    	DB 013h	; 013h, from byte 2efh
    	DB 0C2h	; 0C2h, from byte 2f0h
    	DB 0DBh	; 0DBh, from byte 2f1h
    	DB 002h	; 002h, from byte 2f2h
    	DB 021h	; 021h, from byte 2f3h
    	DB 006h	; 006h, from byte 2f4h
    	DB 005h	; 005h, from byte 2f5h
    	DB 03Ah	; 03Ah, from byte 2f6h
    	DB 0C4h	; 0C4h, from byte 2f7h
    	DB 003h	; 003h, from byte 2f8h
    	DB 047h	; 047h, from byte 2f9h
    	DB 0EEh	; 0EEh, from byte 2fah
    	DB 003h	; 003h, from byte 2fbh
    	DB 077h	; 077h, from byte 2fch
    	DB 0E5h	; 0E5h, from byte 2fdh
    	DB 0E5h	; 0E5h, from byte 2feh
    	DB 0E1h	; 0E1h, from byte 2ffh
    	DB 0E1h	; 0E1h, from byte 300h
    	DB 070h	; 070h, from byte 301h
    	DB 0C3h	; 0C3h, from byte 302h
    	DB 017h	; 017h, from byte 303h
    	DB 000h	; 000h, from byte 304h
    	DB 078h	; 078h, from byte 305h
    	DB 0E6h	; 0E6h, from byte 306h
    	DB 07Fh	; 07Fh, from byte 307h
    	DB 00Eh	; 00Eh, from byte 308h
    	DB 003h	; 003h, from byte 309h
    	DB 021h	; 021h, from byte 30ah
    	DB 0F5h	; 0F5h, from byte 30bh
    	DB 003h	; 003h, from byte 30ch
    	DB 0CDh	; 0CDh, from byte 30dh
    	DB 04Eh	; 04Eh, from byte 30eh
    	DB 001h	; 001h, from byte 30fh
    	DB 0E9h	; 0E9h, from byte 310h
    	DB 03Ah	; 03Ah, from byte 311h
    	DB 005h	; 005h, from byte 312h
    	DB 005h	; 005h, from byte 313h
    	DB 0E6h	; 0E6h, from byte 314h
    	DB 008h	; 008h, from byte 315h
    	DB 0FEh	; 0FEh, from byte 316h
    	DB 008h	; 008h, from byte 317h
    	DB 0C0h	; 0C0h, from byte 318h
    	DB 0E5h	; 0E5h, from byte 319h
    	DB 023h	; 023h, from byte 31ah
    	DB 07Eh	; 07Eh, from byte 31bh
    	DB 02Fh	; 02Fh, from byte 31ch
    	DB 077h	; 077h, from byte 31dh
    	DB 00Dh	; 00Dh, from byte 31eh
    	DB 0C2h	; 0C2h, from byte 31fh
    	DB 01Ah	; 01Ah, from byte 320h
    	DB 003h	; 003h, from byte 321h
    	DB 0E1h	; 0E1h, from byte 322h
    	DB 0C9h	; 0C9h, from byte 323h
    	DB 03Ah	; 03Ah, from byte 324h
    	DB 00Ch	; 00Ch, from byte 325h
    	DB 004h	; 004h, from byte 326h
    	DB 0B7h	; 0B7h, from byte 327h
    	DB 0CAh	; 0CAh, from byte 328h
    	DB 017h	; 017h, from byte 329h
    	DB 000h	; 000h, from byte 32ah
    	DB 078h	; 078h, from byte 32bh
    	DB 0FEh	; 0FEh, from byte 32ch
    	DB 070h	; 070h, from byte 32dh
    	DB 0CAh	; 0CAh, from byte 32eh
    	DB 06Dh	; 06Dh, from byte 32fh
    	DB 003h	; 003h, from byte 330h
    	DB 032h	; 032h, from byte 331h
    	DB 001h	; 001h, from byte 332h
    	DB 004h	; 004h, from byte 333h
    	DB 0E6h	; 0E6h, from byte 334h
    	DB 007h	; 007h, from byte 335h
    	DB 04Fh	; 04Fh, from byte 336h
    	DB 078h	; 078h, from byte 337h
    	DB 0E6h	; 0E6h, from byte 338h
    	DB 008h	; 008h, from byte 339h
    	DB 03Ah	; 03Ah, from byte 33ah
    	DB 007h	; 007h, from byte 33bh
    	DB 004h	; 004h, from byte 33ch
    	DB 0CAh	; 0CAh, from byte 33dh
    	DB 042h	; 042h, from byte 33eh
    	DB 003h	; 003h, from byte 33fh
    	DB 0EEh	; 0EEh, from byte 340h
    	DB 001h	; 001h, from byte 341h
    	DB 0E6h	; 0E6h, from byte 342h
    	DB 001h	; 001h, from byte 343h
    	DB 00Fh	; 00Fh, from byte 344h
    	DB 00Ch	; 00Ch, from byte 345h
    	DB 007h	; 007h, from byte 346h
    	DB 00Dh	; 00Dh, from byte 347h
    	DB 0C2h	; 0C2h, from byte 348h
    	DB 046h	; 046h, from byte 349h
    	DB 003h	; 003h, from byte 34ah
    	DB 032h	; 032h, from byte 34bh
    	DB 00Bh	; 00Bh, from byte 34ch
    	DB 004h	; 004h, from byte 34dh
    	DB 021h	; 021h, from byte 34eh
    	DB 007h	; 007h, from byte 34fh
    	DB 004h	; 004h, from byte 350h
    	DB 07Eh	; 07Eh, from byte 351h
    	DB 0F6h	; 0F6h, from byte 352h
    	DB 008h	; 008h, from byte 353h
    	DB 077h	; 077h, from byte 354h
L_0355:
    	DB 021h	; 021h, from byte 355h
    	DB 004h	; 004h, from byte 356h
    	DB 007h	; 007h, from byte 357h
    	DB 036h	; 036h, from byte 358h
    	DB 000h	; 000h, from byte 359h
    	DB 021h	; 021h, from byte 35ah
    	DB 002h	; 002h, from byte 35bh
    	DB 007h	; 007h, from byte 35ch
    	DB 03Ah	; 03Ah, from byte 35dh
    	DB 00Bh	; 00Bh, from byte 35eh
    	DB 004h	; 004h, from byte 35fh
    	DB 077h	; 077h, from byte 360h
    	DB 023h	; 023h, from byte 361h
    	DB 036h	; 036h, from byte 362h
    	DB 000h	; 000h, from byte 363h
    	DB 02Eh	; 02Eh, from byte 364h
    	DB 007h	; 007h, from byte 365h
    	DB 03Ah	; 03Ah, from byte 366h
    	DB 007h	; 007h, from byte 367h
    	DB 004h	; 004h, from byte 368h
    	DB 077h	; 077h, from byte 369h
    	DB 0C3h	; 0C3h, from byte 36ah
    	DB 01Fh	; 01Fh, from byte 36bh
    	DB 000h	; 000h, from byte 36ch
    	DB 0AFh	; 0AFh, from byte 36dh
    	DB 032h	; 032h, from byte 36eh
    	DB 001h	; 001h, from byte 36fh
    	DB 004h	; 004h, from byte 370h
    	DB 021h	; 021h, from byte 371h
    	DB 007h	; 007h, from byte 372h
    	DB 004h	; 004h, from byte 373h
    	DB 07Eh	; 07Eh, from byte 374h
    	DB 0E6h	; 0E6h, from byte 375h
    	DB 0F7h	; 0F7h, from byte 376h
    	DB 077h	; 077h, from byte 377h
    	DB 0C3h	; 0C3h, from byte 378h
    	DB 017h	; 017h, from byte 379h
    	DB 000h	; 000h, from byte 37ah
    	DB 03Ah	; 03Ah, from byte 37bh
    	DB 007h	; 007h, from byte 37ch
    	DB 004h	; 004h, from byte 37dh
    	DB 0E6h	; 0E6h, from byte 37eh
    	DB 002h	; 002h, from byte 37fh
    	DB 0CAh	; 0CAh, from byte 380h
    	DB 017h	; 017h, from byte 381h
    	DB 000h	; 000h, from byte 382h
    	DB 078h	; 078h, from byte 383h
    	DB 032h	; 032h, from byte 384h
    	DB 00Ch	; 00Ch, from byte 385h
    	DB 004h	; 004h, from byte 386h
    	DB 0C3h	; 0C3h, from byte 387h
    	DB 017h	; 017h, from byte 388h
    	DB 000h	; 000h, from byte 389h
    	DB 0FFh	; 0FFh, from byte 38ah
    	DB 0FFh	; 0FFh, from byte 38bh
    	DB 0FFh	; 0FFh, from byte 38ch
    	DB 0FFh	; 0FFh, from byte 38dh
    	DB 0FFh	; 0FFh, from byte 38eh
    	DB 0FFh	; 0FFh, from byte 38fh
    	DB 000h	; 000h, from byte 390h
    	DB 002h	; 002h, from byte 391h
    	DB 005h	; 005h, from byte 392h
    	DB 004h	; 004h, from byte 393h
    	DB 03Ch	; 03Ch, from byte 394h
    	DB 001h	; 001h, from byte 395h
    	DB 014h	; 014h, from byte 396h
    	DB 006h	; 006h, from byte 397h
    	DB 000h	; 000h, from byte 398h
    	DB 015h	; 015h, from byte 399h
    	DB 06Dh	; 06Dh, from byte 39ah
    	DB 003h	; 003h, from byte 39bh
    	DB 018h	; 018h, from byte 39ch
    	DB 048h	; 048h, from byte 39dh
    	DB 001h	; 001h, from byte 39eh
    	DB 019h	; 019h, from byte 39fh
    	DB 047h	; 047h, from byte 3a0h
    	DB 001h	; 001h, from byte 3a1h
    	DB 008h	; 008h, from byte 3a2h
    	DB 08Ah	; 08Ah, from byte 3a3h
    	DB 002h	; 002h, from byte 3a4h
    	DB 020h	; 020h, from byte 3a5h
    	DB 000h	; 000h, from byte 3a6h
    	DB 001h	; 001h, from byte 3a7h
    	DB 040h	; 040h, from byte 3a8h
    	DB 020h	; 020h, from byte 3a9h
    	DB 001h	; 001h, from byte 3aah
    	DB 005h	; 005h, from byte 3abh
    	DB 07Bh	; 07Bh, from byte 3ach
    	DB 003h	; 003h, from byte 3adh
    	DB 060h	; 060h, from byte 3aeh
    	DB 024h	; 024h, from byte 3afh
    	DB 003h	; 003h, from byte 3b0h
    	DB 017h	; 017h, from byte 3b1h
    	DB 000h	; 000h, from byte 3b2h
    	DB 00Bh	; 00Bh, from byte 3b3h
    	DB 01Fh	; 01Fh, from byte 3b4h
    	DB 004h	; 004h, from byte 3b5h
    	DB 00Ah	; 00Ah, from byte 3b6h
    	DB 000h	; 000h, from byte 3b7h
    	DB 000h	; 000h, from byte 3b8h
    	DB 000h	; 000h, from byte 3b9h
    	DB 000h	; 000h, from byte 3bah
    	DB 000h	; 000h, from byte 3bbh
    	DB 000h	; 000h, from byte 3bch
    	DB 000h	; 000h, from byte 3bdh
    	DB 000h	; 000h, from byte 3beh
    	DB 000h	; 000h, from byte 3bfh
    	DB 000h	; 000h, from byte 3c0h
    	DB 001h	; 001h, from byte 3c1h
    	DB 006h	; 006h, from byte 3c2h
    	DB 005h	; 005h, from byte 3c3h
    	DB 006h	; 006h, from byte 3c4h
    	DB 002h	; 002h, from byte 3c5h
    	DB 006h	; 006h, from byte 3c6h
    	DB 006h	; 006h, from byte 3c7h
    	DB 002h	; 002h, from byte 3c8h
    	DB 000h	; 000h, from byte 3c9h
    	DB 006h	; 006h, from byte 3cah
    	DB 002h	; 002h, from byte 3cbh
    	DB 007h	; 007h, from byte 3cch
    	DB 000h	; 000h, from byte 3cdh
    	DB 000h	; 000h, from byte 3ceh
    	DB 080h	; 080h, from byte 3cfh
    	DB 000h	; 000h, from byte 3d0h
    	DB 000h	; 000h, from byte 3d1h
    	DB 000h	; 000h, from byte 3d2h
    	DB 000h	; 000h, from byte 3d3h
    	DB 030h	; 030h, from byte 3d4h
    	DB 031h	; 031h, from byte 3d5h
    	DB 032h	; 032h, from byte 3d6h
    	DB 033h	; 033h, from byte 3d7h
    	DB 034h	; 034h, from byte 3d8h
    	DB 035h	; 035h, from byte 3d9h
    	DB 036h	; 036h, from byte 3dah
    	DB 037h	; 037h, from byte 3dbh
    	DB 038h	; 038h, from byte 3dch
    	DB 039h	; 039h, from byte 3ddh
    	DB 02Bh	; 02Bh, from byte 3deh
    	DB 02Dh	; 02Dh, from byte 3dfh
    	DB 02Eh	; 02Eh, from byte 3e0h
    	DB 02Ch	; 02Ch, from byte 3e1h
    	DB 045h	; 045h, from byte 3e2h
    	DB 020h	; 020h, from byte 3e3h
    	DB 080h	; 080h, from byte 3e4h
    	DB 080h	; 080h, from byte 3e5h
    	DB 080h	; 080h, from byte 3e6h
    	DB 080h	; 080h, from byte 3e7h
    	DB 080h	; 080h, from byte 3e8h
    	DB 080h	; 080h, from byte 3e9h
    	DB 080h	; 080h, from byte 3eah
    	DB 080h	; 080h, from byte 3ebh
    	DB 080h	; 080h, from byte 3ech
    	DB 080h	; 080h, from byte 3edh
    	DB 00Dh	; 00Dh, from byte 3eeh
    	DB 00Ah	; 00Ah, from byte 3efh
    	DB 019h	; 019h, from byte 3f0h
    	DB 000h	; 000h, from byte 3f1h
    	DB 000h	; 000h, from byte 3f2h
    	DB 000h	; 000h, from byte 3f3h
    	DB 019h	; 019h, from byte 3f4h
    	DB 00Dh	; 00Dh, from byte 3f5h
    	DB 0C8h	; 0C8h, from byte 3f6h
    	DB 002h	; 002h, from byte 3f7h
    	DB 00Ah	; 00Ah, from byte 3f8h
    	DB 0C8h	; 0C8h, from byte 3f9h
    	DB 002h	; 002h, from byte 3fah
    	DB 02Ch	; 02Ch, from byte 3fbh
    	DB 0C8h	; 0C8h, from byte 3fch
    	DB 002h	; 002h, from byte 3fdh
    	DB 0A5h	; 0A5h, from byte 3feh
    	DB 002h	; 002h, from byte 3ffh
