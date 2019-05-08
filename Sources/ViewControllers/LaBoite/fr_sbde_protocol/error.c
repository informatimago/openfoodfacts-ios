#include <stdlib.h>
#include "error.h"

/* ========================================================================== */
/* Error Handling */

out_of_memory_handler handle_out_of_memory=NULL;
error_handler handle_error=NULL;
warning_handler handle_warning=NULL;
verbose_handler handle_verbose=NULL;

/* ========================================================================== */
/* Memory Allocation */

void* check_memory(void* memory,size_t size){
    return memory
            ?memory
            :handle_out_of_memory(size);}

void* checked_malloc(size_t size){
    return check_memory(malloc(size),size);}

void* checked_calloc(size_t nmemb, size_t size){
    return check_memory(calloc(nmemb,size),nmemb*size);}

void* checked_realloc(void* buffer,size_t newsize){
    return check_memory(realloc(buffer,newsize),newsize);}

//// THE END ////
