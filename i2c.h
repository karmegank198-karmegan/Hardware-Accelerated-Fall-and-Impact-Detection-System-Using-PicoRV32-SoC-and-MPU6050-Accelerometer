#ifndef I2C_H
#define I2C_H

#include <stdint.h>

int i2c_init(void);

int i2c_write_reg(uint8_t device_address,
                  uint8_t register_address,
                  uint8_t value);

int i2c_read_reg(uint8_t device_address,
                 uint8_t register_address,
                 uint8_t *value);

int i2c_read_regs(uint8_t device_address,
                  uint8_t first_register,
                  uint8_t *buffer,
                  uint32_t length);

#endif
