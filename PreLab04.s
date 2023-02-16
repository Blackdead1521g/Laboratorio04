 /* Archivo: Lab02.s
 * Dispositivo: PIC16F887
 * Autor: Kevin Alarcón
 * Compilador: pic-as (v2.30), MPLABX V6.05
 * 
 * 
 * Programa: Presionar RB0 o RB1 para incrementar o decrementar usando interrupciones, interrupciones con TMR0
 * Hardware: Push en RB0 y RB1, leds en puerto A y puerto D
 * 
 * Creado: 12 de feb, 2023
 * Última modificación: 12 de feb, 2023
 */
    
    PROCESSOR 16F887
    #include <xc.inc>
    
    ;configuración wor 1
    CONFIG FOSC=INTRC_NOCLKOUT //Oscilador Interno sin salidas
    CONFIG WDTE=OFF //WDT disabled (reinicio repetitivo del pic)
    CONFIG PWRTE=OFF //PWRT enabled (espera de 72ms al iniciar)
    CONFIG MCLRE=OFF //El pin de MCLR se utiliza como I/0
    CONFIG CP =OFF //Sin protección de código
    CONFIG CPD=OFF //Sin protección de datos
    
    CONFIG BOREN=OFF //Sin reinicio cúando el voltaje de alimentación baja de 4V
    CONFIG IESO=OFF //Reinicio sin cambio de reloj de interno a externo
    CONFIG FCMEN=OFF //Cambio de reloj externo a interno en caso de fallo
    CONFIG LVP=OFF //Programación en bajo voltaje permitida
    
    ;configuración word 2
    CONFIG WRT=OFF //Protección de autoescritura por el programa desactivada
    CONFIG BOR4V=BOR40V //Programación abajo de 4V, (BOR21V=2 . 1V)
    
    UP EQU 6
    DOWN EQU 7
    ;--------------------------MACROS------------------------------
    restart_TMR0 macro
	banksel TMR0
	movlw 246
	movwf TMR0
	bcf T0IF
    endm
    
    PSECT udata_bank0; common memory
	cont: DS 3 ;3 bytes
	cont_small: DS 1 ;1 byte
 
    PSECT udata_shr
 	W_TEMP: DS 1 ;1 byte
    	STATUS_TEMP: DS 1 ;1 byte
    
    ;--------------------------vector reset------------------------
    PSECT resVect, class=CODE, abs, delta=2
    ORG 00h ;posición 0000h para el reset
    resetVec:
	PAGESEL main
	goto main
    ;--------------------------Vector interrupción-------------------
    PSECT intVECT, class=CODE, abs, delta=2
    ORG 0004h
    push: 
	movwf W_TEMP
	swapf STATUS, W
	movwf STATUS_TEMP
    isr:
	btfsc RBIF ;Verificamos si alguno de los puertos del 4 al 7 cambiaron de estado
	call int_iocb ;Si, sí cambió de estado, llamamos a nuestra función 
	btfsc T0IF ;Verificamos si la bandera del TMR0 está encendida
	call int_t0 ;Si, Sí está encendida la bandera del TMR0 llamamos a nuestra función
    pop:
	swapf STATUS_TEMP, W
	movwf STATUS
	swapf W_TEMP, F
	swapf W_TEMP, W
	retfie
    
    PSECT code, delta=2, abs
    ORG 100h  ;posición para el código
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
    ;----------------------configuración----------------
    main:
	call config_io ;Llamamos a nuestra subrutina config_io para configurar los pines antes de ejecutar el código
	call config_reloj ;Llamamos a nuestra subrutina config_reloj para configurar la frecuencia del reloj antes de ejecutar el código
	call config_TMR0 ;Llamamos a nuestra función para configurar el TMR0
	call config_iocb
	call config_int_enable
	banksel PORTD ;Se busca el banco en el que está PORTA
	
    
    ;-----------------------loop principal---------------
    loop:
	goto loop ; loop forever
	
    ;----------------------Sub rutinas------------------
    config_io: ;Función para configurar los puertos de entrada/salida
	bsf STATUS, 5 ;banco 11
	bsf STATUS, 6 ;Nos dirigimos al banco 3 porque ahí se encuentran las instrucciones ANSEL y ANSELH
	clrf ANSEL ;pines digitales
	clrf ANSELH
    
	bsf STATUS, 5 ;banco 01
	bcf STATUS, 6 ;Nos dirigimos al banco 1 porque ahí se encuentran lo configuración de los puertos
	
	;Configuramos los bits que usaremos como entradas del PORTB
	bsf TRISB, UP
	bsf TRISB, DOWN
	movlw 0b11110000
	movwf TRISA
	movlw 0b11110000
	movwf TRISD
	clrf TRISC
	
	bcf OPTION_REG, 7 ;Habilitams Pull ups
	bsf WPUB, UP
	bsf WPUB, DOWN
	
	;Nos dirigimos al banco 0 en donde se encuentran los puertos y procedemos a limpiar cada puerto después de cada reinicio
	bcf STATUS, 5 ;banco00
	bcf STATUS, 6 
	clrf PORTA
	clrf PORTD
	clrf PORTC
	return ;Retorna a donde fue llamada esta función
	
    config_reloj:
	banksel OSCCON ;Nos posicionamos en el banco en donde esté el registro OSCCON para configurar el reloj
	;Esta configuración permitirá poner el oscilador a 1 MHz
	bsf IRCF2 ;OSCCON 6 configuramos el bit 2 del IRCF como 1
	bcf IRCF1 ;OSCCON 5 configuramos el bit 1 del IRCF como 0
	bcf IRCF0 ;OSCCON 4 configuramos el bit 0 del IRCF como 0
	bsf SCS ;reloj interno 
	return ;Retorna a donde fue llamada esta función
	
    config_TMR0:
	banksel OPTION_REG
	bcf OPTION_REG, 5 ;Seleccionamos TMR0 como temporizador
	bcf OPTION_REG, 3 ;Asignamos PRESCALER a TMR0
	bsf OPTION_REG, 2 
	bsf OPTION_REG, 1
	bsf OPTION_REG, 0 ;Prescaler de 256 con configuración 111
	restart_TMR0
	return ;Retorna a donde fue llamada esta función

    config_int_enable:
	bsf T0IE ;INTCON
	bcf T0IF ;INTCON
	bsf GIE ;INTCON
	bsf RBIE ;INTCON
	bcf RBIF ;INTCON
	return

    config_iocb:
	banksel TRISB
	bsf IOCB, UP
	bsf IOCB, DOWN
	
	banksel PORTB 
	movf PORTB, W ;al leer termina la condición de mismatch
	bcf RBIF
	return
	
    int_t0:
	restart_TMR0 ;
	    incf cont
	    movf cont, W
	    sublw 100
	    btfss ZERO ;STATUS, 2
	    goto return_t0 
	    clrf cont ;1 segundo
	    incf PORTA
	    /*incf cont
	    movf cont, W
	    btfss STATUS, 2
	    goto return_t0
	    clrf cont
	    incf cont
	    movf cont, W
	    call table
	    movwf PORTC
	    sublw 00111111B 
	    btfss STATUS, 2
	    goto return_t0
	    incf cont
	    movf cont, W
	    call table
	    movwf PORTA*/
	return_t0:
	    return
    
    int_iocb:
	banksel PORTB
	call delay_small
	btfss PORTB, UP
	incf PORTD
	call delay_small
	btfss PORTB, DOWN
	decf PORTD
	bcf RBIF
	return
	
    delay_small: ;Esta función solo nos otorga tiempo
	movlw 163 ; valor inicial del contador en el registro W
	movwf cont_small ;Movemos lo que hay en W al registro cont_small
	decfsz cont_small, 1 ;decrementar el contador
	goto $-1 ;ejecutar línea anterior
	return ;Retorna a donde fue llamada esta función
    END