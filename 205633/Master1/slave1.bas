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
Const Fcrystal =(14745600 /(2 ^ Prescfc))                   'czêstotliwoœæ po przeskalowaniu
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





On Urxc Usart_rx Nosave                                     'deklaracja przerwania URXC (odbiór znaku USART)
On Utxc Usart_tx_end Nosave                                 'deklaracja przerwania UTXC, koniec nadawania

'deklarowanie zmiennych
Dim Adrw As Byte                                            'adres w³asny
Dim Adro As Byte
Dim Bajt As Byte                                            'adres odbiorcy 0...15
Const Bof_bit = &B11000000
Const Bofm_bit = &B10000000
Const Bofmaster_bit = &B11000010
Const Bofs_bit = &B11000100

Const Eof_bit = &B10000000
Const Eofm_bit = &B10100010

Dim Stanodbioru As Byte
Stanodbioru = 0

SBI Ddrd,Led_pin

rcall usart_init                                            'inicjalizacja USARTów i w³¹czenie przerwañ
Sei                                                         'w³¹czenie globalnie przerwañ


Do
   'inne procedury
   ldi rstemp,70
   !out udr, rstemp
   Waitms 500

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
   !cli
   rcall rs_rx                                              'kod mo¿e byæ bezpoœrenio w usart_rx
   sei
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
   in rsdata,udr
   lDs rstemp, {stanodbioru}
   cpi rstemp,1
      breq koniec_ramki

   subi rsdata,bof_bit

      sbic sreg,2
  ret
   sts {adrw},rsdata
   ldi rstemp,1
   sts {stanodbioru},rstemp
  ret

   !koniec_ramki:
   subi rsdata,eof_bit
      sbic sreg,2
     ret
      ldi rstemp,0
      sts {stanodbioru},rstemp

      Te = 1
      ldi rstemp,bofmaster_bit
      !out udr,rstemp

      ldi rstemp,48
      !wyslij_liczby:

      !pusty_UDR:
      sbiS ucsra,udre                                       'petla gdy udre1 jest zajety
      rjmp pusty_UDR

      !out udr,rstemp
      inc rstemp
      cpi rstemp,58
         brne wyslij_liczby

      !pusty_UDR1:
      sbiS ucsra,udre                                       'petla gdy udre1 jest zajety
      rjmp pusty_UDR1

      lds rstemp,{adrw}
      subi rstemp,eof_bit
      !out udr,rstemp
   ret




Usart_tx_end:                                               'przerwanie wyst¹pi gdy USART wyœle znak i UDR bêdzie pusty
   Te = 0                                                   'wy³¹czenie nadajnika, w³¹czenie odbiornika
   'to samo co CBI PORTD,TE_pin, brak zmian w SREG
Return



!usart_init:
'procedura inicjalizacji USARTów
   ldi temp,_ubrr
   !out ubrrl,temp
  '!out ubrrH,temp                                          'mniej znacz¹cy bajt UBRR USART1
   ldi temp,24                                              'w³¹czone odbiorniki i nadajniki USARTów
   !out ucsrb,temp
  ' !out ucsr1b,temp
  'sbi ucsrc,7
   ldi temp,&B10000110                                      'N8bit
   !out ucsrC,temp
  ' !out ucsr1C,temp
   'ustawienia RS485
   Te = 0                                                   'domyœlnie stan odbioru
   sbi ddrd,Te_pin                                          'wyjœcie TE silnopr¹dowe
   'w³¹czenie przerwañ
   Enable Urxc
   Enable Utxc
ret

!dioda:
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