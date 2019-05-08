#include <string.h>
#include "protocol.h"
#include "runtime.h"
#include "controller-ua-client.h"
#define S(name) symbol_intern(string_new_with_c_string(#name))
#define I(val)  integer_new(val)
#define F(val)  floating_new(val)
#define T(val)  string_new_with_c_string(val)
controller_ua_message* controller_ua_client_parse(const char* message){
    if(message==NULL){return NULL;}
    controller_ua_message* result=NULL;
    object* eof=cons(nil,nil);
    object* msg=read_from_string(string_new_with_c_string(message),eof,0,0);
    object* key=NULL;
    if((msg==NULL)||(msg==eof)){ goto done; }
    msg=car(msg);
    if(bool_not(consp(msg))){ goto done; }
    key=car(msg);
    if(object_equal(key,S(VERSION))){
        object* cur=cdr(msg);
        long int version;
        datetime_t time;
        if(integerp(car(cur))){
            version=integer_value(car(cur));
        }else{goto done;}
        cur=cdr(cur);
        if(consp(car(cur))
           && object_equal(caar(cur),S(TIME))
           && stringp(cadr(car(cur)))
           && null(cddr(car(cur)))){
            time=datetime_decode_iso8601(cadr(car(cur)));
        }else{goto done;}
        cur=cdr(cur);
        if(bool_not(null(cur))){
            goto done;}
        result=controller_ua_version_new(version,time);
    }else
    if(object_equal(key,S(SCALES-MEASURE))){
        object* cur=cdr(msg);
        float mass;
        long int slot;
        if(consp(car(cur))
           && object_equal(caar(cur),S(MASS))
           && floatp(cadr(car(cur)))
           && null(cddr(car(cur)))){
            mass=floating_value(cadr(car(cur)));
        }else{goto done;}
        cur=cdr(cur);
        if(consp(car(cur))
           && object_equal(caar(cur),S(SLOT))
           && integerp(cadr(car(cur)))
           && null(cddr(car(cur)))){
            slot=integer_value(cadr(car(cur)));
        }else{goto done;}
        cur=cdr(cur);
        if(bool_not(null(cur))){
            goto done;}
        result=controller_ua_scales_measure_new(mass,slot);
    }else
{goto done;}
  done:
    autorelease_pool_release();
    return result;
}
char* controller_ua_client_format(controller_ua_message* that){
    object* message=NULL;
    switch(that->kind){
    case controller_ua_message_version:
        message=list(S(VERSION),
                       integer_new(that->message.version.version),
                       list(S(TIME),datetime_encode_iso8601(that->message.version.time),NULL),
                             NULL);
        break;
    case controller_ua_message_scales_start:
        message=list(S(SCALES-START),
                       list(S(TIME),datetime_encode_iso8601(that->message.scales_start.time),NULL),
                       list(S(SLOT),integer_new(that->message.scales_start.slot),NULL),
                             NULL);
        break;
    case controller_ua_message_scales_query:
        message=list(S(SCALES-QUERY),
                       list(S(TIME),datetime_encode_iso8601(that->message.scales_query.time),NULL),
                       list(S(SLOT),integer_new(that->message.scales_query.slot),NULL),
                             NULL);
        break;
    case controller_ua_message_scales_stop:
        message=list(S(SCALES-STOP),
                       list(S(TIME),datetime_encode_iso8601(that->message.scales_stop.time),NULL),
                       list(S(SLOT),integer_new(that->message.scales_stop.slot),NULL),
                             NULL);
        break;
    default:
        return NULL;
    }
    char* result=(char*)check_memory(strdup(string_c_string(prin1_to_string(message))),0);
    autorelease_pool_release();
    return result;
}
