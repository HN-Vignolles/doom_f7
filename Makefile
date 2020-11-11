include makedefs

USR_OBJS = build/main.o build/stm32f7xx_hal_msp.o build/stm32f7xx_it.o build/syscalls.o build/sysmem.o build/usbh_conf.o
USR_SRCS = $(patsubst %.o,%.c,$(subst build,src,$(USR_OBJS)))

$(USR_OBJS): $(USR_SRCS)
	$(CC) src$(subst build,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"

# startup
build/$(STARTUP).o: src/$(STARTUP).S
	$(CC) -mcpu=cortex-m7 -g3 -c -x assembler-with-cpp --specs=nano.specs -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb -o "$@" "$<"


################
#   FreeRTOS   #
################
FRTOS_OBJS = \
	build/Libraries/FreeRTOSv/Source/portable/MemMang/heap_4.o \
	build/Libraries/FreeRTOSv/Source/portable/GCC/ARM_CM7/r0p1/port.o \
	build/Libraries/FreeRTOSv/Source/CMSIS_RTOS/cmsis_os.o \
	build/Libraries/FreeRTOSv/Source/croutine.o \
	build/Libraries/FreeRTOSv/Source/list.o \
	build/Libraries/FreeRTOSv/Source/queue.o \
	build/Libraries/FreeRTOSv/Source/tasks.o \
	build/Libraries/FreeRTOSv/Source/timers.o
FRTOS_SRCS  = $(patsubst %.o,%.c,$(subst build/,,$(FRTOS_OBJS)))
$(FRTOS_OBJS): $(FRTOS_SRCS)
	@mkdir -p build/Libraries/FreeRTOSv/Source/portable/MemMang
	@mkdir -p build/Libraries/FreeRTOSv/Source/portable/GCC/ARM_CM7/r0p1
	@mkdir -p build/Libraries/FreeRTOSv/Source/CMSIS_RTOS
	$(CC) $(subst build/,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


###############
#    FatFs    #
###############
FATF_OBJS = \
	build/Libraries/FatFsv/src/option/syscall.o \
	build/Libraries/FatFsv/src/option/unicode.o \
	build/Libraries/FatFsv/src/sd_diskio_dma_rtos.o \
	build/Libraries/FatFsv/src/diskio.o \
	build/Libraries/FatFsv/src/ff.o \
	build/Libraries/FatFsv/src/ff_gen_drv.o
FATF_SRCS  = $(patsubst %.o,%.c,$(subst build/,,$(FRTOS_OBJS)))
$(FATF_OBJS): $(FATF_SRCS)
	@mkdir -p build/Libraries/FatFsv/src/option
	$(CC) $(subst build/,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


###############
#     HAL     #
###############
HAL_PATH = $(CUBE)/Drivers/STM32F7xx_HAL_Driver/Src
HAL_OBJS = \
	build/stm32f7xx_hal.o \
	build/stm32f7xx_hal_cortex.o \
	build/stm32f7xx_hal_dma.o \
	build/stm32f7xx_hal_dma_ex.o \
	build/stm32f7xx_hal_gpio.o \
	build/stm32f7xx_hal_i2c.o \
	build/stm32f7xx_hal_i2c_ex.o \
	build/stm32f7xx_hal_pwr.o \
	build/stm32f7xx_hal_pwr_ex.o \
	build/stm32f7xx_hal_rcc.o \
	build/stm32f7xx_hal_rcc_ex.o \
	build/stm32f7xx_hal_sd.o \
	build/stm32f7xx_hal_tim.o \
	build/stm32f7xx_hal_tim_ex.o \
	build/stm32f7xx_hal_sdram.o \
	build/stm32f7xx_hal_uart.o \
	build/stm32f7xx_hal_ltdc.o \
	build/stm32f7xx_hal_hcd.o \
	build/stm32f7xx_ll_fmc.o \
	build/stm32f7xx_ll_usb.o \
	build/stm32f7xx_ll_sdmmc.o
HAL_SRCS = $(patsubst %.o,%.c,$(subst build,$(HAL_PATH),$(HAL_OBJS)))
$(HAL_OBJS): $(HAL_SRCS)
	$(CC) $(HAL_PATH)$(subst build,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


###############
#    CMSIS    #
###############
CMSIS_SRCS = src/system_stm32f7xx.c 
CMSIS_OBJS = build/system_stm32f7xx.o 
$(CMSIS_OBJS): $(CMSIS_SRCS)
	$(CC) $< -c $(CFLAGS) $(IPATH) -o "$@"


###############
#     BSP     #
###############
BSP_PATH = $(CUBE)/Drivers/BSP/STM32746G-Discovery
BSP_SRCS = \
	$(BSP_PATH)/stm32746g_discovery.c \
	$(BSP_PATH)/stm32746g_discovery_sd.c \
	$(BSP_PATH)/stm32746g_discovery_audio.c \
	$(BSP_PATH)/stm32746g_discovery_lcd.c \
	$(BSP_PATH)/stm32746g_discovery_sdram.c
BSP_OBJS = $(patsubst %.c,%.o,$(subst $(BSP_PATH)/,build/Libraries/$(DEVICE)/,$(BSP_SRCS)))
$(BSP_OBJS): $(BSP_SRCS)
	@mkdir -p build/Libraries/$(DEVICE)
	@echo '>>>>>> $(BSP_OBJS)'
	$(CC) $(subst build/Libraries/$(DEVICE)/,$(BSP_PATH)/,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


######################
#   STM32_USB_Host   #
######################
USBH_OBJS = \
	build/Libraries/STM32_USB_Host_Library/Class/HID/Src/usbh_hid.o \
	build/Libraries/STM32_USB_Host_Library/Class/HID/Src/usbh_hid_keybd.o \
	build/Libraries/STM32_USB_Host_Library/Class/HID/Src/usbh_hid_mouse.o \
	build/Libraries/STM32_USB_Host_Library/Class/HID/Src/usbh_hid_parser.o \
	build/Libraries/STM32_USB_Host_Library/Class/HUB/Src/usbh_hub.o \
	build/Libraries/STM32_USB_Host_Library/Core/Src/usbh_core.o \
	build/Libraries/STM32_USB_Host_Library/Core/Src/usbh_ctlreq.o \
	build/Libraries/STM32_USB_Host_Library/Core/Src/usbh_ioreq.o \
	build/Libraries/STM32_USB_Host_Library/Core/Src/usbh_pipes.o
USBH_SRCS = $(patsubst %.o,%.c,$(subst build/,,$(USBH_OBJS)))
$(USBH_OBJS): $(USBH_SRCS)
	@mkdir -p build/Libraries/STM32_USB_Host_Library/Class/HID/Src
	@mkdir -p build/Libraries/STM32_USB_Host_Library/Class/HUB/Src
	@mkdir -p build/Libraries/STM32_USB_Host_Library/Core/Src
	$(CC) $(subst build/,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


OBJS = $(FRTOS_OBJS) $(FATF_OBJS) $(USBH_OBJS) $(HAL_OBJS) $(CMSIS_OBJS) $(BSP_OBJS) \
	 $(USR_OBJS) build/$(STARTUP).o 


all: $(GAME).elf $(GAME).bin


$(GAME).elf: $(OBJS) STM32F746NGHx_FLASH.ld
	@mkdir -p build
	$(CC) -o "$(GAME).elf" $(OBJS) -mcpu=cortex-m7 -T"STM32F746NGHx_FLASH.ld" --specs=nosys.specs -Wl,-Map="$(GAME).map" -Wl,--gc-sections -static --specs=nano.specs -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb -Wl,--start-group -lc -lm -Wl,--end-group
	@echo 'Finished building target: $@'
	@echo ' '


$(GAME).bin: $(GAME).elf
	$(OBJC) -O binary $< $@


flash: all
	/usr/bin/openocd \
	-f /usr/share/openocd/scripts/interface/stlink-v2-1.cfg \
	-f /usr/share/openocd/scripts/target/stm32f7x.cfg \
	-c "init" \
	-c "reset init" \
	-c "flash probe 0" \
	-c "flash info 0" \
	-c "flash write_image erase $(GAME).bin 0x08000000" \
	-c "reset run" -c shutdown


clean:
	@rm build/*


.PHONY: flash clean
