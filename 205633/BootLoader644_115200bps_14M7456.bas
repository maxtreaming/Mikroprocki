'----------------------------------------------------------------
'                          (c) 1995-2009, MCS
'                        Bootloader.bas
'  This sample demonstrates how you can write your own bootloader
'  in BASCOM BASIC
'  VERSION 2 of the BOOTLOADER. The waiting for the NAK is stretched
'  further a bug was resolved for the M64/M128 that have a big page size
'-----------------------------------------------------------------
'This sample will be extended to support other chips with bootloader
'The loader is supported from the IDE

'zmodyfikowany
'dodano procedury zapisu pamiêci wywo³ywane z programu g³ównego
'procedury rozpoczynaj¹ siê od wektora Bls_writer, nad którym musi byæ kawa³ek
'niewykorzystanej pamiêci
'uzywany jest rejestr R22, który mo¿e przyj¹æ 3 wartoœci 1; 3; 5
'którym odpowiada -> zapis s³owa, czyszczenie, zapis strony

'program bootloadera zajmuje 2048B, a wektor wywo³ania jest 512B od koñca

'by Marcin Kowalczyk

'$crystal = 7372800
$crystal = 14745600
'$crystal = 3686400
$baud = 115200      '57600       'this loader uses serial com
'It is VERY IMPORTANT that the baud rate matches the one of the boot loader
'do not try to use buffered com as we can not use interrupts

'$regfile = "m8def.dat"
'$regfile = "m168def.dat"
'$regfile = "m16def.dat"
'$regfile = "m32def.dat"
'$regfile = "m88def.dat"
'$regfile = "m8515.dat"
'$regfile = "m128def.dat"
'$regfile = "m64def.dat"
'$regfile = "m324pdef.dat"
'$regfile = "m644def.dat"
$regfile = "m644Pdef.dat"
'$regfile = "m328pdef.dat"

Const Bls_writer =(_romsize -512) \ 2       'wektor wywo³ania procedur zapisu FLASH z programu g³ównego
$loader =(_romsize -2048) \ 2       '2048B od koñca pamiêci

#if(_romsize = 2 ^ 17) Or(_romsize = 2 ^ 16)
   Const Maxwordbit = 7       'zale¿y od pojemnoœci FLASH
#endif

#if(_romsize = 2 ^ 15) Or(_romsize = 2 ^ 14)
   Const Maxwordbit = 6
#endif

#if(_romsize = 2 ^ 13) Or(_romsize = 2 ^ 12)
   Const Maxwordbit = 5
#endif

Config Com1 = Dummy , Synchrone = 0 , Parity = None , Stopbits = 1 , Databits = 8 , Clockpol = 0


#if _chip = 24      ' Mega8515
    Osccal = &HB3   ' the internal osc needed a new value
#endif


Const Maxword =(2 ^ Maxwordbit) * 2       '128
Const Maxwordshift = Maxwordbit + 1
Const Cdebug = 0    ' leave this to 0

'#if Cdebug
'   Print Maxword
'   Print Maxwordshift
'#endif



'Dim the used variables
Dim Bstatus As Byte , Bretries As Byte , Bblock As Byte , Bblocklocal As Byte
Dim Bcsum1 As Byte , Bcsum2 As Byte , Buf(128) As Byte , Csum As Byte
Dim J As Byte , Spmcrval As Byte       ' self program command byte value

Dim Z As Long       'this is the Z pointer word
Dim Vl As Byte , Vh As Byte       ' these bytes are used for the data values
Dim Wrd As Word , Page As Word       'these vars contain the page and word address
Dim Bkind As Byte , Bstarted As Byte
'Mega 88 : 32 words, 128 pages



Disable Interrupts  'we do not use ints


'Waitms 100                                                  'wait 100 msec sec
'We start with receiving a file. The PC must send this binary file

'some constants used in serial com
Const Nak = &H15
Const Ack = &H06
Const Can = &H18

'we use some leds as indication in this sample , you might want to remove it
'Config Pina.4 = Output
'Porta.4 = 1         'the stk200 has inverted logic for the leds
'Ledreg Alias Porta.4
'sbi ddra,4
Led_port Alias Portd
Led_ddr Alias Ddrd
Led_pin Alias 7     'wyprowadzenie portu dla kontrolki LED


Ledreg Alias Led_port.led_pin       'gdy katoda LED -> GND
'sbi led_ddr,led_pin 'gdy pr¹d LED ma byæ zwiêkszony, tylko gdy katoda LED->GND
'Ledreg Alias Led_ddr.led_pin       'gdy katoda LED -> GND
Ledreg = 1


$timeout = 200000   'we use a timeout
'When you get LOADER errors during the upload, increase the timeout value
'for example at 16 Mhz, use 200000

Bretries = 5        'we try 5 times
Testfor123:
Bstatus = Waitkey() 'wait for the loader to send a byte

Print Chr(bstatus);

If Bstatus = 123 Then       'did we received value 123 ?
   Bkind = 0        'normal flash loader
   Goto Loader
Elseif Bstatus = 124 Then       ' EEPROM
   Bkind = 1        ' EEPROM loader
   Goto Loader
Elseif Bstatus <> 0 Then
   Decr Bretries
   If Bretries <> 0 Then Goto Testfor123       'we test again
End If

For J = 1 To 10     'this is a simple indication that we start the normal reset vector
   Toggle Ledreg : Waitms 100
Next


'Goto Resetuj        'goto the normal reset vector at address 0
Resetuj:
cbi led_ddr,led_pin 'posprz¹tanie po sobie
cbi led_port,led_pin
Goto _reset         'reset chip



'this is the loader routine. It is a Xmodem-checksum reception routine
Loader:
'  #if Cdebug
'      Print "Clear buffer"
'  #endif
  Do
     Bstatus = Waitkey()
  Loop Until Bstatus = 0


  For J = 1 To 3    'this is a simple indication that we start the normal reset vector
     Toggle Ledreg : Waitms 50
  Next

  If Bkind = 0 Then
     Spmcrval = 3 : Gosub Do_spm       ' erase  the first page
     Spmcrval = 17 : Gosub Do_spm       ' re-enable page
  End If


Bretries = 10       'number of retries

Do
  Bstarted = 0      ' we were not started yet
  Csum = 0          'checksum is 0 when we start
  Print Chr(nak);   ' firt time send a nack
  Do

    Bstatus = Waitkey()       'wait for statuse byte

    Select Case Bstatus
       Case 1:      ' start of heading, PC is ready to send
            Incr Bblocklocal       'increase local block count
            Csum = 1       'checksum is 1
            Bblock = Waitkey() : Csum = Csum + Bblock       'get block
            Bcsum1 = Waitkey() : Csum = Csum + Bcsum1       'get checksum first byte
            For J = 1 To 128       'get 128 bytes
              Buf(j) = Waitkey() : Csum = Csum + Buf(j)
            Next
            Bcsum2 = Waitkey()       'get second checksum byte
            If Bblocklocal = Bblock Then       'are the blocks the same?
               If Bcsum2 = Csum Then       'is the checksum the same?
                  Gosub Writepage       'yes go write the page
                  Print Chr(ack);       'acknowledge
               Else 'no match so send nak
                  Print Chr(nak);
               End If
            Else
               Print Chr(nak);       'blocks do not match
            End If
       Case 4:      ' end of transmission , file is transmitted
             If Wrd > 0 And Bkind = 0 Then       'if there was something left in the page
                 Wrd = 0       'Z pointer needs wrd to be 0
                 Spmcrval = 5 : Gosub Do_spm       'write page
                 Spmcrval = 17 : Gosub Do_spm       ' re-enable page
             End If
             Print Chr(ack);       ' send ack and ready

             'Porta.3 = 0       ' simple indication that we are finished and ok
             Waitms 20
             Goto Resetuj       ' start new program
       Case &H18:   ' PC aborts transmission
             Goto Resetuj       ' ready
       Case 123 : Exit Do       'was probably still in the buffer
       Case 124 : Exit Do
       Case Else
          Exit Do   ' no valid data
    End Select
  Loop
  If Bretries > 0 Then       'attempte left?
     Waitms 1000
     Decr Bretries  'decrease attempts
  Else
     Goto Resetuj   'reset chip
  End If
Loop



'write one or more pages
Writepage:
 If Bkind = 0 Then
   For J = 1 To 128 Step 2       'we write 2 bytes into a page
      Vl = Buf(j) : Vh = Buf(j + 1)       'get Low and High bytes
      lds r0, {vl}  'store them into r0 and r1 registers
      lds r1, {vh}
      Spmcrval = 1 : Gosub Do_spm       'write value into page at word address
      Wrd = Wrd + 2 ' word address increases with 2 because LS bit of Z is not used
      If Wrd = Maxword Then       ' page is full
          Wrd = 0   'Z pointer needs wrd to be 0
          Spmcrval = 5 : Gosub Do_spm       'write page
          Spmcrval = 17 : Gosub Do_spm       ' re-enable page

          Page = Page + 1       'next page
          Spmcrval = 3 : Gosub Do_spm       ' erase  next page
          Spmcrval = 17 : Gosub Do_spm       ' re-enable page
      End If
   Next

 Else               'eeprom
     For J = 1 To 128
       Writeeeprom Buf(j) , Wrd
       Wrd = Wrd + 1
     Next
 End If
 Toggle Ledreg : Waitms 10 : Toggle Ledreg       'indication that we write
Return


Do_spm:
   lds zl,{page}
   lds zh,{page+1}
   ldi r16,Maxwordshift
   _rol1:
   clc
   rol zl
   rol zh
   dec r16
   brne _ROL1
   lds r16,{wrd}
   clr r17
   add zl, r16
   adc zh, r17

   #if _romsize > 65536
      lds r22,{Z+2}
      sts rampz,r22 ' we need to set rampz also for the M128
  #endif

  lds r22, {Spmcrval}

_do_spm:            'procedura wykonania rozkazu SPM
   push r22         'w u¿yciu poza bootloaderem jest tylko R22
   _wait_spm:
   in r22,SPMCsR
   sbrc r22,0       'SPMEN
   rjmp _wait_spm
   pop r22

   _wait_ee:
   sbic EECR,1      'EEWE lub EEPE
   rjmp _wait_ee

   !Out Spmcsr,r22
   spm
   Nop
   nop
ret


!.org Bls_writer    '$7f00 'Wektor odwo³ania z programu glównego
'rozpozniane rozkazu przy pomocy rejestry R22
cpi r22, 1          'czy zapis s³owa
breq _write_word
cpi r22, 5          'czy zapis strony
breq _write_page
cpi r22, 3          'czy czyszczenie strony
breq _erase_page
'niezgodne rozkazy
ret

_write_word:        'zapis s³owa
   ldi r22, 1
   rcall _do_spm
   ret
_write_page:        'zapis strony
   ldi r22, 5
   rcall _do_spm
   ldi r22, 17
   rcall _do_spm
   ret
_erase_page:        'czyszeczenie strony
   ldi r22, 3
   rcall _do_spm
   ldi r22, 17
   rcall _do_spm
   ret