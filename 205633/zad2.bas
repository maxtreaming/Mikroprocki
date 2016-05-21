'program demonstruj¹cy dzia³anie ró¿nych funkcji zwi¹zanych z transmisj¹ RS

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
Const Prescfc = 1                                           'potêga dzielnika czêstotliwoœci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))                   'czêstotliwoœæ po przeskalowaniu
Const Baundrs = 115200                                      'prêdkoœæ transmisji po RS [bps]
Const _ubrr =(((fcrystal / Baundrs) / 16) - 1)              'na potem
'konfigurowanie mikrokontrolera
$regfile = "m32def.dat"                                     'plik konfiguracyjny z literk¹ "p" w nazwie
$crystal = Fcrystal
$baud = Baundrs

Temp Alias R16                                              'aliasy rejestrów procesora
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19

'zmniejszenie czêstotliwoœci taktowania procesora
'ldi temp,128
'!Out clkpr,temp                                             'ustawienie bitu 7, CLKPR = 128
'ldi temp,prescfc                                            'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
'!Out clkpr,temp                                             'CLKPR = Prescfc

'deklarowanie zmiennych
Dim A As Byte                                               'pocz¹tkowo A=0
Dim B As Byte
B = 48                                                      'znak "0" ASCI , to samo co B = Asc("0")

Do
   Print A                                                  'wartoœæ A konwertowana do string, dodatkowo wysy³ane znaki 13 i 10
   Print                                                    'wys³anie pary znaków 13 i 10 - powrót karetki i przejœcie do nowej linii

   Print Hex(a) ; "h"                                       'wartoœc A w zapisie HEX z dodanym stringiem "h"
   Print

   Print A ; " ";                                           'wys³anie stringu liczby A i znaku odstêpu bez 13 i 10
   Incr A                                                   'inkrementacja A w kodzie bascom
   Print A ; " ";
   Incr A
   Print A ; Chr(13) ; Chr(10)                              'liczba A z znakami 13 i 10

   'wys³anie 3 cyfr jedna za drug¹
   Printbin B
   Incr B
   Printbin B
   Incr B
   If B > Asc( "9") Then B = Asc( "0")                      'tylko cyfry
   Printbin B
   Printbin 13
   Printbin 10                                              'to samo co Print Chr(10);

   Print

   'w kodzie ASM
   'nadawanie jednego znaku z prêdkoœci¹ 115200bps trwa ok. 87us
   'drugi znak do wys³ania mo¿e byæ w kolejce wiêæ trzeba poczekaæ min. 174us,
   'aby UDR0 by³ pusty
   Waitus 500

   'UDRO jest pusty, a transmicja poprzednich znaków zakoñczona, wiêc wpiosany
   'do UDR0 znak zostanie od razu przepisany sprzetowo do rejestru wysuwnego
   ' i ropocznie siê transmisja
   ldi rsdata,asc("a")
   !out udr,rsdata
   'tarnsmicja trwa, ale UDR0 jest pusty wiêc od razu mo¿na wpisaæ kolejny znak
   ldi rsdata,asc("b")
   !out udr,rsdata
   'Teraz trzeba poczekaæ do zakoñczenia nadawania znaku "a", by UDR0 znowu,
   'by³ pusty. Nala¿y kontrolowaæ bit UDRE0 w rejestrze UCSR0A lub skorzystaæ
   'z przerwania UDRE

   ldi rsdata,asc("c")                                      'za³adowanie kolejnego znaku
   rcall rs_tx                                              'przejœcie do procedury nadawania
   ldi rsdata,13
   rcall rs_tx
   ldi rsdata,10
   rcall rs_tx


   Wait 1
Loop

!rs_tx:
   sbis ucsra,udre                                          'obejœcie rjmp gdy UDR0 pusty - bit UDRE0 = 1
      rjmp rs_tx                                            'czakanie w pêtli na zwolnienie UDR0
   !out udr,rsdata                                         'wpisanie nowego znaku do UDR0 - nie oznacza rozpoczêcia transmicji
ret