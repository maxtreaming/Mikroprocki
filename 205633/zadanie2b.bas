'program bufora danych wej�ciowych bez u�ycia przerwa�
'rozmiar bufora 16 znak�w, bufor w formie stringu
'za wpisywanym znakiem jest dopisywany znak ko�cz�cy string
'odbi�r znaki 13 powoduje wys�anie zawarto�ci bufora

'kontynuacja zadania:
'1. u�y� przerwania URXC
'2. zmieni� bufor na pier�cieniowy (najwcze�niej zapisane znaki s� zast�powane
'nowymi znakami, a odbi�r znaku 13 ma powodowa� zwr�cenie odebranych znak�w)
'rozmiar bufora 16 lub 64 lub 256

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
Const Prescfc = 1   'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))       'cz�stotliwo�� po przeskalowaniu
'Const Fcrystal =(3686400 /(2 ^ Prescfc))       'cz�stotliwo�� po przeskalowaniu
Const Baundrs = 115200       'pr�dko�� transmisji po RS [bps]
Const _ubrr =(((fcrystal / Baundrs) / 16) - 1)       'potrzebne w nast�pnych zadaniach
'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"       'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
$baud = Baundrs

Temp Alias R16      'aliasy rejestr�w procesora
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19

'zmniejszenie cz�stotliwo�ci taktowania procesora
ldi temp,128
!Out clkpr,temp     'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc   'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp     'CLKPR = Prescfc

'deklarowanie zmiennych
Dim Lstr As Byte    'gdy =0 to string s=""
Dim S As String * 16       ' string o maksymalnej d�ugo�ci 16 + dodatkowo 0

Const Lstr_max = 16
S = ""

Do
   sbic ucsr0a,rxc0 'obej�cie gdy nie obebrano znaku
      rcall rs_rx

Loop

!rs_rx:
   in rsdata,udr0   'przepianie znaku zeruje RXC0
   'sprawdzenie czy polecenie wys�ania zawarto�ci bufora
   cpi rsdata,13
   breq rs_tx

   'sprawdzenie czy nie przekroczono limitu znak�w
   lds rstemp,{lstr}       'bezpo�rednie przepisanie z SRAM
   '{} oznacza wskazania adresu
   cpi rstemp,Lstr_max
   sbis sreg,2      'obej�cie gdy znak�w mniej ni� 16 (bit N, rstemp-16<0)
      ret

   inc rstemp
   sts {lstr},rstemp       'zachowanie licznika po inkrementacji liczby znak�w
   dec rstemp       'przywr�cenie dotychczasowego offsetu w stringu S

   Loadadr S , Y    'za�adowanie adresu zmiennaj S do pary adrespowej Y (r28,r29)
   'dodanie do adresu pocz�tku offsetu
   add yl,rstemp
   ldi rstemp,0     'LDI nie zmienia SREG
   adc yh,rstemp

   st y+,rsdata
   ldi rsdata,0
   st y,rsdata      'dopisanie 0 ko�cz�cego string (mo�na pomin�� zerowanie S)

ret


!rs_tx:
   Print S
'   S = ""           'zerowanie S, mo�na pomin�� gdy dopisywane jest 0
   Lstr = 0

'   sbis ucsr0a,udre0       'obej�cie rjmp gdy UDR0 pusty - bit UDRE0 = 1
'      rjmp rs_tx    'czakanie w p�tli na zwolnienie UDR0
'   !out udr0,rsdata 'wpisanie nowego znaku do UDR0 - nie oznacza rozpocz�cia transmicji
ret

