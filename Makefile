GCCP =/opt/st/stm32cubeide_1.4.0/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.7-2018-q2-update.linux64_1.4.0.202007081208/tools
GCCR = $(GCCP)/bin
CUBE = $(HOME)/STM32Cube/Repository/STM32Cube_FW_F7_V1.16.0
ROOT = $(HOME)/github/doom_f7
PREFIX = arm-none-eabi-

CC = $(GCCR)/$(PREFIX)gcc
OBJC = $(GCCR)/$(PREFIX)objcopy 
LD = $(GCCR)/$(PREFIX)ld
AR = $(GCCR)/$(PREFIX)ar
SIZE = $(GCCR)/$(PREFIX)size
READELF = $(GCCR)/$(PREFIX)readelf
OBJDUMP = $(GCCR)/$(PREFIX)objdump


GAME = doom
DEVICE = stm32f746-disco


CFLAGS = -std=gnu11 -g3 -Os -ffunction-sections -Wall -fstack-usage -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb
CFLAGS += -DUSE_USB_HS -DUSE_HAL_DRIVER -DDATA_IN_ExtSDRAM
#CFLAGS += -DUSE_FULL_ASSERT
CFLAGS += --specs=nano.specs

FRTOS = FreeRTOSv
FATF = FatFsv

IPATH = \
	-I$(GCCP)/arm-none-eabi/include \
	-I$(GCCP)/lib/gcc/arm-none-eabi/7.3.1/include \
	-I$(GCCP)/lib/gcc/arm-none-eabi/7.3.1/include-fixed \
	-I$(ROOT)/Drivers/BSP/Components/rk043fn48h \
	-I$(ROOT)/Drivers/BSP/Components/wm8994 \
	-I$(CUBE)/Drivers/BSP/Components/Common \
	-I$(CUBE)/Drivers/CMSIS/Device/ST/STM32F7xx/Include \
	-I$(CUBE)/Drivers/CMSIS/Include \
	-I$(CUBE)/Drivers/STM32F7xx_HAL_Driver/Inc \
	-I$(CUBE)/Utilities/Log \
	-I$(CUBE)/Utilities/CPU \
	-I$(ROOT)/Libraries/$(FATF)/src \
	-I$(ROOT)/Libraries/$(FATF)/src/drivers \
	-I$(ROOT)/Libraries/$(FRTOS)/Source/include \
	-I$(ROOT)/Libraries/$(FRTOS)/Source/portable/GCC/ARM_CM7/r0p1 \
	-I$(ROOT)/Libraries/$(FRTOS)/Source/CMSIS_RTOS \
	-I$(ROOT)/Libraries/STM32_USB_Host_Library/Core/Inc \
	-I$(ROOT)/Libraries/STM32_USB_Host_Library/Class/HID/Inc \
	-I$(ROOT)/Libraries/STM32_USB_Host_Library/Class/HUB/Inc \
	-I$(ROOT)/Libraries \
	-I$(ROOT)/inc \
	-I$(ROOT)/App/chocdoom \
	-I$(ROOT)/App/chocdoom/doom \
	-I$(ROOT)/App/chocdoom/heretic \
	-I$(ROOT)/App/chocdoom/hexen
IPATH += -I$(CUBE)/Utilities/Fonts

ifeq ($(strip $(DEVICE)),stm32f746-disco)
CFLAGS += -mcpu=cortex-m7 -DSTM32F756xx -DUSE_STM32746G_DISCOVERY
STARTUP = startup_stm32f746xx
IPATH += -I$(CUBE)/Drivers/BSP/STM32746G-Discovery
LDSCRIPT = STM32F746NGHx_FLASH.ld
else ifeq ($(strip $(DEVICE)),stm32f769i-disco)
CFLAGS += -mcpu=cortex-m7 -DSTM32F769xx -DUSE_STM32F769I_DISCO
STARTUP = startup_stm32f746xx
else
$(error DEVICE undefined)
endif


USR_OBJS = build/stm32f7xx_hal_msp.o build/qspi_diskio.o build/main.o  build/stm32f7xx_it.o build/syscalls.o build/sysmem.o build/usbh_conf.o
USR_SRCS = $(patsubst %.o,%.c,$(subst build,src,$(USR_OBJS)))

$(USR_OBJS): $(USR_SRCS)
	$(CC) src$(subst build,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"

# startup
build/$(STARTUP).o: src/$(STARTUP).S
	$(CC) -mcpu=cortex-m7 -g3 -c -x assembler-with-cpp --specs=nano.specs -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb -o "$@" "$<"

################
#     LCD      #
################
LCD_OBJS = build/Libraries/lcd_log.o
$(LCD_OBJS): Libraries/lcd_log.c
	$(CC) $< -c $(CFLAGS) $(IPATH) -o "$@"

################
#   FreeRTOS   #
################
FRTOS_PATH = Libraries/$(FRTOS)/Source
FRTOS_OBJS = \
	build/$(FRTOS_PATH)/portable/MemMang/heap_4.o \
	build/$(FRTOS_PATH)/portable/GCC/ARM_CM7/r0p1/port.o \
	build/$(FRTOS_PATH)/CMSIS_RTOS/cmsis_os.o \
	build/$(FRTOS_PATH)/croutine.o \
	build/$(FRTOS_PATH)/list.o \
	build/$(FRTOS_PATH)/queue.o \
	build/$(FRTOS_PATH)/tasks.o \
	build/$(FRTOS_PATH)/timers.o
FRTOS_SRCS  = $(patsubst %.o,%.c,$(subst build/,,$(FRTOS_OBJS)))
$(FRTOS_OBJS): $(FRTOS_SRCS)
	@mkdir -p build/$(FRTOS_PATH)/portable/MemMang
	@mkdir -p build/$(FRTOS_PATH)/portable/GCC/ARM_CM7/r0p1
	@mkdir -p build/$(FRTOS_PATH)/CMSIS_RTOS
	$(CC) $(subst build/,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


###############
#    FatFs    #
###############
FATF_PATH = Libraries/$(FATF)/src
FATF_OBJS = \
	build/$(FATF_PATH)/option/syscall.o \
	build/$(FATF_PATH)/option/unicode.o \
	build/$(FATF_PATH)/sd_diskio.o \
	build/$(FATF_PATH)/diskio.o \
	build/$(FATF_PATH)/ff.o \
	build/$(FATF_PATH)/ff_gen_drv.o
FATF_SRCS  = $(patsubst %.o,%.c,$(subst build/,,$(FRTOS_OBJS)))
$(FATF_OBJS): $(FATF_SRCS)
	@mkdir -p build/$(FATF_PATH)/option
	$(CC) $(subst build/,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


###############
#     HAL     #
###############
HAL_PATH = $(CUBE)/Drivers/STM32F7xx_HAL_Driver/Src
HAL_OBJS = \
	build/stm32f7xx_hal.o \
	build/stm32f7xx_hal_cortex.o \
	build/stm32f7xx_hal_dma.o build/stm32f7xx_hal_dma_ex.o \
	build/stm32f7xx_hal_dma2d.o \
	build/stm32f7xx_hal_gpio.o \
	build/stm32f7xx_hal_i2c.o build/stm32f7xx_hal_i2c_ex.o \
	build/stm32f7xx_hal_pwr.o build/stm32f7xx_hal_pwr_ex.o \
	build/stm32f7xx_hal_rcc.o build/stm32f7xx_hal_rcc_ex.o \
	build/stm32f7xx_hal_sd.o \
	build/stm32f7xx_hal_tim.o build/stm32f7xx_hal_tim_ex.o \
	build/stm32f7xx_hal_sdram.o \
	build/stm32f7xx_hal_uart.o \
	build/stm32f7xx_hal_ltdc.o build/stm32f7xx_hal_ltdc_ex.o \
	build/stm32f7xx_hal_hcd.o \
	build/stm32f7xx_hal_sai.o \
	build/stm32f7xx_hal_qspi.o \
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
	$(BSP_PATH)/../Components/wm8994/wm8994.c \
	$(BSP_PATH)/stm32746g_discovery.c \
	$(BSP_PATH)/stm32746g_discovery_sd.c \
	$(BSP_PATH)/stm32746g_discovery_audio.c \
	$(BSP_PATH)/stm32746g_discovery_lcd.c \
	$(BSP_PATH)/stm32746g_discovery_sdram.c \
	$(BSP_PATH)/stm32746g_discovery_qspi.c
BSP_OBJS = $(patsubst %.c,%.o,$(subst $(BSP_PATH)/,build/Libraries/$(DEVICE)/,$(BSP_SRCS)))
$(BSP_OBJS): build/stm32f7xx_hal_msp.o $(BSP_SRCS)
	@mkdir -p build/Libraries/$(DEVICE)
	@mkdir -p build/Libraries/Components/wm8994
	@mkdir -p build/Libraries/Components/n25q128a
	$(CC) $(subst build/Libraries/$(DEVICE)/,$(BSP_PATH)/,$*).c -c $(CFLAGS) $(IPATH) -o "$@"
# BSP-Components  
bsptest: $(BSP_OBJS)


######################
#   STM32_USB_Host   #
######################
USBH_PATH = build/Libraries/STM32_USB_Host_Library
USBH_OBJS = \
	$(USBH_PATH)/Class/HID/Src/usbh_hid.o \
	$(USBH_PATH)/Class/HID/Src/usbh_hid_keybd.o \
	$(USBH_PATH)/Class/HID/Src/usbh_hid_mouse.o \
	$(USBH_PATH)/Class/HID/Src/usbh_hid_parser.o \
	$(USBH_PATH)/Class/HUB/Src/usbh_hub.o \
	$(USBH_PATH)/Core/Src/usbh_core.o \
	$(USBH_PATH)/Core/Src/usbh_ctlreq.o \
	$(USBH_PATH)/Core/Src/usbh_ioreq.o \
	$(USBH_PATH)/Core/Src/usbh_pipes.o
USBH_SRCS = $(patsubst %.o,%.c,$(subst build/,,$(USBH_OBJS)))
$(USBH_OBJS): $(USBH_SRCS)
	@mkdir -p $(USBH_PATH)/Class/HID/Src
	@mkdir -p $(USBH_PATH)/Class/HUB/Src
	@mkdir -p $(USBH_PATH)/Core/Src
	$(CC) $(subst build/,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


##############
#    DOOM    #
##############
DOOM_PATH = App/chocdoom
# Ignore heretic, hexen (for now), and i_videohr.c
DOOM_SRCS = $(shell find App -type d \( -path App/chocdoom/heretic -o -path App/chocdoom/hexen \) -prune -false -o -name *.c)
DOOM_OBJS_ = $(patsubst %.c,%.o,$(addprefix build/,$(DOOM_SRCS)))
DOOM_BUILD_FILTER = build%i_videohr.o build%w_stdio.o
DOOM_OBJS = $(filter-out $(DOOM_BUILD_FILTER),$(DOOM_OBJS_))
$(DOOM_OBJS): $(DOOM_SRCS)
	@mkdir -p build/$(DOOM_PATH)/doom
	@mkdir -p build/$(DOOM_PATH)/heretic
	$(CC) $(subst build/,,$*).c -c $(CFLAGS) $(IPATH) -o "$@"



OBJS = $(FRTOS_OBJS) $(FATF_OBJS) $(USBH_OBJS) $(HAL_OBJS) $(CMSIS_OBJS) $(BSP_OBJS) \
	 $(DOOM_OBJS) $(LCD_OBJS) $(USR_OBJS) build/$(STARTUP).o 


all: build/$(GAME).elf build/$(GAME).bin size relf objd


build/$(GAME).elf: $(OBJS) $(LDSCRIPT)
	@mkdir -p build
	$(CC) -o "build/$(GAME).elf" $(OBJS) -mcpu=cortex-m7 -T"$(LDSCRIPT)" --specs=nosys.specs -Wl,-Map="build/$(GAME).map" -Wl,--gc-sections -static --specs=nano.specs -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb -Wl,--start-group -lc -lm -Wl,--end-group
	@echo 'Finished building target: $@'
	@echo ' '


build/$(GAME).bin: build/$(GAME).elf
	$(OBJC) -O binary $< $@


flash: all
	/usr/bin/openocd \
	-f /usr/share/openocd/scripts/interface/stlink-v2-1.cfg \
	-f /usr/share/openocd/scripts/target/stm32f7x.cfg \
	-c "init" \
	-c "reset init" \
	-c "flash probe 0" \
	-c "flash info 0" \
	-c "flash write_image erase build/$(GAME).bin 0x08000000" \
	-c "reset run" -c shutdown

size: build/$(GAME).elf
	$(SIZE) --format=SysV -x build/$(GAME).elf
relf: build/$(GAME).elf
	$(READELF) -a build/$(GAME).elf > build/$(GAME).readelf.txt
objd: build/$(GAME).elf
	$(OBJDUMP) -d build/$(GAME).elf > build/$(GAME).objdump.txt

clean:
	@rm -r build/*


.PHONY: flash clean
