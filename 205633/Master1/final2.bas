


'obliczenia parametr�w konfiguracyjnych
Const Prescfc = 0                                           'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))                   'cz�stotliwo�� po przeskalowaniu
'sta�e konfiguracujne USART�w
Const Baundrs0 = 115200                                     'pr�dko�� transmisji po RS [bps] USART0
Const _ubrr0 =(((fcrystal / Baundrs0) / 16) - 1)            'potrzebne w nast�pnych zadaniach
Const Baundrs1 = Baundrs0                                   'pr�dko�� transmisji po RS [bps] USART1
Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)            'potrzebne w nast�pnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"                                   'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
'$baud = Baundrs0    'zb�dne gdy inicjalizacja w zdefiniowanej procedurze

$eeprom                                                     'zawarto�� eeprom wgrywana na zasadzie programowania
Data 15 , 14 , 13 , 1 , 9 , 11 , 8 , 6 , 4 , 0 , 0 , 0 , 0 , 0 , 0 , 0       '0...15  wartosci w komorkach, to adresy urzadzen
Data 18 , 22 , 19 , 22 , 18 , 20 , 20 , 20 , 24 , 6 , 6 , 6 , 6 , 6 , 6 , 6       'ile bajtow odbieramy od urzadzenia = (bof +ilosc danych+eof)+12 aby byc pewnym ze sie zmiesci . Min okolo 6

$data

'aliasy rejestr�w procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta�e aliasy
Te_pin Alias 4
Te Alias Portd.te_pin                                       'sterowanie przep�ywem w nadajniku/odbiorniku linii

Led_pin Alias 5
Led Alias Portd.led_pin                                     'definicja portow dla diody kontrolnej
SBI Ddrd,Led_pin


On Urxc1 Usart1_rx Nosave                                   'deklaracja przerwania URXC1 (odbi�r znaku USART1)
On Utxc1 Usart1_tx_end Nosave                               'deklaracja przerwania UTXC1, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte                                            'adres w�asny
Dim Adro As Byte                                            'adres odbiorcy 0...15
Dim Nrodbiornika As Byte                                    'wskaznik do adresu odbiorcy w eeprom
Dim Pomocnicza As Byte                                      'zmienna pomocnicza

                                                             'ramka bof
Const Bof_bit = &B110000000                                 'unikalna ramka bof dla mastera.
Const Bofm_bit = &B11000010

Const Eof_bit = &B10000000                                  'ramka eof
Const Eofm_bit = &B10100010                                 'unikalna ramka eof dla master

Dim Stanodbioru As Byte                                     'zmienna przechowujaca inf o tym czy juz zaczelismy odbierac dane
Stanodbioru = 0                                             '0-oczekiwanie na dane
                                                              '1-rozpoczeto odbieranie
Adrw = 2                                                    'nadanie adresu wlasnego
Nrodbiornika = 0                                            'ustawienie wskaznika nr odbiornika

'zmniejszenie cz�stotliwo�ci taktowania procesora
ldi temp,128
!Out clkpr,temp                                             'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc                                            'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp                                             'CLKPR = Prescfc


rcall usart_init                                            'inicjalizacja USART�w i w��czenie przerwa�

'w��czenie timera1 jako czasomierz, do odmierzania okresu rozpoczynania odpytywania urzadzen T=1s.
Const _presctimer1 = 256
Const _fpr1 = 1                                             'czestotliwosc probkowania, pierwszy cykl timera ustawiony na 1s.
Const _ocrtimer1 = Fcrystal / _presctimer1 / _fpr1 -1

Config Timer1 = Timer , Prescale = _presctimer1 , Compare A = Disconnect , Clear Timer = 1
Stop Timer1
Timer1 = 0
Ocr1a = _ocrtimer1





'w��czenie timera0 jako czasomierz, do odmierzania okresu wymiany danych miedzy masterem a poszczegolnym slavem.
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

Start Timer1
Start Timer0
Sei                                                         'w��czenie globalnie przerwa�

Do
     'glowna p�tla
Loop


'''''''''''''''''''''''''''''''''''''''''''''''''''''''PRZERWANIA'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Usart1_rx:

 push rstemp                                                'o ile potrzeba - sprawdzi�
 Push rsdata
 in rstemp,sreg                                             'o ile potrzeba  - sprawdzi�
 push rstemp                                                'o ile potrzeba - sprawdzi�

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
 push rstemp                                                'o ile potrzeba - sprawdzi�
 Push rsdata
 in rstemp,sreg                                             'o ile potrzeba  - sprawdzi�
 push rstemp                                                'o ile potrzeba - sprawdzi�
                                                            'zatrzymanie liczenia
 rcall Wyslij_ramke                                         'wyslij zapytanei do kolejnego urzadzenia

 pop rstemp
 !out sreg,rstemp
 pop rsdata
 pop rstemp
Return


'''''''''''''''''''''''''''''''''''''''''''''''''''''''PROCEDURY'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
!usart_init:
'procedura inicjalizacji USART�w
   ldi temp,0
   !out ubrr0h,temp                                         'bardziej znacz�cy bajt UBRR USART0
   !out ubrr1h,temp
   ldi temp,_ubrr0
   !out ubrr0l,temp                                         'mniej znacz�cy bajt UBRR USART0
   ldi temp,_ubrr1
   !out ubrr1l,temp                                         'mniej znacz�cy bajt UBRR USART1
   ldi temp,24                                              'w��czone odbiorniki i nadajniki USART�w
   !out ucsr0b,temp
   !out ucsr1b,temp
   ldi temp,6                                               'N8bit
   !out ucsr0C,temp
   !out ucsr1C,temp
   'ustawienia RS485
   Te = 0                                                   'domy�lnie stan odbioru
   sbi ddrd,Te_pin                                          'wyj�cie TE silnopr�dowe
   'w��czenie przerwa�
   'Enable Urxc  niepotrzebne przerwanie od komputera
   Enable Urxc1
   Enable Utxc1
ret
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
!Wyslij_ramke:
!CLI
    stanodbioru=0
       ldi rstemp, 10                                       'wyslij trzy znaki: przejscia do kolejnej linii->idz na poczatek linii->wydrukuj 0
 rcall pusty_udr0
  !out udr0,rstemp

   ldi rstemp, 13
 rcall pusty_udr0
  !out udr0,rstemp

   ldi rstemp, 48
 rcall pusty_udr0
  !out udr0,rstemp





   Readeeprom Adro , Nrodbiornika                           'odczyt adresu odbiornika z listy eeprom

 lds rstemp,{adro}                                          'zaladuj adres Odb do rstemp
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
   lds rstemp,{Stanodbioru}                                 'pobranie statusu transmisji
   cpi rstemp,1
      Breq no_bof                                           'jezeli status=1, znaczy ze juz rozpoczal sie odbior danych

   cpi rsdata,bofm_bit                                      'jezeli status=0, sprawdzamy czy bajt==bofm
      breq yes_bof
   ret                                                      'jezeli status=0, bajt nierowny bofm, nie rob nic

   !yes_bof:
      ldi rstemp,1
      sts {Stanodbioru},rstemp                              'jezeli status=0, bajt == bofm, zmien status na 1, czyli rozpoczynamy odbior danych
   ret


   !no_bof:                                                 'jezeli nie jest to bof:
   mov rstemp,rsdata                                        'skopiuj otrzymany bajt do rstemp
    subi rstemp,eof_bit                                     'odejmij unikalnu eof mastera.
     sbis sreg,2                                            'jezeli to moj eof, to wynik bedzie 0,jezeli nie bedzie ujemny
      rjmp end_of_frame                                     'moj eof-> skocz do konca procedury
    rcall pusty_udr0                                        'jezeli nie moj eof-> sprawdz czy pusty udr0
    !out udr0,rsdata                                        'i wyslij bajt
    ret

    !end_of_frame:                                          'jezeli status=1,bajt == eofm to zmien status transmisji
      ldi rstemp,0
      sts {Stanodbioru},rstemp
    ret

!pusty_udr1:
sbis ucsr1a,udre1                                           'petla gdy udre1 jest zajety
   rjmp pusty_UDR1
ret

!pusty_UDR0:
   sbis ucsr0a,udre0                                        'petla gdy udre0 jest zajety
   rjmp pusty_UDR0
ret

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