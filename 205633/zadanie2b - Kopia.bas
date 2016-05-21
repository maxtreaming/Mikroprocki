'program bufora danych wejœciowych bez u¿ycia przerwañ
'rozmiar bufora 16 znaków, bufor w formie stringu
'za wpisywanym znakiem jest dopisywany znak koñcz¹cy string
'odbiór znaki 13 powoduje wys³anie zawartoœci bufora

'kontynuacja zadania:
'1. u¿yæ przerwania URXC
'2. zmieniæ bufor na pierœcieniowy (najwczeœniej zapisane znaki s¹ zastêpowane
'nowymi znakami, a odbiór znaku 13 ma powodowaæ zwrócenie odebranych znaków)
'rozmiar bufora 16 lub 64 lub 256

'wgranie bootloadera wymaga u¿ycia programatora STK500 native driver
'po wgraniu bootloadera nale¿y zmieniæ typ programatopra i od³¹czyæ programator

'u¿yæ bootloadera modyfikowanego MCS bez kodu dostêpu
'W Options->Programmer:
'1. ma byæ wybrany MCS Bootloader
'2. poni¿ej w zak³adce MCS Loader: Reset: DTR

'wymagane po³¹czenia:
'USB_RS.TxD -> PD.0
'USB_RS.Rxd -> PD.1
'USB_RS.DTR -> Reset (pojedynczy ko³ek ko³o przycisku resetu)

'by Marcin Kowalczyk

'obliczenia parametrów konfiguracyjnych
Const Prescfc = 1   'potêga dzielnika czêstotliwoœci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))       'czêstotliwoœæ po przeskalowaniu
'Const Fcrystal =(3686400 /(2 ^ Prescfc))       'czêstotliwoœæ po przeskalowaniu
Const Baundrs = 115200       'prêdkoœæ transmisji po RS [bps]
Const _ubrr =(((fcrystal / Baundrs) / 16) - 1)       'potrzebne w nastêpnych zadaniach
'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"       'plik konfiguracyjny z literk¹ "p" w nazwie
$crystal = Fcrystal
$baud = Baundrs

Temp Alias R16      'aliasy rejestrów procesora
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19

'zmniejszenie czêstotliwoœci taktowania procesora
ldi temp,128
!Out clkpr,temp     'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc   'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp     'CLKPR = Prescfc

'deklarowanie zmiennych
Dim Lstr As Byte    'gdy =0 to string s=""
Dim S As String * 16       ' string o maksymalnej d³ugoœci 16 + dodatkowo 0

Const Lstr_max = 16
S = ""

Do
   sbic ucsr0a,rxc0 'obejœcie gdy nie obebrano znaku
      rcall rs_rx

Loop

!rs_rx:
   in rsdata,udr0   'przepianie znaku zeruje RXC0
   'sprawdzenie czy polecenie wys³ania zawartoœci bufora
   cpi rsdata,13
   breq rs_tx

   'sprawdzenie czy nie przekroczono limitu znaków
   lds rstemp,{lstr}       'bezpoœrednie przepisanie z SRAM
   '{} oznacza wskazania adresu
   cpi rstemp,Lstr_max
   sbis sreg,2      'obejœcie gdy znaków mniej ni¿ 16 (bit N, rstemp-16<0)
      ret

   inc rstemp
   sts {lstr},rstemp       'zachowanie licznika po inkrementacji liczby znaków
   dec rstemp       'przywrócenie dotychczasowego offsetu w stringu S

   Loadadr S , Y    'za³adowanie adresu zmiennaj S do pary adrespowej Y (r28,r29)
   'dodanie do adresu pocz¹tku offsetu
   add yl,rstemp
   ldi rstemp,0     'LDI nie zmienia SREG
   adc yh,rstemp

   st y+,rsdata
   ldi rsdata,0
   st y,rsdata      'dopisanie 0 koñcz¹cego string (mo¿na pomin¹æ zerowanie S)

ret


!rs_tx:
   Print S
'   S = ""           'zerowanie S, mo¿na pomin¹æ gdy dopisywane jest 0
   Lstr = 0

'   sbis ucsr0a,udre0       'obejœcie rjmp gdy UDR0 pusty - bit UDRE0 = 1
'      rjmp rs_tx    'czakanie w pêtli na zwolnienie UDR0
'   !out udr0,rsdata 'wpisanie nowego znaku do UDR0 - nie oznacza rozpoczêcia transmicji
ret

