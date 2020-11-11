GCCP = /opt/st/stm32cubeide_1.4.0/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.7-2018-q2-update.linux64_1.4.0.202007081208/tools
GCCR = $(GCCP)/bin
CUBE = $(HOME)/STM32Cube/Repository/STM32Cube_FW_F7_V1.16.0
ROOT = $(HOME)/github/doom_f7
PREFIX = arm-none-eabi-

CC = $(GCCR)/$(PREFIX)gcc
OBJC = $(GCCR)/$(PREFIX)objcopy 
LD = $(GCCR)/$(PREFIX)ld
AR = $(GCCR)/$(PREFIX)ar
SIZE = $(GCCR)/$(PREFIX)size


GAME = doom
DEVICE = stm32f746-disco


CFLAGS = -std=gnu11 -g3 -Os -ffunction-sections -Wall -fstack-usage -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb
CFLAGS += -DUSE_USB_HS -DDATA_IN_ExtSDRAM -DUSE_HAL_DRIVER
CFLAGS += --specs=nosys.specs
CFLAGS += --specs=nano.specs

FRTOS = FreeRTOSv
FATF = FatFsv

IPATH = \
	-I$(GCCP)/arm-none-eabi/include \
	-I$(GCCP)/lib/gcc/arm-none-eabi/7.3.1/include \
	-I$(GCCP)/lib/gcc/arm-none-eabi/7.3.1/include-fixed \
	-I$(CUBE)/Drivers/BSP/STM32746G-Discovery \
	-I$(ROOT)/Drivers/BSP/Components/rk043fn48h \
	-I$(CUBE)/Drivers/BSP/Components/Common \
	-I$(CUBE)/Drivers/CMSIS/Device/ST/STM32F7xx/Include \
	-I$(CUBE)/Drivers/CMSIS/Include \
	-I$(CUBE)/Drivers/STM32F7xx_HAL_Driver/Inc \
	-I$(CUBE)/Utilities/Log \
	-I$(CUBE)/Utilities/Fonts \
	-I$(CUBE)/Utilities/CPU \
	-I$(ROOT)/Libraries/$(FATF)/src \
	-I$(ROOT)/Libraries/$(FATF)/src/drivers \
	-I$(ROOT)/Libraries/$(FRTOS)/Source/include \
	-I$(ROOT)/Libraries/$(FRTOS)/Source/portable/GCC/ARM_CM7/r0p1 \
	-I$(ROOT)/Libraries/$(FRTOS)/Source/CMSIS_RTOS \
	-I$(ROOT)/Libraries/STM32_USB_Host_Library/Core/Inc \
	-I$(ROOT)/Libraries/STM32_USB_Host_Library/Class/HID/Inc \
	-I$(ROOT)/Libraries/STM32_USB_Host_Library/Class/HUB/Inc \
	-I$(ROOT)/inc \
	-I$(ROOT)/App/chocdoom \
	-I$(ROOT)/App/chocdoom/doom


ifeq ($(strip $(DEVICE)),stm32f746-disco)
CFLAGS += -mcpu=cortex-m7 -DSTM32F756xx -DUSE_STM32746G_DISCOVERY
STARTUP = startup_stm32f746xx
IPATH += -I$(CUBE)/Drivers/BSP/STM32746G-Discovery
else ifeq ($(strip $(DEVICE)),stm32f769i-disco)
CFLAGS += -mcpu=cortex-m7 -DSTM32F769xx -DUSE_STM32F769I_DISCO
STARTUP = startup_stm32f746xx
else
$(error DEVICE undefined and $(USR_SRCS))
endif


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
FRTOS_PATH = Libraries/FreeRTOSv/Source
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
FATF_PATH = Libraries/FatFsv/src
FATF_OBJS = \
	build/$(FATF_PATH)/option/syscall.o \
	build/$(FATF_PATH)/option/unicode.o \
	build/$(FATF_PATH)/sd_diskio_dma_rtos.o \
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
	build/stm32f7xx_hal_gpio.o \
	build/stm32f7xx_hal_i2c.o build/stm32f7xx_hal_i2c_ex.o \
	build/stm32f7xx_hal_pwr.o build/stm32f7xx_hal_pwr_ex.o \
	build/stm32f7xx_hal_rcc.o build/stm32f7xx_hal_rcc_ex.o \
	build/stm32f7xx_hal_sd.o \
	build/stm32f7xx_hal_tim.o build/stm32f7xx_hal_tim_ex.o \
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
	$(CC) $(subst build/Libraries/$(DEVICE)/,$(BSP_PATH)/,$*).c -c $(CFLAGS) $(IPATH) -o "$@"


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
# dummy.c am_map.c doomdef.c doomstat.c dstrings.c d_event.c d_items.c d_iwad.c d_loop.c d_main.c d_mode.c d_net.c f_finale.c f_wipe.c g_game.c hu_lib.c hu_stuff.c info.c i_cdmus.c i_endoom.c i_joystick.c i_main.c i_scale.c i_sound.c i_system.c i_timer.c i_video.c memio.c m_argv.c m_bbox.c m_cheat.c m_config.c m_controls.c m_fixed.c m_menu.c m_misc.c m_random.c p_ceilng.c p_doors.c p_enemy.c p_floor.c p_inter.c p_lights.c p_map.c p_maputl.c p_mobj.c p_plats.c p_pspr.c p_saveg.c p_setup.c p_sight.c p_spec.c p_switch.c p_telept.c p_tick.c p_user.c r_bsp.c r_data.c r_draw.c r_main.c r_plane.c r_segs.c r_sky.c r_things.c sha1.c sounds.c statdump.c st_lib.c st_stuff.c s_sound.c tables.c v_video.c wi_stuff.c w_checksum.c w_file.c w_file_stdc.c w_main.c w_wad.c z_zone.c
DOOM_PATH = 
DOOM_OBJS = \
	build/App/



OBJS = $(FRTOS_OBJS) $(FATF_OBJS) $(USBH_OBJS) $(HAL_OBJS) $(CMSIS_OBJS) $(BSP_OBJS) \
	 $(USR_OBJS) build/$(STARTUP).o 


all: $(GAME).elf $(GAME).bin size


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

size: $(GAME).elf
	$(SIZE) --format=sysv -d $(GAME).elf

clean:
	@rm build/*


.PHONY: flash clean
