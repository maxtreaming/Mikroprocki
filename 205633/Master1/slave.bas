'program testowy komunikacji na magistarli RS485
'znaki nadane w terminalu na jednym komputerze s¹ wysy³ane gdy adres odbiorcy 0
'wpisuj¹c znaki najpierw wpisaæ dwa znaki adresu, potem tekst do wys³ania i enter

'zadania:
'1. w procedurze odbioru wprowadziæ weryfikacjê adresu zawartego w BOF,
'2. wprowadziæ EOF,
'3. wprowadziæ automatyczne odpowiedzi ramk¹ potwierdzenia odbioru,
'4. zastosowaæ przerwanie UDRE1,
'5. wprowadziæ dwudzielnoœæ bufora tabin(), jedna po³owa s³uzy do nadawania,
'a druga do odbioru znaków lub wprowadziæ bufor pierœcieniowy.

'by Marcin Kowalczyk

'obliczenia parametrów konfiguracyjnych
Const Prescfc = 0                                           'potêga dzielnika czêstotliwoœci taktowania procesora
Const Fcrystal =(16000000 /(2 ^ Prescfc))                   'czêstotliwoœæ po przeskalowaniu
'sta³e konfiguracujne USARTów
Const Baundrs0 = 115200                                     'prêdkoœæ transmisji po RS [bps] USART0
Const _ubrr =(((fcrystal / Baundrs0) / 16) - 1)             'potrzebne w nastêpnych zadaniach
'Const Baundrs1 = Baundrs0                                   'prêdkoœæ transmisji po RS [bps] USART1
'Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)            'potrzebne w nastêpnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m32def.dat"                                     'plik konfiguracyjny z literk¹ "p" w nazwie
$crystal = Fcrystal
'$baud = Baundrs0    'zbêdne gdy inicjalizacja w zdefiniowanej procedurze


'aliasy rejestrów procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta³e aliasy
Te_pin Alias 2
Te Alias Portd.te_pin                                       'sterowanie przep³ywem w nadajniku/odbiorniku linii

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



On Urxc Usart_rx Nosave                                     'deklaracja przerwania URXC (odbiór znaku USART)
On Utxc Usart_tx_end Nosave                                 'deklaracja przerwania UTXC, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte                                            'adres w³asny
Dim Adro As Byte                                            'adres odbiorcy 0...15
Dim Tabin(50) As Byte                                       'tabela znaków odebranych
Const Lstrmax = 24                                          'maksymalna liczba znaków w tabin
Dim Lstr As Byte                                            'liczba odebranych znaków z USART0
Dim Zmienna As Byte
Zmienna = 0
Const Bof_bit = &B11000000
Const Eof_bit = &B10000000

Dim Stanodbioru As Byte


SBI Ddrd,Led_pin

Enable Oc1a
Start Timer1
rcall usart_init                                            'inicjalizacja USARTów i w³¹czenie przerwañ
Sei                                                         'w³¹czenie globalnie przerwañ


Do
   'inne procedury
Loop

Usart_rx:                                                   'etykieta bascomowa koniecznie bez !
   push rstemp                                              'o ile potrzeba - sprawdziæ
   in rstemp,sreg                                           'o ile potrzeba  - sprawdziæ
   push rstemp                                              'o ile potrzeba - sprawdziæ
   push rsdata                                              'o ile potrzeba  - sprawdziæ
   push yl                                                  'o ile potrzeba  - sprawdziæ
   push yh                                                  'o ile potrzeba  - sprawdziæ
   push r1                                                  'o ile potrzeba  - sprawdziæ
   push r0                                                  'o ile potrzeba  - sprawdziæ

   rcall rs_rx                                              'kod mo¿e byæ bezpoœrenio w usart_rx

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
                                           'wpisnie 0 na koñcu - oznaczenie koñca ³añcucha
ret



Usart_tx_end:                                               'przerwanie wyst¹pi gdy USART wyœle znak i UDR bêdzie pusty
   Te = 0                                                   'wy³¹czenie nadajnika, w³¹czenie odbiornika
   'to samo co CBI PORTD,TE_pin, brak zmian w SREG
Return

Przerwanie_timer:
 push rstemp                                              'o ile potrzeba - sprawdziæ
   in rstemp,sreg                                           'o ile potrzeba  - sprawdziæ
   push rstemp                                              'o ile potrzeba - sprawdziæ
   push rsdata                                              'o ile potrzeba  - sprawdziæ
   push yl                                                  'o ile potrzeba  - sprawdziæ
   push yh                                                  'o ile potrzeba  - sprawdziæ
   push r1                                                  'o ile potrzeba  - sprawdziæ
   push r0                                                  'o ile potrzeba  - sprawdziæ

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
'procedura inicjalizacji USARTów
   ldi temp,0
   !out ubrr,temp                                           'bardziej znacz¹cy bajt UBRR USART0
  ' !out ubrrh,temp
   ldi temp,_ubrr
   !out ubrrl,temp                                          'mniej znacz¹cy bajt UBRR USART0
  ' ldi temp,_ubrr
   '!out ubrrl,temp                                          'mniej znacz¹cy bajt UBRR USART1
   ldi temp,24                                              'w³¹czone odbiorniki i nadajniki USARTów
   !out ucsrb,temp
  ' !out ucsr1b,temp
   ldi temp,6                                               'N8bit
   !out ucsrC,temp
  ' !out ucsr1C,temp
   'ustawienia RS485
   Te = 0                                                   'domyœlnie stan odbioru
   sbi ddrd,Te_pin                                          'wyjœcie TE silnopr¹dowe
   'w³¹czenie przerwañ
   Enable Urxc
   Enable Utxc
ret