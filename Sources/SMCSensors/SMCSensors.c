#include "SMCSensors.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <mach/mach.h>
#include <string.h>

// --- Private IOKit / IOHIDEventSystem API ----------------------------------
// These symbols are exported by IOKit but have no public headers. They are the
// same interface used by powermetrics and many open-source sensor utilities.

typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient     *IOHIDServiceClientRef;
typedef struct __IOHIDEvent             *IOHIDEventRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int        IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timeout);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kIOHIDEventTypeTemperature 15
#define kIOHIDEventFieldTemperature (kIOHIDEventTypeTemperature << 16)

// kHIDPage_AppleVendor / kHIDUsage_AppleVendor_TemperatureSensor
#define kAppleVendorUsagePage 0xff00
#define kTemperatureSensorUsage 5

static CFDictionaryRef create_matching_dict(void) {
    int page  = kAppleVendorUsagePage;
    int usage = kTemperatureSensorUsage;

    CFNumberRef pageNum  = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
    CFNumberRef usageNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);

    CFStringRef keys[2] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    CFNumberRef vals[2] = { pageNum, usageNum };

    CFDictionaryRef dict = CFDictionaryCreate(
        kCFAllocatorDefault,
        (const void **)keys,
        (const void **)vals,
        2,
        &kCFTypeDictionaryKeyCallBacks,
        &kCFTypeDictionaryValueCallBacks);

    CFRelease(pageNum);
    CFRelease(usageNum);
    return dict;
}

void smc_enumerate_temperature_sensors(smc_sensor_callback cb, void *ctx) {
    if (!cb) return;

    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return;

    CFDictionaryRef match = create_matching_dict();
    IOHIDEventSystemClientSetMatching(client, match);

    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (services) {
        CFIndex count = CFArrayGetCount(services);
        for (CFIndex i = 0; i < count; i++) {
            IOHIDServiceClientRef service =
                (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
            if (!service) continue;

            CFTypeRef nameRef = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
            IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);

            if (event) {
                double temp = IOHIDEventGetFloatValue(event, kIOHIDEventFieldTemperature);

                char nameBuf[256];
                nameBuf[0] = '\0';
                if (nameRef && CFGetTypeID(nameRef) == CFStringGetTypeID()) {
                    CFStringGetCString((CFStringRef)nameRef, nameBuf, sizeof(nameBuf), kCFStringEncodingUTF8);
                }

                cb(nameBuf[0] ? nameBuf : "Unknown", temp, ctx);
                CFRelease(event);
            }

            if (nameRef) CFRelease(nameRef);
        }
        CFRelease(services);
    }

    CFRelease(match);
    CFRelease(client);
}

// --- SMC (System Management Controller) temperature sensors ------------------

typedef struct {
    UInt32 key;
    struct { char major, minor, build, reserved; UInt16 release; } vers;
    struct { UInt16 version, length; UInt32 cpuPLimit, gpuPLimit, memPLimit; } pLimitData;
    struct { UInt32 dataSize, dataType; UInt8 dataAttributes; } keyInfo;
    UInt8 result, status, data8;
    UInt32 data32;
    UInt8 bytes[32];
} SMCKeyData;  // 80 bytes on arm64

static UInt32 smc_fourcc(const char *s) {
    return ((UInt32)(unsigned char)s[0] << 24) | ((UInt32)(unsigned char)s[1] << 16) |
           ((UInt32)(unsigned char)s[2] << 8)  | (unsigned char)s[3];
}

static void smc_fourcc_str(UInt32 k, char out[5]) {
    out[0] = (k >> 24) & 0xff; out[1] = (k >> 16) & 0xff;
    out[2] = (k >> 8) & 0xff;  out[3] = k & 0xff; out[4] = 0;
}

static kern_return_t smc_io(io_connect_t c, SMCKeyData *in, SMCKeyData *out) {
    size_t sz = sizeof(SMCKeyData);
    return IOConnectCallStructMethod(c, 2, in, sizeof(SMCKeyData), out, &sz);
}

#define SMC_CMD_READ  5
#define SMC_CMD_INFO  9
#define SMC_CMD_INDEX 8

void smc_enumerate_smc_sensors(smc_sensor_callback cb, void *ctx) {
    if (!cb) return;

    io_service_t service = IOServiceGetMatchingService(
        kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service) return;

    io_connect_t conn;
    if (IOServiceOpen(service, mach_task_self(), 0, &conn) != KERN_SUCCESS) {
        IOObjectRelease(service);
        return;
    }
    IOObjectRelease(service);

    // Read total key count from "#KEY"
    SMCKeyData in = {0}, out = {0};
    in.key = smc_fourcc("#KEY");
    in.data8 = SMC_CMD_INFO;
    if (smc_io(conn, &in, &out) != KERN_SUCCESS) { IOServiceClose(conn); return; }

    UInt32 ksz = out.keyInfo.dataSize;
    memset(&in, 0, sizeof(in));
    in.key = smc_fourcc("#KEY"); in.data8 = SMC_CMD_READ; in.keyInfo.dataSize = ksz;
    if (smc_io(conn, &in, &out) != KERN_SUCCESS) { IOServiceClose(conn); return; }

    UInt32 total = ((UInt32)out.bytes[0] << 24) | ((UInt32)out.bytes[1] << 16) |
                   ((UInt32)out.bytes[2] << 8)  | out.bytes[3];

    for (UInt32 i = 0; i < total; i++) {
        memset(&in, 0, sizeof(in));
        memset(&out, 0, sizeof(out));
        in.data8 = SMC_CMD_INDEX;
        in.data32 = i;
        if (smc_io(conn, &in, &out) != KERN_SUCCESS) continue;

        char kn[5];
        smc_fourcc_str(out.key, kn);
        if (kn[0] != 'T') continue;

        // Only include CPU (Tp/Te), GPU (Tg), SoC (Ts), ANE (Ta)
        char second = kn[1];
        if (second != 'p' && second != 'e' && second != 'g' &&
            second != 's' && second != 'a') continue;

        UInt32 theKey = out.key;

        // Get key info (data type and size)
        memset(&in, 0, sizeof(in));
        in.key = theKey; in.data8 = SMC_CMD_INFO;
        if (smc_io(conn, &in, &out) != KERN_SUCCESS) continue;
        UInt32 dSize = out.keyInfo.dataSize;
        UInt32 dType = out.keyInfo.dataType;

        // Read value
        memset(&in, 0, sizeof(in));
        in.key = theKey; in.data8 = SMC_CMD_READ; in.keyInfo.dataSize = dSize;
        if (smc_io(conn, &in, &out) != KERN_SUCCESS) continue;

        // Parse temperature (little-endian on Apple Silicon)
        double temp = -999;
        if (dType == smc_fourcc("flt ") && dSize == 4) {
            float f;
            memcpy(&f, out.bytes, 4);
            temp = (double)f;
        } else if (dType == smc_fourcc("sp78") && dSize == 2) {
            int16_t raw = ((int16_t)out.bytes[0] << 8) | out.bytes[1];
            temp = raw / 256.0;
        }
        if (temp < 1.0 || temp > 130.0) continue;

        char name[64];
        switch (second) {
            case 'p': snprintf(name, sizeof(name), "CPU (SMC %s)", kn); break;
            case 'e': snprintf(name, sizeof(name), "CPU (SMC %s)", kn); break;
            case 'g': snprintf(name, sizeof(name), "GPU (SMC %s)", kn); break;
            case 's': snprintf(name, sizeof(name), "SoC (SMC %s)", kn); break;
            case 'a': snprintf(name, sizeof(name), "ANE (SMC %s)", kn); break;
            default:  snprintf(name, sizeof(name), "%s",               kn);    break;
        }

        cb(name, temp, ctx);
    }

    IOServiceClose(conn);
}
