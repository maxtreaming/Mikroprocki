'komentarze
$regfile = "m644pdef.dat"
$crystal = 14745600

'sbi ddrc,0
'sbi PORTC,0
'Ddrc = 0
'Portc = 255

         '&h
'!out portc,r16
       'Portc = 1
 'Ddrc = 255
 Portc = 1
 LDI r17,1
          'lewo
         'Sbi portC,1

Do
     in r16,portc
   sbrs r17,0
      lsR r16

   sbrc r17,0
      lsL r16

    !out portc,r16

    Andi r16,&h81

    Sbis sreg,1
      mov r17,r16

   Waitms 200

Loop