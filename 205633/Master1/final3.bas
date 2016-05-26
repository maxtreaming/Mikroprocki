


'obliczenia parametrów konfiguracyjnych
Const Prescfc = 2                                           'potêga dzielnika czêstotliwoœci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))                   'czêstotliwoœæ po przeskalowaniu
'sta³e konfiguracujne USARTów
Const Baundrs0 = 115200                                     'prêdkoœæ transmisji po RS [bps] USART0
Const _ubrr0 =(((fcrystal / Baundrs0) / 16) - 1)            'potrzebne w nastêpnych zadaniach
Const Baundrs1 = Baundrs0                                   'prêdkoœæ transmisji po RS [bps] USART1
Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)            'potrzebne w nastêpnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"                                   'plik konfiguracyjny z literk¹ "p" w nazwie
$crystal = Fcrystal
'$baud = Baundrs0    'zbêdne gdy inicjalizacja w zdefiniowanej procedurze

$eeprom                                                     'zawartoœæ eeprom wgrywana na zasadzie programowania
Data 15 , 14 , 13 , 1 , 9 , 11 , 8 , 6 , 4 , 0 , 0 , 0 , 0 , 0 , 0 , 0,       '0...15  wartosci w komorkach, to adresy urzadzen
Data 18 , 22 , 19 , 50 , 18 , 20 , 20 , 20 , 24 , 6 , 6 , 6 , 6 , 6 , 6 , 6       'ile bajtow odbieramy od urzadzenia = (bof +ilosc danych+eof)+12 aby byc pewnym ze sie zmiesci . Min okolo 6

$data

'aliasy rejestrów procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta³e aliasy
Te_pin Alias 4
Te Alias Portd.te_pin                                       'sterowanie przep³ywem w nadajniku/odbiorniku linii

Led_pin Alias 5
Led Alias Portd.led_pin                                     'definicja portow dla diody kontrolnej
SBI Ddrd,Led_pin

On Urxc Usart0_rx Nosave
On Urxc1 Usart1_rx Nosave                                   'deklaracja przerwania URXC1 (odbiór znaku USART1)
On Utxc1 Usart1_tx_end Nosave                               'deklaracja przerwania UTXC1, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte                                            'adres w³asny
Dim Adro As Byte                                            'adres odbiorcy 0...15
Dim Nrodbiornika As Byte                                    'wskaznik do adresu odbiorcy w eeprom
Dim Pomocnicza As Byte                                      'zmienna pomocnicza
Dim Stan As Byte
Stan = 0                                                    'ramka bof
Const Bof_bit = &B110000000                                 'unikalna ramka bof dla mastera.
Const Bofm_bit = &B11000010

Const Eof_bit = &B10000000                                  'ramka eof
Const Eofm_bit = &B10100010                                 'unikalna ramka eof dla master

Dim Stanodbioru As Byte                                     'zmienna przechowujaca inf o tym czy juz zaczelismy odbierac dane
Stanodbioru = 0                                             '0-oczekiwanie na dane
                                                              '1-rozpoczeto odbieranie
Adrw = 2                                                    'nadanie adresu wlasnego
Nrodbiornika = 0                                            'ustawienie wskaznika nr odbiornika

'zmniejszenie czêstotliwoœci taktowania procesora
ldi temp,128
!Out clkpr,temp                                             'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc                                            'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp                                             'CLKPR = Prescfc


rcall usart_init                                            'inicjalizacja USARTów i w³¹czenie przerwañ

'w³¹czenie timera1 jako czasomierz, do odmierzania okresu rozpoczynania odpytywania urzadzen T=1s.
Const _presctimer1 = 256
Const _fpr1 = 1                                             'czestotliwosc probkowania, pierwszy cykl timera ustawiony na 1s.
Const _ocrtimer1 = Fcrystal / _presctimer1 / _fpr1 -1

Config Timer1 = Timer , Prescale = _presctimer1 , Compare A = Disconnect , Clear Timer = 1
Stop Timer1
Timer1 = 0
Ocr1a = _ocrtimer1





'w³¹czenie timera0 jako czasomierz, do odmierzania okresu wymiany danych miedzy masterem a poszczegolnym slavem.
Const _presctimer0 = 1024
Const _fpr0 = 1                                             'czestotliwosc probkowania, pierwszy cykl timera ustawiony na 1s.
Const _ocrtimer0 = 1                                        'Fcrystal / _presctimer / _fpr -1

Config Timer0 = Timer , Prescale = _presctimer0 , Compare A = Disconnect , Clear Timer = 1
Stop Timer0
Timer0 = 0
Ocr0a = _ocrtimer0


On Oc1a Timer1_interrupt Nosave
On Oc0a Timer0_interrupt Nosave

Enable Oc1a
Enable Oc0a

rcall RTC_init

Start Timer1
Start Timer0
Sei                                                         'w³¹czenie globalnie przerwañ

Do
     'glowna pêtla
Loop


'''''''''''''''''''''''''''''''''''''''''''''''''''''''PRZERWANIA'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
 Usart0_rx:
 push rstemp                                                'o ile potrzeba - sprawdziæ
 Push rsdata
 in rstemp,sreg                                             'o ile potrzeba  - sprawdziæ
 push rstemp                                                'o ile potrzeba - sprawdziæ

  in rsdata,udr0                                            'wywolanie proceduty odbioru danych z lini rs485
  cpi rsdata,32
   breq spacja
   rjmp koniec_spacji

   !spacja:
   lds rstemp, {stan}
      sbrs rstemp,0
      Stop Timer1
      sbrc rstemp,0
      Start Timer1

      sbrs rstemp,0
      Stan = 1
      sbrc rstemp,0
      Stan = 0



   !koniec_spacji:
 pop rstemp
 !out sreg,rstemp
 pop rsdata
 pop rstemp
 Return
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Usart1_rx:

 push rstemp                                                'o ile potrzeba - sprawdziæ
 Push rsdata
 in rstemp,sreg                                             'o ile potrzeba  - sprawdziæ
 push rstemp                                                'o ile potrzeba - sprawdziæ

 rcall rs_rx                                                'wywolanie proceduty odbioru danych z lini rs485

 pop rstemp
 !out sreg,rstemp
 pop rsdata
 pop rstemp
Return
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Usart1_tx_end:                                              'przerwanie konca wysylania danych przez master ma jedynie zamienic stan na lini Te
    Te = 0                                                  'przejscie w tryb odbioru
Return
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Timer1_interrupt:                                           'T=1s
   rcall dioda                                              'kontrolne miganie diody co 1s.
   Start Timer0                                             'wlaczenie timera wyliczajacego okresy odbioru danych

Return
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Timer0_interrupt:                                           'przerwanie od konca czasu odbioru danych
 push rstemp                                                'o ile potrzeba - sprawdziæ
 Push rsdata
 in rstemp,sreg                                             'o ile potrzeba  - sprawdziæ
 push rstemp                                                'o ile potrzeba - sprawdziæ
                                                            'zatrzymanie liczenia
 rcall Wyslij_ramke                                         'wyslij zapytanei do kolejnego urzadzenia

 pop rstemp
 !out sreg,rstemp
 pop rsdata
 pop rstemp
Return


'''''''''''''''''''''''''''''''''''''''''''''''''''''''PROCEDURY'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
!usart_init:
'procedura inicjalizacji USARTów
   ldi temp,0
   !out ubrr0h,temp                                         'bardziej znacz¹cy bajt UBRR USART0
   !out ubrr1h,temp
   ldi temp,_ubrr0
   !out ubrr0l,temp                                         'mniej znacz¹cy bajt UBRR USART0
   ldi temp,_ubrr1
   !out ubrr1l,temp                                         'mniej znacz¹cy bajt UBRR USART1
   ldi temp,24                                              'w³¹czone odbiorniki i nadajniki USARTów
   !out ucsr0b,temp
   !out ucsr1b,temp
   ldi temp,6                                               'N8bit
   !out ucsr0C,temp
   !out ucsr1C,temp
   'ustawienia RS485
   Te = 0                                                   'domyœlnie stan odbioru
   sbi ddrd,Te_pin                                          'wyjœcie TE silnopr¹dowe
   'w³¹czenie przerwañ
   'Enable Urxc  niepotrzebne przerwanie od komputera
   Enable Urxc
   Enable Urxc1
   Enable Utxc1
ret
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
!Wyslij_ramke:
!CLI
    Stanodbioru = 0





   Readeeprom Adro , Nrodbiornika                           'odczyt adresu odbiornika z listy eeprom

 lds rstemp,{adro}                                          'zaladuj adres Odb do rstemp
 cpi rstemp,0
    breq  zeruj
 rcall wyslij_enter

 rcall pusty_udr0                                           'sprawdz czy udr0 pusty
 cpi rstemp,10                                              'porownaj adro z 10
   brlo cyfry                                               'jezeli mniejszy to drukuj cyfry, jezeli nie, litery

 subi rstemp,-55                                            'aby w kodzie ascii wydrukowac litery, nalezy dodac 55 do wartosci adresu odb
  rjmp koniec_cyfr

  !cyfry:
  subi rstemp,-48                                           'aby w kodzie ascii wydrukowac cyfry, nalezy dodac 48 do wartosci adresu odb

  !koniec_cyfr:
  !out udr0,rstemp                                          'wyslij cyfre w systemie szesnastkowym




  rcall pusty_udr0                                          'sprawdz czy udr0 pusty
  ldi rstemp,58
  !out udr0,rstemp                                          'wyslij :
 Nrodbiornika = Nrodbiornika + 16                           'wskaznik ilosci bajtow odbieranych od odbiornika jest taki jak jego adres, ale przesuniete o 16 w eeprom                         '
 Readeeprom Pomocnicza , Nrodbiornika                       'odczyt ilosci z eeprom
 Nrodbiornika = Nrodbiornika - 16                           'powrot do wskaznika adresu

 Timer0 = 0                                                 'zerowanie timera i ustawienie ocr
 Ocr0a = Pomocnicza * _ocrtimer0                            'ocr0a=ilosc bajtow*czas trwania transmisji 1 bajta



 lds rstemp,{Adro}                                          'tworzenie ramki bof
 ori rstemp,bof_bit                                         'dodanie do adresu ramki bof

  Te = 1                                                    'transmisja
  !out Udr1,rstemp

  ldi rstemp,eofm_bit                                       'tworzenie ramki eof
   rcall pusty_udr1                                         'sprawdz czy udr1 pusty

  !out Udr1,rstemp                                          'wyslij ramke eof

  lds rstemp,{Nrodbiornika}
   cpi rstemp, 16                                           'sprawdzenie czy licznik <= 16
   BREQ zeruj                                               'jezeli tak, skocz do zeruj
   inc rstemp                                               'jezeli nie, zwieksz Nr odbiornika
 rjmp koniec_transmisji
 !zeruj:                                                    'zerowanie oznacza, ze odpytalismy juz wszystkie odbiorniki
   ldi rstemp,0
   Stop Timer0                                              'zatrzymanie timer0
   Print                                                    'przejscie do kolejnej linii w celu zostawienia jednej pustej
   !koniec_transmisji:

    STS {Nrodbiornika},rstemp                               'aktualizacja wskaznika adresu

  sei                                                       'wlaczenie przerwan
ret
''''''''''''''''''''''''''''''''''''''''''
!rs_rx:
   in rsdata,udr1                                           'odebranie danych z linii
   sbrs rsdata,7
   !out udr0,rsdata
    ret
''''''''''''''''''''''''''''''''''''''''''
!pusty_udr1:
sbis ucsr1a,udre1                                           'petla gdy udre1 jest zajety
   rjmp pusty_UDR1
ret
''''''''''''''''''''''''''''''''''''''''''
!pusty_UDR0:
   sbis ucsr0a,udre0                                        'petla gdy udre0 jest zajety
   rjmp pusty_UDR0
ret
''''''''''''''''''''''''''''''''''''''''''
!dioda:                                                     'zmiana stanu diody
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
      ret
''''''''''''''''''''''''''''''''''''''''''
!wyslij_enter:
ldi rsdata, 10                                              'wyslij trzy znaki: przejscia do kolejnej linii->idz na poczatek linii->wydrukuj 0
 rcall pusty_udr0
  !out udr0,rsdata

ldi rsdata, 13
 rcall pusty_udr0
  !out udr0,rsdata

ldi rsdata, 48
 rcall pusty_udr0
  !out udr0,rsdata
ret
''''''''''''''''''''''''''''''''''''''''''
!RTC_init:
Config Sda = Portc.1
Config Scl = Portc.0
I2cinit
   I2cstart
   I2cwbyte 162
   I2cwbyte 0
   I2cwbyte 0
   I2cstop

   I2cstart
   I2cwbyte 162
   I2cwbyte &H0D
   I2cwbyte &B10000011
   I2cstop
ret
