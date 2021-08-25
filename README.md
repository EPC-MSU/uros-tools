# Системные инструменты для работы c уровнями ROM и ОS

Рабочая среда предоставляется docker-контейнером. 

# Структура инструментов

## UROS (уровень ОС)

- **initer**- создает рабочий ssd из .swu
- **snapshoter** - наоброт, снимает с ssd .swu

## ROM

- *flashrom* - зашивает прошивку .rom во flash платы 
	
	```bash
	sudo ./flashrom -p ft2232_spi:type=arm-usb-tiny,port=A,divisor=8 -w ./recovery-msbt2-20210811111832.rom
	```

