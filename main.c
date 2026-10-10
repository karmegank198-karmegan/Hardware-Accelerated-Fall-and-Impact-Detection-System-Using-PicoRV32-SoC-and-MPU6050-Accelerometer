#include <stdint.h>

/*
 * Hardware-Accelerated Fall and Impact Detection
 * Processor: PicoRV32
 * Sensor: MPU6050
 *
 * Assumed peripheral register map:
 * 0x04000000 : Status and acceleration magnitude
 * 0x04000004 : X-axis acceleration
 * 0x04000008 : Y-axis and Z-axis acceleration
 *
 * UART registers:
 * 0x02000004 : Baud-rate divisor
 * 0x02000008 : UART data
 */

/* UART register addresses */
#define UART_DIV_REG   (*(volatile uint32_t *)0x02000004)
#define UART_DATA_REG  (*(volatile uint32_t *)0x02000008)

/* Fall-detection peripheral registers */
#define FALL_STATUS_REG (*(volatile uint32_t *)0x04000000)
#define ACCEL_X_REG     (*(volatile uint32_t *)0x04000004)
#define ACCEL_YZ_REG    (*(volatile uint32_t *)0x04000008)

/* Status bits */
#define FALL_BIT       (1U << 0)
#define FREE_FALL_BIT  (1U << 1)
#define IMPACT_BIT     (1U << 2)

/*
 * Initialize UART.
 *
 * Assumption: 100 MHz clock and approximately 115200 baud.
 * Verify the divisor convention in the simpleuart implementation.
 */
static void uart_init(void)
{
    UART_DIV_REG = 868;
}

/* Transmit one character */
static void uart_putc(char c)
{
    UART_DATA_REG = (uint32_t)(uint8_t)c;
}

/* Transmit a string */
static void uart_puts(const char *s)
{
    while (*s != '\0') {
        if (*s == '\n') {
            uart_putc('\r');
        }

        uart_putc(*s);
        s++;
    }
}

/* Print an unsigned 32-bit value in hexadecimal */
static void uart_print_hex(uint32_t value)
{
    static const char hex_digits[] = "0123456789ABCDEF";

    uart_puts("0x");

    for (int shift = 28; shift >= 0; shift -= 4) {
        uart_putc(hex_digits[(value >> shift) & 0xFU]);
    }
}

/* Print a signed 16-bit acceleration value */
static void uart_print_signed16(uint32_t value)
{
    int32_t signed_value = (int16_t)(value & 0xFFFFU);

    if (signed_value < 0) {
        uart_putc('-');
        signed_value = -signed_value;
    }

    if (signed_value >= 10000) {
        uart_putc('0' + (signed_value / 10000));
        signed_value %= 10000;
    }

    if (signed_value >= 1000) {
        uart_putc('0' + (signed_value / 1000));
        signed_value %= 1000;
    }

    if (signed_value >= 100) {
        uart_putc('0' + (signed_value / 100));
        signed_value %= 100;
    }

    if (signed_value >= 10) {
        uart_putc('0' + (signed_value / 10));
        signed_value %= 10;
    }

    uart_putc('0' + signed_value);
}

/* Simple delay to reduce UART output frequency */
static void delay(void)
{
    for (volatile uint32_t i = 0; i < 1000000U; i++) {
        __asm__ volatile ("nop");
    }
}

int main(void)
{
    uint32_t status;
    uint32_t axis_x;
    uint32_t axis_yz;

    uart_init();

    uart_puts("\n");
    uart_puts("================================\n");
    uart_puts(" PicoRV32 Fall Detection System\n");
    uart_puts(" MPU6050 Hardware Interface\n");
    uart_puts("================================\n");

    while (1) {

        /* Read hardware peripheral registers */
        status = FALL_STATUS_REG;
        axis_x = ACCEL_X_REG;
        axis_yz = ACCEL_YZ_REG;

        /* Decode acceleration values */
        int16_t x = (int16_t)(axis_x & 0xFFFFU);
        int16_t y = (int16_t)(axis_yz & 0xFFFFU);
        int16_t z = (int16_t)((axis_yz >> 16) & 0xFFFFU);

        /* Extract detector flags */
        uint32_t fall = status & FALL_BIT;
        uint32_t free_fall = status & FREE_FALL_BIT;
        uint32_t impact = status & IMPACT_BIT;

        /* Extract the assumed 16-bit magnitude field */
        uint32_t magnitude_mg = (status >> 16) & 0xFFFFU;

        uart_puts("\n--- Sensor Reading ---\n");

        uart_puts("Acceleration X: ");
        uart_print_signed16((uint16_t)x);
        uart_puts("\n");

        uart_puts("Acceleration Y: ");
        uart_print_signed16((uint16_t)y);
        uart_puts("\n");

        uart_puts("Acceleration Z: ");
        uart_print_signed16((uint16_t)z);
        uart_puts("\n");

        uart_puts("Raw status register: ");
        uart_print_hex(status);
        uart_puts("\n");

        uart_puts("Magnitude (assuming mg): ");
        uart_print_hex(magnitude_mg);
        uart_puts("\n");

        if (free_fall) {
            uart_puts("WARNING: FREE FALL DETECTED!\n");
        }

        if (impact) {
            uart_puts("WARNING: IMPACT DETECTED!\n");
        }

        if (fall) {
            uart_puts("ALERT: FALL DETECTED!\n");
        } else {
            uart_puts("Status: No latched fall detected\n");
        }

        delay();
    }

    return 0;
}
