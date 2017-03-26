; Ludwik Ciechanski
; 
; PARSER ARGUMENTOW
; +++++++++++++++++

ARG equ 4

daneA segment
	tab_dane	db	128 dup (?) 	;tablica do ktorej zostana wczytane dane wejsciowe
	iarg 		db	0d				;ilosc argumentow
	parg 		db	ARG*2 dup (0)	;parametry poszczegolnych argumentow: adres1,dlugosc1,adres2,dlugosc2,...
	licznik 	db	0d				;ilosc znakow do przetworzenia
	
	;------------------
	;komunikaty i bledy
	err0	db	"Blad: za duzo argumentow! $"
	;------------------
daneA ends

stosA segment stack
	dw	100 dup (?)
top dw	?
stosA ends

kod segment
	;-----------------
	odloz_rejestry macro
		push ax
		push bx
		push cx
		push dx
	endm
	przywroc_rejestry macro
		pop dx
		pop cx
		pop bx
		pop ax
	endm
	;=================
	;----- WCZYTAJ ------
	;wczytanie danych do tablicy, bez bialych znakow
	WCZYTAJ proc
		odloz_rejestry
		
		mov di,offset tab_dane			;zaladowanie DI offsetem tablicy docelowej
		mov si,82h						;zaladowanie SI adresem pierwszego znaku argumentow
		mov cl,byte ptr es:[80h]		;ilosc znakow w podanych argumentach, lacznie z bialymi znakami
		
		cmp cl,0d						;calkowity brak argumentow
		je koniec						;zakoncz
		cmp cl,1d						;jeden argument, znaczy spacja 
		je koniec						;tez zakoncz
		
		mov ah,1d						;rejestr AH pelni funkcje flagi oczekiwania na argument, 1=true,0=false
		mov bx,offset parg				;zaladowanie BX offsetem tablicy parametrow argumentow
		dec bx							;start przed tablica, pozniej bedzie 'inc'
		
	kolejny_znak:
		cmp cl,1d						;czy wszystkie znaki zostały przeanalizowane?    1, bo na koncu linii zostaje 13,CR
		je koniec
		mov al,es:[si]					;zaladuj kolejny znak do AL
		
		cmp al,20h						;czy to spacja?
		je przesun						;jesli tak, przesun sie dalej
		cmp al,9h						;czy to tabulator?
		je przesun						;jesli tak, przesun sie dalej				;	
		jne zapisz_znak					;zapisz znak w tablicy docelowej			;
		
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

		cmp ds:[iarg],ARG				;czy nie ma juz zbyt wielu argumentow?
		ja err_za_duzo_arg				;jesli za duzo to skocz do bledu
		
		inc bx							;przesun sie o jeden w tablicy dlugosci i adresow argumentow
		mov [bx],di					;zapisz aktualny adres (poczatek argumentu)
		inc bx							;znowu przesun sie o jeden, tamze bedzie zliczana dlugosc danego argumentu
		
	dalej:
		inc di							;przesun sie o jeden w tablicy docelowej
		mov dh,1d
		add [bx],dh					;zwiekszenie licznika dlugosci danego argumentu
		jmp kolejny_znak
			
	koniec:
		przywroc_rejestry
		ret		
	WCZYTAJ endp
	;=================
	
	;=================
	;------ WYPISZ -------
	;wypisanie argumentow
	;w kolejnych liniach

	WYPISZ proc
		odloz_rejestry
		
		mov bx,offset parg				;do BX offset tablicy parametrow argumentow
		inc bx							;na pierwszej pozycji jest adres, na drugiej dlugosc, itd.
		mov cl,ds:[iarg]				;do CL ilosc argumentow do wypisania
		mov ax,0d
		mov si,ax
		
	kolejny_argument:
		mov ch,[bx]					;do CH dlugosc biezacego argumentu
		mov di,si
		
		wypisz_znak:
			mov dl,ds:[tab_dane+si]	;aktualny znak do wypisania
			mov ah,2
			int 21h
			
			inc si
			dec ch
			cmp ch,0d
			jne wypisz_znak	
		
		;----------------
		COMMENT @
		mov dl,9d						;tabulator
		mov ah,2
		int 21h
		
		mov dl,"("
		mov ah,2
		int 21h
		
		xor ax,ax 

		push cx
			mov ax,si
			sub ax,di
			
			mov cl,10d
			div cl

			mov ch,ah
			
			add al,48d
			mov dl,al
			mov ah,2
			int 21h
			
			add ch,48d
			mov dl,ch
			mov ah,2
			int 21h
		pop cx
		
		mov dl,")"
		mov ah,2
		int 21h
		@
		;--------------------
		
		mov dl,10d                  	;nowa linia				
		mov ah,2 				
		int 21h
		
		add bx,2d
		dec cl
		cmp cl,0d
		jne kolejny_argument	
		
		przywroc_rejestry
		ret
	WYPISZ endp
	;=================
	
	;+++++++++++++++++

		program:
			;PSP do rejestru ES
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
			call WYPISZ
			
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
	
	err_za_duzo_arg:
		mov dx,offset err0
		wypisz_zakoncz
			
kod ends
end program