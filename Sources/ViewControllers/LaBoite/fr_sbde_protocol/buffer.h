#ifndef fr_sbde_protocol_buffer_h
#define fr_sbde_protocol_buffer_h

typedef struct buffer buffer_t;

buffer_t* buffer_new_capacity(unsigned long size);
buffer_t* buffer_new_copy(unsigned long size, char* data);
buffer_t* buffer_new(unsigned long size, char* data);
unsigned long buffer_size(buffer_t* buffer);
char* buffer_data(buffer_t* buffer);
void buffer_free(buffer_t* buffer);

#endif
