#include <sys/socket.h>
#include <netdb.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <time.h>
#include <sysexits.h>
#include "client.h"
#include "socket.h"
#include "buffer.h"
#include "controller-ua-client.h"

static void* client_out_of_memory_handler(size_t size){
    ERROR(ENOMEM,"Out of memory, trying to allocate %zu bytes",size);
    exit(EX_OSERR);}

static void print_message(const char* level,const char* file, unsigned long line, const char* function, const char* format, va_list args){
    fflush(stdout);
    fprintf(stderr,"%s:%lu: %s in %s(): ",file,line,level,function);
    vfprintf(stderr,format,args);
    fprintf(stderr,"\n");
    fflush(stderr);}

static void client_error_handler(const char* file, unsigned long line, const char* function, int status, const char* format, ...){
    va_list args;
    va_start(args,format);
    print_message("error",file,line,function,format,args);
    va_end(args);
    return;}

void fr_sbde_protocol_client_initialize(void){
    fr_sbde_protocol_initialize(client_out_of_memory_handler,
                                client_error_handler,
                                NULL,NULL);}

typedef struct connection {
    socket_t* socket;
    char error_message[128];
    bool errorp;
    bool connectedp;
} connection_t;

const char* fr_sbde_protocol_client_error(connection_t* connection){
    if((connection==NULL)||(!connection->errorp)){return NULL;}
    return connection->error_message;}

static connection_t* report_error(connection_t* connection,int error){
    char buffer[1024];
    strerror_r(error,buffer,sizeof(buffer)-1);
    snprintf(connection->error_message,sizeof(connection->error_message)-1,"socket error %d: %s",error,buffer);
    connection->errorp=true;
    return connection;}

connection_t* fr_sbde_protocol_client_connect(const char* host,uint16_t port){
#ifdef DEBUG
    fprintf(stderr,"%ld fr_sbde_protocol_client_connect(%s,%d)\n",time(NULL),host,port);
#endif
    connection_t* that=checked_malloc(sizeof(*that));
    that->errorp=false;
    that->connectedp=false;

    struct addrinfo hints;
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET; /* AF_UNSPEC; Allow IPv4 or IPv6 */
    hints.ai_socktype = SOCK_STREAM; /* Stream socket */
    hints.ai_flags = 0;           /* For wildcard IP address */
    hints.ai_protocol = 0;          /* Any protocol */
    hints.ai_canonname = NULL;
    hints.ai_addr = NULL;
    hints.ai_next = NULL;

    char portBuffer[10];
    snprintf(portBuffer,sizeof(portBuffer)-1,"%hu",port);

    struct addrinfo * addresses;

    int res=getaddrinfo(host,portBuffer,&hints,&addresses);
    if(res!=0){
        snprintf(that->error_message,sizeof(that->error_message)-1,"getaddrinfo: %s",gai_strerror(res));
        that->errorp=true;
#ifdef DEBUG
    fprintf(stderr,"%ld fr_sbde_protocol_client_connect(%s,%d) -> error\n",time(NULL),host,port);
#endif
        return that;}

    that->socket=socket_new_connected_to_addresses(addresses);
    freeaddrinfo(addresses);

    if(that->socket==NULL){ /* should not occur. */
        return report_error(that,ENOMEM);}
    if((socket_state(that->socket)==socket_state_connected)
       && (socket_error(that->socket)==0)){
        that->connectedp=true;
#ifdef DEBUG
    fprintf(stderr,"%ld fr_sbde_protocol_client_connect(%s,%d) -> connected\n",time(NULL),host,port);
#endif
        return that;}
error:
    return report_error(that,socket_error(that->socket));}

static char crlf[]="\015\012";

static bool receive_line(connection_t* connection,int fd,buffer_t* line){
    char* start=buffer_data(line);
    size_t expect=buffer_size(line)-1;
    bool drop=false;
    while(1){
        ssize_t size=recv(fd,start,expect,0);
        if(size<0){
            switch(errno){
              case EAGAIN:
              case EINTR:
                  continue;
              case ECONNRESET:
              case EPIPE:
                  return false;
              default:
                  report_error(connection,errno);
                  return false;}}
        else{
            start[size]='\0';
            /* We must scan from the start in case start points to \l. */
            char* newline=strstr(buffer_data(line),crlf);
            if(newline!=NULL){
                newline[0]='\0';
                if(drop){
                    drop=false;
                    start=buffer_data(line);
                    expect=buffer_size(line)-1;
                    continue;}
                else{
                    return true;}}
            start+=size;
            expect-=size;
            if(expect<=0){
                /* line too long: just drop until we find a newline */
                drop=true;
                start=buffer_data(line);
                expect=buffer_size(line)-1;}}}}

static bool send_line(connection_t* connection,int fd,buffer_t* msgtext){
    printf("Sending:  %s\n",buffer_data(msgtext));
    struct iovec iov[2];
    iov[0].iov_base=buffer_data(msgtext);
    iov[0].iov_len=strlen(buffer_data(msgtext));
    iov[1].iov_base=crlf;
    iov[1].iov_len=2;
    struct msghdr header={NULL,0,iov,2,NULL,0,0};
    while(1){
        ssize_t size=sendmsg(fd,&header,0);
        if(size<0){
            switch(errno){
              case EAGAIN:
              case EINTR:
                  continue;
              case ECONNRESET:
              case EPIPE:
                  return false;
              default:
                  report_error(connection,errno);
                  return false;}}
        else{
            int i=0;
            while(size>0){
                if(size<=iov[i].iov_len){
                    iov[i].iov_base+=size;
                    iov[i].iov_len-=size;
                    size=0;
                    break;}
                else{
                    iov[i].iov_base+=iov[i].iov_len;
                    size-=iov[i].iov_len;
                    iov[i].iov_len=0;
                    i++;}}
            if(iov[1].iov_len==0){
                return true;}}}}

static bool check_connection(connection_t* connection){
    if(connection==NULL){return false;}
    if(socket_state(connection->socket)!=socket_state_opened){return false;}
    if(!connection->connectedp){
        if(connection->socket!=NULL){
            socket_close(connection->socket);
            socket_delete(connection->socket);}
        return false;}
    return true;}

controller_ua_message* fr_sbde_protocol_client_receive_message(connection_t* connection){
    if(!check_connection(connection)){return NULL;}
    buffer_t* line=buffer_new_capacity(8192);
    if(receive_line(connection,socket_fd(connection->socket),line)){
        controller_ua_message* message=controller_ua_client_parse(buffer_data(line));
        buffer_free(line);
        return message;}
    else{
        buffer_free(line);
        return NULL;}}

bool fr_sbde_protocol_client_connected(connection_t* connection){
    if(connection==NULL){return false;}
    return connection->connectedp;}

bool fr_sbde_protocol_client_send_message(connection_t* connection,controller_ua_message* message){
    if(!check_connection(connection)){return NULL;}
    char* msgText=controller_ua_client_format(message);
    if(msgText==NULL){
        report_error(connection,EINVAL);
        return false;}
    buffer_t* line=buffer_new(strlen(msgText)+1,msgText);
    bool result=send_line(connection,socket_fd(connection->socket),line);
    buffer_free(line);
    free(msgText);
    return result;}

void fr_sbde_protocol_client_disconnect(connection_t* connection){
    if(connection==NULL){return;}
    if(connection->socket!=NULL){
        socket_close(connection->socket);
        socket_delete(connection->socket);}
    free(connection);}


//// THE END ////
