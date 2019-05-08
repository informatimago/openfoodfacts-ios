#include <stdlib.h>
#include <string.h>
#include "buffer.h"
#include "error.h"

typedef struct buffer {
    unsigned long flags;
    unsigned long size;
    char* data;
} buffer_t;

enum {
    buffer_flag_allocated=(1<<0)
};

unsigned long buffer_size(buffer_t* buffer){
	return buffer->size;}

char* buffer_data(buffer_t* buffer){
	return buffer->data;}

buffer_t* buffer_new_capacity(unsigned long size){
    buffer_t* buffer=(buffer_t*)checked_malloc(sizeof(*buffer));
    if(buffer==NULL){
        return NULL;}
    buffer->flags=buffer_flag_allocated;
    buffer->size=size;
    buffer->data=(char*)checked_malloc(buffer->size);
    if(buffer->data==NULL){
        free(buffer);
        return NULL;}
    return buffer;}

buffer_t* buffer_new_copy(unsigned long size, char* data){
    buffer_t* buffer=buffer_new_capacity(size);
    if(buffer==NULL){
        return NULL;}
    memcpy(buffer->data,data,buffer->size);
    return buffer;}

buffer_t* buffer_new(unsigned long size, char* data){
    buffer_t* buffer=(buffer_t*)checked_malloc(sizeof(*buffer));
    if(buffer==NULL){
        return NULL;}
    buffer->flags=0;
    buffer->size=size;
    buffer->data=data;
    return buffer;}

void buffer_free(buffer_t* buffer){
    if(buffer==NULL){
        return;}
    if(buffer->flags&buffer_flag_allocated){
        free(buffer->data);}
	memset(buffer, 0, sizeof(*buffer));
    free(buffer);}

/**** THE END ****/
