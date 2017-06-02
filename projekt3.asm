; Ludwik Ciechanski
; 
; PROJEKT 3
; krzywa Kocha
; +++++++++++++++++

.387								
CR		equ	13 
LF		equ	10
ARG		equ	2						;maksymalna liczba argumentow
IMAX	equ 6						;maksymalna liczba iteracji
LSIZE	equ 28672					;maksymalna dlugosc napisu opisujacego krzywa
; uzasadnienie: dlugosc napisu opisujacego krzywa Kocha dla n iteracji dana jest wzorem: K(n) = 7 * 4^n
; K(6) = 28672, K(7) = 114688, natomiast rozmiar segmentu to 65536

daneA segment
	tab_dane	db	128	dup (?)		;tablica do ktorej zostana wczytane dane wejsciowe (argumenty z linii polecen)
	iarg 		db	0d				;ilosc argumentow
	parg 		db	ARG*2 dup (0)	;parametry poszczegolnych argumentow: adres1,dlugosc1,adres2,dlugosc2,...
	
	iternum		db	0d				;liczba iteracji l-systemu (dopuszczalna wartosc: 0-6)
	len			db	0d				;dlugosc pojedynczego odcinka krzywej (dopuszczalna wartosc: 1-80)
	lsystem		db 	LSIZE dup (?)	;miejsce na stworzenie l-systemu
				db  ?
	
	three 		dw 	3				;uzywane do obliczenia 60 stopni = PI / 3
	x 			dw 	32d				;wspolrzedna x pixela
	y 			dw 	50d				;wspolrzedna y pixela
	temp		dw  0				;zmienna pomocnicza
	;--------------------------------------------------------
	;komunikaty i bledy
	errah	db	"Error: too many arguments!",CR,LF,"$"
	erral	db	"Error: not enough arguments!",CR,LF,"$"
	errtyp	db	"Error: arguments must be numbers!",CR,LF,"$"
	errbig1	db	"Error: 'iternum' might be maximum 6!",CR,LF,"$"
	errbig2	db	"Error: 'len' might be maximum 99!",CR,LF,"$"	
	;--------------------------------------------------------
daneA ends

stosA segment stack
		dw	512 dup (?)
	top	dw	?
stosA ends

code segment	
	;==================================
	;-----------LOAD_ARGS--------------
	;wczytanie danych do tablicy, bez bialych znakow
	LOAD_ARGS proc
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
	LOAD_ARGS endp
	;==================================

	;==================================
	;----------PARSE_ARGS--------------
	;sprawdza poprawnosc argumentow
	;konewertuje string -> liczba
	PARSE_ARGS proc
		push ax
		push bx
		push cx
		push dx
		push di
		
		;kontrola ilosci argumentow
		cmp ds:[iarg],ARG				;czy wywolano z dwoma argumentami?
		jb err_args_l					;za malo argumentow
		ja err_args_h					;za duzo argumentow
		
		;dane
		mov si,offset tab_dane			;zaladowanie SI offsetem tablicy danych
		mov bx,offset parg				;zaladowanie BX offsetem tablicy parametrow argumentow
		
		;czy dane argumenty sa liczbami
		;1 argument (iternum)
		inc bx							;0->adres 1 argumentu, 1->dlugosc 1 argumentu, 2->adres 2 argumentu, 3->dlugosc 2 argumentu
		mov cl,[bx]					;dlugosc pierwszego argumentu do CL
		cmp cl,1d						;iternum < 10 ?
		jne err_args_big_iternum		;jesli nie, skocz do bledu
		
		mov ch,48d						;48d = 0
		cmp ds:[si],ch
		jb err_args_type				;jezeli znak < 0, skocz do bledu
		mov ch,57d						;57d = 9
		cmp ds:[si],ch
		ja err_args_type				;jezeli znak > 9, skocz do bledu
		
		mov al,ds:[si]
		sub al,48d						;"ascii -> int"
		cmp al,IMAX						;sprawdzenie czy podana wartosc nie przekracza 6
		ja err_args_big_iternum			;jesli > 6, skocz do bledu
		mov ds:[iternum],al			;zapisanie wartosci do zmiennej 'iternum'
		
		;2 argument (len)
		add bx,2d						;przejscie w parg do dlugosci drugiego argumentu
		mov cl,[bx]					;dlugosc drugiego argumentu do CL
		cmp cl,2d						;len < 100 ?
		ja err_args_big_len				;jesli nie, skocz do bledu
		
	next_char:
		inc si							;przesuniecie w tablicy danych do kolejnego znaku
		
		mov ch,48d						;48d = 0
		cmp ds:[si],ch
		jb err_args_type				;jezeli znak < 0, skocz do bledu
		mov ch,57d						;57d = 9
		cmp ds:[si],ch
		ja err_args_type				;jezeli znak > 9, skocz do bledu
		
		mov dl,1d						;mnoznik
		dec cl				
		cmp cl,0d						;czy zostal jeden znak?
		je one_char
		mov dl,10d						;jesli dwa znaki -> mnoznik = 10
		one_char:
			mov al,ds:[si]
			sub al,48d					;"ascii -> int"
			mul dl						;ax = al * dl
			add ds:[len],al			;dodanie wyniku mnozenia do zmiennej 'len'
		cmp cl,0d
		jne next_char		
			
		pop di
		pop dx
		pop cx
		pop bx
		pop ax
		ret
	PARSE_ARGS endp
	;==================================
	
	;==================================
	;--------GENERATE_LSYSTEM----------
	;rekurencyjnie generuje l-system zadany przez 'iternum'
	GENERATE_LSYSTEM proc	
		push ax
		push bx
		push cx
		push di
		
		mov ax,seg daneA
		mov es,ax
		
		xor cx,cx
		mov cl,byte ptr ds:[iternum]	;CX = iternum
		mov di,offset lsystem			;zaladowanie DI offsetem napisu reprezentujacego l-system
		
		mov ah,'F'			;znaki wykorzystywane do tworzenia napisu
		mov bl,'-'
		mov bh,'+'
		
		;---------------------
		call iterationF		;F
		mov al,bh			
		stosb				;+	
		stosb				;+
		call iterationF		;F
		mov al,bh			
		stosb				;+	
		stosb				;+
		call iterationF		;F
		;---------------------
		
		mov al,0			;dodanie symbolu (zero) konczacego napis
		stosb	
		pop di
		pop cx
		pop bx
		pop ax
		ret
		
	iterationF:
		jcxz stop			;CX == 0, warunek konca
		dec cx 				;wywolania rekurencyjne z (CX-1)

		;---------------------
		call iterationF		;F
		mov al,bl
		stosb				;-
		call iterationF		;F
		mov al,bh
		stosb				;+
		stosb				;+
		call iterationF		;F
		mov al,bl
		stosb				;-
		call iterationF		;F
		;---------------------

		inc cx 				;powrot
		ret		
	stop:
		mov al,ah			;F
		stosb 				;ES:[DI] <- AL, DI++
		ret
	GENERATE_LSYSTEM endp
	;==================================
	
	;==================================
	;---------DRAW_KOCH_CURVE----------
	;analizuje kolejne znaki napisu reprezentujacego l-system
	DRAW_KOCH_CURVE proc
		push ax
		push si
		
		finit
		fldpi							;[PI]
		fidiv word ptr ds:[three]		;[PI/3]
		fldz							;[angle=0, PI/3]
		fild word ptr ds:[y]			;[y, angle=0, PI/3]
		fild word ptr ds:[x]			;[x, y, angle=0, PI/3]
		
		mov si,offset lsystem		;zaladowanie SI offsetem napisu Lsystem
		dec si
		
	analyse_chars:
		inc si
		mov al,ds:[si]				;pojedynczy znak do AL
		cmp al,0
		je end_analyse
		cmp al,'+'
		je add_angle
		cmp al,'-'
		je sub_angle
		
		call DRAW_LINE				;F -> rysuj linie
		jmp analyse_chars
		
		add_angle:					;[x, y, angle, PI/3]
			fxch st(2)				;[angle, y, x, PI/3]
			fadd st(0),st(3)		;[angle+PI/3, y, x, PI/3]
			fxch st(2)				;[x, y, angle, PI/3]
			jmp analyse_chars
			
		sub_angle:					;[x, y, angle, PI/3]	
			fxch st(2)				;[angle, y, x, PI/3]
			fsub st(0),st(3)		;[angle-PI/3, y, x, PI/3]
			fxch st(2)				;[x, y, angle, PI/3]
			jmp analyse_chars
		
	end_analyse:
		pop si
		pop ax
		ret
	DRAW_KOCH_CURVE endp
	;==================================
	
	;==================================
	;------------DRAW_LINE-------------
	;rysuje pojedyncza prosta zadana przez wartosci z rejestrow koprocesora
	DRAW_LINE proc
		push ax
		push cx
		push di
		
		fld st(2)					;[angle, x, y, angle, PI/3]
		fsincos						;[cos, sin, x, y, angle, PI/3]
							
		mov cl,ds:[len]			;dlugosc linii do CL
	
	line_pixel:
		cmp cl,0d
		je line_end
		
		mov ax,0A000h
		mov es,ax
		
		fxch st(3)
		fist word ptr ds:[temp]	;y do zmiennej temp
		fxch st(3)	
		cmp ds:[temp],199d			;czy nie wychodze poza dolny zakres
		ja skip_pixel
		
		mov ax,ds:[temp]
		mov di,320
		mul di						;AX = 320 * y
		
		fxch st(2)
		fist word ptr ds:[temp]	;x do zmiennej temp
		fxch st(2)
		cmp ds:[temp],319d			;czy nie wychodze poza prawy zakres
		ja skip_pixel
		
		add ax,ds:[temp]			;AX = 320 * y + x
		mov di,ax					;DI = AX
		mov al,byte ptr ds:[temp]	;ustawienie koloru
		mov byte ptr es:[di],al	;pokolorowanie odpowiedniego piksela
		
	skip_pixel:
		fxch st(2)
		fadd st(0),st(2)			;x += cos(angle)
		fxch st(2)
		
		fxch st(3)
		fadd st(0),st(1)			;y += sin(angle)
		fxch st(3)
	
		dec cl
		jmp line_pixel
	line_end:					
		fistp word ptr ds:[temp]
		fistp word ptr ds:[temp]
		
		pop di
		pop cx
		pop ax
		ret			
	DRAW_LINE endp
	;==================================

	;++++++++++++++++++++++++++++++++++

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
			
			;-----------------------------------------
			;glowna czesc programu - wywolania funkcji
			call LOAD_ARGS
			call PARSE_ARGS
			call GENERATE_LSYSTEM
			
			;tryb graficzny 320x200
			mov ah,0
			mov al,13h
			int 10h
			
			call DRAW_KOCH_CURVE
			;-----------------------------------------
			
			;czekaj na dowolny klawisz
			xor ax,ax
			int 16h
			
			;wyjscie z trybu graficznego
			mov ax,3
			int 10h
			
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
	err_args_type:
		mov dx,offset errtyp
		wypisz_zakoncz
	err_args_big_iternum:
		mov dx,offset errbig1
		wypisz_zakoncz
	err_args_big_len:
		mov dx,offset errbig2
		wypisz_zakoncz
			
code ends
end program