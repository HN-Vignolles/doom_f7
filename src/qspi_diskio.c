/**
 ******************************************************************************
 * @file    qspi_diskio.c
 * @author  MCD Application Team
 * @author  HN-Vignolles
 * @brief   SDRAM Disk I/O driver.
 ******************************************************************************
 * @attention
 *
 * <h2><center>&copy; Copyright (c) 2017 STMicroelectronics International N.V.
 * All rights reserved.</center></h2>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted, provided that the following conditions are met:
 *
 * 1. Redistribution of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 * 3. Neither the name of STMicroelectronics nor the names of other
 *    contributors to this software may be used to endorse or promote products
 *    derived from this software without specific written permission.
 * 4. This software, including modifications and/or derivative works of this
 *    software, must execute solely and exclusively on microcontroller or
 *    microprocessor devices manufactured by or for STMicroelectronics.
 * 5. Redistribution and use of this software other than as permitted under
 *    this license is void and will automatically terminate your rights under
 *    this license.
 *
 * THIS SOFTWARE IS PROVIDED BY STMICROELECTRONICS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS, IMPLIED OR STATUTORY WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NON-INFRINGEMENT OF THIRD PARTY INTELLECTUAL PROPERTY
 * RIGHTS ARE DISCLAIMED TO THE FULLEST EXTENT PERMITTED BY LAW. IN NO EVENT
 * SHALL STMICROELECTRONICS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 ******************************************************************************
 */

#include "ff_gen_drv.h"
#include "qspi_diskio.h"
#include "stm32746g_discovery_qspi.h"
#include "stm32746g_discovery.h"

/* Block Size in Bytes */
#define BLOCK_SIZE                4096

/* Disk status */
static volatile DSTATUS Stat = STA_NOINIT;


DSTATUS QSPIDISK_initialize (BYTE);
DSTATUS QSPIDISK_status (BYTE);
DRESULT QSPIDISK_read (BYTE, BYTE*, DWORD, UINT);
#if _USE_WRITE == 1
DRESULT QSPIDISK_write (BYTE, const BYTE*, DWORD, UINT);
#endif /* _USE_WRITE == 1 */
#if _USE_IOCTL == 1
DRESULT QSPIDISK_ioctl (BYTE, BYTE, void*);
#endif /* _USE_IOCTL == 1 */


const Diskio_drvTypeDef  QSPIDISK_Driver =
{
		QSPIDISK_initialize,
		QSPIDISK_status,
		QSPIDISK_read,
#if  _USE_WRITE
		QSPIDISK_write,
#endif  /* _USE_WRITE == 1 */
#if  _USE_IOCTL == 1
		QSPIDISK_ioctl,
#endif /* _USE_IOCTL == 1 */
};

// set the status (written) bit for the corresponding block (subsector)
volatile uint32_t mw[128];
typedef enum wBitO{
	O_SET,
	O_GET
} wBitO_t;
uint32_t wBit(uint32_t addr,wBitO_t opt){
	uint32_t blkIndex = (addr & 0xffffff000) >> (3*4); //0-4095 blocks
	uint32_t index = blkIndex / 32; //...packed in 128 words
	uint32_t bit = 1 << (blkIndex & 0x1f);
	if(opt == O_SET){
		mw[index] |= bit;
		return 0;
	}
	else if(opt == O_GET)
		return mw[index] & bit;
	else
		return -1;
}

/**
 * @brief  Initializes a Drive
 * @param  lun : not used
 * @retval DSTATUS: Operation status
 */
DSTATUS QSPIDISK_initialize(BYTE lun){
	Stat = STA_NOINIT;

	/* Configure the QSPI device */
	if(BSP_QSPI_Init() == QSPI_OK)
		Stat &= ~STA_NOINIT;

	//BSP_QSPI_MemoryMappedMode(); --> read only

	/* Configure LPTR register with the low-power time out value */
	//WRITE_REG(QUADSPI->LPTR, 0xFFF);
	//BSP_QSPI_Erase_Chip();

	return Stat;
}

/**
 * @brief  Gets Disk Status
 * @param  lun : not used
 * @retval DSTATUS: Operation status
 */
DSTATUS QSPIDISK_status(BYTE lun){
	return Stat;
}

/**
 * @brief  Reads Sector(s)
 * @param  lun : not used
 * @param  *buff: Data buffer to store read data
 * @param  sector: Sector address (LBA)
 * @param  count: Number of sectors to read (1..128)
 * @retval DRESULT: Operation result
 */
DRESULT QSPIDISK_read(BYTE lun, BYTE *buff, DWORD sector, UINT count){
	uint8_t *pSrcBuffer = (uint8_t *)buff;
	uint32_t BufferSize = BLOCK_SIZE * count;
	uint32_t pQSPIAddress = sector * BLOCK_SIZE;
	BSP_LED_On(LED_GREEN);
	BSP_QSPI_Read(pSrcBuffer,pQSPIAddress,BufferSize);
	BSP_LED_Off(LED_GREEN);
	return RES_OK;
}

/**
 * @brief  Writes Sector(s)
 * @param  lun : not used
 * @param  *buff: Data to be written
 * @param  sector: Sector address (LBA)
 * @param  count: Number of sectors to write (1..128)
 * @retval DRESULT: Operation result
 */
#if _USE_WRITE == 1
DRESULT QSPIDISK_write(BYTE lun, const BYTE *buff, DWORD sector, UINT count)
{
	uint8_t *pDstBuffer = (uint8_t *)buff;
	uint32_t BufferSize = BLOCK_SIZE * count;
	uint32_t pQSPIAddress = sector * BLOCK_SIZE;

	uint8_t verify[8192];
	volatile int cnt;
	volatile uint8_t res=0;

	BSP_QSPI_Erase_Block(pQSPIAddress);
	BSP_QSPI_Write(pDstBuffer,pQSPIAddress,BufferSize);
	wBit(pQSPIAddress,O_SET);
	BSP_QSPI_Read(verify,pQSPIAddress,BufferSize);
	for(cnt=0;cnt < BufferSize;cnt++){
		if(pDstBuffer[cnt] != verify[cnt]){
			__ASM volatile ("NOP");
			break;
		}
	}

	__ASM volatile ("NOP");
	return RES_OK;
}
#endif /* _USE_WRITE == 1 */

/**
  * @brief  I/O control operation
  * @param  lun : not used
  * @param  cmd: Control code
  * @param  *buff: Buffer to send/receive control data
  * @retval DRESULT: Operation result
  */
#if _USE_IOCTL == 1
DRESULT QSPIDISK_ioctl(BYTE lun, BYTE cmd, void *buff)
{
  DRESULT res = RES_ERROR;

  if (Stat & STA_NOINIT) return RES_NOTRDY;

  switch (cmd)
  {
  /* Make sure that no pending write process */
  case CTRL_SYNC :
    res = RES_OK;
    break;

  /* Get number of sectors on the disk (DWORD) */
  case GET_SECTOR_COUNT :
    *(DWORD*)buff = N25Q128A_FLASH_SIZE / BLOCK_SIZE;
    res = RES_OK;
    break;

  /* Get R/W sector size (WORD) */
  case GET_SECTOR_SIZE :
    *(WORD*)buff = BLOCK_SIZE;
    res = RES_OK;
    break;

  /* Get erase block size in unit of sector (DWORD) */
  case GET_BLOCK_SIZE :
    *(DWORD*)buff = 1;
	res = RES_OK;
    break;

  default:
    res = RES_PARERR;
  }

  return res;
}
#endif /* _USE_IOCTL == 1 */

/************************ (C) COPYRIGHT STMicroelectronics *****END OF FILE****/

