#ifndef fr_sbde_protocol_runtime_h
#define fr_sbde_protocol_runtime_h
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include "error.h"

typedef enum {
    type_null,
    type_integer,
    type_floating,
    type_string,
    type_symbol,
    type_cons,
    type_hashtable,
    type_wrapper,
    type_t,
} type_tag;

typedef struct object object;

extern object* nil;
bool null(void*);
void autorelease_pool_release(void);
object* object_retain(object* object);
object* object_autorelease(object* object);
void object_release(object* object);
long int object_retain_count(object* object); /* for debugging */

long int object_sxhash(object* object);
bool object_eql(object* a,object* b);
bool object_equal(object* a,object* b);

type_tag object_type(object* object);
bool stringp(object* obj);
bool symbolp(object* obj);
bool integerp(object* obj);
bool floatp(object* obj);
bool consp(object* obj);
bool hashtablep(object* obj);
bool wrapper(object* obj);

object* string_new_with_c_string(const char* cstring);
char string_char_at(object* string,size_t index);
size_t string_length(object* string);
const char* string_c_string(object* string);
object* string_new_with_capacity(size_t size);
object* string_nappend(object* string,object* right);

object* symbol_intern(object* name);
object* symbol_name(object* symbol);

object* integer_new(long int value);
long int integer_value(object* integer);

object* floating_new(float value);
float floating_value(object* integer);

typedef void (*destructor_pr)(void *);
object* wrapper_new(void* cdata,destructor_pr destructor);
void* wrapper_cdata(object* wrapper);

object* cons(object* car,object* cdr);
object* car(object* cons);
object* cdr(object* cons);
object* caar(object* cons);
object* cadr(object* cons);
object* cdar(object* cons);
object* cddr(object* cons);
object* rplaca(object* cons,object* car);
object* rplacd(object* cons,object* cdr);


object* list(object* element,...);
object* first(object* list);
object* rest(object* list);
object* second(object* list);
object* third(object* list);
object* fourth(object* list);
object* fifth(object* list);
object* sixth(object* list);
object* seventh(object* list);
object* eighth(object* list);
object* nineth(object* list);
object* tenth(object* list);

typedef bool (*test_pr)(object*,object*);
typedef object* (*key_pr)(object*);

object* hashtable_new(test_pr test);
size_t hashtable_count(object* table);
void hashtable_put(object* table,object* key,object* value);
object* hashtable_get(object* table,object* key);
object* hashtable_remove(object* table,object* key); /* returns the removed value */
typedef bool (*hashtable_enumerate_pr)(object* key,object* value,object* closure); /* return false to stop */
void hashtable_enumerate(object* table,hashtable_enumerate_pr enumerate,object* closure);



bool bool_not(bool val);
object* identity(object* obj);
object* find(object* element,object* sequence,test_pr test,key_pr key);
long int position(object* element,object* sequence,test_pr test,key_pr key);
object* member(object* element,object* list,test_pr test,key_pr key);
long int length(object* sequence);
long int list_length(object* list);
object* nth(long int index,object* list);
object* elt(object* sequence,long int index);


object* read_from_string(object* string,object* eof_value,size_t start,size_t end);
object* prin1_to_string(object* obj);
object* prin1(object* obj,FILE* output);
object* print(object* obj,FILE* output);
void terpri(FILE* output);

void fr_sbde_protocol_runtime_initialize(out_of_memory_handler user_handle_out_of_memory,
                                         error_handler user_handle_error,
                                         warning_handler user_handle_warning,
                                         verbose_handler user_handle_verbose);


#define dolist(var,list)                                                    \
    for(object* var ## _current = list, * var = car(var ## _current);       \
        bool_not(null(var ## _current));                                    \
        var ## _current = cdr(var ## _current), var = car(var ## _current))

#endif
