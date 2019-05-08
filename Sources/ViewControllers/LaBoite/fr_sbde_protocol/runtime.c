// -*- mode:c;coding:utf-8 -*-
//****************************************************************************
//FILE:               runtime.c
//LANGUAGE:           c
//SYSTEM:             POSIX
//USER-INTERFACE:     NONE
//DESCRIPTION
//
//    Implements the protocol runtime.
//
//AUTHORS
//    <PJB> Pascal J. Bourguignon <pjb@informatimago.com>
//MODIFICATIONS
//    2019-04-05 <PJB> Created.
//BUGS
//LEGAL
//    Proprietary
//
//    Copyright SBDE SAS ACV 2019 - 2019
//
//    All Rights Reserved.
//
//    This program and its documentation constitute intellectual property
//    of SBDE SAS ACV and is protected by the copyright laws of
//    the European Union and other countries.
//****************************************************************************
#include <stdio.h>
#include <stdint.h>
#include <limits.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>
#include <math.h>
#include <pthread.h>
#if defined(Linux) || defined(Darwin)
#include <sysexits.h>
#endif
#ifndef Darwin
int digittoint(int ch){
    return ch-'0';}
#endif
#include "runtime.h"



#define object_header \
    type_tag tag; \
    long int retain_count

typedef struct object {
    object_header;
} object;

void object_header_init(object* object,type_tag tag){
    object->tag=tag;
    object->retain_count=0;}


typedef struct {
    object_header;
    long int value;;
} integer_t;

typedef struct {
    object_header;
    float value;
} floating_t;

typedef struct {
    object_header;
    void* cdata;
    destructor_pr destructor;
} wrapper_t;

typedef struct {
    object_header;
    size_t capacity;
    size_t length;
    char* characters;
} string_t;

typedef struct {
    object_header;
    object* name;
} symbol_t;

typedef struct {
    object_header;
    object* car;
    object* cdr;
} cons_t;

typedef struct {
    object_header;
    test_pr test;
    size_t element_count;
    size_t bucket_count;
    object** buckets;
} hashtable_t;


static void object_free(object* object);
static void string_free(object* object);
static void cons_free(object* object);
static void hashtable_free(object* object);
static void wrapper_free(object* wrapper);
long int integer_sxhash(object* integer);
long int floating_sxhash(object* floating);
long int string_sxhash(object* string);
long int symbol_sxhash(object* symbol);
long int cons_sxhash(object* cons);
long int hashtable_sxhash(object* table);
long int wrapper_sxhash(object* wrapper);


void out_of_bound_error(object* that,size_t index,size_t length){
}

void type_error(object* that,type_tag tag){
}

bool check_type(object* object,type_tag tag){
    if(object_type(object)==tag){
        return true;}
    else{
        type_error(object,tag);
        return false;}}


type_tag object_type(object* obj){
    if(obj==NULL){return type_null;}
    return obj->tag;}

object* nil=NULL;

bool null(void* obj){return (obj==NULL) || object_eql(nil,(object*)obj);}
bool stringp(object* obj){return object_type(obj)==type_string;}
bool symbolp(object* obj){return object_type(obj)==type_symbol;}
bool integerp(object* obj){return object_type(obj)==type_integer;}
bool floatp(object* obj){return object_type(obj)==type_floating;}
bool consp(object* obj){return object_type(obj)==type_cons;}
bool hashtablep(object* obj){return object_type(obj)==type_hashtable;}
bool wrapper(object* obj){return object_type(obj)==type_wrapper;}

static pthread_key_t autorelease_pool_key;

object* autorelease_pool(){
    return (object*)pthread_getspecific(autorelease_pool_key);}

void set_autorelease_pool(object* new_pool){
    int res=pthread_setspecific(autorelease_pool_key,new_pool);
    if(res<0){
        ERROR(EX_OSERR,"pthread_setspecific signaled error: %s",strerror(res));}}


void autorelease_pool_initialize(){
    int res=pthread_key_create(&autorelease_pool_key,
                               (destructor_pr)object_release);
    if(res<0){
        ERROR(EX_OSERR,"pthread_key_create signaled error: %s",strerror(res));
    }
    set_autorelease_pool(NULL);
}

object* object_retain(object* object){
    if(null(object)){return object;}
    object->retain_count++;
    return object;}

void object_release(object* object){
    if(null(object)){return;}
    object->retain_count--;
    if(object->retain_count==0){
        object_free(object);}}

object* autorelease_cons(object* car,object* cdr){
    cons_t* that=(cons_t*)checked_malloc(sizeof(*that));
    if(that==NULL){return NULL;}
    object_header_init((object*)that,type_cons);
    that->car=object_retain(car);
    that->cdr=object_retain(cdr);
    return (object*)that;}

object* object_autorelease(object* obj){
    if(null(obj)){return obj;}
    object* pool=autorelease_pool();
    set_autorelease_pool(object_retain(autorelease_cons(obj,pool)));
    object_release(pool);
    return obj;}

void autorelease_pool_release(){
    object_release(autorelease_pool());
    set_autorelease_pool(NULL);}


long int object_retain_count(object* object){
    if(null(object)){return 0;}
    return object->retain_count;}

static void object_free(object* object){
    if(null(object)){return;}
    switch(object->tag){
      case type_symbol:    /* nop */               return;
      case type_string:    string_free(object);    return;
      case type_cons:      cons_free(object);      return;
      case type_hashtable: hashtable_free(object); return;
      case type_wrapper:   wrapper_free(object);   return;
      default: free(object); return;}}

long int object_sxhash(object* object){
    switch(object_type(object)){
      case type_null:      return 0;
      case type_integer:   return integer_sxhash(object);
      case type_floating:  return floating_sxhash(object);
      case type_symbol:    return symbol_sxhash(object);
      case type_string:    return string_sxhash(object);
      case type_cons:      return cons_sxhash(object);
      case type_hashtable: return hashtable_sxhash(object);
      default: type_error(object,type_t); return 0;}}

bool object_eql(object* a,object* b){
    if(object_type(a)!=object_type(b)){
        return false;}
    switch(object_type(a)){
      case type_null:      return a==b;
      case type_integer:   return integer_value(a)==integer_value(b);
      case type_floating:  return floating_value(a)==floating_value(b);
      case type_symbol:    return a==b;
      case type_string:    return a==b;
      case type_cons:      return a==b;
      case type_hashtable: return a==b;
      default: type_error(a,type_t); return false;}}

bool object_equal(object* a,object* b){
    if(object_type(a)!=object_type(b)){
        return false;}
    switch(object_type(a)){
      case type_null:      return (a==b);
      case type_integer:   return (a==b) || (integer_value(a)==integer_value(b));
      case type_floating:  return (a==b) || (floating_value(a)==floating_value(b));
      case type_symbol:    return (a==b);
      case type_string:    return (a==b) || ((string_length(a)==string_length(b)) && (0==strcmp(string_c_string(a),string_c_string(b))));
      case type_cons:      return (a==b) || (object_equal(car(a),car(b)) && object_equal(cdr(a),cdr(b)));
      case type_hashtable: return (a==b);
      default: type_error(a,type_t); return false;}}


object* integer_new(long int value){
    integer_t* that=(integer_t*)checked_malloc(sizeof(*that));
    if(that==NULL){return NULL;}
    object_header_init((object*)that,type_integer);
    that->value=value;
    return object_autorelease((object*)that);}

long int integer_value(object* integer){
    if(!check_type(integer,type_integer)){return 0;}
    integer_t* that=(integer_t*)integer;
    return that->value;}

long int integer_sxhash(object* integer){
    return integer_value(integer);}


object* floating_new(float value){
    floating_t* that=(floating_t*)checked_malloc(sizeof(*that));
    if(that==NULL){return NULL;}
    object_header_init((object*)that,type_floating);
    that->value=value;
    return object_autorelease((object*)that);}

float floating_value(object* floating){
    if(!check_type(floating,type_floating)){return 0.0;}
    floating_t* that=(floating_t*)floating;
    return that->value;}

long int floating_sxhash(object* floating){
    return lroundf(floating_value(floating));}



object* wrapper_new(void* cdata,destructor_pr destructor){
    wrapper_t* that=(wrapper_t*)checked_malloc(sizeof(*that));
    if(that==NULL){return NULL;}
    object_header_init((object*)that,type_wrapper);
    that->cdata=cdata;
    that->destructor=destructor;
    return object_autorelease((object*)that);}

void* wrapper_cdata(object* wrapper){
    if(!check_type(wrapper,type_wrapper)){return NULL;}
    wrapper_t* that=(wrapper_t*)wrapper;
    return that->cdata;}

long int wrapper_sxhash(object* wrapper){
    return (long int)((intptr_t)wrapper);}

static void wrapper_free(object* wrapper){
    if(!check_type(wrapper,type_wrapper)){return;}
    wrapper_t* that=(wrapper_t*)wrapper;
    if(that->destructor!=NULL){
        that->destructor(that->cdata);}
    free(that);}



object* string_new_with_c_string(const char* cstring){
    string_t* that=(string_t*)checked_malloc(sizeof(*that));
    if(that==NULL){return NULL;}
    object_header_init((object*)that,type_string);
    size_t length=strlen(cstring);
    that->characters=(char*)checked_malloc(1+length);
    if(that->characters==NULL){free(that);return NULL;}
    that->capacity=length;
    that->length=length;
    strcpy(that->characters,cstring);
    return object_autorelease((object*)that);}

object* string_new_with_capacity(size_t size){
    string_t* that=(string_t*)checked_malloc(sizeof(*that));
    if(that==NULL){return NULL;}
    object_header_init((object*)that,type_string);
    that->characters=(char*)checked_malloc(1+size);
    if(that->characters==NULL){free(that);return NULL;}
    that->capacity=size;
    that->length=0;
    that->characters[that->length]='\0';
    return object_autorelease((object*)that);}

object* string_nappend(object* string,object* right){
    if(!check_type(string,type_string)){return NULL;}
    if(!check_type(right,type_string)){return string;}
    string_t* that=(string_t*)string;
    string_t* thot=(string_t*)right;
    size_t newlength=that->length+thot->length;
    if(that->capacity<newlength){
        that->characters=(char*)checked_realloc(that->characters,newlength+1);
        that->capacity=newlength;}
    strcpy(that->characters+that->length,
           thot->characters);
    that->length=newlength;
    return string;}

object* string_copy(object* string){
    if(!check_type(string,type_string)){return NULL;}
    string_t* original=(string_t*)string;
    return string_new_with_c_string(original->characters);}

static void string_free(object* object){
    if(!check_type(object,type_string)){return;}
    string_t* that=(string_t*)object;
    free(that->characters);
    free(that);}

char string_char_at(object* string,size_t index){
    if(!check_type(string,type_string)){return '\0';}
    string_t* that=(string_t*)string;
    if((index<0)||(that->length<=index)){
        out_of_bound_error(string,index,that->length);}
    return that->characters[index];}

size_t string_length(object* string){
    if(!check_type(string,type_string)){return 0;}
    string_t* that=(string_t*)string;
    return that->length;}

const char* string_c_string(object* string){
    if(!check_type(string,type_string)){return "";}
    string_t* that=(string_t*)string;
    return that->characters;}

long int string_sxhash(object* string){
    if(!check_type(string,type_string)){return 0;}
    string_t* that=(string_t*)string;
    long int sxhash=that->length;
    for(size_t i=0;i<that->length;i++){
        sxhash+=that->characters[i];}
    return sxhash;}

static object* symbols=NULL;

static void symbols_initialize(void){
    if(symbols==NULL){
        symbols=object_retain(hashtable_new(object_equal));
        nil=symbol_intern(string_new_with_c_string("NIL"));}}

object* symbol_intern(object* name){
    symbols_initialize();
    if(!check_type(name,type_string)){return NULL;}
    object* value=hashtable_get(symbols,name);
    symbol_t* that=(symbol_t*)nil;
    if(null(value)){
        that=(symbol_t*)checked_malloc(sizeof(*that));
        if(that==NULL){return NULL;}
        object_header_init((object*)that,type_symbol);
        that->name=object_retain(string_copy(name));
        hashtable_put(symbols,that->name,(object*)that);}
    else if(check_type(value,type_symbol)){
        that=(symbol_t*)value;}
    return (object*)that;}

object* symbol_name(object* symbol){
    if(!check_type(symbol,type_symbol)){return 0;}
    symbol_t* that=(symbol_t*)symbol;
    return that->name;}

long int symbol_sxhash(object* symbol){
    if(!check_type(symbol,type_symbol)){return 0;}
    symbol_t* that=(symbol_t*)symbol;
    long int sxhash=type_symbol+object_sxhash(that->name);
    return sxhash;}


object* cons(object* car,object* cdr){
    return object_autorelease(autorelease_cons(car,cdr));}

static void cons_free(object* cons){
    if(!check_type(cons,type_cons)){return;}
    object_release(car(cons));
    object_release(cdr(cons));
    free(cons);}

long int cons_sxhash(object* cons){
    if(!check_type(cons,type_cons)){return 0;}
    long int sxhash=object_sxhash(car(cons))+0x101*object_sxhash(cdr(cons));
    return sxhash;}

object* car(object* cons){
    if(!check_type(cons,type_cons)){return NULL;}
    cons_t* that=(cons_t*)cons;
    return that->car;}

object* cdr(object* cons){
    if(!check_type(cons,type_cons)){return NULL;}
    cons_t* that=(cons_t*)cons;
    return that->cdr;}

object* caar(object* cons){return car(car(cons));}
object* cadr(object* cons){return car(cdr(cons));}
object* cdar(object* cons){return cdr(car(cons));}
object* cddr(object* cons){return cdr(cdr(cons));}

object* rplaca(object* cons,object* car){
    if(!check_type(cons,type_cons)){return 0;}
    cons_t* that=(cons_t*)cons;
    object_retain(car);
    object_release(that->car);
    that->car=car;
    return cons;}

object* rplacd(object* cons,object* cdr){
    if(!check_type(cons,type_cons)){return 0;}
    cons_t* that=(cons_t*)cons;
    object_retain(cdr);
    object_release(that->cdr);
    that->cdr=cdr;
    return cons;}

object* list(object* element,...){
    va_list args;
    va_start(args,element);
    object* list=cons(nil,nil);
    object* tail=list;
    while(element!=NULL){
        rplacd(tail,cons(element,nil));
        tail=cdr(tail);
        element=va_arg(args,object*);}
    va_end(args);
    return cdr(list);}

object* first(object*   list){return car(list);}
object* rest(object*    list){return cdr(list);}
object* second(object*  list){return cadr(list);}
object* third(object*   list){return cadr(cdr(list));}
object* fourth(object*  list){return cadr(cddr(list));}
object* fifth(object*   list){return cadr(cddr(cdr(list)));}
object* sixth(object*   list){return cadr(cddr(cdr(list)));}
object* seventh(object* list){return cadr(cddr(cddr(list)));}
object* eighth(object*  list){return cadr(cddr(cddr(cdr(list))));}
object* nineth(object*  list){return cadr(cddr(cddr(cddr(list))));}
object* tenth(object*   list){return cadr(cddr(cddr(cddr(cdr(list)))));}

object* hashtable_new(test_pr test){
    hashtable_t* that=(hashtable_t*)checked_malloc(sizeof(*that));
    if(that==NULL){return NULL;}
    object_header_init((object*)that,type_hashtable);
    that->test=test;
    that->element_count=0;
    that->bucket_count=8;
    that->buckets=(object**)checked_malloc(sizeof(object*)*that->bucket_count);
    for(size_t i=0;i<that->bucket_count;i++){
        that->buckets[i]=nil;}
    return object_autorelease((object*)that);}

size_t hashtable_count(object* table){
    if(!check_type(table,type_hashtable)){return 0;}
    hashtable_t* that=(hashtable_t*)table;
    return that->element_count;}

static bool assoc_previous_cell(object* alist,object* key,test_pr test,object** previous_cell){
    (*previous_cell)=nil;
    while(bool_not(null(alist))){
        if(test(caar(alist),key)){
            return true;}
        (*previous_cell)=alist;
        alist=cdr(alist);}
    return false;}

void hashtable_put(object* table,object* key,object* value){
    if(!check_type(table,type_hashtable)){return;}
    hashtable_t* that=(hashtable_t*)table;
    object* previous_value_cell=nil;
    size_t index=object_sxhash(key)%that->bucket_count;
    if(assoc_previous_cell(that->buckets[index],key,that->test,&previous_value_cell)){
        if(null(previous_value_cell)){
            rplacd(car(that->buckets[index]),value);}
        else{
            rplacd(cadr(previous_value_cell),value);}}
    else{
        that->buckets[index]=object_retain(cons(cons(key,value),that->buckets[index]));
        that->element_count++;}}

object* hashtable_get(object* table,object* key){
    if(!check_type(table,type_hashtable)){return 0;}
    hashtable_t* that=(hashtable_t*)table;
    object* previous_value_cell=nil;
    size_t index=object_sxhash(key)%that->bucket_count;
    if(assoc_previous_cell(that->buckets[index],key,that->test,&previous_value_cell)){
        if(null(previous_value_cell)){
            return cdar(that->buckets[index]);}
        else{
            return cdr(cadr(previous_value_cell));}}
    else{
        return NULL;}}

object* hashtable_remove(object* table,object* key){
    if(!check_type(table,type_hashtable)){return 0;}
    hashtable_t* that=(hashtable_t*)table;
    object* previous_value_cell=nil;
    size_t index=object_sxhash(key)%that->bucket_count;
    if(assoc_previous_cell(that->buckets[index],key,that->test,&previous_value_cell)){
        object* result=nil;
        if(null(previous_value_cell)){
            result=cdar(that->buckets[index]);
            that->buckets[index]=object_retain(cdr(object_autorelease(that->buckets[index])));}
        else{
            result=cdr(cadr(previous_value_cell));
            rplacd(previous_value_cell,cdr(previous_value_cell));}
        that->element_count--;
        return result;}
    else{
        return NULL;}}

void hashtable_enumerate(object* table,hashtable_enumerate_pr enumerate,object* closure){
    if(!check_type(table,type_hashtable)){return;}
    hashtable_t* that=(hashtable_t*)table;
    for(size_t i=0;i<that->bucket_count;i++){
        object* current=that->buckets[i];
        while(!null(current)){
            if(!enumerate(caar(current),cdar(current),closure)){
                return;}
            current=cdr(current);}}}

static void hashtable_free(object* object){
    if(!check_type(object,type_hashtable)){return;}
    hashtable_t* that=(hashtable_t*)object;
    size_t i=that->bucket_count;
    while(0<i){
        i--;
        object_release(that->buckets[i]);}
    free(that->buckets);
    free(that);}

long int hashtable_sxhash(object* cons){
    return ((long int)(intptr_t)cons)>>5;}





/*----------------------------------------------------------------------*/

bool bool_not(bool val){return !val;}

object* identity(object* obj){return obj;}

object* find(object* element,object* sequence,test_pr test,key_pr key){
    while(bool_not(null(sequence))){
        if(test(element,key(car(sequence)))){
            return car(sequence);}
        sequence=cdr(sequence);}
    return NULL;}


long int position(object* element,object* sequence,test_pr test,key_pr key){
    long int pos=0;
    while(bool_not(null(sequence))){
        if(test(element,key(car(sequence)))){
            return pos;}
        ++pos;
        sequence=cdr(sequence);}
    return -1;}

object* member(object* element,object* list,test_pr test,key_pr key){
    while(bool_not(null(list))){
        if(test(element,key(car(list)))){
            return list;}
        list=cdr(list);}
    return NULL;}

long int length(object* sequence){
    switch(object_type(sequence)){
      case type_null: return 0;
      case type_string: return string_length(sequence);
      case type_cons: return list_length(sequence);
      default: type_error(sequence,type_cons); return 0;}}

long int list_length(object* list){
    if(!check_type(list,type_cons)){return 0;}
    long int len=0;
    while(bool_not(null(list))){
        ++len;
        list=cdr(list);}
    return len;}

object* elt(object* sequence,long int index){
    object* current=sequence;
    long int counter=index;
    while((0<counter) && bool_not(null(current))){
        --counter;
        current=cdr(current);}
    if(0<counter){
        out_of_bound_error(sequence,index,length(sequence));}
    return car(sequence);}

object* nth(long int index,object* list){
    while((0<index) && bool_not(null(list))){
        --index;
        list=cdr(list);}
    return car(list);}

static object* make_string_buffer(void){
    return cons(nil,nil);}

static void string_buffer_append(object* buffer,object* string){
    if(null(car(buffer))){
        rplaca(buffer,cons(string,nil));
        rplacd(buffer,car(buffer));}
    else{
        rplacd(cdr(buffer),cons(string,nil));
        rplacd(buffer,cddr(buffer));}}

static object* string_buffer_output_string(object* buffer){
    size_t size=0;
    dolist(element,car(buffer)){
        size=size+string_length(element);}
    object* string=string_new_with_capacity(size);
    dolist(element,car(buffer)){
        string_nappend(string,element);}
    return string;}

static void string_print(object* obj,object* buffer){
    size_t len=string_length(obj);
    object* quote=string_new_with_c_string("\"");
    string_buffer_append(buffer,quote);
    if((NULL==strchr(string_c_string(obj),'\\'))
       &&(NULL==strchr(string_c_string(obj),'"'))){
        string_buffer_append(buffer,obj);}
    else{
        for(size_t i=0;i<len;i++){
            char ch=string_char_at(obj,i);
            char buffer[4];
            if((ch=='\\')||(ch=='"')){
                snprintf(buffer,sizeof(buffer)-1,"\\%c",ch);}
            else{
                snprintf(buffer,sizeof(buffer)-1,"%c",ch);}}}
    string_buffer_append(buffer,quote);}

static void list_print(object* obj,object* buffer){
    string_buffer_append(buffer,string_new_with_c_string("("));
    while(consp(obj)){
        string_buffer_append(buffer,prin1_to_string(car(obj)));
        obj=cdr(obj);
        if(consp(obj)){
            string_buffer_append(buffer,string_new_with_c_string(" "));}
        else if(bool_not(null(obj))){
            string_buffer_append(buffer,string_new_with_c_string(" . "));
            string_buffer_append(buffer,prin1_to_string(obj));}}
    string_buffer_append(buffer,string_new_with_c_string(")"));}

static void integer_print(object* obj,object* buffer){
    char cbuf[80];
    snprintf(cbuf,sizeof(cbuf)-1,"%ld",integer_value(obj));
    string_buffer_append(buffer,string_new_with_c_string(cbuf));}

static void floating_print(object* obj,object* buffer){
    char cbuf[80];
    snprintf(cbuf,sizeof(cbuf)-1,"%f",floating_value(obj));
    string_buffer_append(buffer,string_new_with_c_string(cbuf));}

#ifdef DEBUG
static void hashtable_print(object* table,object* buffer){
    if(!check_type(table,type_hashtable)){return;}
    hashtable_t* that=(hashtable_t*)table;
    char cbuf[256];
    snprintf(cbuf,sizeof(cbuf)-1,"#<hashtable :retain_count %ld :test %p :element_count %zu: bucket_count %zu :buckets %p",
             that->retain_count,that->test,that->element_count,that->bucket_count,that->buckets);
    string_buffer_append(buffer,string_new_with_c_string(cbuf));
    for(size_t i=0;i<that->bucket_count;i++){
        object* current=that->buckets[i];
        snprintf(cbuf,sizeof(cbuf)-1,"\n  :bucket[%zu] ",i);
        string_buffer_append(buffer,string_new_with_c_string(cbuf));
        string_buffer_append(buffer,prin1_to_string(current));}
    snprintf(cbuf,sizeof(cbuf)-1,"\n  %p>",table);
    string_buffer_append(buffer,string_new_with_c_string(cbuf));}
#else
static void hashtable_print(object* obj,object* buffer){
    char cbuf[80];
    snprintf(cbuf,sizeof(cbuf)-1,"#<hashtable count=%ld %p>",hashtable_count(obj),obj);
    string_buffer_append(buffer,string_new_with_c_string(cbuf));}
#endif

static void unknown_print(object* obj,object* buffer,const char*type){
    char cbuf[80];
    snprintf(cbuf,sizeof(cbuf)-1,"#<%s %p>",type,obj);
    string_buffer_append(buffer,string_new_with_c_string(cbuf));}

static void object_print(object* obj,object* buffer){
    switch(object_type(obj)){
      case type_null:      string_buffer_append(buffer,symbol_name(nil)); return;
      case type_integer:   integer_print(obj,buffer);                     return;
      case type_floating:  floating_print(obj,buffer);                    return;
      case type_symbol:    string_buffer_append(buffer,symbol_name(obj)); return;
      case type_string:    string_print(obj,buffer);                      return;
      case type_cons:      list_print(obj,buffer);                        return;
      case type_hashtable: hashtable_print(obj,buffer);                   return;
      case type_wrapper:   unknown_print(obj,buffer,"wrapper");           return;
      default:             unknown_print(obj,buffer,"unknown");           return; }}

object* prin1_to_string(object* obj){
    object* buffer=make_string_buffer();
    object_print(obj,buffer);
    return string_buffer_output_string(buffer);}

object* prin1(object* obj,FILE* output){
    fprintf(output,"%s",string_c_string(prin1_to_string(obj)));
    return obj;}

object* print(object* obj,FILE* output){
    terpri(output);
    prin1(obj,output);
    return obj;}

void terpri(FILE* output){
    fprintf(output,"\n");}

static const char* terminating_chars="\"'(),;` \t\n\r\v\f";
static const char* spaces=" \t\n\r\v\f";
static const char* skip_spaces(const char* current,const char* final){
    while((current<final)&&(strchr(spaces,*current))){
        current++;}
    return current;}

static const char* read1(const char* current,const char* final,object** result);

static const char* read_delimited_list1(const char* current,const char* final,object** result){
    object* list=cons(nil,nil);
    object* tail=list;
    object* element=nil;
    do{
        current=read1(current,final,&element);
        if((element==nil)&&(current==final)){
            (*result)=element;
            return current;}
        else{
            rplacd(tail,cons(element,nil));
            tail=cdr(tail);
            current=skip_spaces(current,final);}
    }while((current<final) && (current[0]!=')'));
    if(current<final){current++;}
    (*result)=cdr(list);
    return current;}

static const char* read_string1(const char* current,const char* final,object** result){
    const char* start=current;
    while((current<final)&&((*current)!='"')){
        if((*current)=='\\'){
            current++;
            if(current<final){
                current++;}
            else{
                return current;}}
        else{
            current++;}}
    if(current<final){
        char* buffer=(char*)checked_malloc(current-start+1);
        if(buffer==NULL){return current;}
        size_t i=0;
        while(start<current){
            if((*start)=='\\'){
                start++;}
            buffer[i]=(*start);
            i++;
            start++;}
        buffer[i]='\0';
        (*result)=string_new_with_c_string(buffer);
        free(buffer);
        return current+1;}
    else{
        return current;}}


static long int long_mul(long int a,long int b,bool* overflow){
    long int sign=((a<0)?-1:1)*((b<0)?-1:1);
    long int aa=((a<0)?-a:a);
    long int bb=((b<0)?-b:b);
    if(aa<LONG_MAX/bb){
        (*overflow)=false;
        return aa*bb*sign;}
    else{
        (*overflow)=true;
        return 0;}}

static long int long_add(long int a,long int b,bool* overflow){
    if(b<0){
        if(a>=LONG_MIN-b){
            (*overflow)=false;
            return a+b;}
        else{
            (*overflow)=true;
            return 0;}}
    else{
        if(a<=LONG_MAX-b){
            (*overflow)=false;
            return a+b;}
        else{
            (*overflow)=true;
            return 0;}}}

static object* parse_integer1(const char* start,const char* end){
    long int sign=1;
    long int value=0;
    switch(*start){
      case '-': sign=-1; start++; break;
      case'+': start++; break;}
    while(start<end){
        if(isdigit(*start)){
            bool overflow=false;
            value=long_mul(value,10,&overflow);
            if(overflow){
                return nil;}
            value=long_add(value,digittoint(*start),&overflow);
            if(overflow){
                return nil;}
            start++;}
        else{
            return nil;}}
    return integer_new(sign*value);}

static object* parse_float1(const char* start,const char* end){
    double sign=1.0e0;
    double value=0.0e0;
    double fraction=1.0e0;
    bool before_dot=true;
    switch(*start){
      case '-': sign=-1.0e0; start++; break;
      case'+': start++; break;}
    while(start<end){
        if(before_dot){
            if(isdigit(*start)){
                value=(value*10.0e0)+(double)digittoint(*start);
                start++;}
            else if((*start)=='.'){
                before_dot=false;
                start++;
            }
            else{
                return nil;}}
        else{
            if(isdigit(*start)){
                fraction=fraction/10.0e0;
                value+=fraction*(double)digittoint(*start);
                start++;}
            else if(((*start)=='e')||((*start)=='E')){
                start++;
                object* exponent=parse_integer1(start,end);
                if(bool_not(null(exponent))){
                    double dexponent=(double)integer_value(exponent);
                    value*=pow(10.0e0,dexponent);
                    break;}
                else{
                    return nil;}}
            else{
                return nil;}}}
    return floating_new(sign*value);}

static object* parse_token1(const char* start,const char* end){
    char* buffer=(char*)checked_malloc(end-start+1);
    size_t i=0;
    if(buffer==NULL){return nil;}
    while(start<end){
        if((*start)=='\\'){
            start++;
            if(start<end){
                goto increment;
            }
            else{
                return nil;}}
        else{
      increment:
            if(isalpha(*start)){
                buffer[i]=toupper(*start);}
            else{
                buffer[i]=(*start);}
            i++;
            start++;}}
    buffer[i]='\0';
    object* result=symbol_intern(string_new_with_c_string(buffer));
    free(buffer);
    return result;}

static const char* read_token1(const char* current,const char* final,object** result){
    /*
    [-+]?[0-9]+                           integer
    [-+]?[0-9]+.[0-9]+([eE][-+]?[0-9]+)?  float
    else                                  symbol
    */
    const char* start=current;
    while((current<final)&&(NULL==strchr(terminating_chars,(*current)))){
        current++;}
    if(current<final){
        object* value=nil;
        if(bool_not(null(value=parse_integer1(start,current)))){
            (*result)=value;}
        else if(bool_not(null(value=parse_float1(start,current)))){
            (*result)=value;}
        else{
            (*result)=parse_token1(start,current);}}
    return current;}

static const char* read1(const char* current,const char* final,object** result){
    switch(current[0]){
      case '(': return read_delimited_list1(current+1,final,result);
      case '"': return read_string1(current+1,final,result);
      default:  return read_token1(current,final,result);}}

object* read_from_string(object* string,object* eof_value,size_t start,size_t end){
    /* return eof_value or (cons object-read final-string-index) */
    size_t length=string_length(string);
    if(end==0){
        end=length;}
    if((start<0)||(end<start)||(length<end)){
        out_of_bound_error(string,end,length);}
    object* result=nil;
    const char* begin=string_c_string(string)+start;
    const char* current=begin;
    const char* final=current+end;
    current=skip_spaces(current,final);
    current=read1(current,final,&result);
    if((result==nil)&&(current==final)){
        return eof_value;}
    else{
        return cons(result,integer_new(current-begin));}}



static void* default_out_of_memory_handler(size_t size){
    ERROR(ENOMEM,"Out of memory, trying to allocate %zu bytes",size);
#if defined(Linux) || defined(Darwin)
    exit(EX_OSERR);
#else
    return NULL;
#endif
}

static void print_message(const char* level,const char* file, unsigned long line, const char* function, const char* format, va_list args){
    fflush(stdout);
    fprintf(stderr,"%s:%lu: %s in %s(): ",file,line,level,function);
    vfprintf(stderr,format,args);
    fprintf(stderr,"\n");
    fflush(stderr);}

static void default_error_handler(const char* file, unsigned long line, const char* function, int status, const char* format, ...){
    va_list args;
    va_start(args,format);
    print_message("error",file,line,function,format,args);
    va_end(args);
#if defined(Linux) || defined(Darwin)
    exit(status);
#else
    return;
#endif
}

static void default_warning_handler(const char* file, unsigned long line, const char* function, int status, const char* format, ...){
    (void)status;
    va_list args;
    va_start(args,format);
    print_message("warning",file,line,function,format,args);
    va_end(args);}

static void default_verbose_handler(const char* file, unsigned long line, const char* function, const char* format, ...){
    va_list args;
    va_start(args,format);
    print_message("verbose",file,line,function,format,args);
    va_end(args);}



void fr_sbde_protocol_runtime_initialize(out_of_memory_handler user_handle_out_of_memory,
                                         error_handler user_handle_error,
                                         warning_handler user_handle_warning,
                                         verbose_handler user_handle_verbose){
    /* Order matters: */
    /* 1 */
    handle_out_of_memory=(user_handle_out_of_memory==NULL)?default_out_of_memory_handler:user_handle_out_of_memory;
    handle_error=(user_handle_error==NULL)?default_error_handler:user_handle_error;
    handle_warning=(user_handle_warning==NULL)?default_warning_handler:user_handle_warning;
    handle_verbose=(user_handle_verbose==NULL)?default_verbose_handler:user_handle_verbose;
    /* 2 */
    autorelease_pool_initialize();
    /* 3 */
    symbols_initialize();}

//// THE END ////
