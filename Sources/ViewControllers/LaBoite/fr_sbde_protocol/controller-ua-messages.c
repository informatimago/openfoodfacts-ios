#include <string.h>
#include "protocol.h"
#include "runtime.h"
#include "controller-ua-messages.h"
controller_ua_message* controller_ua_version_new(long int version_number,datetime_t datetime){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_version;
        that->message.version.version_number=version_number;
        that->message.version.datetime=datetime;
    }
    return that;
}
controller_ua_message* controller_ua_tare_set_new(long int slot_index){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_tare_set;
        that->message.tare_set.slot_index=slot_index;
    }
    return that;
}
controller_ua_message* controller_ua_calibration_new(long int slot_index,float mass){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_calibration;
        that->message.calibration.slot_index=slot_index;
        that->message.calibration.mass=mass;
    }
    return that;
}
controller_ua_message* controller_ua_scales_start_new(datetime_t datetime,long int slot_index){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_start;
        that->message.scales_start.datetime=datetime;
        that->message.scales_start.slot_index=slot_index;
    }
    return that;
}
controller_ua_message* controller_ua_scales_query_new(datetime_t datetime,long int slot_index){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_query;
        that->message.scales_query.datetime=datetime;
        that->message.scales_query.slot_index=slot_index;
    }
    return that;
}
controller_ua_message* controller_ua_scales_stop_new(datetime_t datetime,long int slot_index){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_stop;
        that->message.scales_stop.datetime=datetime;
        that->message.scales_stop.slot_index=slot_index;
    }
    return that;
}
controller_ua_message* controller_ua_scales_measure_new(float mass,long int slot_index){
    controller_ua_message* that=(controller_ua_message*)checked_malloc(sizeof(controller_ua_message));
    if(that!=NULL){
        that->kind=controller_ua_message_scales_measure;
        that->message.scales_measure.mass=mass;
        that->message.scales_measure.slot_index=slot_index;
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
            if(bool_not(long_int_equal(that->message.version.version_number,thot->message.version.version_number))){return false;}
            if(bool_not(datetime_equal(that->message.version.datetime,thot->message.version.datetime))){return false;}
            return true;
        case controller_ua_message_tare_set:
            if(bool_not(long_int_equal(that->message.tare_set.slot_index,thot->message.tare_set.slot_index))){return false;}
            return true;
        case controller_ua_message_calibration:
            if(bool_not(long_int_equal(that->message.calibration.slot_index,thot->message.calibration.slot_index))){return false;}
            if(bool_not(float_equal(that->message.calibration.mass,thot->message.calibration.mass))){return false;}
            return true;
        case controller_ua_message_scales_start:
            if(bool_not(datetime_equal(that->message.scales_start.datetime,thot->message.scales_start.datetime))){return false;}
            if(bool_not(long_int_equal(that->message.scales_start.slot_index,thot->message.scales_start.slot_index))){return false;}
            return true;
        case controller_ua_message_scales_query:
            if(bool_not(datetime_equal(that->message.scales_query.datetime,thot->message.scales_query.datetime))){return false;}
            if(bool_not(long_int_equal(that->message.scales_query.slot_index,thot->message.scales_query.slot_index))){return false;}
            return true;
        case controller_ua_message_scales_stop:
            if(bool_not(datetime_equal(that->message.scales_stop.datetime,thot->message.scales_stop.datetime))){return false;}
            if(bool_not(long_int_equal(that->message.scales_stop.slot_index,thot->message.scales_stop.slot_index))){return false;}
            return true;
        case controller_ua_message_scales_measure:
            if(bool_not(float_equal(that->message.scales_measure.mass,thot->message.scales_measure.mass))){return false;}
            if(bool_not(long_int_equal(that->message.scales_measure.slot_index,thot->message.scales_measure.slot_index))){return false;}
            return true;
    default:
        return false;
    }
}
