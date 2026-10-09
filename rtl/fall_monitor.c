/*
 * fall_monitor.c
 *
 * PicoRV32 firmware for the memory-mapped fall-detection peripheral.
 *
 * Peripheral map:
 *   0x04000000 STATUS/MAGNITUDE
 *      bit 0      fall_detected
 *      bit 1      free_fall
 *      bit 2      impact
 *      bits 31:16 magnitude_mg[15:0]
 *   0x04000004 ACCEL_X (sign-extended)
 *   0x04000008 ACCEL_Y in bits 15:0, ACCEL_Z in bits 31:16
 *
 * PicoSoC simple UART:
 *   0x02000004 UART baud divider
 *   0x02000008 UART data register
 *
 * The program must be built with a RISC-V bare-metal toolchain and linked
 * for the actual boot arrangement used by your PicoSoC/board. This C file
 * alone does not program the SPI flash or create a linker script.
 */

#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))

#define FALL_STATUS_ADDR  0x04000000u
#define FALL_ACCEL_X_ADDR 0x04000004u
#define FALL_ACCEL_YZ_ADDR 0x04000008u

#define UART_DIV_ADDR     0x02000004u
#define UART_DATA_ADDR    0x02000008u

#define STATUS_FALL       (1u << 0)
#define STATUS_FREE_FALL  (1u << 1)
#define STATUS_IMPACT     (1u << 2)

/* Change this if your system clock or target baud rate differs. */
#ifndef CLK_FREQ_HZ
#define CLK_FREQ_HZ 50000000u
#endif
#ifndef UART_BAUD
#define UART_BAUD 115200u
#endif

static void uart_putc(char c)
{
    /*
     * PicoSoC simpleuart uses the data register write as the transmit
     * operation. Its bus wait logic stalls accesses while transmission
     * is busy, so ordinary volatile writes are used here.
     */
    REG32(UART_DATA_ADDR) = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

static void uart_put_u32(uint32_t value)
{
    char digits[10];
    unsigned int n = 0;

    if (value == 0) {
        uart_putc('0');
        return;
    }

    while (value && n < sizeof(digits)) {
        digits[n++] = (char)('0' + (value % 10u));
        value /= 10u;
    }

    while (n > 0)
        uart_putc(digits[--n]);
}

static void uart_init(void)
{
    /* simpleuart divider is based on system clock / baud rate. */
    REG32(UART_DIV_ADDR) = (CLK_FREQ_HZ / UART_BAUD) - 1u;
}

static void delay(volatile uint32_t count)
{
    while (count--)
        __asm__ volatile ("" ::: "memory");
}

int main(void)
{
    uint32_t previous_status = 0xFFFFFFFFu;

    uart_init();
    uart_puts("\r\nPicoRV32 fall monitor started\r\n");

    for (;;) {
        uint32_t status = REG32(FALL_STATUS_ADDR);
        uint32_t magnitude_mg = (status >> 16) & 0xFFFFu;

        if (status != previous_status) {
            if (status & STATUS_FALL) {
                uart_puts("ALERT: FALL DETECTED, magnitude=");
                uart_put_u32(magnitude_mg);
                uart_puts(" mg\r\n");
            } else if (status & STATUS_FREE_FALL) {
                uart_puts("INFO: free-fall condition\r\n");
            } else if (status & STATUS_IMPACT) {
                uart_puts("INFO: impact detected\r\n");
            }

            previous_status = status;
        }

        /* Keep the polling rate reasonable for UART output. */
        delay(100000u);
    }

    return 0;
}
