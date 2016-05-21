'program bufora danych wej�ciowych z u�yciem przerwa� URXC i UDRE
'bufor mie�ci �a�cuch 16 znak�w + 2 znaki ko�ca linii i powrotu karetki
'odbi�r znaku 13 powoduje wys�anie zawarto�ci bufora i pary 13 i 10

'kontynuacja zadania:
'1. zmieni� bufor na pier�cieniowy (najwcze�niej zapisane znaki s� zast�powane
'nowymi znakami, a odbi�r znaku 13 ma powodowa� zwr�cenie odebranych znak�w),
'przed wpisaniem znak�w 13 i 10 wys�a� pierwsze dwa znaki je�li s� min. 2 znaki
'do wyslania
'alternatywnie znaki 13 i 10 mo�na wysy�a� z procedury usart_tx po jej modyfikacji
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
'Const Fcrystal =(3686400 /(2 ^ Prescfc))
Const Baundrs = 115200       'pr�dko�� transmisji po RS [bps]
Const _ubrr =(((fcrystal / Baundrs) / 16) - 1)       'potrzebne w nast�pnych zadaniach

Const Lstr_max = 16 'pojemno�� bufora wej�ciowego
Const Bufrange = Lstr_max + 2       'rozmair string lub tabeli, 2 dodatkowe znaki 13 i 10
'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"       'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
$baud = Baundrs
'aliasy rejestr�w procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta�e aliasy
Led_reg Alias Ddrd  'rejestr kontrolki nadawania, gdy anoda LED -> Ucc
'Led_reg Alias Portd 'rejestr kontrolki nadawania, gdy katoda LED -> GND
Led_pin Alias 7     'numer wyprowadzenia portu dla kontrolki

'zmniejszenie cz�stotliwo�ci taktowania procesora
ldi temp,128
!Out clkpr,temp     'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc    'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp     'CLKPR = Prescfc

On Urxc Usart_rx Nosave       'deklaracja przerwania URXC (odbi�r znaku USART0)
'nosave - nie s� umieszczane na stosie r0...r31 i SREG
On Udre Usart_tx Nosave       'deklaracja przerwania UDRE (pustego UDR0)

'deklarowanie zmiennych
Dim Lstr As Byte    'gdy =0 to string s=""
Dim Ch2s As Byte    'licznik znak�w do wys�ania
'Dim S As String * Bufrange       ' string o maksymalnej d�ugo�ci 16 + dodatkowo 0 + 2
Dim Tabs(bufrange) As Byte       'alternatywnie tabela

Enable Urxc         'w��czenie przerwania URXC0
Disable Udre
Sei                 'w��czenie globalnie przerwa�

Do
   'inne procedury
Loop

'procedura przerwania kompatybilna z bascom
Usart_rx:           'etykieta bascomowa koniecznie bez !
'u�ywane rejestry w procedurze przerwania wsp�dzielone z rejestrami
'w procedurach, kt�re mog� by� przerwane nale�y zapami�ta�
   push rstemp      'o ile potrzeba - sprawdzi�
   in rstemp,sreg   'o ile potrzeba  - sprawdzi�
   push rstemp      'o ile potrzeba - sprawdzi�
   push yl          'o ile potrzeba  - sprawdzi�
   push yh          'o ile potrzeba  - sprawdzi�

   rcall rs_rx      'kod mo�e by� bezpo�renio w usart_rx

   'odtworzenie stanu jak przed przerwanie
   pop yh           'o ile potrzeba - sprawdzi�
   pop yl           'o ile potrzeba - sprawdzi�
   pop rstemp       'o ile potrzeba - sprawdzi�
   !out sreg,rstemp 'o ile potrzeba - sprawdzi�
   pop rstemp       'o ile potrzeba - sprawdzi�
Return              'to samo co RETI             '

!rs_rx:
   'Loadadr S , Y    'za�adowanie adresu zmiennaj S do pary adrespowej Y
   Loadadr Tabs(1) , Y       'za�adowanie adresu zmiennaj S do pary adrespowej Y
   lds rstemp,{lstr}       'bezpo�rednie przepisanie z SRAM licznika znak�w
   ldi rsdata,0     'potrzebne przy dodawaniu byte do word
   add yl,rstemp    'dodanie offsetu
   adc yh,rsdata
   'w Y adres do zapisu
   'gdy odebranym znakiem b�dzie 13 to mo�na zainicjowa� nadawanie 2 znak�w

   in rsdata,udr0   'przepisanie znaku zeruje RXC0 (bit przerwania URXC)
   'sprawdzenie czy polecenie wys�ania zawarto�ci bufora
   cpi rsdata,13    'sprawdzenie czy odebrano znak 13
   breq znak_13     'przy odbiorze 13 nie ma znaczenia ograniczenie liczby znak�w
      cpi rstemp,Lstr_max       'sprawdzenie czy nie przekroczono limitu znak�w
      brmi znak_13
         ret        'wyj�cie gdy rstemp-lstr_max>=0
   !znak_13:

   inc rstemp       'inkrementacja licznika znak�w
   st y+,rsdata     'zapisanie odebranego znaku do bufora

   cpi rsdata,13    'sprawdzenie czy nakaz nadawania
   brne no_13       'obej�cie gdy nie 13
      ldi rsdata,10
      st y,rsdata   'zapisanie w buforze dodatkowo znaku nowej linii
      'Loadadr S , Y 'za�adowanie adresu pierwszego znaku
      Loadadr Tabs(1) , Y       'za�adowanie adresu pierwszego znaku
      'zainicjowanie transmisji 2 pierwszych znak�w, pozostaje wys�a� o 2 mniej
      ld rsdata,y+
      !out udr0,rsdata
      ld rsdata,y
      !out udr0,rsdata
      dec rstemp    'dekrementacja licznika znak�w do wyslania
      breq no_13    'obej�cie gdy licznik jest zerowy (wyslanie tylko 13 i 10)
         Enable Udre       'w��czenie przerwania UDRE
         Disable Urxc       'wy��czenie przerwania odbioru - zb�dne przy halfduplex
         sts {ch2s},rstemp       'liczba znak�w do wys�ania
         sbi led_reg,led_pin       'w��czenie kontrolki nadawania
   !no_13:
   sts {lstr},rstemp       'zachowanie licznika po inkrementacji liczby znak�w
   !buffor_of:
ret

Usart_tx:'procedura przerwania kompatybilna z bascom
'przerwanie wyst�pi gdy s� znaki do wys�ania i mo�na wpisa� znak do UDR0
   push rstemp      'o ile potrzeba - sprawdzi�
   in rstemp,sreg   'o ile potrzeba  - sprawdzi�
   push rstemp      'o ile potrzeba - sprawdzi�
   push rsdata      'o ile potrzeba - sprawdzi�
   'para Y nie b�dzie odtwarzana, bo nie jest wsp�u�ytkowana
'obliczenie offsetu do odczytu z bufora
'przed pierwszym przerwaniem 2 znaki by�y wpisane do UDR0 -> offset kolejnego 2
   'ldi rsdata,2     'liczba znak�w wys�anych na starcie, z stringiem S
   'lds rstemp,{ch2s}       'og�lna liczba znak�w do wys�ania, z stringiem S
   'add rsdata,rstemp       'offset odczytu ostatniego znaku, z stringiem S
   lds rsdata,{ch2s}       ''og�lna liczba znak�w do wys�ania, z tabel� tabS
   lds rstemp,{lstr}       'liczba znak�w pozosta�ych do wys�ania
   !sub rsdata,rstemp       'offset odczytu bie��cego znaku
   'Loadadr S , Y           'za�adowanie adresu pierwszego znaku, z stringiem S
   Loadadr Tabs(3) , Y       'za�adowanie adresu trzeciego znaku
   add yl,rsdata
   ldi rsdata,0     'potrzebne do dodania byte (offset) do word (s�owo adresowe)
   adc yh,rsdata    'doko�czenie dodawania z c
   ld rsdata,y      'za�adowanie bajtu do wys�ania po adresem Y
   !out udr0,rsdata

   dec rstemp       'dekrementacja licznika znak�w
   sts {lstr},rstemp       'zapisanie w SRAM
   brne no_lstr0
      Disable Udre  'wy��czenie przerwania UDRE
      Enable Urxc   'w��czenie przerwania odbioru - zb�dne przy halfduplex
      cbi led_reg,led_pin       'wy��czenie kontrolki nadawania
   !no_lstr0:
   pop rsdata       'o ile potrzeba - sprawdzi�
   pop rstemp       'o ile potrzeba - sprawdzi�
   !out sreg,rstemp 'o ile potrzeba - sprawdzi�
   pop rstemp       'o ile potrzeba - sprawdzi�
Return