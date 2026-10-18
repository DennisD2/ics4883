package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"
)

// normalizeHex entfernt führende Nullen und wandelt alles in Kleinbuchstaben um (z.B. "0407H" -> "407h")
func normalizeHex(val string) string {
	val = strings.ToLower(val)
	// Suffix h/H entfernen, um führende Nullen der reinen Zahl leichter zu strippen
	hasH := strings.HasSuffix(val, "h")
	if hasH {
		val = strings.TrimSuffix(val, "h")
	}
	// Führende Nullen entfernen (aber eine Null übrig lassen, falls es "0h" war)
	val = strings.TrimLeft(val, "0")
	if val == "" {
		val = "0"
	}
	if hasH {
		val += "h"
	}
	return val
}

func main() {
	filename := "ics4883.asm"
	file, err := os.Open(filename)
	if err != nil {
		fmt.Printf("Fehler beim Öffnen der Datei: %v\n", err)
		return
	}
	defer file.Close()

	equMap := make(map[string]string)    // Key: normalisierter Wert (z.B. "407h"), Value: Name
	unprocessed := make(map[string]bool) // Set für nicht verarbeitete Adressen
	var codeLines []string

	// Verbesserter Regex für EQU-Zeilen: Erlaubt flexible Leerzeichen und optionale führende Nullen
	equRegex := regexp.MustCompile(`(?i)^\s*([a-zA-Z0-9_]+)\s+EQU\s+([0-9a-fA-F]+[hH])`)

	// Regex für Hex-Zahlen im Code
	addrRegex := regexp.MustCompile(`(?i)\b([0-9a-fA-F]+[hH])\b`)

	scanner := bufio.NewScanner(file)

	// --- SCHRITT 1 & 2: Datei parsen und EQU-Map aufbauen ---
	for scanner.Scan() {
		line := scanner.Text()
		matches := equRegex.FindStringSubmatch(line)

		if len(matches) > 0 {
			name := matches[1]
			// Hier normalisieren wir den EQU-Wert (z.B. "0505h" -> "505h")
			val := normalizeHex(matches[2])
			equMap[val] = name
			fmt.Printf("%s\n", line)
		} else {
			codeLines = append(codeLines, line)
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Printf("Fehler beim Lesen der Datei: %v\n", err)
		return
	}

	fmt.Println("; ==============================================================================")
	fmt.Println("; REFACTORED CODE OUTPUT")
	fmt.Println("; ==============================================================================")

	// --- SCHRITT 3 - 6: Code durchgehen und Werte ersetzen ---
	for _, line := range codeLines {
		parts := strings.SplitN(line, ";", 2)
		codePart := parts[0]
		commentPart := ""
		if len(parts) > 1 {
			commentPart = ";" + parts[1]
		}

		foundAddresses := addrRegex.FindAllString(codePart, -1)
		replaced := false

		for _, addr := range foundAddresses {
			// Auch den gefundenen Wert im Code normalisieren (z.B. "0505h" -> "505h")
			normAddr := normalizeHex(addr)

			if equName, found := equMap[normAddr]; found {
				codePart = strings.ReplaceAll(codePart, addr, equName)
				replaced = true
			} else {
				unprocessed[normAddr] = true
			}
		}

		if replaced {
			fmt.Println(codePart + commentPart)
		} else {
			fmt.Println(line)
		}
	}

	// --- SCHRITT 7: Unprocessed Liste sortiert ausgeben ---
	fmt.Println("\n; ==============================================================================")
	fmt.Println("; UNPROCESSED ADDRESSES / VALUES")
	fmt.Println("; ==============================================================================")

	var sortedUnprocessed []string
	for addr := range unprocessed {
		sortedUnprocessed = append(sortedUnprocessed, addr)
	}
	sort.Strings(sortedUnprocessed)

	for _, addr := range sortedUnprocessed {
		fmt.Printf("; - %s\n", addr)
	}
}
