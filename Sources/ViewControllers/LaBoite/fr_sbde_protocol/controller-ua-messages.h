#ifndef controller_ua_messages_h
#define controller_ua_messages_h
#include "protocol.h"
typedef enum {
    controller_ua_message_version,
    controller_ua_message_scales_start,
    controller_ua_message_scales_query,
    controller_ua_message_scales_stop,
    controller_ua_message_scales_measure,
} controller_ua_message_kind;
typedef struct {
    controller_ua_message_kind kind;
    union {
        struct {
            long int version;
            datetime_t time;
        } version;
        struct {
            datetime_t time;
            long int slot;
        } scales_start;
        struct {
            datetime_t time;
            long int slot;
        } scales_query;
        struct {
            datetime_t time;
            long int slot;
        } scales_stop;
        struct {
            float mass;
            long int slot;
        } scales_measure;
    } message;
} controller_ua_message;
controller_ua_message* controller_ua_version_new(long int version,datetime_t time);
controller_ua_message* controller_ua_scales_start_new(datetime_t time,long int slot);
controller_ua_message* controller_ua_scales_query_new(datetime_t time,long int slot);
controller_ua_message* controller_ua_scales_stop_new(datetime_t time,long int slot);
controller_ua_message* controller_ua_scales_measure_new(float mass,long int slot);
void controller_ua_message_free(controller_ua_message* that);
bool controller_ua_message_equal(controller_ua_message* that,controller_ua_message* thot);
#endif
