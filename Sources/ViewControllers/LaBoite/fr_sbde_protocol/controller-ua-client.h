#ifndef controller_ua_client_h
#define controller_ua_client_h
#include "protocol.h"
#include "controller-ua-messages.h"
controller_ua_message* controller_ua_client_parse(const char* message);
char* controller_ua_client_format(controller_ua_message* that);
#endif
