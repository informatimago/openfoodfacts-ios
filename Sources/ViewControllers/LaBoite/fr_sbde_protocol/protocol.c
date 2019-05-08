#include <stdio.h>
#include <string.h>
#include "protocol.h"
#include "runtime.h"
#if defined(Linux) || defined(Darwin)
#include <time.h>
#endif


void fr_sbde_protocol_initialize(out_of_memory_handler user_handle_out_of_memory,
                                 error_handler user_handle_error,
                                 warning_handler user_handle_warning,
                                 verbose_handler user_handle_verbose){
    fr_sbde_protocol_runtime_initialize(user_handle_out_of_memory,
                                        user_handle_error,
                                        user_handle_warning,
                                        user_handle_verbose);}



object* datetime_encode_iso8601(datetime_t datetime){
    char buffer[17]="yyyymmddThhmmssZ";
    sprintf(buffer,"%04u%02u%02uT%02u%02u%02uZ",
            datetime.year,datetime.month,datetime.day,
            datetime.hour,datetime.minute,datetime.second);
    return string_new_with_c_string(buffer);}


datetime_t datetime_decode_iso8601(object* string){
    const char* buffer=string_c_string(string);
    datetime_t datetime;
    sscanf(buffer,"%4hu%2hhu%2hhuT%2hhu%2hhu%2hhuZ",
           &datetime.year,&datetime.month,&datetime.day,
           &datetime.hour,&datetime.minute,&datetime.second);
    return datetime;}

#if defined(Linux) || defined(Darwin)
datetime_t datetime_now(void){
    static datetime_t result;
    static time_t last=0;
    time_t clock=time(NULL);
    if(last!=clock){
        struct tm now;
        last=clock;
        gmtime_r(&clock,&now);
        result.year=now.tm_year+1900;
        result.month=now.tm_mon+1;
        result.day=now.tm_mday;
        result.hour=now.tm_hour;
        result.minute=now.tm_min;
        result.second=now.tm_sec;}
    return result;}
#endif

bool datetime_equal(datetime_t a,datetime_t b){
    return (a.year==b.year)
            &&(a.month==b.month)
            &&(a.day==b.day)
            &&(a.hour==b.hour)
            &&(a.minute==b.minute)
            &&(a.second==b.second);}

bool long_int_equal(long int a,long int b){
    return a==b;}

bool float_equal(float a,float b){
    return a==b;}

bool cstring_equal(const char* a,const char* b){
    return 0==strcmp(a,b);}

void* rawpointer(void* pointer){
    return pointer;}

int cstring_length(void* cstring){
    if(cstring==NULL){
        return 0;}
    return (int)strlen((char*)cstring);}

int cstring_ref(void* cstring,int index){
    if((cstring==NULL)||(index<0)){
        return 0;}
    return ((unsigned char*)cstring)[index];}

unsigned char* UMP_UInt8(void* pointer){
    return (unsigned char*)pointer;}

const char* cstring_from_UMP_UInt8(unsigned char* pointer){
    return (const char*)pointer;}

//// THE END ////


