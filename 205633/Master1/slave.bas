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
Const Prescfc = 0                                           'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(16000000 /(2 ^ Prescfc))                   'cz�stotliwo�� po przeskalowaniu
'sta�e konfiguracujne USART�w
Const Baundrs0 = 115200                                     'pr�dko�� transmisji po RS [bps] USART0
Const _ubrr =(((fcrystal / Baundrs0) / 16) - 1)             'potrzebne w nast�pnych zadaniach
'Const Baundrs1 = Baundrs0                                   'pr�dko�� transmisji po RS [bps] USART1
'Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)            'potrzebne w nast�pnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m32def.dat"                                     'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
'$baud = Baundrs0    'zb�dne gdy inicjalizacja w zdefiniowanej procedurze


'aliasy rejestr�w procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta�e aliasy
Te_pin Alias 2
Te Alias Portd.te_pin                                       'sterowanie przep�ywem w nadajniku/odbiorniku linii

Led_pin Alias 3
Led Alias Portd.led_pin

'Led_reg Alias Ddrd  'rejestr kontrolki nadawania, gdy anoda LED -> Ucc
'Led_reg Alias Portd 'rejestr kontrolki nadawania, gdy katoda LED -> GND
'Led_pin Alias 7     'numer wyprowadzenia portu dla kontrolki

Const _presctimer = 64
Const _fpr = 1                                              'czestotliwosc probkowania
Const _ocrtimer = Fcrystal / _presctimer / _fpr -1

Config Timer1 = Timer , Prescale = _presctimer , Compare A = Disconnect , Clear Timer = 1
Stop Timer1
Timer1 = 0
Ocr1a = _ocrtimer

On Oc1a Przerwanie_timer Nosave



On Urxc Usart_rx Nosave                                     'deklaracja przerwania URXC (odbi�r znaku USART)
On Utxc Usart_tx_end Nosave                                 'deklaracja przerwania UTXC, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte                                            'adres w�asny
Dim Adro As Byte                                            'adres odbiorcy 0...15
Dim Tabin(50) As Byte                                       'tabela znak�w odebranych
Const Lstrmax = 24                                          'maksymalna liczba znak�w w tabin
Dim Lstr As Byte                                            'liczba odebranych znak�w z USART0
Dim Zmienna As Byte
Zmienna = 0
Const Bof_bit = &B11000000
Const Eof_bit = &B10000000

Dim Stanodbioru As Byte


SBI Ddrd,Led_pin

Enable Oc1a
Start Timer1
rcall usart_init                                            'inicjalizacja USART�w i w��czenie przerwa�
Sei                                                         'w��czenie globalnie przerwa�


Do
   'inne procedury
Loop

Usart_rx:                                                   'etykieta bascomowa koniecznie bez !
   push rstemp                                              'o ile potrzeba - sprawdzi�
   in rstemp,sreg                                           'o ile potrzeba  - sprawdzi�
   push rstemp                                              'o ile potrzeba - sprawdzi�
   push rsdata                                              'o ile potrzeba  - sprawdzi�
   push yl                                                  'o ile potrzeba  - sprawdzi�
   push yh                                                  'o ile potrzeba  - sprawdzi�
   push r1                                                  'o ile potrzeba  - sprawdzi�
   push r0                                                  'o ile potrzeba  - sprawdzi�

   rcall rs_rx                                              'kod mo�e by� bezpo�renio w usart_rx

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
                                             '

!rs_rx:
                                           'wpisnie 0 na ko�cu - oznaczenie ko�ca �a�cucha
ret



Usart_tx_end:                                               'przerwanie wyst�pi gdy USART wy�le znak i UDR b�dzie pusty
   Te = 0                                                   'wy��czenie nadajnika, w��czenie odbiornika
   'to samo co CBI PORTD,TE_pin, brak zmian w SREG
Return

Przerwanie_timer:
 push rstemp                                              'o ile potrzeba - sprawdzi�
   in rstemp,sreg                                           'o ile potrzeba  - sprawdzi�
   push rstemp                                              'o ile potrzeba - sprawdzi�
   push rsdata                                              'o ile potrzeba  - sprawdzi�
   push yl                                                  'o ile potrzeba  - sprawdzi�
   push yh                                                  'o ile potrzeba  - sprawdzi�
   push r1                                                  'o ile potrzeba  - sprawdzi�
   push r0                                                  'o ile potrzeba  - sprawdzi�

   ldi rsdata, 3
   Te = 1

   Sbis portd,led_pin
      rjmp zapal_led
   sbic portd,led_pin
      rjmp zgas_led
   !zapal_led:
      Led = 1
      rjmp wyslij
   !zgas_led:
      Led = 0
   !wyslij:

   !out udr, rsdata

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

!usart_init:
'procedura inicjalizacji USART�w
   ldi temp,0
   !out ubrr,temp                                           'bardziej znacz�cy bajt UBRR USART0
  ' !out ubrrh,temp
   ldi temp,_ubrr
   !out ubrrl,temp                                          'mniej znacz�cy bajt UBRR USART0
  ' ldi temp,_ubrr
   '!out ubrrl,temp                                          'mniej znacz�cy bajt UBRR USART1
   ldi temp,24                                              'w��czone odbiorniki i nadajniki USART�w
   !out ucsrb,temp
  ' !out ucsr1b,temp
   ldi temp,6                                               'N8bit
   !out ucsrC,temp
  ' !out ucsr1C,temp
   'ustawienia RS485
   Te = 0                                                   'domy�lnie stan odbioru
   sbi ddrd,Te_pin                                          'wyj�cie TE silnopr�dowe
   'w��czenie przerwa�
   Enable Urxc
   Enable Utxc
ret