; Ludwik Ciechanski
; 
; PROJEKT 1
; skrot klucza publicznego w postaci grafiki ASCII
; +++++++++++++++++

ARG equ 2

daneA segment
	tab_dane	db	128 dup (?) 	;tablica do ktorej zostana wczytane dane wejsciowe
	tab_bin		db	16	dup (?)		;tablica z zapisem binarnym klucza
	tab_szach	db	153 dup	(0)		;tablica reprezentujaca szachownice 17x9
	tab_ascii	db	'.','o','+','=','*','B','O','X','@','%','&','#','/','^' ;znaki ascii
	
	iarg 		db	0d				;ilosc argumentow
	parg 		db	ARG*2 dup (0)	;parametry poszczegolnych argumentow: adres1,dlugosc1,adres2,dlugosc2,...
	pole_kon	dw	1				;pole zakonczenia ruchow gonca/skoczka
	flaga		db	0d				;flaga modyfikacji
	ramka_gorna db	"+---[RSA  1024]---+$"
	ramka_dolna db 	"+-----------------+$"
		
	;------------------
	;komunikaty i bledy
	err0	db	"Blad: za duzo argumentow! $"
	err1d	db	"Blad: wymagana dlugosc pierwszego argumentu: 1 $"
	err1t	db	"Blad: pierwszy argument winien byc 0 lub 1 $"
	err2d	db	"Blad: wymagana dlugosc drugiego argumentu: 32 $"
	err2t	db	"Blad: drugi argument winien skladac sie ze znakow 0-9a-f $"
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
	endm
	przywroc_rejestry macro
		pop cx
		pop bx
		pop ax
	endm
	;=================
	;---- WCZYTAJ ----
	;wczytanie danych do tablicy, bez bialych znakow
	WCZYTAJ proc
		push ax
		push bx
		push cx
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
		dec bx							; ?
		
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

		cmp ds:[iarg],ARG				; 
		ja err_za_duzo_arg				;
		
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
		
		;kontrola dlugosci argumentow
		mov bx,offset parg				;zaladowanie BX offsetem tablicy parametrow argumentow
		inc bx							;0->adres 1 argumentu, 1->dlugosc 1 argumentu, 2->adres 2 argumentu, 3->dlugosc 2 argumentu
		mov ch,1d
		cmp [bx],ch					;sprawdzenie dlugosci 1 argumentu
		jne err_1_dlugosc				;jezeli rozna od 1, skocz do bledu
		
		add bx,2d						;3->dlugosc 2 argumentu
		mov ch,32d
		cmp [bx],ch					;sprawdzenie dlugosci 2 argumentu
		jne err_2_dlugosc				;jezeli rozna od 32, skocz do bledu
		
		;kontrola poprawnosci argumentow
		mov di,offset tab_dane			;zaladowanie DI offsetem tablicy danych

		;-- 1 argument --
		;----- 0/1 ------
		mov al,30h						;zero w kodzie ASCII
		cmp ds:[di],al					
		jb err_1_typ					;jezeli mniejszy od zera, skocz do bledu
		mov al,31h						;jedynka w kodzie ASCII
		cmp ds:[di],al
		ja err_1_typ					;jezeli wiekszy od jedynki, skocz do bledu
		
		mov dl,ds:[di]
		sub dl,48d						; :) :) :) :)
		mov ds:[flaga],dl				;zapisz flage
		
		;--- 2 argument ----
		;- 32 cyfry 0-9a-f -
		mov ch,[bx]					;do CH dlugosc 2 argumentu
		inc ch							;
		
		kolejny_znak:
			dec ch
			cmp ch,0d					;sprawdzenie czy wszystkie znaki zostaly przeanalizowane
			je koniec					;jezeli tak, skocz na koniec
			inc di						;przesun sie do kolejnej cyfry (zacznie od pierwszej, bo wczesniej byl na 1 argumencie
			
			mov al,30h					;30h = 0
			cmp ds:[di],al
			jb err_2_typ				;jezeli znak < 0, skocz do bledu
			mov al,39h					;39h = 9
			cmp ds:[di],al
			jbe cyfra					;jezeli 0 <= znak <= 9, skocz do cyfra
			mov al,61h					;61h = a
			cmp ds:[di],al
			jb err_2_typ				;jezeli 9 < znak < 'a', skocz do bledu
			mov al,66h					;66h = f 
			cmp ds:[di],al				
			jbe litera					;jezeli 'a'<= znak <='f' skocz do litera
			ja err_2_typ				;jezeli znak jest dalej niz 'f', skocz do bledu
			
		cyfra:
			mov al,48d					;przesuniecie: 0-9 (znak) -> 0-9 (dec)
			sub ds:[di],al
			jmp kolejny_znak
			
		litera:
			mov al,87d					;przesuniecie: a-f (znak) -> 10-15 (dec)
			sub ds:[di],al
			jmp kolejny_znak
		
		koniec:
			pop di
			pop dx
			pop cx
			pop bx
			pop ax
			ret
	KONTROLA endp
	;=================
	
	;=================
	;------ HEXBIN -------
	;pary cyfr heksadecymalnych
	;zamienia na 1 bajtowe liczby binarne
	HEXBIN proc
		push ax
		push cx
		push dx
		push di
		push si
	
		mov si,offset tab_dane			;SI-source index, zaladowany offsetem tablicy danych argumentow
		inc si							;aby byc na poczatku cyfr hex, pierwsza w tab_dane jest flaga 0/1
		mov di,offset tab_bin			;DI-destination index, zaladowany offsetem tablicy w ktorej zapisze binarna reprezentacje klucza
		mov ch,16d						;iterator petli, ktora wykona sie 16 razy (tyle jest par cyfr hex)
		
		kolejna_para:
			mov al,ds:[si]				;pobranie pierwszej cyfry do AL
			inc si						;przejscie do nastepnej cyfry
			mov cl,4d					;
			shl al,cl					;przesuniecie pierwszej cyfry o 4 bity w lewo
			mov dl,al					;przechowalnia
			
			mov al,ds:[si]				;pobranie drugiej cyfry do AL
			inc si						;przejscie dalej
			
			add dl,al					;sumowanie, w DL znajdzie sie binarna reprezentacja (1 bajt) dwoch analizowanych cyfr hex
			mov ds:[di],dl				;zapisanie wyniku w tablicy docelowej
			inc di						;przejscie dalej w tejze tablicy
		
			dec ch						;zmniejszenie iteratora petli
			cmp ch,0d					;czy wszystkie pary zostaly przeanalizowane?
			jne kolejna_para			;jesli nie, analizuj kolejna pare
	
		pop si
		pop di
		pop dx
		pop cx
		pop ax
		ret
	HEXBIN endp
	;=================
	
	;=================
	;--ANALIZA_BITOW--
	;16 bajtow * 4 pary bitow
	ANALIZA_BITOW proc
			push ax
			push cx
			push dx
			push di
			push si
	
			mov di,offset tab_bin			;zaladowanie DI offsetem tablicy zawierajacej binarna reprezentacje skrotu klucza
			mov ch,17d						;iterator petli glownej (do analizy jest 16 bajtow) 		;17, bo na poczatku petli 'dec'
			mov si,76d						;w SI bedzie pozycja gonca, poczatkowa -> 76 (srodek szachownicy)

		kolejny_bajt:
			dec ch
			cmp ch,0d						;jesli przeanalizowano wszystkie bajty
			je koniec						;skocz do 'koniec'
			
			mov al,ds:[di]					;zaladuj do AL bajt do analizy
			inc di							;przesun dalej (dla nastepnego przebiegu petli)
			mov dh,5d						;licznik par bitow		;5, bo na poczatku petli 'dec'
			
			kolejna_para:
				dec dh
				cmp dh,0d					;jesli przeanalizowano 4 pary bitow
				je kolejny_bajt				;analizuj kolejny bajt
				
				;"w kazdym bajcie goniec analizuje pary bitow, w kierunku od najmlodszej do najstarszej"
				shr al,1d					;przesuniecie w prawo o 1 bit, flaga CF przyjmuje wartosc ostatniego bitu "wyrzuconego" poza obreb
				jnc west					;CF=0 -> przesuniecie w lewo / na zachod
				jmp east					;w przeciwnym przypadku CF=1 -> przesuniecie w prawo / na wschod
				
				west:
					shr al,1d				;przesuniecie w prawo, teraz bedzie analizowany drugi bit z pary
					jc S_W					;jesli CF=1 -> przesuniecie w dol -> poludniowy zachod -> SW
					jmp N_W					;jesli CF=0 -> przesuniecie w gore -> polnocny zachod -> NW
				east:
					shr al,1d				;przesuniecie w prawo, teraz bedzie analizowany drugi bit z pary
					jc S_E					;jesli CF=1 -> przesuniecie w dol -> poludniowy wschod -> SE
					jmp N_E					;jesli CF=0 -> przesuniecie w gore -> polnocny wschod -> NE
				
				S_W:
					call ruch_SW
					jmp kolejna_para
				N_W:
					call ruch_NW
					jmp kolejna_para
				S_E:
					call ruch_SE
					jmp kolejna_para
				N_E: 
					call ruch_NE
					jmp kolejna_para
		
		koniec:
			mov ds:[pole_kon],si			;zapisanie pola w ktorym goniec / skoczek zakonczyl ruchy
			pop si
			pop di
			pop dx
			pop cx
			pop ax
			ret
	ANALIZA_BITOW endp
	;=================
	
	;+++++++++++++++++
	;RUCHY GONCA / SKOCZKA
	;pole gonca / skoczka w SI
	;-----------------
	zwieksz_licznik_odwiedzin_pola macro
		mov bx,offset tab_szach				;poczatek szachownicy do BX
		add bx,si							;przejscie do pola aktualnie zajmowanego przez gonca/skoczka
		mov ax,1d
		add ds:[bx],ax						;zwiekszenie o 1 licznika odwiedzin danego pola
	endm
	;-----------------
	flaga_plus macro
		mov cl,ds:[flaga]					;wartosc flagi do CL
		inc cl								;zwiekszenie CL o jeden, bedzie on iteratorem petli przesuniec w prawo
				;jesli flaga=0 petla wykona sie jeden raz (ruch gonca)  /  jesli flaga=1 petla wykona sie dwa razy (ruch skoczka)
	endm
	;-----------------
	ruch_NE proc
		odloz_rejestry
		flaga_plus
		
		cmp si,16d							;czy goniec jest w prawym gornym rogu?
		je koniec							;jesli tak, skocz na koniec
		cmp si,17d							;czy goniec jest przy gornej granicy szachownicy?
		ja north							;jesli nie, skocz do north (jedno pole w gore)
		jb east								;jesli tak, skocz do east (tylko ruch(y) w prawo)
		
		north:
			sub si,17d						;ruch do gory
		east:
			;operacja 'div' pracuje na rejestrze AX, w AL bedzie wynik dzialania, w AH reszta
			mov ax,si						;biezaca pozycja gonca do AX
			mov bh,17d						;dzielna=17 do BH
			div bh							;AX div BH
			cmp ah,16d						;reszta w AH, czy jest rowna 16?
			je koniec						;jesli tak, to goniec jest przy prawej krawedzi -> koniec		
			inc si							;w przeciwnym razie goniec idzie w prawo
			
			dec cl							;sprawdzenie czy to goniec czy skoczek
			cmp cl,0d						
			jne east						;jesli skoczek, to petla wykona sie jeszcze raz
			
		koniec:
			zwieksz_licznik_odwiedzin_pola
			przywroc_rejestry
			ret
	ruch_NE endp
	;-----------------
	ruch_NW proc
		odloz_rejestry
		flaga_plus
		
		cmp si,0d							;czy goniec jest w lewym gornym rogu?
		je koniec							;jesli tak, skocz na koniec
		cmp si,17d							;czy goniec jest przy gornej granicy szachownicy?
		ja north							;jesli nie, skocz do north (jedno pole w gore)
		jb west								;jesli tak, skocz do west (tylko ruch(y) w lewo)
		
		north:
			sub si,17d						;ruch do gory
		west:
			;operacja 'div' pracuje na rejestrze AX, w AL bedzie wynik dzialania, w AH reszta
			mov ax,si						;biezaca pozycja gonca do AX
			mov bh,17d						;dzielna=17 do BH
			div bh							;AX div BH
			cmp ah,0d						;reszta w AH, czy jest rowna 0?
			je koniec						;jesli tak, to goniec jest przy lewej krawedzi -> koniec		
			dec si							;w przeciwnym razie goniec idzie w lewo
			
			dec cl							;sprawdzenie czy to goniec czy skoczek
			cmp cl,0d						
			jne west						;jesli skoczek, to petla wykona sie jeszcze raz
			
		koniec:
			zwieksz_licznik_odwiedzin_pola
			przywroc_rejestry
			ret
	ruch_NW endp
	;-----------------
	ruch_SE proc
		odloz_rejestry
		flaga_plus
		
		cmp si,152d							;czy goniec jest w prawym dolnym rogu?
		je koniec							;jesli tak, skocz na koniec
		cmp si,135d							;czy goniec jest przy dolnej granicy szachownicy?
		jb south							;jesli nie, skocz do south (jedno pole w dol)
		ja east								;jesli tak, skocz do east (tylko ruch(y) w prawo)
		
		south:
			add si,17d						;ruch w dol
		east:
			;operacja 'div' pracuje na rejestrze AX, w AL bedzie wynik dzialania, w AH reszta
			mov ax,si						;biezaca pozycja gonca do AX
			mov bh,17d						;dzielna=17 do BH
			div bh							;AX div BH
			cmp ah,16d						;reszta w AH, czy jest rowna 16?
			je koniec						;jesli tak, to goniec jest przy prawej krawedzi -> koniec		
			inc si							;w przeciwnym razie goniec idzie w prawo
			
			dec cl							;sprawdzenie czy to goniec czy skoczek
			cmp cl,0d						
			jne east						;jesli skoczek, to petla wykona sie jeszcze raz
			
		koniec:
			zwieksz_licznik_odwiedzin_pola
			przywroc_rejestry
			ret
	ruch_SE endp
	;-----------------
	ruch_SW proc
		odloz_rejestry
		flaga_plus
		
		cmp si,136d							;czy goniec jest w lewym dolnym rogu?
		je koniec							;jesli tak, skocz na koniec
		cmp si,135d							;czy goniec jest przy dolnej granicy szachownicy?
		jb south							;jesli nie, skocz do south (jedno pole w dol)
		ja west								;jesli tak, skocz do west (tylko ruch(y) w lewo)
		
		south:
			add si,17d						;ruch w dol
		west:
			;operacja 'div' pracuje na rejestrze AX, w AL bedzie wynik dzialania, w AH reszta
			mov ax,si						;biezaca pozycja gonca do AX
			mov bh,17d						;dzielna=17 do BH
			div bh							;AX div BH
			cmp ah,0d						;reszta w AH, czy jest rowna 0?
			je koniec						;jesli tak, to goniec jest przy lewej krawedzi -> koniec		
			dec si							;w przeciwnym razie goniec idzie w lewo
			
			dec cl							;sprawdzenie czy to goniec czy skoczek
			cmp cl,0d						
			jne west						;jesli skoczek, to petla wykona sie jeszcze raz
			
		koniec:
			zwieksz_licznik_odwiedzin_pola
			przywroc_rejestry
			ret
	ruch_SW endp
	;+++++++++++++++++
	
	;=================
	;----KONWERTUJ----
	;konwersja liczb w tab_szach
	;na odpowiednie znaki ASCII
	KONWERTUJ proc
		odloz_rejestry
		push dx
		push di
		push si
		
		mov si,offset tab_ascii				;w SI beda znaki ASCII (wg.tabeli)
		mov di,offset tab_szach				;w DI szachownica z ilosciami odwiedzin na polach
		dec di								;
		mov cl,154d							;153 pola do analizy (154, bo dec na poczatku petli)			;czy tu moze byc CL?
		
		kolejne_pole:
			dec cl
			cmp cl,0d						;czy wszystko zostalo przekonwertowane?
			je koniec						;jesli tak, to skocz do 'koniec'
			
			inc di							;przesun sie na kolejne pole szachownicy
			mov ah,ds:[di]					;wartosc aktualnego pola zaladuj do AH
			cmp ah,0d						;czy pole ma wartosc 0?
			je kolejne_pole					;jesli tak pozostaw puste pole, i analizuj kolejne
			
			cmp ah,14d						
			jae ponad						;jesli pole zostalo odwiedzone >=14 razy -> zamien na '^'
			
			mov bl,ds:[di]					;wartosc aktualnego pola do BL								; ?????
			dec bl
			mov dh,ds:[si+bx]				;adekwatny znak ascii do DH
			mov ds:[di],dh					;tenze znak zapisac w aktualnym polu szachownicy
			jmp kolejne_pole
		
		ponad:
			mov dl,"^"
			mov ds:[di],dl
			jmp kolejne_pole
			
		koniec:
			mov bx,offset tab_szach		
			mov dl,"S"
			mov ds:[bx+76d],dl				;na srodku szachownicy "S" (pole poczatku ruchow)
			
			add bx,ds:[pole_kon]			;przejscie na pole zakonczenia ruchow							;sprawdzic
			mov dl,"E"
			mov ds:[bx],dl					;tamze "E"
			
		pop si
		pop di
		pop dx
		przywroc_rejestry
		ret
	KONWERTUJ endp
	;=================
	
	;=================
	;-----DRUKUJ------
	;wydrukowanie ASCII-Art
	DRUKUJ proc
		push ax
		push cx
		push dx
		push di
		push si
		
		mov si,offset tab_szach				;do SI poczatek szachownicy
		mov cl,9d							;CL bedzie licznikiem wierszy
		
		mov dx,offset ramka_gorna			;gorna ramka do DX
		mov ah,9
		int 21h								;wydrukowanie tejze ramki
		mov dx,10d
		mov ah,2
		int 21h								;wydrukowanie nowej linii
		
		kolejny_wiersz:
			mov ch,0d						;CH bedzie licznikiem elementow w wierszu
			mov dx,"|"						;ramka boczna lewa
			mov ah,2
			int 21h							;wydrukowanie ramki bocznej
			
			kolejny_znak:
				cmp ch,17d					;czy wydrukowano juz 17 znakow?
				je koniec_wiersza
				
				mov dx,ds:[si]				;aktualny znak do DX
				mov ah,2
				int 21h
				
				inc ch						;zwieksz licznik wydrukowanych znakow w wierszu
				inc si						;przesun sie w szachownicy do kolejnego pola
				jmp kolejny_znak
				
		koniec_wiersza:
			mov dx,"|"						;ramka boczna prawa
			mov ah,2
			int 21h							;wydrukowanie ramki bocznej
			mov dx,10d
			mov ah,2
			int 21h							;wydrukowanie nowej linii
			
			dec cl							;zmniejszenie licznika wierszy pozostalych do wydrukowania
			cmp cl,0d						
			jne kolejny_wiersz				;jesli CL != 0, drukuj kolejny wiersz
			
		mov dx,offset ramka_dolna			;dolna ramka do DX
		mov ah,9
		int 21h								;wydrukowanie tejze ramki
					
		pop si
		pop di
		pop dx
		pop cx
		pop ax
		ret
	DRUKUJ endp
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
			call HEXBIN
			call ANALIZA_BITOW
			call KONWERTUJ
			call DRUKUJ
			
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
	err_1_dlugosc:
		mov dx,offset err1d
		wypisz_zakoncz
	err_1_typ:
		mov dx,offset err1t
		wypisz_zakoncz
	err_2_dlugosc:
		mov dx,offset err2d
		wypisz_zakoncz
	err_2_typ:
		mov dx,offset err2t
		wypisz_zakoncz
			
kod ends
end program