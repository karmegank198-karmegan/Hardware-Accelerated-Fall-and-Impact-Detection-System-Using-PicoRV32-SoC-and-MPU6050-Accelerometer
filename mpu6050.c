#include "mpu6050.h"
#include "i2c.h"

int mpu6050_init(void)
{
    uint8_t id;

    /* Verify that the sensor responds. */
    if (i2c_read_reg(MPU6050_ADDR,
                     MPU6050_WHO_AM_I,
                     &id) != 0)
    {
        return -1;
    }

    if (id != 0x68)
    {
        return -2;
    }

    /* Wake up the MPU6050. */
    if (i2c_write_reg(MPU6050_ADDR,
                      MPU6050_PWR_MGMT_1,
                      0x00) != 0)
    {
        return -3;
    }

    /* Set accelerometer range to +/-4g. */
    if (i2c_write_reg(MPU6050_ADDR,
                      MPU6050_ACCEL_CONFIG,
                      0x08) != 0)
    {
        return -4;
    }

    return 0;
}

int mpu6050_read(MPU6050_Data *data)
{
    uint8_t raw[6];

    if (data == 0)
        return -1;

    /* Read registers 0x3B through 0x40. */
    if (i2c_read_regs(MPU6050_ADDR,
                      MPU6050_ACCEL_XOUT_H,
                      raw,
                      6) != 0)
    {
        return -2;
    }

    data->x = (int16_t)(
        ((uint16_t)raw[0] << 8) | raw[1]
    );

    data->y = (int16_t)(
        ((uint16_t)raw[2] << 8) | raw[3]
    );

    data->z = (int16_t)(
        ((uint16_t)raw[4] << 8) | raw[5]
    );

    return 0;
}
