#include <stdint.h>

/* =========================================================
   PicoRV32 MEMORY-MAPPED REGISTERS
   ========================================================= */

/* UART registers */
#define UART_DIV_REG \
    (*(volatile uint32_t *)0x02000004)

#define UART_DATA_REG \
    (*(volatile uint32_t *)0x02000008)

/* Fall detection peripheral registers */
#define FALL_STATUS_REG \
    (*(volatile uint32_t *)0x04000000)

#define ACCEL_X_REG \
    (*(volatile uint32_t *)0x04000004)

#define ACCEL_YZ_REG \
    (*(volatile uint32_t *)0x04000008)

/* =========================================================
   FALL STATUS BITS
   Verify these bit assignments against fall_peripheral.v.
   ========================================================= */

#define FALL_BIT       (1U << 0)
#define FREE_FALL_BIT  (1U << 1)
#define IMPACT_BIT     (1U << 2)

/* =========================================================
   UART CONFIGURATION
   ========================================================= */

/*
 * Example: 100 MHz clock / 115200 baud ~= 868.
 *
 * This value is valid only if the UART divisor convention
 * and actual clock frequency match your RTL.
 */
#define UART_DIVISOR 868U
static void uart_print_decimal(uint32_t value);

/* =========================================================
   UART FUNCTIONS
   ========================================================= */

static void uart_init(void)
{
    UART_DIV_REG = UART_DIVISOR;
}

static void uart_putc(char c)
{
    UART_DATA_REG = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *str)
{
    while (*str != '\0')
    {
        if (*str == '\n')
        {
            uart_putc('\r');
        }

        uart_putc(*str);
        str++;
    }
}

static void uart_print_hex(uint32_t value)
{
    static const char hex_digits[] = "0123456789ABCDEF";

    uart_puts("0x");

    for (int shift = 28; shift >= 0; shift -= 4)
    {
        uart_putc(hex_digits[(value >> shift) & 0x0FU]);
    }
}

static void uart_print_signed16(int16_t value)
{
    if (value < 0)
    {
        uart_putc('-');

        /*
         * Widen before negating to avoid signed 16-bit
         * overflow for -32768.
         */
        uint32_t magnitude = (uint32_t)(-(int32_t)value);

        uart_print_decimal(magnitude);
    }
    else
    {
        uart_print_decimal((uint32_t)value);
    }
}

static void uart_print_decimal(uint32_t value)
{
    char buffer[10];
    int count = 0;

    if (value == 0U)
    {
        uart_putc('0');
        return;
    }

    while (value > 0U && count < (int)sizeof(buffer))
    {
        buffer[count++] = (char)('0' + (value % 10U));
        value /= 10U;
    }

    while (count > 0)
    {
        uart_putc(buffer[--count]);
    }
}

/* =========================================================
   ACCELERATION REGISTER EXTRACTION
   ========================================================= */

/*
 * Assumed register layout at 0x04000008:
 *
 * Bits [15:0]  = Y-axis acceleration
 * Bits [31:16] = Z-axis acceleration
 *
 * Confirm this layout in fall_peripheral.v.
 */

static int16_t get_y_acceleration(uint32_t yz)
{
    return (int16_t)(yz & 0xFFFFU);
}

static int16_t get_z_acceleration(uint32_t yz)
{
    return (int16_t)((yz >> 16) & 0xFFFFU);
}

/* =========================================================
   DELAY
   ========================================================= */

/*
 * Approximate software delay only.
 * Its duration depends on CPU clock and compiler settings.
 */

static void delay(volatile uint32_t count)
{
    while (count > 0U)
    {
        count--;
    }
}

/* =========================================================
   MAIN PROGRAM
   ========================================================= */

int main(void)
{
    uart_init();

    uart_puts("\n");
    uart_puts("================================\n");
    uart_puts(" PicoRV32 Fall Detection System\n");
    uart_puts(" MPU6050 Accelerometer Monitoring\n");
    uart_puts("================================\n");

    uart_puts("Firmware started.\n");
    uart_puts("Monitoring hardware registers...\n\n");

    while (1)
    {
        /* Read the memory-mapped hardware registers. */
        uint32_t status = FALL_STATUS_REG;
        uint32_t x_raw  = ACCEL_X_REG;
        uint32_t yz_raw = ACCEL_YZ_REG;

        /* Interpret the register values. */
        int16_t x_accel = (int16_t)(x_raw & 0xFFFFU);
        int16_t y_accel = get_y_acceleration(yz_raw);
        int16_t z_accel = get_z_acceleration(yz_raw);

        /* Extract the upper 16-bit magnitude field. */
        uint32_t magnitude = (status >> 16) & 0xFFFFU;

        /* Print raw register values. */
        uart_puts("Status: ");
        uart_print_hex(status);
        uart_puts("\n");

        uart_puts("X raw: ");
        uart_print_signed16(x_accel);
        uart_puts("\n");

        uart_puts("Y raw: ");
        uart_print_signed16(y_accel);
        uart_puts("\n");

        uart_puts("Z raw: ");
        uart_print_signed16(z_accel);
        uart_puts("\n");

        uart_puts("Magnitude field: ");
        uart_print_decimal(magnitude);
        uart_puts("\n");

        /* Report detection status. */
        if (status & FALL_BIT)
        {
            uart_puts("ALERT: FALL DETECTED!\n");
        }
        else
        {
            uart_puts("Fall: Not detected\n");
        }

        if (status & FREE_FALL_BIT)
        {
            uart_puts("Event: FREE FALL\n");
        }

        if (status & IMPACT_BIT)
        {
            uart_puts("Event: IMPACT DETECTED\n");
        }

        uart_puts("--------------------------------\n");

        delay(100000U);
    }

    return 0;
}
