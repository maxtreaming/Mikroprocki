'program testowy komunikacji na magistarli RS485
'znaki nadane w terminalu na jednym komputerze s� wysy�ane gdy adres odbiorcy 0
'wpisuj�c znaki najpierw wpisa� dwa znaki adresu, potem tekst do wys�ania i enter

'zadania:
'1. w procedurze odbioru wprowadzi� weryfikacj� adresu zawartego w BOF,
'2. wprowadzi� EOF,
'3. wprowadzi� automatyczne odpowiedzi ramk� potwierdzenia odbioru,
'4. zastosowa� przerwanie UDRE1,
'5. wprowadzi� dwudzielno�� bufora tabin(), jedna po�owa s�uzy do nadawania,
'a druga do odbioru znak�w lub wprowadzi� bufor pier�cieniowy.

'by Marcin Kowalczyk

'obliczenia parametr�w konfiguracyjnych
Const Prescfc = 0   'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))       'cz�stotliwo�� po przeskalowaniu
'sta�e konfiguracujne USART�w
Const Baundrs0 = 115200       'pr�dko�� transmisji po RS [bps] USART0
Const _ubrr0 =(((fcrystal / Baundrs0) / 16) - 1)       'potrzebne w nast�pnych zadaniach
Const Baundrs1 = Baundrs0       'pr�dko�� transmisji po RS [bps] USART1
Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)       'potrzebne w nast�pnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"       'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
'$baud = Baundrs0    'zb�dne gdy inicjalizacja w zdefiniowanej procedurze

$eeprom             'zawarto�� eeprom wgrywana na zasadzie programowania
Data 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0       '0...15
Data 2 , 0 , 1 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0       '16...31, 16 - adres wlasny (dec.)
$data

'aliasy rejestr�w procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta�e aliasy
Te_pin Alias 5
Te Alias Portd.te_pin       'sterowanie przep�ywem w nadajniku/odbiorniku linii

'Led_reg Alias Ddrd  'rejestr kontrolki nadawania, gdy anoda LED -> Ucc
'Led_reg Alias Portd 'rejestr kontrolki nadawania, gdy katoda LED -> GND
'Led_pin Alias 7     'numer wyprowadzenia portu dla kontrolki

On Urxc Usart0_rx Nosave       'deklaracja przerwania URXC (odbi�r znaku USART0)
On Urxc1 Usart1_rx Nosave       'deklaracja przerwania URXC1 (odbi�r znaku USART1)
On Utxc1 Usart1_tx_end Nosave       'deklaracja przerwania UTXC1, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte    'adres w�asny
Dim Adro As Byte    'adres odbiorcy 0...15
Dim Tabin(50) As Byte       'tabela znak�w odebranych
Const Lstrmax = 24  'maksymalna liczba znak�w w tabin
Dim Lstr As Byte    'liczba odebranych znak�w z USART0
Const Bof_bit = &B10100000
Dim Stanodbioru As Byte


'zmniejszenie cz�stotliwo�ci taktowania procesora
ldi temp,128
!Out clkpr,temp     'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc    'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp     'CLKPR = Prescfc


rcall usart_init    'inicjalizacja USART�w i w��czenie przerwa�
Sei                 'w��czenie globalnie przerwa�

Readeeprom Adrw , 16
'Adrw = 10
Print "Moj adres: " ; Adrw

Do
   'inne procedury
Loop

Usart0_rx:          'etykieta bascomowa koniecznie bez !
   push rstemp      'o ile potrzeba - sprawdzi�
   in rstemp,sreg   'o ile potrzeba  - sprawdzi�
   push rstemp      'o ile potrzeba - sprawdzi�
   push rsdata      'o ile potrzeba  - sprawdzi�
   push yl          'o ile potrzeba  - sprawdzi�
   push yh          'o ile potrzeba  - sprawdzi�
   push r1          'o ile potrzeba  - sprawdzi�
   push r0          'o ile potrzeba  - sprawdzi�

   rcall rs_rx      'kod mo�e by� bezpo�renio w usart_rx

   'odtworzenie stanu jak przed przerwanie
   pop r0
   pop r1
   pop yh
   pop yl
   pop rsdata
   pop rstemp
   !out sreg,rstemp
   pop rstemp
Return

Usart1_rx:          'etykieta bascomowa koniecznie bez !
   push rstemp      'o ile potrzeba - sprawdzi�
   in rstemp,sreg   'o ile potrzeba  - sprawdzi�
   push rstemp      'o ile potrzeba - sprawdzi�
   push rsdata
'   push yl          'o ile potrzeba  - sprawdzi�
'   push yh          'o ile potrzeba  - sprawdzi�

   rcall rs_rx1

   'odtworzenie stanu jak przed przerwanie
'   pop yh
'   pop yl
   pop rsdata
   pop rstemp
   !out sreg,rstemp
   pop rstemp
Return              '
    !rs_rx1:
    in rsdata,udr1


   'Weryfikacja
   'subi rsdata,bof_bit       'po odjeciu powinien wyjsc adres wlasny
   lds rstemp,{adrw}
   subi rstemp,(256-bof_bit)       'dodatnie bof_bit
   !sub rstemp,rsdata       'powinno wyjsc 0
   BRNE no_bof
      ldi rstemp,1
      STS {stanodbioru},rstemp
      ret
   !no_bof:
   lds rstemp,{stanodbioru}
   cpi rstemp,1
   SBIS sreg,1      'ret gdy to rstemp=1
      ret

   !out udr0,rsdata 'wys�anie znaku do kumputera bez przetwarzania
   cpi rsdata,13
   SBIS sreg,1      'ret gdy to rstemp=1
      ret

   ldi rstemp,0
   STS {stanodbioru},rstemp
   ret
   ldi rsdata, 10   'wyslanie
   !pc_tx:
   sbis ucsr0a,udre0
         rjmp pc_tx 'czekaj a� UDR1 pusty
   !out udr0,rsdata 'wys�anie znaku do kumputera bez przetwarzania

    Return

!rs_rx:
   in rsdata,udr0   'odebrany znak z komputera swojego
      !out udr0,rsdata 'wys�anie znaku do kumputera bez przetwarzania
   'znaki s� zapisywane z buforze tabin()  do odbioru 13
   cpi rsdata,13
   breq rec13
      lds rstemp,{lstr}
      cpi rstemp,lstrmax
      sbis sreg,2   'obej�cie gdy liczba mniejsza od lstrmax
         Ret        'wyj�cie gdy odebrano ponad Lstrmax znak�w
      inc rstemp
      sts {lstr},rstemp
      dec rstemp
      Loadadr Tabin(1) , Y
      add yl,rstemp
      ldi rstemp,0
      adc yh,rstemp 'w Y adres zapisu do tabin
      st y+,rsdata
      st y,rstemp   'wpisnie 0 na ko�cu - oznaczenie ko�ca �a�cucha
   ret

!rec13:
   ldi rstemp,0
   sts {lstr},rstemp       'wyzerowanie licznika bajt�w, rozpoznanie ko�ca przez 0
   'weryfikacja zakresu adresu 0...15, adres w dw�ch pierwszych znakach w tabin
   'najpier dziesi�tki potem jednostki
   Loadadr Tabin(1) , Y
   ld rsdata,y+     'dziesi�tki +48
   subi rsdata,48
   ldi rstemp,10
   mul rsdata,rstemp       'w r0 liczba 10 razy wi�ksza
   ld rsdata,y+     'jednostki +48
   subi rsdata,48
   add rsdata,r0
   cpi rsdata,16    'wersyfikacj adresu - ma by� adres 0...15
   sbis sreg,2      'obej�cie gdy adres prawid�owy
      Ret

   sts {adro},rsdata       'do testu
   ori rsdata,bof_bit
   !out udr1,rsdata 'wys�anie BOF

   !rs485_tx:
      sbis ucsr1a,udre1
         rjmp rs485_tx       'czekaj a� UDR1 pusty
      ld rsdata,y+
      tst rsdata    'kontrola ko�ca
      breq frame_end
      Te = 1        'w��czenie nadajnika
      !out udr1,rsdata       'wys�anie znaku na magistarl� RS485 bez przetwarzania
   rjmp rs485_tx:

   !frame_end:
   Te = 1
   ldi rsdata,13
   !out udr1,rsdata 'wys�anie znaku ko�cz�cego ramk�

   'Print Adro       'do testu, uwaga na u�yte zasoby w przerwaniu i wyd�u�enie procedury
ret

Usart1_tx_end:      'przerwanie wyst�pi gdy USART wy�le znak i UDR b�dzie pusty
   Te = 0           'wy��czenie nadajnika, w��czenie odbiornika
   'to samo co CBI PORTD,TE_pin, brak zmian w SREG
Return

!usart_init:
'procedura inicjalizacji USART�w
   ldi temp,0
   !out ubrr0h,temp 'bardziej znacz�cy bajt UBRR USART0
   !out ubrr1h,temp
   ldi temp,_ubrr0
   !out ubrr0l,temp 'mniej znacz�cy bajt UBRR USART0
   ldi temp,_ubrr1
   !out ubrr1l,temp 'mniej znacz�cy bajt UBRR USART1
   ldi temp,24      'w��czone odbiorniki i nadajniki USART�w
   !out ucsr0b,temp
   !out ucsr1b,temp
   ldi temp,6       'N8bit
   !out ucsr0C,temp
   !out ucsr1C,temp
   'ustawienia RS485
   Te = 0           'domy�lnie stan odbioru
   sbi ddrd,Te_pin  'wyj�cie TE silnopr�dowe
   'w��czenie przerwa�
   Enable Urxc
   Enable Urxc1
   Enable Utxc1
ret