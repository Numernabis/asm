.286

; Ludwik Ciechanski
; 
; PROJEKT 2
; cykliczny kod nadmiarowy
; +++++++++++++++++
CR		equ	13d 
LF		equ	10d
ARG		equ	3						;maksymalna ilosc argumentow
BS		equ	512						;buffer size
POLY	equ	8001h					;wielomian do obliczania sum CRC

daneA segment
	tab_dane	db	128	dup (?)		;tablica do ktorej zostana wczytane dane wejsciowe (argumenty z linii polecen)
	tab_crc		dw	256	dup (?)		;tablica pomocnicza do obliczania CRC
	tab_crc_hex	db	4	dup (?)		;suma CRC do zapisu (w postaci heksadecymalnej)
	
	iarg 		db	0d				;ilosc argumentow
	parg 		db	ARG*2 dup (0)	;parametry poszczegolnych argumentow: adres1,dlugosc1,adres2,dlugosc2,...
	flag		db	0d				;flaga modyfikacji
	kod 		dw 	1				;zmienna do obliczania wartosci dla znakow ascii
	kodtmp		dw 	1
	crc			dw	1				;zmienna do obliczania wartosci sumy kontrolnej CRC
	crctmp		dw  1
	
	fin1 		db  64  dup (?)		;nazwa pliku do odczytu (input/input1).                 
	fin2 		db  64  dup (?)		;nazwa pliku do odczytu (intput2).                 
	fon 		db  64	dup (?)		;nazwa pliku do zapisu (output).
	handle1 	dw  ?				;uchwyt do pliku 1                
	handle2 	dw  ?				;uchwyt do pliku 2                
	buffer		db  BS  dup (?)		;bufor
	bufpos		dw  0				;pozycja w buforze	
	bufchars	dw  0				;ilosc znakow w buforze
	char		db	0				;pojedynczy znak
	eof			db  0				;flaga konca pliku

	buffer_crc	db  4   dup (?)		;bufor do odczytu sumy kontrolnej z pliku input2
		
	;------------------
	;komunikaty i bledy
	kom_zg  db	"Message: checksums are compatible :)",CR,LF,"$"
	kom_nzg db	"Message: checksums are not compatible :(",CR,LF,"$"
	errah	db	"Error: too many arguments!",CR,LF,"$"
	erral	db	"Error: not enough arguments!",CR,LF,"$"
	err1d	db	"Error: if using 3 args version, the first argument must be two signs long",CR,LF,"$"
	err1t	db	"Error: if using 3 args version, the first argument must be '-v'",CR,LF,"$"
	errfo	db	"Error: unable to open file(s).",CR,LF,"$"
	errfs	db	"Error: unable to save data to file.",CR,LF,"$"
	errfc	db	"Error: unable to close file(s).",CR,LF,"$"
	;------------------
daneA ends

stosA segment stack
		dw	256 dup (?)
	top	dw	?
stosA ends

code segment
	;=================
	
	;=================
	;---- WCZYTAJ ----
	;wczytanie danych do tablicy, bez bialych znakow
	WCZYTAJ proc
		push ax
		push bx
		push cx
		push dx
		push di
		push si
		
		mov di,offset tab_dane			;zaladowanie DI offsetem tablicy docelowej
		mov si,82h						;zaladowanie SI adresem pierwszego znaku argumentow
		mov cl,byte ptr es:[80h]		;ilosc znakow w podanych argumentach, lacznie z bialymi znakami
		
		cmp cl,0d						;calkowity brak argumentow
		je koniec						;zakoncz
		cmp cl,1d						;jeden argument, znaczy spacja 
		je koniec						;tez zakoncz
		
		mov ah,1d						;rejestr AH pelni funkcje flagi oczekiwania na argument, 1=true,0=false
		mov bx,offset parg				;zaladowanie BX offsetem tablicy parametrow argumentow
		dec bx							;oczekiwanie przed tablica
		
	kolejny_znak:
		cmp cl,1d						;czy wszystkie znaki zostały przeanalizowane?    1, bo na koncu linii zostaje 13 (CR)
		je koniec
		mov al,es:[si]					;zaladuj kolejny znak do AL
		
		cmp al,20h						;czy to spacja?
		je przesun						;jesli tak, przesun sie dalej
		cmp al,9h						;czy to tabulator?
		je przesun						;jesli tak, przesun sie dalej	
		jne zapisz_znak					;zapisz znak w tablicy docelowej
		
	przesun:
		inc si							;przesun sie o jeden w tablicy wejsciowej
		dec cl							;zmniejsz ilosc znakow	
		mov ah,1d						;oczekiwanie na argument = true
		jmp kolejny_znak
		
	zapisz_znak:
		mov ds:[di],al					;zapisz znak w tablicy docelowej
		inc si							;przesun sie o jeden w tablicy wejsciowej
		dec cl							;zmniejsz ilosc znakow	
		
		cmp ah,1d						;czy oczekiwano na kolejny argument?
		jne dalej						;to nie jest poczatek nowego argumentu, laduj dalej
		mov ah,0d						;to jest poczatek nowego argumentu, flaga oczekiwania=false
		inc ds:[iarg]					;zwiekszenie licznika argumentow
		
		inc bx							;przesun sie o jeden w tablicy dlugosci i adresow argumentow
		mov [bx],di					;zapisz aktualny adres (poczatek argumentu)
		inc bx							;znowu przesun sie o jeden, tamze bedzie zliczana dlugosc danego argumentu
		
	dalej:
		inc di							;przesun sie o jeden w tablicy docelowej					
		add byte ptr [bx],1d			;zwiekszenie licznika dlugosci danego argumentu
		jmp kolejny_znak
			
	koniec:
		pop si
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		ret		
	WCZYTAJ endp
	;=================

	;=================
	;--- KONTROLA ----
	;kontrola danych
	KONTROLA proc
		push ax
		push bx
		push cx
		push dx
		push di
		
		;kontrola ilosci argumentow
		cmp ds:[iarg],2d				;czy wywolano z dwoma argumentami? (wersja 1)
		jb err_args_l					;za malo argumentow
		je koniec
		cmp ds:[iarg],3d				;czy wywolano z trzema argumentami? (wersja 2)
		ja err_args_h					;za duzo argumentow
		
		;wersja 2
		;kontrola poprawnosci pierwszego argumentu
		mov bx,offset parg				;zaladowanie BX offsetem tablicy parametrow argumentow
		inc bx							;0->adres 1 argumentu, 1->dlugosc 1 argumentu, 2->adres 2 argumentu, 3->dlugosc 2 argumentu
		mov ch,2d
		cmp [bx],ch					;sprawdzenie dlugosci 1 argumentu
		jne err_arg1_len				;jezeli rozna od 2, skocz do bledu

		mov di,offset tab_dane			;zaladowanie DI offsetem tablicy danych
		mov al,"-"							;ew. -> 2dh
		cmp ds:[di],al					
		jne err_arg1_type
		inc di
		mov al,"v"							;ew. -> 76h
		cmp ds:[di],al
		jne err_arg1_type
		
		mov ds:[flag],1d
		
	koniec:
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	KONTROLA endp
	;=================
	
	wczytaj_znak macro
		mov al,ds:[bx]
		mov ds:[di],al
		inc di
		inc bx
	endm
	dopisz_zero macro
		mov al,0d
		mov ds:[di],al
	endm
	;=================
	;-- OTWORZ_PLIKI -
	;otwarcie stosownych plikow
	OTWORZ_PLIKI proc
		push ax
		push bx
		push cx
		push dx
		push di
		push si
	
		mov si,offset parg				;source - tablica parametrow argumentow
		cmp ds:[flag],1d				;czy flaga modyfikacji jest rowna 1?
		jne input1						;jesli nie wczytuj plik 'input1'
		add si,2d						;jesli tak, zwieksz si o 2, aby ominac parametry argumentu pierwszego ("-v")
	
	input1:
		mov di,offset fin1				;destination - nazwa pliku
		xor bx,bx
		mov bl, byte ptr ds:[si]		;adres poczatku argumentu
		xor cx,cx
		mov cl, byte ptr ds:[si+1]	;dlugosc argumentu
		i1_nazwa:
			wczytaj_znak
			loop i1_nazwa
		dopisz_zero
		
		mov dx,offset fin1
		mov al,0d						;tryb tylko do odczytu
		mov ah,3dh						;proba otwarcia pliku
		int 21h
		jc err_file_open				;obsluga ewentualnego bledu
		mov ds:[handle1],ax			;uchwyt otrzymany w AX przenies do 'handle1'
		
		cmp ds:[flag],0d				;ponowne sprawdzenie flagi modyfikacji	
		je output						;jesli jest rowna 0, skok do output. w przeciwnym razie kontynuuj 'input2'
		
	input2:
		mov di,offset fin2
		xor bx,bx
		mov bl, byte ptr ds:[si+2]
		xor cx,cx
		mov cl, byte ptr ds:[si+3]
		i2_nazwa:
			wczytaj_znak
			loop i2_nazwa
		dopisz_zero
		
		mov dx,offset fin2
		mov al,0d						;tryb tylko do odczytu
		mov ah,3dh						;proba otwarcia pliku
		int 21h
		jc err_file_open				;obsluga ewentualnego bledu
		mov ds:[handle2],ax			;uchwyt otrzymany w AX przenies do 'handle2'
		
		jmp koniec						;otwarto juz dwa pliki -> koniec
		
	output:
		mov di,offset fon
		xor bx,bx
		mov bl, byte ptr ds:[si+2]
		xor cx,cx
		mov cl, byte ptr ds:[si+3]
		o_nazwa:
			wczytaj_znak
			loop o_nazwa
		dopisz_zero
		
		mov dx,offset fon
		mov al,1d						;tryb tylko do zapisu
		mov ah,3dh						;proba otwarcia pliku
		int 21h
		jc err_file_open				;obsluga ewentualnego bledu
		mov ds:[handle2],ax			;uchwyt otrzymany w AX przenies do 'handle2'
		
	koniec:
		pop si
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	OTWORZ_PLIKI endp
	;=================
	
	;=================
	; INICJUJ_TABLICE 
	;wypelnienie tablicy tab_crc wartosciami potrzebnymy do obliczenia sumy kontrolnej CRC
	INICJUJ_TABLICE proc
		push ax
		push bx
		push cx
		push dx
		push di
	
		xor dx,dx
		mov dl,1d
		mov cl,15d
		shl dx,cl						;teraz w DX jest (1<<15), bedzie uzyte pozniej
		
		mov di,0d						;kolejne znaki ASCII / indeks w tab_crc / licznik petli
	outer_loop:
		mov ax,di
		mov ds:[kod],ax
		call ODWROC_BITY
		mov cl,9d
		inner_loop:
			dec cl
			cmp cl,0d
			je end_inner
			mov bx,ds:[kod]
			mov ds:[kodtmp],bx			;zmienna pomocnicza 'kodtmp'
			
			shl ds:[kod],1d			;kod = (kod << 1);
			
			and ds:[kodtmp],dx			;kodtmp = kod & (1<<15)
			cmp ds:[kodtmp],0d			;kodtmp = 0 ?
			je inner_loop
			xor ds:[kod],POLY			;kod = kod ^ POLY	(POLY to wielomian)
			jmp inner_loop
			
		end_inner:
			call ODWROC_BITY
			mov ax,ds:[kod]
			mov ds:[tab_crc+di],ax		;zapisanie obliczonego kodu do tab_crc
			inc di						;kolejny znak do analizy
			cmp di,256d					;czy juz wszystkie znaki?
			jne outer_loop				;jesli nie, kolejny znak
		
	koniec:
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	INICJUJ_TABLICE endp
	;=================
	
	;=================
	;-- ODWROC_BITY --
	;odwraca bity w zmiennej 'kod'
	ODWROC_BITY proc
		push ax
		push cx
	
		mov cx,16d						;licznik petli, 16 bitow do zamiany
		mov ax,ds:[kod]				;kod do odwrocenia w AX
		mov ds:[kod],0d				;'kod' wyzerowany
		
	kolejny_bit:
		shl ds:[kod],1d				;przesun 'kod' o jeden bit w lewo
		shr ax,1d						;z AX wyciagnij bit z prawej strony
		jnc zero						;sprawdzenie flagi CF
		add ds:[kod],1d				;jesli CF=1, wyciagniety bit byl jedynka, wiec 'kod' += 1
	zero:
		loop kolejny_bit
				
	koniec:
		pop cx
		pop ax
		ret
	ODWROC_BITY endp
	;=================
	
	;=================
	;--- GET_CHAR ----
	;pobiera jeden znak z bufora, w razie potrzeby laduje bufor
	GET_CHAR proc
		push ax
		push bx
		push cx
		push dx

		mov ax,ds:[bufpos]
		mov dx,ds:[bufchars]
		cmp dx,ax
		ja get_from_buff

		;zaladowanie danych do bufora
		mov ah,3fh						;odczyt
		mov bx,ds:[handle1]			;uchwyt do pliku 1
		mov cx,BS						;rozmiar bufora, 512 znakow
		mov dx,offset buffer		
		int 21h

		mov ds:[bufpos],0				;wyzerowanie pozycji w buforze
		mov ds:[bufchars],ax			;w AX otrzymano ilosc pobranych znakow

	get_from_buff:
		mov ax,ds:[bufchars]
		cmp ax,0d						;jezeli pobrano 0 znakow -> koniec pliku
		je end_of_file
		
		mov bx,ds:[bufpos]				;biezaca pozycja do BX
		mov al,ds:[buffer + bx] 		;odczyt znaku z bufora
		mov ds:[char],al				;zapisz znak w 'char'
		inc ds:[bufpos] 				;przesuniecie w buforze do kolejnego znaku
		jmp go_back
	
	end_of_file:
		mov ds:[eof],1d				;koniec pliku
	go_back:     
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	GET_CHAR endp
	;=================
	
	;=================
	;-- OBLICZ_CRC ---
	;oblicza sume kontrolna CRC dla pliku input/input1
	OBLICZ_CRC proc
		push ax
		push bx
		push cx
		push dx
		push si

		xor ax,ax
		mov ds:[crc],ax				;wyzerowanie 'crc'
		mov ds:[crc],65535d			;crc = 2^16 - 1
		mov si,offset tab_crc
	crc_loop:
		call GET_CHAR
		cmp ds:[eof],1d
		je koniec
		
		mov ax,ds:[crc]
		mov ds:[crctmp],ax				;kopia 'crc'
		and ds:[crctmp],255d			;crc & 255
		xor dx,dx
		mov dl,ds:[char]				;znak do DX
		xor ds:[crctmp],dx				;crctmp = (crc & 255) XOR char
		mov bx,ds:[crctmp]				;powyzsze do BX
		mov cl,8d
		shr ds:[crc],cl				;crc = crc>>8
		mov dx,ds:[si+bx]				;tab_crc[(crc & 255) XOR char]
		xor ds:[crc],dx				;crc = (crc>>8) XOR tab_crc[(crc & 255) XOR char]
		
		jmp crc_loop
		
	koniec:    
		mov cx,65535d
		xor ds:[crc],cx				;crc = crc XOR (2^16 -1)
		
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	OBLICZ_CRC endp
	;=================
	
	;=================
	;- ZAMIEN_NA_HEX -
	;obliczona sume kontrolna zamienia na postac hex
	ZAMIEN_NA_HEX proc
		push ax
		push bx
		push cx
		push dx
		push si

		mov ax,ds:[crc]				;suma CRC do AX
		mov bx,16d						;dzielnik = 16
		mov si,offset tab_crc_hex		;tablica w ktorej bedzie zapisana postac heksadecymalna
	div16:
		xor dx,dx						;wyzerowanie DX
		div bx							;AX = AX div BX, reszta w DX
		push dx							;odlozenie reszty na stos, celem odwrocenia kolejnosci
		inc cl
		cmp cl,4d
		jne div16						;dzielenie trzeba wykonac 4 razy
	zapisz_cyfre:
		pop dx							;pobranie kolejnej cyfry ze stosu
		cmp dx,10d						;okreslenie czy cyfra jest 0-9 czy A-F
		jae litera
		add dx,48d						;przesuniecie celem otrzymania wlasciwego znaku ASCII
		jmp zapis
		litera:
			add dx,55d
		zapis:
			mov ds:[si],dl				;zapisanie cyfry HEX do tablicy
			inc si
		dec cl
		cmp cl,0d
		jne zapisz_cyfre	
		
		pop si
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	ZAMIEN_NA_HEX endp
	;=================
	
	;=================
	;-ZAPISZ_DO_PLIKU-
	;obliczona sume CRC w postaci heksadecymalnej zapisuje do pliku output
	ZAPISZ_DO_PLIKU proc
		push ax
		push bx
		push cx
		push dx

		mov bx,ds:[handle2]            ;uchwyt pliku do zapisu w BX
		mov cx,4d					    ;liczba bajtow do zapisania
		mov dx,offset tab_crc_hex      	;dane do zapisania
		mov ah,40h                     	;przerwanie zapisu do pliku
		int 21h
		jc err_file_save                ;w razie problemu skok do komunikatu
		
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	ZAPISZ_DO_PLIKU endp
	;=================
	
	;=================
	;--POROWNAJ_CRC --
	;porownuje zgodnosc obliczonej sumy CRC pliku input1 oraz sumy zapisanej w pliku input2
	POROWNAJ_CRC proc
		push ax
		push bx
		push cx
		push dx
		push di
		push si
		
		;zaladowanie sumy kontrolnej z pliku input2
		mov ah,3fh						;odczyt
		mov bx,ds:[handle2]			;uchwyt do pliku 2
		mov cx,4						;rozmiar bufora, 4 znaki
		mov dx,offset buffer_crc		
		int 21h
		
		mov si,offset buffer_crc
		mov di,offset tab_crc_hex
		mov cx,4d
		mov bl,0d
		porownaj:
			mov al,ds:[si+bx]
			mov dl,ds:[di+bx]
			cmp al,dl
			jne niezgodnosc
			inc bl
			loop porownaj
			
	;zgodnosc sum
		mov dx,offset kom_zg
		mov ah,9
		int 21h
		jmp koniec
		
	niezgodnosc:
		mov dx,offset kom_nzg
		mov ah,9
		int 21h
		
	koniec:
		pop si
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	POROWNAJ_CRC endp
	;=================
	
	;=================
	;- ZAMKNIJ_PLIKI -
	;zamyka uzywane pliki
	ZAMKNIJ_PLIKI proc
		push ax
		push bx
	
		mov bx,ds:[handle1]
		mov ah,3eh						;zamkniecie pliku
		int 21h
		jc err_file_close
		
		mov bx,ds:[handle2]
		int 21h
		jc err_file_close

		pop bx
		pop ax
		ret
	ZAMKNIJ_PLIKI endp
	;=================
	
	;+++++++++++++++++

		program:
			;PSP do rejestru ES
			mov ah, 62h
			int 21h
			mov bx,ds
			mov es,bx
			
			;segment danych do DS
			mov ax,daneA
			mov ds,ax

			;inicjalizacja stosu
			mov ax,seg stosA
			mov ss,ax
			mov sp,offset top
			
			xor ax,ax
			xor bx,bx
			
			;glowna czesc programu - wywolania funkcji
			call WCZYTAJ
			call KONTROLA
			call OTWORZ_PLIKI
			call INICJUJ_TABLICE
			call OBLICZ_CRC
			call ZAMIEN_NA_HEX
			
			cmp ds:[flag],1d
			je wersja2
			call ZAPISZ_DO_PLIKU
			jmp ending
		wersja2:
			call POROWNAJ_CRC			
		ending:
			call ZAMKNIJ_PLIKI
			
			;koniec programu
			mov ah,4ch
			int 21h		
	;=================
	
	;=================
	wypisz_zakoncz macro
		mov ah,9
		int 21h
		mov ah,4ch
		int 21h	
	endm
	;=================
	;-----------------
	;OBSLUGA BLEDOW	
	err_args_l:
		mov dx,offset erral
		wypisz_zakoncz
	err_args_h:
		mov dx,offset errah
		wypisz_zakoncz		
	err_arg1_len:
		mov dx,offset err1d
		wypisz_zakoncz
	err_arg1_type:
		mov dx,offset err1t
		wypisz_zakoncz
	err_file_open:
		mov dx,offset errfo
		wypisz_zakoncz
	err_file_save:
		mov dx,offset errfs
		wypisz_zakoncz		
	err_file_close:
		mov dx,offset errfc
		wypisz_zakoncz
			
code ends
end program
