 /* Archivo: Lab02.s
 * Dispositivo: PIC16F887
 * Autor: Kevin Alarc�n
 * Compilador: pic-as (v2.30), MPLABX V6.05
 * 
 * 
 * Programa: Presionar RB0 o RB1 para incrementar o decrementar usando interrupciones, interrupciones con TMR0
 * Hardware: Push en RB0 y RB1, leds en puerto A y puerto D
 * 
 * Creado: 12 de feb, 2023
 * �ltima modificaci�n: 16 de feb, 2023
 */
    
    PROCESSOR 16F887
    #include <xc.inc>
    
    ;configuraci�n wor 1
    CONFIG FOSC=INTRC_NOCLKOUT //Oscilador Interno sin salidas
    CONFIG WDTE=OFF //WDT disabled (reinicio repetitivo del pic)
    CONFIG PWRTE=OFF //PWRT enabled (espera de 72ms al iniciar)
    CONFIG MCLRE=OFF //El pin de MCLR se utiliza como I/0
    CONFIG CP =OFF //Sin protecci�n de c�digo
    CONFIG CPD=OFF //Sin protecci�n de datos
    
    CONFIG BOREN=OFF //Sin reinicio c�ando el voltaje de alimentaci�n baja de 4V
    CONFIG IESO=OFF //Reinicio sin cambio de reloj de interno a externo
    CONFIG FCMEN=OFF //Cambio de reloj externo a interno en caso de fallo
    CONFIG LVP=OFF //Programaci�n en bajo voltaje permitida
    
    ;configuraci�n word 2
    CONFIG WRT=OFF //Protecci�n de autoescritura por el programa desactivada
    CONFIG BOR4V=BOR40V //Programaci�n abajo de 4V, (BOR21V=2 . 1V)
    
    UP EQU 6
    DOWN EQU 7
    ;--------------------------MACROS------------------------------
    restart_TMR0 macro
	banksel TMR0 ;Nos ubicamos en el banco donde est� TMR0
	movlw 246 ;Cargamos al acumulador el valor que se le pondr� al TMR0
	movwf TMR0 ;Cargamos el valor N calculado para un desborde de 1000mS
	bcf T0IF ;Colocamos en cero la bandera del TMR0
    endm
    
    PSECT udata_bank0; common memory
	cont: DS 3 ;3 bytes
	cont1: DS 3 ;3 bytes
	cont2: DS 3 ;3 bytes
 
    PSECT udata_shr
 	W_TEMP: DS 1 ;1 byte
    	STATUS_TEMP: DS 1 ;1 byte
    
    ;--------------------------vector reset------------------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h ;posici�n 0000h para el reset
    resetVec:
	PAGESEL main
	goto main
    ;--------------------------Vector interrupci�n-------------------
    PSECT intVECT, class=CODE, abs, delta=2
    ORG 0004h
    push: 
	movwf W_TEMP ;Movemos lo que hay en el acumulador al registro
	swapf STATUS, W ;Intercambiamos los bits del registro STATUS y lo metemos al acumulador
	movwf STATUS_TEMP ;Movemos lo que hay en el acumulador al registro
    isr:
	btfsc RBIF ;Verificamos si alguno de los puertos de B cambiaron de estado
	call int_iocb ;Si, s� cambi� de estado, llamamos a nuestra funci�n 
	btfsc T0IF ;Verificamos si la bandera del TMR0 est� encendida
	call int_t0 ;Si, S� est� encendida la bandera del TMR0 llamamos a nuestra funci�n
    pop:
	swapf STATUS_TEMP, W ;Intercambiamos los bits del registro STATUS y lo metemos al acumulador
	movwf STATUS ;Movemos lo que hay en el acumulador al registro
	swapf W_TEMP, F ;Intercambiamos los bits del registro y lo metemos al mismo registro
	swapf W_TEMP, W ;Intercambiamos los bits del registro y lo metemos al acumulador
	retfie ;Carga el PC con el valor que se encuentra en la parte superior de la pila, asegurando as� la vuelta de la interrupci�n
    
    PSECT code, delta=2, abs
    ORG 100h  ;posici�n para el c�digo
    table:
	clrf PCLATH
	bsf PCLATH, 0 ;PCLATH en 01
	andlw 0X0F ;
	addwf PCL ;PC = PCLATH + PCL | Sumamos W al PCL para seleccionar una dato de la tabla
	retlw 00111111B ;0
	retlw 00000110B;1
	retlw 01011011B ;2
	retlw 01001111B ;3
	retlw 01100110B ;4
	retlw 01101101B ;5
	retlw 01111101B ;6
	retlw 00000111B ;7
	retlw 01111111B ;8
	retlw 01101111B ;9
	retlw 01110111B ;A
	retlw 01111100B ;B
	retlw 00111001B ;C
	retlw 01011110B ;D
	retlw 01111001B ;E
	retlw 01110001B ;F
	
    ;----------------------configuraci�n----------------
    main:
	call config_io ;Llamamos a nuestra subrutina config_io para configurar los pines antes de ejecutar el c�digo
	call config_reloj ;Llamamos a nuestra subrutina config_reloj para configurar la frecuencia del reloj antes de ejecutar el c�digo
	call config_TMR0 ;Llamamos a nuestra funci�n para configurar el TMR0
	call config_iocb ;Llamamos a nuestra funci�n que habilita las interrupciones en el puerto B
	call config_int_enable ;Llamamos a nuestra funci�n que habilita las interrupciones en general
	banksel PORTD ;Se busca el banco en el que est� PORTA
	
    
    ;-----------------------loop principal---------------
    loop:
	goto loop ; loop forever
	
    ;----------------------Sub rutinas------------------
    config_io: ;Funci�n para configurar los puertos de entrada/salida
	bsf STATUS, 5 ;banco 11
	bsf STATUS, 6 ;Nos dirigimos al banco 3 porque ah� se encuentran las instrucciones ANSEL y ANSELH
	clrf ANSEL ;pines digitales
	clrf ANSELH
    
	bsf STATUS, 5 ;banco 01
	bcf STATUS, 6 ;Nos dirigimos al banco 1 porque ah� se encuentran lo configuraci�n de los puertos
	
	;Configuramos los bits que usaremos como entradas del PORTB
	bsf TRISB, UP
	bsf TRISB, DOWN
	
	;Configuramos las salidas
	movlw 0b11110000
	movwf TRISA
	clrf TRISD
	clrf TRISC
	clrf TRISE
	
	bcf OPTION_REG, 7 ;Habilitamos Pull ups
	bsf WPUB, UP
	bsf WPUB, DOWN
	
	;Nos dirigimos al banco 0 en donde se encuentran los puertos y procedemos a limpiar cada puerto despu�s de cada reinicio
	bcf STATUS, 5 ;banco00
	bcf STATUS, 6 
	clrf cont2
	clrf cont1
	clrf cont
	clrf PORTA
	clrf PORTD
	clrf PORTC
	clrf PORTE
	return ;Retorna a donde fue llamada esta funci�n
	
    config_reloj:
	banksel OSCCON ;Nos posicionamos en el banco en donde est� el registro OSCCON para configurar el reloj
	;Esta configuraci�n permitir� poner el oscilador a 1 MHz
	bsf IRCF2 ;OSCCON 6 configuramos el bit 2 del IRCF como 1
	bcf IRCF1 ;OSCCON 5 configuramos el bit 1 del IRCF como 0
	bcf IRCF0 ;OSCCON 4 configuramos el bit 0 del IRCF como 0
	bsf SCS ;reloj interno 
	return ;Retorna a donde fue llamada esta funci�n
	
    config_TMR0:
	banksel OPTION_REG
	bcf OPTION_REG, 5 ;Seleccionamos TMR0 como temporizador
	bcf OPTION_REG, 3 ;Asignamos PRESCALER a TMR0
	bsf OPTION_REG, 2 
	bsf OPTION_REG, 1
	bsf OPTION_REG, 0 ;Prescaler de 256 con configuraci�n 111
	restart_TMR0 ;Reiniciamos el TMR0 con nuestra funci�n
	return ;Retorna a donde fue llamada esta funci�n

    config_int_enable:
	bsf T0IE ;INTCON ;Habilitamos la interrupci�n del TMR0
	bcf T0IF ;INTCON ;Ponemos en cero la bandera del TMR0
	bsf GIE ;INTCON ;Habilitamos las interrupciones en general
	bsf RBIE ;INTCON ;Habilitamos la interrupci�n del cambio en el puerto B
	bcf RBIF ;INTCON ;Ponemos en cero el cambio de estado para que se reinicie la verificaci�n
	return

    config_iocb:
	banksel TRISB ;Nos ubicamos en el banco del TRISB
	bsf IOCB, UP ;Habilitamos la interrupci�n al cambiar el estado de RB6
	bsf IOCB, DOWN ;Habilitamos la interrupci�n al cambiar el estado de RB7
	
	banksel PORTB 
	movf PORTB, W ;al leer termina la condici�n de mismatch
	bcf RBIF ;Ponemos en cero el cambio de estado para que se reinicie la verificaci�n
	return ;Retornamos de nuestra funci�n
	
    int_t0:
	restart_TMR0 ;Reiniciamos el TMR0
	    incf cont ;Incrementamos la variable de nuestro contador del TMR0
	    movf cont, W ;Movemos nuestra variable al acumulador
	    sublw 100 ;A 100 le restamos lo que hay en el acumulador y lo gradamos en el acumulador
	    btfss ZERO ;STATUS, 2 ;verificamos si la bandera de Zero se activa
	    goto return_t0 ;Sino se activa retornamos de la funci�n porque queremos que se ejecute solo cuando hayan pasado 1000ms (1s)
	    clrf cont ;1 segundo Si se activa, limpiaremos nuestro contador del TMR0
	    
	    incf cont1 ;Incrementaremos la variable del contador del unidades
	    movf cont1, W ;Movemos al acumulador nuestra variable
	    sublw 10 ;A 10 le restamos lo que hay en el acumulador y lo guardamos en el acumulador
	    btfss ZERO ;STATUS, 2 ;verificamos si la bandera de Zero se activa
	    goto $+3 ; Sino se activa hacemos un salto 3 lineas adelante
	    clrf cont1 ;1 segundo Si se activa limpiamos la variable de nuestro contador de unidades
	    incf cont2 ;Incrementamos nuestro variable del contador de decenas

	    movf cont1, W ;Movemos al acumulador nuestra variable cont1 ya sea que su valor sea 0 u otro
	    call table ;Llamamos a nuestra tabla y retornamos un valor
	    movwf PORTD ;Dicho valor lo presentamos en el puerto D
	    
	    movf cont2, W ;Movemos al acumulador nuestra variable
	    sublw 6 ;A 6 le restamos lo que hay en el acumulador y lo guardamos en el acumulador
	    btfss ZERO ;STATUS, 2 ;verificamos si la bandera de Zero se activa
	    goto $+2 ;Sino est� activada hacemos un salto 2 lineas adelante
	    clrf cont2 ;Si se activa limpiamos nuestra variable del contador de decenas
	    movf cont2, W ;Movemos nuestra variable al acumulador
	    call table ;Llamamos a nuestra tabla y retornamos un valor
	    movwf PORTC ;Dicho valor lo presentamos en el puerto D
	    
	return_t0:
	    return ;Retornamos de nuestra funci�n
    
    int_iocb:
	banksel PORTB ;Nos ubicamos en el banco del purto B
	btfss PORTB, UP ;Al estar en pullup normalmente el boton est� en 1, as� que verificamos si est� en 1 (desoprimido) o en 0 (oprimido
			;el bit 6 del puerto B
	incf PORTE ;Si est� en 0 (oprimido) incrementamos el puerto E
	btfss PORTB, DOWN  ;Al estar en pullup normalmente el boton est� en 1, as� que verificamos si est� en 1 (desoprimido) o en 0 (oprimido
			   ;el bit 7 del puerto B
	decf PORTE ;Si est� en 0 (oprimido) decrementamos el puerto E
	bcf RBIF ;Ponemos en cero el cambio de estado para que se reinicie la verificaci�n
	return ;Retornamos de nuestra funci�n
    END