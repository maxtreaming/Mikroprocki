'program bufora danych wejœciowych z u¿yciem przerwañ URXC i UDRE
'bufor mieœci ³añcuch 16 znaków + 2 znaki koñca linii i powrotu karetki
'odbiór znaku 13 powoduje wys³anie zawartoœci bufora i pary 13 i 10

'kontynuacja zadania:
'1. zmieniæ bufor na pierœcieniowy (najwczeœniej zapisane znaki s¹ zastêpowane
'nowymi znakami, a odbiór znaku 13 ma powodowaæ zwrócenie odebranych znaków),
'przed wpisaniem znaków 13 i 10 wys³aæ pierwsze dwa znaki jeœli s¹ min. 2 znaki
'do wyslania
'alternatywnie znaki 13 i 10 mo¿na wysy³aæ z procedury usart_tx po jej modyfikacji
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
'Const Fcrystal =(3686400 /(2 ^ Prescfc))
Const Baundrs = 115200       'prêdkoœæ transmisji po RS [bps]
Const _ubrr =(((fcrystal / Baundrs) / 16) - 1)       'potrzebne w nastêpnych zadaniach

Const Lstr_max = 16 'pojemnoœæ bufora wejœciowego
Const Bufrange = Lstr_max + 2       'rozmair string lub tabeli, 2 dodatkowe znaki 13 i 10
'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"       'plik konfiguracyjny z literk¹ "p" w nazwie
$crystal = Fcrystal
$baud = Baundrs
'aliasy rejestrów procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta³e aliasy
Led_reg Alias Ddrd  'rejestr kontrolki nadawania, gdy anoda LED -> Ucc
'Led_reg Alias Portd 'rejestr kontrolki nadawania, gdy katoda LED -> GND
Led_pin Alias 7     'numer wyprowadzenia portu dla kontrolki

'zmniejszenie czêstotliwoœci taktowania procesora
ldi temp,128
!Out clkpr,temp     'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc    'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp     'CLKPR = Prescfc

On Urxc Usart_rx Nosave       'deklaracja przerwania URXC (odbiór znaku USART0)
'nosave - nie s¹ umieszczane na stosie r0...r31 i SREG
On Udre Usart_tx Nosave       'deklaracja przerwania UDRE (pustego UDR0)

'deklarowanie zmiennych
Dim Lstr As Byte    'gdy =0 to string s=""
Dim Ch2s As Byte    'licznik znaków do wys³ania
'Dim S As String * Bufrange       ' string o maksymalnej d³ugoœci 16 + dodatkowo 0 + 2
Dim Tabs(bufrange) As Byte       'alternatywnie tabela

Enable Urxc         'w³¹czenie przerwania URXC0
Disable Udre
Sei                 'w³¹czenie globalnie przerwañ

Do
   'inne procedury
Loop

'procedura przerwania kompatybilna z bascom
Usart_rx:           'etykieta bascomowa koniecznie bez !
'u¿ywane rejestry w procedurze przerwania wspó³dzielone z rejestrami
'w procedurach, które mog¹ byæ przerwane nale¿y zapamiêtaæ
   push rstemp      'o ile potrzeba - sprawdziæ
   in rstemp,sreg   'o ile potrzeba  - sprawdziæ
   push rstemp      'o ile potrzeba - sprawdziæ
   push yl          'o ile potrzeba  - sprawdziæ
   push yh          'o ile potrzeba  - sprawdziæ

   rcall rs_rx      'kod mo¿e byæ bezpoœrenio w usart_rx

   'odtworzenie stanu jak przed przerwanie
   pop yh           'o ile potrzeba - sprawdziæ
   pop yl           'o ile potrzeba - sprawdziæ
   pop rstemp       'o ile potrzeba - sprawdziæ
   !out sreg,rstemp 'o ile potrzeba - sprawdziæ
   pop rstemp       'o ile potrzeba - sprawdziæ
Return              'to samo co RETI             '

!rs_rx:
   'Loadadr S , Y    'za³adowanie adresu zmiennaj S do pary adrespowej Y
   Loadadr Tabs(1) , Y       'za³adowanie adresu zmiennaj S do pary adrespowej Y
   lds rstemp,{lstr}       'bezpoœrednie przepisanie z SRAM licznika znaków
   ldi rsdata,0     'potrzebne przy dodawaniu byte do word
   add yl,rstemp    'dodanie offsetu
   adc yh,rsdata
   'w Y adres do zapisu
   'gdy odebranym znakiem bêdzie 13 to mo¿na zainicjowaæ nadawanie 2 znaków

   in rsdata,udr0   'przepisanie znaku zeruje RXC0 (bit przerwania URXC)
   'sprawdzenie czy polecenie wys³ania zawartoœci bufora
   cpi rsdata,13    'sprawdzenie czy odebrano znak 13
   breq znak_13     'przy odbiorze 13 nie ma znaczenia ograniczenie liczby znaków
      cpi rstemp,Lstr_max       'sprawdzenie czy nie przekroczono limitu znaków
      brmi znak_13
         ret        'wyjœcie gdy rstemp-lstr_max>=0
   !znak_13:

   inc rstemp       'inkrementacja licznika znaków
   st y+,rsdata     'zapisanie odebranego znaku do bufora

   cpi rsdata,13    'sprawdzenie czy nakaz nadawania
   brne no_13       'obejœcie gdy nie 13
      ldi rsdata,10
      st y,rsdata   'zapisanie w buforze dodatkowo znaku nowej linii
      'Loadadr S , Y 'za³adowanie adresu pierwszego znaku
      Loadadr Tabs(1) , Y       'za³adowanie adresu pierwszego znaku
      'zainicjowanie transmisji 2 pierwszych znaków, pozostaje wys³aæ o 2 mniej
      ld rsdata,y+
      !out udr0,rsdata
      ld rsdata,y
      !out udr0,rsdata
      dec rstemp    'dekrementacja licznika znaków do wyslania
      breq no_13    'obejœcie gdy licznik jest zerowy (wyslanie tylko 13 i 10)
         Enable Udre       'w³¹czenie przerwania UDRE
         Disable Urxc       'wy³¹czenie przerwania odbioru - zbêdne przy halfduplex
         sts {ch2s},rstemp       'liczba znaków do wys³ania
         sbi led_reg,led_pin       'w³¹czenie kontrolki nadawania
   !no_13:
   sts {lstr},rstemp       'zachowanie licznika po inkrementacji liczby znaków
   !buffor_of:
ret

Usart_tx:'procedura przerwania kompatybilna z bascom
'przerwanie wyst¹pi gdy s¹ znaki do wys³ania i mo¿na wpisaæ znak do UDR0
   push rstemp      'o ile potrzeba - sprawdziæ
   in rstemp,sreg   'o ile potrzeba  - sprawdziæ
   push rstemp      'o ile potrzeba - sprawdziæ
   push rsdata      'o ile potrzeba - sprawdziæ
   'para Y nie bêdzie odtwarzana, bo nie jest wspó³u¿ytkowana
'obliczenie offsetu do odczytu z bufora
'przed pierwszym przerwaniem 2 znaki by³y wpisane do UDR0 -> offset kolejnego 2
   'ldi rsdata,2     'liczba znaków wys³anych na starcie, z stringiem S
   'lds rstemp,{ch2s}       'ogólna liczba znaków do wys³ania, z stringiem S
   'add rsdata,rstemp       'offset odczytu ostatniego znaku, z stringiem S
   lds rsdata,{ch2s}       ''ogólna liczba znaków do wys³ania, z tabel¹ tabS
   lds rstemp,{lstr}       'liczba znaków pozosta³ych do wys³ania
   !sub rsdata,rstemp       'offset odczytu bie¿¹cego znaku
   'Loadadr S , Y           'za³adowanie adresu pierwszego znaku, z stringiem S
   Loadadr Tabs(3) , Y       'za³adowanie adresu trzeciego znaku
   add yl,rsdata
   ldi rsdata,0     'potrzebne do dodania byte (offset) do word (s³owo adresowe)
   adc yh,rsdata    'dokoñczenie dodawania z c
   ld rsdata,y      'za³adowanie bajtu do wys³ania po adresem Y
   !out udr0,rsdata

   dec rstemp       'dekrementacja licznika znaków
   sts {lstr},rstemp       'zapisanie w SRAM
   brne no_lstr0
      Disable Udre  'wy³¹czenie przerwania UDRE
      Enable Urxc   'w³¹czenie przerwania odbioru - zbêdne przy halfduplex
      cbi led_reg,led_pin       'wy³¹czenie kontrolki nadawania
   !no_lstr0:
   pop rsdata       'o ile potrzeba - sprawdziæ
   pop rstemp       'o ile potrzeba - sprawdziæ
   !out sreg,rstemp 'o ile potrzeba - sprawdziæ
   pop rstemp       'o ile potrzeba - sprawdziæ
Return