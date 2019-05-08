#ifndef fr_sbde_protocol_client_h
#define fr_sbde_protocol_client_h
#include <stdint.h>
#include "controller-ua-messages.h"

typedef struct connection connection_t;

void fr_sbde_protocol_client_initialize(void);
connection_t* fr_sbde_protocol_client_connect(const char* host,uint16_t port);
const char* fr_sbde_protocol_client_error(connection_t* connection);
controller_ua_message* fr_sbde_protocol_client_receive_message(connection_t* connection);
bool fr_sbde_protocol_client_send_message(connection_t* connection,controller_ua_message* message);
void fr_sbde_protocol_client_disconnect(connection_t* connection);

#endif
