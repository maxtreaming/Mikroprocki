


'obliczenia parametrów konfiguracyjnych
Const Prescfc = 0                                           'potêga dzielnika czêstotliwoœci taktowania procesora
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
Data 15 , 14 , 13 , 1 , 9 , 11 , 8 , 6 , 4 , 7 , 0 , 0 , 0 , 0 , 0 , 0       '0...15
Data 24 , 10 , 15 , 20 , 25 , 30 , 24 , 24 , 36 , 6 , 6 , 6 , 6 , 6 , 6 , 6       'ile bajtow odbieramy od urzadzenia = (bof +ilosc danych+eof)x3 aby byc pewnym ze sie zmiesci

$data

'aliasy rejestrów procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta³e aliasy
Te_pin Alias 4
Te Alias Portd.te_pin                                       'sterowanie przep³ywem w nadajniku/odbiorniku linii
'Led_reg Alias Ddrd  'rejestr kontrolki nadawania, gdy anoda LED -> Ucc
'Led_reg Alias Portd 'rejestr kontrolki nadawania, gdy katoda LED -> GND
'Led_pin Alias 7     'numer wyprowadzenia portu dla kontrolki

'On Urxc Usart0_rx Nosave                                    'deklaracja przerwania URXC (odbiór znaku USART0)
On Urxc1 Usart1_rx Nosave                                   'deklaracja przerwania URXC1 (odbiór znaku USART1)
On Utxc1 Usart1_tx_end Nosave                               'deklaracja przerwania UTXC1, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte                                            'adres w³asny
Dim Adro As Byte                                            'adres odbiorcy 0...15
Dim Nrodbiornika As Byte
Dim Pomocnicza As Byte

Const Bof_bit = &B110000000
Const Bofm_bit = &B11000010

Const Eof_bit = &B10000000
Const Eofm_bit = &B10100010

Dim Stanodbioru As Byte
Stanodbioru = 0
Adrw = 2
Nrodbiornika = 15

'zmniejszenie czêstotliwoœci taktowania procesora
ldi temp,128
!Out clkpr,temp                                             'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc                                            'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp                                             'CLKPR = Prescfc


rcall usart_init                                            'inicjalizacja USARTów i w³¹czenie przerwañ

'w³¹czenie timera jako czasomierz, do odmierzania okresu wymiany danych miedzy masterem a slavem.
Const _presctimer = 256
Const _fpr = 15625                                          'czestotliwosc probkowania, pierwszy cykl timera ustawiony na 1s.
Const _ocrtimer = 942                                       'Fcrystal / _presctimer / _fpr -1

Config Timer1 = Timer , Prescale = _presctimer , Compare A = Disconnect , Clear Timer = 1
Stop Timer1
Timer1 = 0
Ocr1a = _ocrtimer

On Oc1a Timer1_interrupt Nosave
Enable Oc1a
Start Timer1

Sei                                                         'w³¹czenie globalnie przerwañ

Do

Loop


'''''''''''''''''''''''''''''''''''''''''''''''''''''''PRZERWANIA'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

Usart1_rx:

 push rstemp                                                'o ile potrzeba - sprawdziæ
 Push rsdata
 in rstemp,sreg                                             'o ile potrzeba  - sprawdziæ
 push rstemp                                                'o ile potrzeba - sprawdziæ
                                                            'zatrzymanie liczenia
 rcall rs_rx

 pop rstemp
 !out sreg,rstemp
 pop rsdata
 pop rstemp
Return
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Usart1_tx_end:
    Te = 0
Return
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Timer1_interrupt:
 push rstemp                                                'o ile potrzeba - sprawdziæ
 Push rsdata
 in rstemp,sreg                                             'o ile potrzeba  - sprawdziæ
 push rstemp                                                'o ile potrzeba - sprawdziæ
                                                            'zatrzymanie liczenia
 rcall Wyslij_ramke

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
   Enable Urxc1
   Enable Utxc1
ret
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
!Wyslij_ramke:
!CLI
       ldi rstemp, 10                                       'wylaczenie przerwan, aby koniec transmisji nie przeszkodzil w procedurze
 rcall pusty_udr0
  !out udr0,rstemp

   ldi rstemp, 13                                           'wylaczenie przerwan, aby koniec transmisji nie przeszkodzil w procedurze
 rcall pusty_udr0
  !out udr0,rstemp

   ldi rstemp, 48                                           'wylaczenie przerwan, aby koniec transmisji nie przeszkodzil w procedurze
 rcall pusty_udr0
  !out udr0,rstemp

  lds rstemp, {adro}
  cpi rstemp,15
   brne pisz_dalej
     ldi rstemp, 2                                          'wylaczenie przerwan, aby koniec transmisji nie przeszkodzil w procedurze
 rcall pusty_udr0
  !out udr0,rstemp

  !pisz_dalej:

                                                       'zatrzymanie przerwania timera
 lds rstemp,{Nrodbiornika}
 cpi rstemp, 15                                             'sprawdzenie czy licznik <= 15
   BREQ zeruj                                               'jezeli tak, skocz do zeruj
   inc rstemp                                               'jezeli nie, zwieksz Nr odbiornika
 rjmp kopiuj_adres

 !zeruj:
   ldi rstemp,0

 !kopiuj_adres:
   STS {Nrodbiornika},rstemp
   Readeeprom Adro , Nrodbiornika                           'odczyt adresu odbiornika z listy eeprom

 lds rstemp,{adro}
 rcall pusty_udr0
 cpi rstemp,10
   brlo cyfry

 subi rstemp,-55
 !out udr0,rstemp
  rjmp koniec_cyfr
  !cyfry:
  subi rstemp,-48
  !out udr0,rstemp



  !koniec_cyfr:
  rcall pusty_udr0
  ldi rstemp,58
  !out udr0,rstemp
 Nrodbiornika = Nrodbiornika + 16                           'wskaznik czasu komunikacji z odbiornikiem jest taki jak jego adres, ale przesuniete o 16 w eeprom                         '
 Readeeprom Pomocnicza , Nrodbiornika                       'odczyt czasu z eeprom
 Nrodbiornika = Nrodbiornika - 16                           'powrot do wskaznika adresu

 Timer1 = 0
 Ocr1a = Pomocnicza * _ocrtimer                             'Czasodbiornika * 1000                              'zerowanie timera i ustawienie ocr



 lds rstemp,{Adro}                                          'tworzenie ramki bof
 ori rstemp,bof_bit
 !pusty_UDR:

  Start Timer1                                              'rozpoczyna sie pomiar okresu komunikacji z konkretnym odbiornikiem
  Te = 1                                                    'transmisja
  !out Udr1,rstemp                                          'tworzenie ramki eof
  ldi rstemp,eofm_bit

   rcall pusty_udr1

  !out Udr1,rstemp                                          'transmisja
  sei
ret
''''''''''''''''''''''''''''''''''''''''''
!rs_rx:
   in rsdata,udr1                                           'odebranie danych

   lds rstemp,{Stanodbioru}                                 'pobranie statusu transmisji
   cpi rstemp,1
      Breq no_bof                                           'jezeli status=1, znaczy ze juz rozpoczal sie odbior danych

   cpi rsdata,bofm_bit                                      'jezeli status=0, sprawdzamy czy bajt==bofm
      breq yes_bof
   ret
                                                           'jezeli status=0, bajt nierowny bofm, nie rob nic

   !yes_bof:
      ldi rstemp,1
      sts {Stanodbioru},rstemp                              'jezeli status=0, bajt == bofm, zmien status na 1, czyli rozpoczynamy odbior danych
   ret


   !no_bof:
    cpi rsdata,eofm_bit
      breq end_of_frame
    rcall pusty_udr0
    !out udr0,rsdata
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