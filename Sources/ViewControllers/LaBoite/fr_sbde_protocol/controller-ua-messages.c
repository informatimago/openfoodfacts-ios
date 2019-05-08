#include <string.h>
#include "protocol.h"
#include "runtime.h"
#include "controller-ua-messages.h"
controller_ua_message* controller_ua_version_new(long int version,datetime_t time){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_version;
        that->message.version.version=version;
        that->message.version.time=time;
    }
    return that;
}
controller_ua_message* controller_ua_scales_start_new(datetime_t time,long int slot){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_start;
        that->message.scales_start.time=time;
        that->message.scales_start.slot=slot;
    }
    return that;
}
controller_ua_message* controller_ua_scales_query_new(datetime_t time,long int slot){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_query;
        that->message.scales_query.time=time;
        that->message.scales_query.slot=slot;
    }
    return that;
}
controller_ua_message* controller_ua_scales_stop_new(datetime_t time,long int slot){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_stop;
        that->message.scales_stop.time=time;
        that->message.scales_stop.slot=slot;
    }
    return that;
}
controller_ua_message* controller_ua_scales_measure_new(float mass,long int slot){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_measure;
        that->message.scales_measure.mass=mass;
        that->message.scales_measure.slot=slot;
    }
    return that;
}
void controller_ua_message_free(controller_ua_message* that){
    free(that);
}
bool controller_ua_message_equal(controller_ua_message* that,controller_ua_message* thot){
    if((that==NULL)||(thot==NULL)){return false;}
    if(that->kind!=thot->kind){return false;}
    switch(that->kind){
        case controller_ua_message_version:
            if(bool_not(long_int_equal(that->message.version.version,thot->message.version.version))){return false;}
            if(bool_not(datetime_equal(that->message.version.time,thot->message.version.time))){return false;}
            return true;
        case controller_ua_message_scales_start:
            if(bool_not(datetime_equal(that->message.scales_start.time,thot->message.scales_start.time))){return false;}
            if(bool_not(long_int_equal(that->message.scales_start.slot,thot->message.scales_start.slot))){return false;}
            return true;
        case controller_ua_message_scales_query:
            if(bool_not(datetime_equal(that->message.scales_query.time,thot->message.scales_query.time))){return false;}
            if(bool_not(long_int_equal(that->message.scales_query.slot,thot->message.scales_query.slot))){return false;}
            return true;
        case controller_ua_message_scales_stop:
            if(bool_not(datetime_equal(that->message.scales_stop.time,thot->message.scales_stop.time))){return false;}
            if(bool_not(long_int_equal(that->message.scales_stop.slot,thot->message.scales_stop.slot))){return false;}
            return true;
        case controller_ua_message_scales_measure:
            if(bool_not(float_equal(that->message.scales_measure.mass,thot->message.scales_measure.mass))){return false;}
            if(bool_not(long_int_equal(that->message.scales_measure.slot,thot->message.scales_measure.slot))){return false;}
            return true;
    default:
        return false;
    }
}
