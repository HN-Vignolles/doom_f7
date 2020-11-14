/**
  ******************************************************************************
  * @file    Templates/Src/main.c 
  * @author  MCD Application Team
  * @version V1.0.0
  * @date    22-April-2016
  * @brief   Main program body
  ******************************************************************************
  * @attention
  *
  * <h2><center>&copy; COPYRIGHT(c) 2016 STMicroelectronics</center></h2>
  *
  * Redistribution and use in source and binary forms, with or without modification,
  * are permitted provided that the following conditions are met:
  *   1. Redistributions of source code must retain the above copyright notice,
  *      this list of conditions and the following disclaimer.
  *   2. Redistributions in binary form must reproduce the above copyright notice,
  *      this list of conditions and the following disclaimer in the documentation
  *      and/or other materials provided with the distribution.
  *   3. Neither the name of STMicroelectronics nor the names of its contributors
  *      may be used to endorse or promote products derived from this software
  *      without specific prior written permission.
  *
  * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
  * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
  * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
  * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  *
  ******************************************************************************
  */

#include "main.h"
#include "stdio.h"
#include "lcd_log.h"

//The stm32f746g-discovery has lesser memory (RAM and SDRAM) than the f769-disc.
//Using the main RAM for .data and .bss sections results in overflow
//Using SDRAM for .bss can break some things (bss segment should be zero-filled at startup)

#ifdef USE_STM32F769I_DISCO
extern uint8_t _isr_vector_ram_start asm("_isr_vector_ram_start");     /* Defined by the linker. */
extern uint8_t _isr_vector_flash_start asm("_isr_vector_flash_start"); /* Defined by the linker. */
extern uint8_t _isr_vector_flash_end asm("_isr_vector_flash_end");     /* Defined by the linker. */
#endif

USBH_HandleTypeDef hUSBHost[5], *phUSBHost = NULL;
uint8_t host_state;
osThreadId thread_id;

extern SD_HandleTypeDef uSdHandle;

static void SystemClock_Config(void);
static void Error_Handler(void);
static void MPU_Config(void);
static void CPU_CACHE_Enable(void);

static void USBThread(void const *argument);
static void DoomThread(void const *argument);
static void USBH_UserProcess(USBH_HandleTypeDef *phost, uint8_t id);
static void HUB_Process(void);

extern void D_DoomMain (void);
#define LCD_FRAME_BUFFER          ((uint32_t)0xC0000000)


int main(void)
{
#ifdef USE_STM32F769I_DISCO
	/* Copy ISRs to RAM (c.f. system_stm32f7xx.c) */
	memcpy(	(uint8_t *)&_isr_vector_ram_start,
			(uint8_t *)&_isr_vector_flash_start,
			&_isr_vector_flash_end - &_isr_vector_flash_start );

	/* Relocate the vector table */
	SCB->VTOR = (uint32_t) &_isr_vector_ram_start;
#endif

	/* Configure the MPU attributes as Write Through */
	MPU_Config();

	/* Enable the CPU Cache */
	CPU_CACHE_Enable();

	/* STM32F7xx HAL library initialization:
       - Configure the Flash ART accelerator on ITCM interface
       - Configure the Systick to generate an interrupt each 1 msec
       - Set NVIC Group Priority to 4
       - Low Level Initialization
	 */
	HAL_Init();

	/* Configure the system clock to 216 MHz */
	SystemClock_Config();

#ifdef USE_STM32F769I_DISCO
	/* Initialize the SDRAM */
	BSP_SDRAM_Init();
#endif /* DATA_IN_ExtSDRAM */

	BSP_LED_Init(LED_GREEN); // Debug led for sdcard activity

	char Path[4]={0,0,0,0};
	FIL MyFile;
	FATFS 	FatFs; //This structure should be in the main internal ram.
	memset(&FatFs,0,sizeof(FATFS));
	memset(&MyFile,0,sizeof(FIL));
	volatile int *test = (int*)malloc(sizeof(int));

	FATFS_LinkDriver(&SD_Driver, Path);
	BSP_SD_Detect_MspInit(&uSdHandle, NULL);
	while( BSP_SD_IsDetected() != 1 );
	if( f_mount(&FatFs, (TCHAR const*)Path, 0) != FR_OK ) Error_Handler();
	else {
		*test = 23;
	}
	BSP_LCD_Init();
	BSP_LCD_LayerDefaultInit(LTDC_ACTIVE_LAYER, LCD_FRAME_BUFFER);
	BSP_LCD_SelectLayer(LTDC_ACTIVE_LAYER);
	BSP_LCD_FillCircle(BSP_LCD_GetXSize() - 40, 120, 20);
	BSP_LCD_SetFont(&LCD_DEFAULT_FONT);
	BSP_LCD_SetBackColor(LCD_COLOR_BLACK);
	BSP_LCD_Clear(LCD_COLOR_BLACK);
	BSP_LCD_SetTextColor(LCD_COLOR_WHITE);

	LCD_LOG_Init();
	LCD_LOG_SetHeader((uint8_t *)"Log:");
	LCD_UsrLog("Testing 1\n");
	printf("Testing 2\n");
	D_DoomMain ();

	memset(&hUSBHost[0], 0, sizeof(USBH_HandleTypeDef));

	hUSBHost[0].valid   = 1;
	hUSBHost[0].address = USBH_DEVICE_ADDRESS;
	hUSBHost[0].Pipes   = USBH_malloc(sizeof(uint32_t) * USBH_MAX_PIPES_NBR);

	/* Init Host Library */
	USBH_Init(&hUSBHost[0], USBH_UserProcess, 0);

	/* Add Supported Class */
	USBH_RegisterClass(&hUSBHost[0], USBH_HID_CLASS);
	USBH_RegisterClass(&hUSBHost[0], USBH_HUB_CLASS);

	/* Start Host Process */
	USBH_Start(&hUSBHost[0]);

	/* USB task */
	//osThreadDef(USB_Thread, USBThread, osPriorityNormal, 0, 8 * configMINIMAL_STACK_SIZE);
	//osThreadCreate(osThread(USB_Thread), NULL);

	/* Doom task */
	osThreadDef(DOOM_Thread, DoomThread, osPriorityNormal, 0, 16 * configMINIMAL_STACK_SIZE);
	thread_id = osThreadCreate(osThread(DOOM_Thread), NULL);

	//osThreadSuspend (thread_id);

	/* Start scheduler */
	osKernelStart();

	/* We should never get here as control is now taken by the scheduler */
	for( ;; );
}

void vApplicationStackOverflowHook( TaskHandle_t xTask, signed char *pcTaskName )
{
	for( ;; );
}

static void USBThread(void const * argument)
{
	for( ;; )
	{
	    /* USB Host Background task */
		HUB_Process();
	}
}

static void DoomThread(void const * argument)
{
	D_DoomMain ();
}

/**
  * @brief
  * @param
  * @retval
  */
static void HUB_Process(void)
{
	static uint8_t current_port = -1;

	if(phUSBHost != NULL && phUSBHost->valid == 1)
	{
		USBH_Process(phUSBHost);

		if(phUSBHost->busy)
			return;
	}

	for( ;; )
	{
		current_port++;

		if(current_port > MAX_HUB_PORTS)
			current_port = 0;

		if(hUSBHost[current_port].valid)
		{
			phUSBHost = &hUSBHost[current_port];
			USBH_LL_SetupEP0(phUSBHost);

			if(phUSBHost->valid == 3)
			{
				phUSBHost->valid = 1;
				phUSBHost->busy  = 1;
			}

			break;
		}
	}
}

/**
  * @brief  User Process
  * @param  phost: Host Handle
  * @param  id: Host Library user message ID
  * @retval None
  */
static void USBH_UserProcess(USBH_HandleTypeDef *phost, uint8_t id)
{
  	switch(id)
  	{
  		case HOST_USER_SELECT_CONFIGURATION:
    			break;

 	 	case HOST_USER_DISCONNECTION:
 	 			host_state = HOST_USER_DISCONNECTION;
    			break;

  		case HOST_USER_CLASS_ACTIVE:
  				osDelay (100);

  				host_state = HOST_USER_CLASS_ACTIVE;

  				osThreadResume (thread_id);
    			break;

  		case HOST_USER_CONNECTION:
  				host_state = HOST_USER_CONNECTION;
    			break;

  		default:
    			break;
  	}
}

/**
  * @brief
  * @param
  * @retval
  */
void HAL_Delay(__IO uint32_t Delay)
{
	uint32_t tick;

	tick = (SystemCoreClock/1000) * Delay;
	while(tick--)
	{
	}
}

/**
  * @brief  System Clock Configuration
  *         The system Clock is configured as follow : 
  *            System Clock source            = PLL (HSE)
  *            SYSCLK(Hz)                     = 216000000
  *            HCLK(Hz)                       = 216000000
  *            AHB Prescaler                  = 1
  *            APB1 Prescaler                 = 4
  *            APB2 Prescaler                 = 2
  *            HSE Frequency(Hz)              = 25000000
  *            PLL_M                          = 25
  *            PLL_N                          = 432
  *            PLL_P                          = 2
  *            PLL_Q                          = 9
  *            PLL_R                          = 7
  *            VDD(V)                         = 3.3
  *            Main regulator output voltage  = Scale1 mode
  *            Flash Latency(WS)              = 7
  * @param  None
  * @retval None
  */
static void SystemClock_Config(void)
{
	RCC_ClkInitTypeDef RCC_ClkInitStruct;
	RCC_OscInitTypeDef RCC_OscInitStruct;
	HAL_StatusTypeDef ret = HAL_OK;
#ifdef USE_STM32F769I_DISCO
	/* Enable Power Control clock */
	__HAL_RCC_PWR_CLK_ENABLE();

	/* The voltage scaling allows optimizing the power consumption when the device is
     clocked below the maximum system frequency, to update the voltage scaling value 
     regarding system frequency refer to product datasheet.  */
	__HAL_PWR_VOLTAGESCALING_CONFIG(PWR_REGULATOR_VOLTAGE_SCALE1);
#endif
	/* Enable HSE Oscillator and activate PLL with HSE as source */
	RCC_OscInitStruct.OscillatorType = RCC_OSCILLATORTYPE_HSE;
	RCC_OscInitStruct.HSEState = RCC_HSE_ON;
	RCC_OscInitStruct.PLL.PLLState = RCC_PLL_ON;
	RCC_OscInitStruct.PLL.PLLSource = RCC_PLLSOURCE_HSE;
	RCC_OscInitStruct.PLL.PLLM = 25;
#ifdef USE_STM32F769I_DISCO
	RCC_OscInitStruct.PLL.PLLN = 432;
#endif
#ifdef USE_STM32746G_DISCOVERY
	RCC_OscInitStruct.PLL.PLLN = 400;
	RCC_OscInitStruct.PLL.PLLQ = 8;
#endif
	RCC_OscInitStruct.PLL.PLLP = RCC_PLLP_DIV2;
#ifdef USE_STM32F769I_DISCO
	RCC_OscInitStruct.PLL.PLLQ = 9;
	RCC_OscInitStruct.PLL.PLLR = 7;
#endif
	if(HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK) Error_Handler();

	/* Activate the OverDrive to reach the 216 MHz Frequency */
	if(HAL_PWREx_EnableOverDrive() != HAL_OK) Error_Handler();

	/* Select PLL as system clock source and configure the HCLK, PCLK1 and PCLK2 clocks dividers */
	RCC_ClkInitStruct.ClockType = (RCC_CLOCKTYPE_SYSCLK | RCC_CLOCKTYPE_HCLK | RCC_CLOCKTYPE_PCLK1 | RCC_CLOCKTYPE_PCLK2);
	RCC_ClkInitStruct.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
	RCC_ClkInitStruct.AHBCLKDivider = RCC_SYSCLK_DIV1;
	RCC_ClkInitStruct.APB1CLKDivider = RCC_HCLK_DIV4;
	RCC_ClkInitStruct.APB2CLKDivider = RCC_HCLK_DIV2;
#ifdef USE_STM32F769I_DISCO
	if(HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_7) != HAL_OK) Error_Handler();
#endif
#ifdef USE_STM32746G_DISCOVERY
	if(HAL_RCC_ClockConfig(&RCC_ClkInitStruct, FLASH_LATENCY_6) != HAL_OK) Error_Handler();
#endif
}

/**
  * @brief  This function is executed in case of error occurrence.
  * @param  None
  * @retval None
  */
static void Error_Handler(void)
{
  /* User may add here some code to deal with this error */
  while(1)
  {
  }
}

/**
  * @brief  Configure the MPU attributes as Write Through for Internal SRAM1/2.
  * @note   The Base Address is 0x20020000 since this memory interface is the AXI.
  *         The Configured Region Size is 512KB because the internal SRAM1/2 
  *         memory size is 384KB.
  * @param  None
  * @retval None
  */
static void MPU_Config(void)
{
  MPU_Region_InitTypeDef MPU_InitStruct;
  
  /* Disable the MPU */
  HAL_MPU_Disable();

  /* Configure the MPU attributes as WT for SRAM */
  MPU_InitStruct.Enable = MPU_REGION_ENABLE;
  MPU_InitStruct.BaseAddress = 0x20020000;
  MPU_InitStruct.Size = MPU_REGION_SIZE_512KB;
  MPU_InitStruct.AccessPermission = MPU_REGION_FULL_ACCESS;
  MPU_InitStruct.IsBufferable = MPU_ACCESS_NOT_BUFFERABLE;
  MPU_InitStruct.IsCacheable = MPU_ACCESS_CACHEABLE;
  MPU_InitStruct.IsShareable = MPU_ACCESS_SHAREABLE;
  MPU_InitStruct.Number = MPU_REGION_NUMBER0;
  MPU_InitStruct.TypeExtField = MPU_TEX_LEVEL0;
  MPU_InitStruct.SubRegionDisable = 0x00;
  MPU_InitStruct.DisableExec = MPU_INSTRUCTION_ACCESS_ENABLE;

  HAL_MPU_ConfigRegion(&MPU_InitStruct);

  /* Enable the MPU */
  HAL_MPU_Enable(MPU_PRIVILEGED_DEFAULT);
}

/**
  * @brief  CPU L1-Cache enable.
  * @param  None
  * @retval None
  */
static void CPU_CACHE_Enable(void){
  	SCB_EnableICache();
	SCB_EnableDCache();
}


#ifdef  USE_FULL_ASSERT

/**
  * @brief  Reports the name of the source file and the source line number
  *         where the assert_param error has occurred.
  * @param  file: pointer to the source file name
  * @param  line: assert_param error line source number
  * @retval None
  */
void assert_failed(uint8_t* file, uint32_t line)
{ 
  /* User can add his own implementation to report the file name and line number,
     ex: printf("Wrong parameters value: file %s on line %d\r\n", file, line) */

  /* Infinite loop */
  while (1)
  {
  }
}
#endif

/**
  * @}
  */

/**
  * @}
  */

/************************ (C) COPYRIGHT STMicroelectronics *****END OF FILE****/
