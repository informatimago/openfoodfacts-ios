#ifndef fr_sbde_protocol_protocol_h
#define fr_sbde_protocol_protocol_h
#include <stdint.h>
#include "error.h"
#include "runtime.h"


/*
Passing NULLs makes it use the default handlers.
*/
void fr_sbde_protocol_initialize(out_of_memory_handler user_handle_out_of_memory,
                                 error_handler user_handle_error,
                                 warning_handler user_handle_warning,
                                 verbose_handler user_handle_verbose);


typedef struct {
    /* date and time in UTC */
    uint16_t year;   /* 2019 .. 3019 */
    uint8_t  month;  /* 1 .. 12 */
    uint8_t  day;    /* 1 .. 31 */
    uint8_t  hour;   /* 0 .. 23 */
    uint8_t  minute; /* 0 .. 59 */
    uint8_t  second; /* 0 .. 59 */
} datetime_t;

object* datetime_encode_iso8601(datetime_t datetime);
datetime_t datetime_decode_iso8601(object* string);
bool datetime_equal(datetime_t a,datetime_t b);

#if defined(Linux) || defined(Darwin)
datetime_t datetime_now(void);
#endif

bool long_int_equal(long int a,long int b);
bool float_equal(float a,float b);
bool cstring_equal(const char* a,const char* b);

void* rawpointer(void* pointer);
int cstring_length(void* cstring);
int cstring_ref(void* cstring,int index);

unsigned char* UMP_UInt8(void* pointer);
const char* cstring_from_UMP_UInt8(unsigned char* pointer);
#endif

