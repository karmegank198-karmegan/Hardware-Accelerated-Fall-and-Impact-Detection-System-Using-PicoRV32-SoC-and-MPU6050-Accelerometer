#ifndef MPU6050_H
#define MPU6050_H

#include <stdint.h>

#define MPU6050_ADDR          0x68

#define MPU6050_WHO_AM_I      0x75
#define MPU6050_PWR_MGMT_1    0x6B
#define MPU6050_ACCEL_CONFIG  0x1C
#define MPU6050_ACCEL_XOUT_H  0x3B

typedef struct
{
    int16_t x;
    int16_t y;
    int16_t z;
} MPU6050_Data;

int mpu6050_init(void);
int mpu6050_read(MPU6050_Data *data);

#endif
