'program testowy komunikacji na magistarli RS485
'znak nadany w terminalu na jednym komputerze jest odbierany przez inne komputery

'by Marcin Kowalczyk

'obliczenia parametr�w konfiguracyjnych
Const Prescfc = 0   'pot�ga dzielnika cz�stotliwo�ci taktowania procesora
Const Fcrystal =(14745600 /(2 ^ Prescfc))       'cz�stotliwo�� po przeskalowaniu
'sta�e konfiguracujne USART�w
Const Baundrs0 = 115200       'pr�dko�� transmisji po RS [bps] USART0
Const _ubrr0 =(((fcrystal / Baundrs0) / 16) - 1)       'potrzebne w nast�pnych zadaniach
Const Baundrs1 = Baundrs0       'pr�dko�� transmisji po RS [bps] USART1
Const _ubrr1 =(((fcrystal / Baundrs1) / 16) - 1)       'potrzebne w nast�pnych zadaniach

'konfigurowanie mikrokontrolera
$regfile = "m644pdef.dat"       'plik konfiguracyjny z literk� "p" w nazwie
$crystal = Fcrystal
'$baud = Baundrs0    'zb�dne gdy inicjalizacja w zdefiniowanej procedurze

'aliasy rejestr�w procesora
Temp Alias R16
Temph Alias R17
Rstemp Alias R18
Rsdata Alias R19
'pozosta�e aliasy
Te_pin Alias 5
Te Alias Portd.te_pin       'sterowanie przep�ywem w nadajniku/odbiorniku linii

'Led_reg Alias Ddrd  'rejestr kontrolki nadawania, gdy anoda LED -> Ucc
'Led_reg Alias Portd 'rejestr kontrolki nadawania, gdy katoda LED -> GND
'Led_pin Alias 7     'numer wyprowadzenia portu dla kontrolki

On Urxc Usart0_rx Nosave       'deklaracja przerwania URXC (odbi�r znaku USART0)
On Urxc1 Usart1_rx Nosave       'deklaracja przerwania URXC1 (odbi�r znaku USART1)
On Utxc1 Usart1_tx_end Nosave       'deklaracja przerwania UTXC1, koniec nadawania

'deklarowanie zmiennych
'Dim Adrw As Byte    'adres w�asny


'zmniejszenie cz�stotliwo�ci taktowania procesora
ldi temp,128
!Out clkpr,temp     'ustawienie bitu 7, CLKPR = 128
ldi temp,prescfc    'aktualizacja CLKPR dopiero po uprzednim ustawienu bitu 7
!Out clkpr,temp     'CLKPR = Prescfc

'Adrw = 10

rcall usart_init    'inicjalizacja USART�w i w��czenie przerwa�
Sei                 'w��czenie globalnie przerwa�

Do
   'inne procedury
Loop



Usart0_rx:          'etykieta bascomowa koniecznie bez !
   push rstemp      'o ile potrzeba - sprawdzi�
   in rstemp,sreg   'o ile potrzeba  - sprawdzi�
   push rstemp      'o ile potrzeba - sprawdzi�
'   push yl          'o ile potrzeba  - sprawdzi�
'   push yh          'o ile potrzeba  - sprawdzi�

   rcall rs_rx      'kod mo�e by� bezpo�renio w usart_rx

   'odtworzenie stanu jak przed przerwanie
'   pop yh
'   pop yl
   pop rstemp
   !out sreg,rstemp
   pop rstemp
Return

Usart1_rx:          'etykieta bascomowa koniecznie bez !
   push rstemp      'o ile potrzeba - sprawdzi�
   in rstemp,sreg   'o ile potrzeba  - sprawdzi�
   push rstemp      'o ile potrzeba - sprawdzi�
'   push yl          'o ile potrzeba  - sprawdzi�
'   push yh          'o ile potrzeba  - sprawdzi�

   in rstemp,udr1
   !out udr0,rstemp 'wys�anie znaku do kumputera bez przetwarzania

   'odtworzenie stanu jak przed przerwanie
'   pop yh
'   pop yl
   pop rstemp
   !out sreg,rstemp
   pop rstemp
Return              '

!rs_rx:
   'znak odebrany jest wysy�any na magistarl�
   in rstemp,udr0
      'sbi ddrd,7       'kontrolka
      '!out udr0,rstemp  'do testu
   Te = 1           'w��czenie nadajnika
   !out udr1,rstemp 'wys�anie znaku na magistarl� RS485 bez przetwarzania
ret

Usart1_tx_end:      'przerwanie wyst�pi gdy USART wy�le znak i UDR b�dzie pusty
   Te = 0           'wy��czenie nadajnika, w��czenie odbiornika
   'to samo co CBI PORTD,TE_pin, brak zmian w SREG
Return

!usart_init:
'procedura inicjalizacji USART�w
   ldi temp,0
   !out ubrr0h,temp 'bardziej znacz�cy bajt UBRR USART0
   !out ubrr1h,temp
   ldi temp,_ubrr0
   !out ubrr0l,temp 'mniej znacz�cy bajt UBRR USART0
   ldi temp,_ubrr1
   !out ubrr1l,temp 'mniej znacz�cy bajt UBRR USART1
   ldi temp,24      'w��czone odbiorniki i nadajniki USART�w
   !out ucsr0b,temp
   !out ucsr1b,temp
   ldi temp,6       'N8bit
   !out ucsr0C,temp
   !out ucsr1C,temp
   'ustawienia RS485
   Te = 0           'domy�lnie stan odbioru
   sbi ddrd,Te_pin  'wyj�cie TE silnopr�dowe
   'w��czenie przerwa�
   Enable Urxc
   Enable Urxc1
   Enable Utxc1
ret