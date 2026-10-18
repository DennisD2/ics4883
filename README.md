# ICS 4883 Instrument Coupler 
Some files to get knowledge about this ancient device.
It aims to control instruments (e.g. astronomical ones)
via an GPIB interface. It has many input and output lines 
to control other devices.

### File ics-electronic-4883-f2708-1kbyte.rom
ROM dump.

### File ics4883_baseline.asm
This file is created from ROM dump. Per byte, it has a line 

DB 0{bytevalue}h ; {bytevalue} (oct={bytevalue in octal}) from address {address} h/d = {hex address} {decimal address}".

to enable analysis of that byte. 

Examples:
```shell
DB 000h	; 00 (oct=0), from address h/d = 1 1

DB 0F3h	; F3 (oct=363), from address h/d = 17 23
```
It can be assembled using tools "asl" and "p2bin". Result
is a binary file.

### File ics4883.asm
Manually disassembled and documented ROM content.
Created mostly with AI help.

### File Makefile
Makefile that assembles ics4883.asm and compares result
with original ROM. This allows to quickly check if changes
to the file are correct disassemblations.

### Directory "doc"
Has some more info on instrument coupler.
