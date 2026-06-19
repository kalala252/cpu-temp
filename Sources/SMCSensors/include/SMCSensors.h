#ifndef SMCSENSORS_H
#define SMCSENSORS_H

#ifdef __cplusplus
extern "C" {
#endif

/// Callback invoked once per temperature sensor.
/// - name:  Human readable sensor name (UTF-8, NUL terminated). Never NULL.
/// - value: Temperature in degrees Celsius.
/// - ctx:   Opaque pointer passed through from the caller.
typedef void (*smc_sensor_callback)(const char *name, double value, void *ctx);

/// Enumerates all on-device temperature sensors using the IOHIDEventSystem
/// thermal interface. Works without root on both Apple Silicon and Intel Macs.
void smc_enumerate_temperature_sensors(smc_sensor_callback cb, void *ctx);

/// Enumerates CPU, GPU, SoC, and ANE temperature sensors via the SMC
/// (System Management Controller). Provides actual core temperatures on
/// Apple Silicon where IOHIDEventSystem only exposes PMU sensors.
void smc_enumerate_smc_sensors(smc_sensor_callback cb, void *ctx);

#ifdef __cplusplus
}
#endif

#endif /* SMCSENSORS_H */
