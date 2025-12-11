/******************************************************************************
* @file    helloworld.c
* This file implements a UART-driven menu system to interface with the
* custom enhancedPwm IP and the Zynq's TTC (Triple Timer Counter) for interrupts.
*
******************************************************************************/
#include <stdint.h>
#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "enhancedPwm_AXI.h"
#include "final_oscope.h"
#include "xuartps_hw.h"
#include "platform.h"

#include "xil_exception.h"
#include "xttcps.h"
#include "xscugic.h"

#define ENHANCED_PWM_BASEADDR   XPAR_ENHANCEDPWM_0_BASEADDR
#define USART_BASEADDR          XPAR_UART1_BASEADDR  
#define DUTY_CYCLE_OFFSET       0
#define PWM_COUNT_OFFSET        4

// Magic numbers 
#define TTC0_0_DEVICE_ID        0U
#define TTC0_0_INTR_ID          XPS_TTC0_0_INT_ID		// in xparameters_ps.h
#define INTC_DEVICE_ID          0U


typedef struct {
    u32 OutputHz;           /* Output frequency */
    XInterval Interval;     /* Interval value */
    u8 Prescaler;           /* Prescaler value */
    u16 Options;            /* Option settings */
} TmrCntrSetup;


#define NUM_TTC0_INDEX  1


/* Set up routines for timer counters */
int SetupIntervalTimerWithInterrupt(void);
static int SetupInterruptSystem(u16 IntcDeviceID, XScuGic *IntcInstancePtr);
static void Ttc0IsrHander(void *CallBackRef, u32 StatusEvent);


XScuGic InterruptController;  /* Interrupt controller instance */
XTtcPs  TtcPsInst[NUM_TTC0_INDEX];  /* Number of available timer counters */

TmrCntrSetup SettingsTable[NUM_TTC0_INDEX] = {
        {10000, 0, 0, 0}
};

#define SIN_LUT_LENGTH 64
#define SINC_LUT_LENGTH 64

typedef enum {
    WAVE_SINE = 0,
    WAVE_SINC = 1
} WaveformType;

u16 phaseIncrement = 0;
u16 dutyCycle = 0;
u8 generateWave = FALSE;
WaveformType currentWaveform = WAVE_SINE;

u8 sinLut[SIN_LUT_LENGTH + 1] = {128, 140, 152, 165, 176, 188, 198, 208, 218, 226, 234, 240, 245, 250, 253, 254, 255, 254, 253, 250, 245, 240, 234, 226, 218, 208, 198, 188, 176, 165, 152, 140, 128, 115, 103, 90, 79, 67, 57, 47, 37, 29, 21, 15, 10, 5, 2, 1, 0, 1, 2, 5, 10, 15, 21, 29, 37, 47, 57, 67, 79, 90, 103, 115, 128};
u8 sincLut[SINC_LUT_LENGTH + 1] = {128, 124, 120, 118, 116, 117, 119, 123, 128, 133, 138, 142, 
    144, 144, 141, 135, 128, 120, 112, 105, 101, 101, 105, 114, 128, 146, 166, 188, 209, 228, 
    242, 252, 255, 252, 242, 228, 209, 188, 166, 146, 128, 114, 105, 101, 101, 105, 112, 120, 
    128, 135, 141, 144, 144, 142, 138, 133, 128, 123, 119, 117, 116, 118, 120, 124, 128};

int main()
{
    u8 c;
    int Status;
    phaseIncrement=10;

    init_platform();

    Status = SetupInterruptSystem(INTC_DEVICE_ID, &InterruptController);
    if (Status != XST_SUCCESS) {
        printf("!!! SetupInterruptSystem FAILED !!!\n\r");
        return XST_FAILURE;
    }

    Status = SetupIntervalTimerWithInterrupt();
    if (Status != XST_SUCCESS) {
        printf("!!! SetupIntervalTimerWithInterrupt FAILED !!!\n\r");
        return Status;
    }

    printf("Welcome to the Enhanced PWM interface\n\r");

    // SETTING DEFAULTS
    u32 slv3 = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
    // enable channel 1 and 2
    slv3 |= (1 << 2);
    slv3 |= (1 << 3);

    /* ---- 2. Set Trigger Mode (not Forced) ----
       Forced mode bit = bit[1]
       Trigger mode means that bit[1] should be 0
    */
    slv3 &= ~(1 << 7); // default flag reg clear bit should be =0
    slv3 &= ~(1 << 6); // default reset bit = 0 (not resetting)
    slv3 &= ~(1 << 1); // default forced bit = 0 (trigger mode)
    slv3 &= ~(1 << 0); // default single bit = 0
    FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, slv3);

    // default trig voltage is zero
    u32 slv4 = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET);

    slv4 = (slv4 & 0xFFFF0000) | 0x0000; // lower 16 bits = 0
    FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET, slv4);

    while(1) {

        c=XUartPs_RecvByte(USART_BASEADDR);

        switch(c) {

        /*-------------------------------------------------
         * Reply with the help menu
         *-------------------------------------------------
         */
        case '?':
            printf("--------------------------\r\n");
            printf("PL LED4 displays the PWM output \r\n");
            printf("Disable the Enhanced PWM module by pressing PL_KEY4\r\n");
            printf("PWM Counter       %u \r\n", ENHANCEDPWM_AXI_mReadReg(XPAR_ENHANCEDPWM_AXI_0_BASEADDR , PWM_COUNT_OFFSET));
            printf("Duty Cycle = %d\r\n", dutyCycle);
            printf("Current Waveform: %s\r\n", currentWaveform == WAVE_SINE ? "SINE" : "SINC");
            printf("Wave Generation: %s\r\n", generateWave ? "ON" : "OFF");
            printf("--------------------------\r\n");
            printf("?: help menu\r\n");
            printf("r: Universal reset\r\n");
            printf("d: Enter a duty cycle.\r\n");
            printf("f: Flush terminal\r\n");
            printf("0: read enhanced PWM registers\r\n");
            printf("1: read ttc0 index 0 registers\r\n");
            printf("a: Toggle Ch1 on/off\r\n");
            printf("b: Toggle Ch2 on/off\r\n");
            printf("s: Toggle wave generation on/off\r\n");
            printf("w: Select waveform (sine or sinc)\r\n");
            printf("S: Serial Information\r\n");
            printf("t: Trigger mode\r\n");
            printf("n: Button - acquire\r\n");
            printf("+: Increase voltage trigger\r\n");
            printf("-: Decrease voltage trigger\r\n");
            printf("v: Reset voltage trigger back to 0\r\n");
            printf("u: Display last 64 values of waveform\r\n");
            break;

        case 'r':
            printf("Resetting....\r\n");
            #define RST_MASK (1 << 6)
            u32 slv3_reset_val = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
            u32 assert_reset = slv3_reset_val | RST_MASK;
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, assert_reset);

            u32 deassert_reset = assert_reset & (~RST_MASK);
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, deassert_reset);

            printf("Reset pulse complete.\r\n");
            break;

            /*-------------------------------------------------
             * Tell the counter to count up once
             *-------------------------------------------------
             */
        case 'd':
            dutyCycle = 0;
            printf("Enter a decimal value between 0 and 256:\r\n");
            do {
                c=XUartPs_RecvByte(USART_BASEADDR);
                if ( (c >= '0') && (c <= '9') ) {
                    dutyCycle = dutyCycle * 10 + (c-'0');
                    putchar(c);
                }

            } while (c != '\r');

            printf("\r\n");
            ENHANCEDPWM_AXI_mWriteReg(XPAR_ENHANCEDPWM_AXI_0_BASEADDR , DUTY_CYCLE_OFFSET, dutyCycle);          // put value into slv_reg1

            printf("loaded: %d\r\n",dutyCycle);
            break;


            /*-------------------------------------------------
             * Toggle wave generation
             *-------------------------------------------------
             */
    
        case 's':

            if (generateWave == TRUE) {
                generateWave = FALSE;
                printf("Wave off\r\n");
                // Setting to midpoint DC when wave off
                ENHANCEDPWM_AXI_mWriteReg(XPAR_ENHANCEDPWM_AXI_0_BASEADDR , DUTY_CYCLE_OFFSET, 128);
            } else {
                //phaseIncrement += 10;
                generateWave = TRUE;
                printf("Waveform: %s\r\n", currentWaveform == WAVE_SINE ? "SINE" : "SINC");
                printf("Wave on, phase accumulator = %d\r\n",phaseIncrement);
            }

            break;

        case 'w':
            printf("Select waveform:\r\n");
            printf("  1: Sine wave\r\n");
            printf("  2: Sinc wave\r\n");
            printf("Enter selection: ");
            
            c = XUartPs_RecvByte(USART_BASEADDR);
            putchar(c);
            printf("\r\n");
            
            if (c == '1') {
                currentWaveform = WAVE_SINE;
                printf("Waveform set to SINE\r\n");
            } else if (c == '2') {
                currentWaveform = WAVE_SINC;
                printf("Waveform set to SINC\r\n");
            } else {
                printf("Invalid char\r\n");
            }
            
            if (generateWave == TRUE) {
                printf("changing waveform...\r\n");
            } else {
                printf("press 's' to see change\r\n");
            }
            break;

            /*-------------------------------------------------
             * Read the AXI register associated with the enhancedPwm component
             *-------------------------------------------------
             */
        case '0':
            printf("ENHANCED_PWM_BASEADDR registers \r\n");
            for (c=0; c<4; c++) {
                printf("M[BASEADDR + %d] = %u\r\n",4*c,ENHANCEDPWM_AXI_mReadReg(XPAR_ENHANCEDPWM_AXI_0_BASEADDR , 4*c));
            }
            break;
        case '2':
            printf("Bits \r\n");
            //printf("M[BASEADDR + %d] = %u\r\n",4*c,ENHANCEDPWM_AXI_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR , ));
            break;
            /*-------------------------------------------------
             * Read the AXI register associated with the TTC0_0 component
             *-------------------------------------------------
             */
        case '1':
            printf("XTtcPs_GetCounterValue  = %04x\r\n", XTtcPs_GetCounterValue(& TtcPsInst[TTC0_0_DEVICE_ID])  );
            printf("XTtcPs_GetInterval  = %04x\r\n", XTtcPs_GetInterval(& TtcPsInst[TTC0_0_DEVICE_ID]) );
            printf("XTtcPs_GetPrescaler     = %04x\r\n", XTtcPs_GetPrescaler(& TtcPsInst[TTC0_0_DEVICE_ID]) );
            printf("XTtcPs_GetOptions   = %04x\r\n", XTtcPs_GetOptions(& TtcPsInst[TTC0_0_DEVICE_ID]) );
            printf("TtcPsInst[TTC_TICK_DEVICE_ID].Config.InputClockHz = %u\r\n", TtcPsInst[TTC0_0_DEVICE_ID].Config.InputClockHz);
            printf("SettingsTable[0][%04u, %04x, %04x, %04x]\r\n",SettingsTable[0].OutputHz, SettingsTable[0].Interval, SettingsTable[0].Prescaler, SettingsTable[0].Options);
            break;


            /*-------------------------------------------------
             * Clear the terminal window
             *-------------------------------------------------
             */
        case 'f':
            for (c=0; c<40; c++) printf("\r\n");
            break;

        case 'S':
            printf("Serial registers\r\n");
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_CR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_MR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_IER_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_IDR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_IMR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_ISR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_BAUDGEN_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_RXTOUT_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_RXWM_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_MODEMCR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_MODEMSR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_SR_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_FIFO_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_BAUDDIV_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_FLOWDEL_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_TXWM_OFFSET));
            printf("%u ",XUartPs_ReadReg(USART_BASEADDR, XUARTPS_RXBS_OFFSET));
            printf("\r\n");
            break;
            /*-------------------------------------------------
             * Unknown character was
             *-------------------------------------------------
             */
        case 'P':
            printf("Enter a frequency in Hz:\r\n");
            u16 frequency = 0;
            do {
                c=XUartPs_RecvByte(USART_BASEADDR);
                if ( (c >= '0') && (c <= '9') ) {
                    frequency = frequency * 10 + (c-'0');
                    putchar(c);
                }

            } while (c != '\r');
            phaseIncrement = 6.5516 * frequency + 0.0062; // from my regression
            printf("\r\n");
            printf("loaded: %d\r\n",phaseIncrement);
            break;
        case 'a':
            u32 slv3_read_ch1 = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
            #define CH1_TOGGLE_MASK (1 << 2)
            u32 updated_ch1 = slv3_read_ch1 ^ CH1_TOGGLE_MASK;
            int new_bit_value_ch1 = (updated_ch1 >> 2) & 1;

            if (new_bit_value_ch1 == 1) {
                printf("Channel 1 on\r\n");
            } else {
                printf("Channel 1 off\r\n");
            }
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, updated_ch1 );
            break;
        case 'b':
            u32 slv3_read_ch2 = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
            #define CH2_TOGGLE_MASK (1 << 3)
            u32 updated_ch2 = slv3_read_ch2 ^ CH2_TOGGLE_MASK;

            int new_bit_value_ch2 = (updated_ch2 >> 3) & 1;

            if (new_bit_value_ch2 == 1) {
                printf("Channel 2 on\r\n");
            } else {
                printf("Channel 2 off\r\n");
            }
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, updated_ch2 );
            break;
        case 't':
            #define FORCED_MASK (1 << 1)
            u32 slv3_read = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);

            u32 updated_reg = slv3_read ^ FORCED_MASK;

            int new_forced_bit = (updated_reg >> 1) & 1;
            if (new_forced_bit == 1) {
                printf("FORCED MODE - wait for button press\r\n");
            } else {
                printf("TRIGGER MODE\r\n");
            }

            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, updated_reg );
            break;
        case 'n':
            printf("BUTTON PRESSED\r\n");
            #define SINGLE_MASK (1 << 0)
            u32 slv3_read_single = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);

            u32 reg_high = slv3_read_single | SINGLE_MASK; // set high regardless
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, reg_high);

            u32 reg_low = reg_high & (~SINGLE_MASK); // clear bit 0
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, reg_low);
            break;
        case '+':
            printf("Incrementing Trigger Voltage...\r\n");
            u32 full_reg_read = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET);

            int16_t current_voltage = (int16_t)(full_reg_read & 0xFFFF); //read lower 16, cast to signed

            current_voltage+=1000; // can change this later
            printf("New Trigger Voltage Value: %d\r\n", current_voltage);

            u32 full_reg_write = (full_reg_read & 0xFFFF0000) | ((u32)current_voltage & 0xFFFF); //cast back to u32
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET, full_reg_write);
            
            break;
        case '-':
            printf("Decrementing Trigger Voltage...\r\n");

            u32 full_reg_read_1 = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET);
            int16_t current_voltage_1 = (int16_t)(full_reg_read_1 & 0xFFFF);
            current_voltage_1-=1000;

            printf("New Trigger Voltage Value: %d\r\n", current_voltage_1);
            u32 full_reg_write_1 = (full_reg_read_1 & 0xFFFF0000) | ((u32)current_voltage_1 & 0xFFFF);

            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET, full_reg_write_1);

            break;
        case 'v':
            printf("Resetting Trigger Voltage to 0...\r\n");
            u32 reg_read = FINAL_OSCOPE_mReadReg(
                XPAR_FINAL_OSCOPE_0_BASEADDR,
                FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET
            );
            u32 reg_write = (reg_read & 0xFFFF0000) | 0x0000;
            FINAL_OSCOPE_mWriteReg(
                XPAR_FINAL_OSCOPE_0_BASEADDR,
                FINAL_OSCOPE_S00_AXI_SLV_REG4_OFFSET,
                reg_write
            );

            printf("Trigger Voltage set to 0\r\n");
        break;
        case 'u':
            printf("Display final 64 samples\r\n");
            #define FLAG_CLEAR_BIT (7)
            #define FLAG_Q_BIT (4) 
            #define FLAG_Q_MASK (1 << FLAG_Q_BIT) // slv reg 2 (read from)
            #define FLAG_CLEAR_MASK (1 << FLAG_CLEAR_BIT) // slv reg 3 (write to)

            #define SINGLE_MODE_MASK (1 << 0)
            u32 reg3_config = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, reg3_config | SINGLE_MODE_MASK);

            u32 reg3_initial = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
            FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, reg3_initial & (~FLAG_CLEAR_MASK));


            for (int i = 0; i < 64; i++) {
                
                // wait for 1 falg to be set
                uint32_t current_q_bit;
                printf("Current Q: %u \r\n", current_q_bit);
                u32 slv2_flag_read;
                do {
                    slv2_flag_read = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG2_OFFSET);
                    //current_q_bit = (slv2_flag_read & FLAG_Q_MASK); // Check if Q is set to 1
                } while ((slv2_flag_read & FLAG_Q_MASK) == 0); // Loop until the bit is 1
                printf("Exited do while loop, bit should be 1. Q bit: %d\r\n", current_q_bit);

                // once Q=1
                u32 ch1data_32bit = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG0_OFFSET);
                printf("ch1[%d]: %lu\r\n", i, (unsigned long)ch1data_32bit);

                // clear flag - set to high then to low 
                
                u32 reg3_set_clear = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
                FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, reg3_set_clear | FLAG_CLEAR_MASK);
                u32 reg3_clear_done = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET);
                FINAL_OSCOPE_mWriteReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG3_OFFSET, reg3_clear_done & (~FLAG_CLEAR_MASK));

            }
            printf("64 samples read complete.\r\n");
            break;
        case 'o':
            #define FLAG_Q_MASK_2 (1 << 4)
        for (int i = 0; i < 64; i++) {
                
                // wait for 1 falg to be set
                u32 slv2_flag_read_2 = FINAL_OSCOPE_mReadReg(XPAR_FINAL_OSCOPE_0_BASEADDR, FINAL_OSCOPE_S00_AXI_SLV_REG2_OFFSET);
                uint32_t current_q_bit_2;
                current_q_bit_2 = (slv2_flag_read_2 & FLAG_Q_MASK_2);
                printf("Current Q: %u \r\n", current_q_bit_2);

            }
        break;
        default:
            printf("unrecognized character: %c\r\n",c);
            break;
        } // end case

    } // end while

    return 0;

} // end main



/****************************************************************************/
/**
 *
 * This function sets up the TTC0 timer with an associated ISR
 *
 * @param   None
 *
 * @return  XST_SUCCESS if everything sets up well, XST_FAILURE otherwise.
 *
 * @note        None
 *
 *****************************************************************************/
int SetupIntervalTimerWithInterrupt(void)
{
    int Status;
    TmrCntrSetup    *TimerSetup;
    XTtcPs_Config   *Config;
    XTtcPs          *TtcTimerInstPtr;


    TtcTimerInstPtr = &(TtcPsInst[TTC0_0_DEVICE_ID]);
    TimerSetup = &SettingsTable[TTC0_0_DEVICE_ID];

    /*
     * Set up appropriate options for Ticker: interval mode without
     * waveform output.
     */
    TimerSetup->Options |= (XTTCPS_OPTION_INTERVAL_MODE |
                          XTTCPS_OPTION_WAVE_DISABLE);


    Config = XTtcPs_LookupConfig(TTC0_0_DEVICE_ID);
    if (NULL == Config) {
        return XST_FAILURE;
    }

    /*
     * Initialize the device
     */
    Status = XTtcPs_CfgInitialize(TtcTimerInstPtr, Config, Config->BaseAddress);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /*
     * Set the options
     */
    XTtcPs_SetOptions(TtcTimerInstPtr, TimerSetup->Options);

    /*
     * Timer frequency is preset in the TimerSetup structure,
     * however, the value is not reflected in its other fields, such as
     * IntervalValue and PrescalerValue. The following call will map the
     * frequency to the interval and prescaler values.
     */
    XTtcPs_CalcIntervalFromFreq(TtcTimerInstPtr, TimerSetup->OutputHz,
        &(TimerSetup->Interval), &(TimerSetup->Prescaler));

    /*
     * Set the interval and prescaler
     */
    XTtcPs_SetInterval(TtcTimerInstPtr, TimerSetup->Interval);
    XTtcPs_SetPrescaler(TtcTimerInstPtr, TimerSetup->Prescaler);


    /*
     * Connect to the interrupt controller
     */
    Status = XScuGic_Connect(&InterruptController, TTC0_0_INTR_ID,
        (Xil_ExceptionHandler)XTtcPs_InterruptHandler, (void *)TtcTimerInstPtr);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    XTtcPs_SetStatusHandler(&(TtcPsInst[TTC0_0_DEVICE_ID]), &(TtcPsInst[TTC0_0_DEVICE_ID]),
                          (XTtcPs_StatusHandler)Ttc0IsrHander);

    /*
     * Enable the interrupt for the Timer counter
     */
    XScuGic_Enable(&InterruptController, TTC0_0_INTR_ID);

    /*
     * Enable the interrupts for the tick timer/counter
     * We only care about the interval timeout.
     */
    XTtcPs_EnableInterrupts(TtcTimerInstPtr, XTTCPS_IXR_INTERVAL_MASK);

    /*
     * Start the tick timer/counter
     */
    XTtcPs_Start(TtcTimerInstPtr);

    return Status;
}



/****************************************************************************/
/**
 *
 * This function setups the interrupt system such that interrupts can occur.
 * This function is application specific since the actual system may or may not
 * have an interrupt controller.  The TTC could be directly connected to a
* processor without an interrupt controller.  The user should modify this
 * function to fit the application.
 *
 * @param   IntcDeviceID is the unique ID of the interrupt controller
 * @param   IntcInstacePtr is a pointer to the interrupt controller
 * instance.
 *
 * @return  XST_SUCCESS if successful, otherwise XST_FAILURE.
 *
 * @note        None.
 *
 *****************************************************************************/
static int SetupInterruptSystem(u16 IntcDeviceID,
        XScuGic *IntcInstancePtr)
{
    int Status;
    XScuGic_Config *IntcConfig; /* The configuration parameters of the
                                 interrupt controller */

    /*
     * Initialize the interrupt controller driver
     */
    IntcConfig = XScuGic_LookupConfig(IntcDeviceID);
    if (NULL == IntcConfig) { // <-- 2. FIXED: Changed from Config
        return XST_FAILURE;
    }

    Status = XScuGic_CfgInitialize(IntcInstancePtr, IntcConfig,
        IntcConfig->CpuBaseAddress);
    if (Status != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /*
     * Connect the interrupt controller interrupt handler to the hardware
     * interrupt handling logic in the ARM processor.
     */
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler) XScuGic_InterruptHandler, // <-- 3. FIXED: Removed "fsc" typo
        IntcInstancePtr);

    /*
     * Enable interrupts in the ARM
     */
    Xil_ExceptionEnable();

    return XST_SUCCESS;
}

/***************************************************************************/
/**
 *
 * This function is the handler which handles the periodic TTC0 interrupt.
 *
 * @param   CallBackRef contains a callback reference from the driver, in
 * this case it is the instance pointer for the TTC driver.
 *
 * @return  None.
 *
 * @note    None.
 *
 *************************************************/
static void Ttc0IsrHander(void *CallBackRef, u32 StatusEvent)
{

    static u16 phaseAccumulator = 0;
    u16 lutIndex = 0;
    u8 dutyCycleValue = 128;

    // Do ISR stuff here
    if (generateWave == TRUE) {
        phaseAccumulator += phaseIncrement;
        lutIndex = (phaseAccumulator >> 10);
        //lutIndex = (phaseAccumulator >> 10) & 0x3F;  // Mask to 0-63 range

        if (currentWaveform == WAVE_SINE) {
            dutyCycleValue = sinLut[lutIndex];
        } else {
            dutyCycleValue = sincLut[lutIndex];
        }
        ENHANCEDPWM_AXI_mWriteReg(XPAR_ENHANCEDPWM_AXI_0_BASEADDR , DUTY_CYCLE_OFFSET, dutyCycleValue);
    }
}