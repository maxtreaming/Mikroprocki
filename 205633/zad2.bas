'program demonstruj�cy dzia�anie r�nych funkcji zwi�zanych z transmisj� RS

'wgranie bootloadera wymaga u�ycia programatora STK500 native driver
'po wgraniu bootloadera nale�y zmieni� typ programatopra i od��czy� programator

'u�y� bootloadera modyfikowanego MCS bez kodu dost�pu
'W Options->Programmer:
'1. ma by� wybrany MCS Bootloader
'2. poni�ej w zak�adce MCS Loader: Reset: DTR

'wymagane po��czenia:
'USB_RS.TxD -> PD.0
'USB_RS.Rxd -> PD.1
'USB_RS.DTR -> Reset (pojedynczy ko�ek ko�o przycisku resetu)

'by Marcin Kowalczyk

'obliczenia parametr�w konfiguracyjnych
Const Prescfc = 1                                           'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))                   'cz�stotliwo�� po przeskalowaniu
Const Baundrs = 115200                                      'pr�dko�� transmisji po RS [bps]
Const _ubrr =(((fcrystal / Baundrs) / 16) - 1)              'na potem
'konfigurowanie mikrokontrolera
$regfile = "m32def.dat"                                     'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
$baud = Baundrs

Temp Alias R16                                              'aliasy rejestr�w procesora
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19

'zmniejszenie cz�stotliwo�ci taktowania procesora
'ldi temp,128
'!Out clkpr,temp                                             'ustawienie bitu 7, CLKPR = 128
'ldi temp,prescfc                                            'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
'!Out clkpr,temp                                             'CLKPR = Prescfc

'deklarowanie zmiennych
Dim A As Byte                                               'pocz�tkowo A=0
Dim B As Byte
B = 48                                                      'znak "0" ASCI , to samo co B = Asc("0")

Do
   Print A                                                  'warto�� A konwertowana do string, dodatkowo wysy�ane znaki 13 i 10
   Print                                                    'wys�anie pary znak�w 13 i 10 - powr�t karetki i przej�cie do nowej linii

   Print Hex(a) ; "h"                                       'warto�c A w zapisie HEX z dodanym stringiem "h"
   Print

   Print A ; " ";                                           'wys�anie stringu liczby A i znaku odst�pu bez 13 i 10
   Incr A                                                   'inkrementacja A w kodzie bascom
   Print A ; " ";
   Incr A
   Print A ; Chr(13) ; Chr(10)                              'liczba A z znakami 13 i 10

   'wys�anie 3 cyfr jedna za drug�
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
   'nadawanie jednego znaku z pr�dko�ci� 115200bps trwa ok. 87us
   'drugi znak do wys�ania mo�e by� w kolejce wi�� trzeba poczeka� min. 174us,
   'aby UDR0 by� pusty
   Waitus 500

   'UDRO jest pusty, a transmicja poprzednich znak�w zako�czona, wi�c wpiosany
   'do UDR0 znak zostanie od razu przepisany sprzetowo do rejestru wysuwnego
   ' i ropocznie si� transmisja
   ldi rsdata,asc("a")
   !out udr,rsdata
   'tarnsmicja trwa, ale UDR0 jest pusty wi�c od razu mo�na wpisa� kolejny znak
   ldi rsdata,asc("b")
   !out udr,rsdata
   'Teraz trzeba poczeka� do zako�czenia nadawania znaku "a", by UDR0 znowu,
   'by� pusty. Nala�y kontrolowa� bit UDRE0 w rejestrze UCSR0A lub skorzysta�
   'z przerwania UDRE

   ldi rsdata,asc("c")                                      'za�adowanie kolejnego znaku
   rcall rs_tx                                              'przej�cie do procedury nadawania
   ldi rsdata,13
   rcall rs_tx
   ldi rsdata,10
   rcall rs_tx


   Wait 1
Loop

!rs_tx:
   sbis ucsra,udre                                          'obej�cie rjmp gdy UDR0 pusty - bit UDRE0 = 1
      rjmp rs_tx                                            'czakanie w p�tli na zwolnienie UDR0
   !out udr,rsdata                                         'wpisanie nowego znaku do UDR0 - nie oznacza rozpocz�cia transmicji
ret