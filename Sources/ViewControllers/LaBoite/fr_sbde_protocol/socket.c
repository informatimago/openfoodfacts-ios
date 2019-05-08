// -*- mode:c;coding:utf-8 -*-
//****************************************************************************
//FILE:               socket.c
//LANGUAGE:           c
//SYSTEM:             POSIX
//USER-INTERFACE:     NONE
//DESCRIPTION
//
//    This module encapsulates sockets.
//
//AUTHORS
//    <PJB> Pascal J. Bourguignon <pjb@informatimago.com>
//MODIFICATIONS
//    2002-07-20 <PJB> Created.
//BUGS
//LEGAL
//    Proprietary
//
//    Copyright Pascal J. Bourguignon 2002 - 2019
//
//    All Rights Reserved.
//
//    This program and its documentation constitute intellectual property
//    of Pascal J. Bourguignon and is protected by the copyright laws of
//    the European Union and other countries.
//****************************************************************************
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <time.h>
#include "socket.h"
#include "error.h"

typedef struct socket {
    socket_state_t      state;
    int                 error;
    int                 fd;
    int                 domain;
    struct sockaddr*    local_address;
    socklen_t           local_address_size;
    struct sockaddr*    remote_address;
    socklen_t           remote_address_size;
}                   socket_t;


void socket_delete(socket_t* that)
{
    if(that->fd!=(-1)){
        close(that->fd);
    }
    if(that->local_address!=0){
        free(that->local_address);
    }
    if(that->remote_address!=0){
        free(that->remote_address);
    }
}


static socket_t* socket_new_foetus(void)
{
    socket_t* that=(socket_t*)checked_malloc(sizeof(*that));
    if(that==NULL){
        return(NULL);
    }
    that->state=socket_state_miscarried;
    that->error=0;
    that->fd=(-1);
    that->domain=PF_UNSPEC;
    that->local_address=0;
    that->local_address_size=0;
    that->remote_address=0;
    that->remote_address_size=0;
    return(that);
}


socket_t* socket_new(int domain,
                     struct sockaddr* local_address,
                     socklen_t local_address_size)
{
    socket_t* that=socket_new_foetus();
    if(that==NULL){
        return(0);
    }
    that->local_address=malloc(local_address_size);
    if(that->local_address==0){
        return(0);
    }

    that->domain=domain;
    that->local_address_size=local_address_size;
    memcpy(that->local_address,local_address,local_address_size);
    /* create a new socket */
    that->fd=socket(that->domain,SOCK_STREAM,0);
    that->error=errno;
    if(that->fd<0){
        that->state=socket_state_miscarried;
    }else{
        that->state=socket_state_born;
    }
    return(that);
}

socket_t* socket_new_bound_with_addresses(struct addrinfo* addresses){
    socket_t* that=socket_new_foetus();
    if(that==NULL){ /* should not occur. */
        return(NULL);}

    for(struct addrinfo* current=addresses;current!=NULL;current=current->ai_next){
        /* create a new socket */
        that->fd=socket(current->ai_family,current->ai_socktype,current->ai_protocol);
        that->error=errno;
        if(that->fd<0){
            continue;}

        /* set SO_REUSEADDR to avoid bind() error "address already in use". */
        int flag=1;
        setsockopt(that->fd,SOL_SOCKET,SO_REUSEADDR,&flag,sizeof(flag));

        if(0==bind(that->fd,current->ai_addr,current->ai_addrlen)){
            that->domain=current->ai_family;
            that->local_address_size=current->ai_addrlen;
            that->local_address=checked_malloc(current->ai_addrlen);
            memcpy(that->local_address,current->ai_addr,current->ai_addrlen);
            break;
        }
        that->error=errno;
        close(that->fd);
        that->fd=-1;
    }

    if(that->fd<0){
        that->state=socket_state_miscarried;
    }else{
        that->state=socket_state_bound;
        that->error=0;
    }
    return(that);
}

bool socket_bind(socket_t* that,int max_bind_retries)
{
    if(socket_state(that)!=socket_state_born){
        return(false);
    }

    /* set SO_REUSEADDR to avoid bind() error "address already in use". */
    {
        int flag=1;
        setsockopt(that->fd,SOL_SOCKET,SO_REUSEADDR,&flag,sizeof(flag));
    }

    /* bind the socket */
    {
        int retry=0;
        struct sockaddr* address=malloc(that->local_address_size);
        if(address==0){
            that->error=ENOMEM;
            close(that->fd);
            that->fd=(-1);
            return(false);
        }
        for(;;){
            memcpy(address,that->local_address,that->local_address_size);
            if(0==bind(that->fd,address,that->local_address_size)){
                that->state=socket_state_bound;
                that->error=0;
                break;
            }
            retry++;
            if(retry>=max_bind_retries){
                that->error=errno;
                close(that->fd);
                break;
            }
            sleep(1);
        }
        free(address);
    }
    return(true);
}


bool socket_listen(socket_t* that)
{
    const int backlog=10;

    if(socket_state(that)!=socket_state_bound){
        return(socket_state(that)==socket_state_listening);
    }

    if(0==listen(that->fd,backlog)){
        that->state=socket_state_listening;
        that->error=0;
    }else{
        that->error=errno;
    }
    return(socket_state(that)==socket_state_listening);
}


void socket_build_poll(socket_t* that,
                       struct pollfd* ufds,unsigned int* nfds)
{
    if(socket_state(that)==socket_state_listening){
        unsigned int n=(*nfds)++;
        ufds[n].fd=that->fd;
        ufds[n].events=POLLIN;
        ufds[n].revents=0;
    }
}


socket_t* socket_accept(socket_t* that)
{
    if(socket_state(that)!=socket_state_listening){
        return(0);
    }else{
        int fd;
        socklen_t size;
        struct sockaddr* address=malloc(that->local_address_size);
        /*  Ok, for now, we'll use local_address_size, but it could be
        better to have a size depending on the domain... */
        if(address==0){
            that->error=ENOMEM;
            return(0);
        }

        size=that->local_address_size;
        fd=accept(that->fd,address,&size);
        if(fd<0){
            that->error=errno;
            free(address);
            return(0);
        }else{
            socket_t* result=socket_new_foetus();
            result->fd=fd;
            result->error=0;
            result->state=socket_state_connected;
            result->domain=that->domain;
            result->local_address=malloc(that->local_address_size);
            memcpy(result->local_address,
                   that->local_address,that->local_address_size);
            result->local_address_size=that->local_address_size;
            result->remote_address=address;
            result->remote_address_size=size;
            that->error=0;
            return(result);
        }
    }
}

socket_t* socket_new_connected_to_addresses(struct addrinfo* addresses){
    socket_t* that=socket_new_foetus();
    if(that==NULL){ /* should not occur. */
        return(NULL);}

    for(struct addrinfo* current=addresses;current!=NULL;current=current->ai_next){
        /* create a new socket */
#ifdef DEBUG
        char nhost[80];
        char nserv[40];
        int res=getnameinfo(current->ai_addr,current->ai_addrlen,
                            nhost,sizeof(nhost)-1,
                            nserv,sizeof(nserv)-1,
                            NI_NUMERICHOST|NI_NUMERICSERV);
        if(res==0){
            fprintf(stderr,"%ld fr_sbde_protocol_client_connect(%s,%s)\n",time(NULL),nhost,nserv);
        }
#endif
        that->fd=socket(current->ai_family,current->ai_socktype,current->ai_protocol);
        that->error=errno;
        if(that->fd<0){
            continue;}

        if(0==connect(that->fd,current->ai_addr,current->ai_addrlen)){
            that->domain=current->ai_family;
            that->remote_address_size=current->ai_addrlen;
            that->remote_address=checked_malloc(current->ai_addrlen);
            memcpy(that->remote_address,current->ai_addr,current->ai_addrlen);
            break;
        }
        that->error=errno;
        close(that->fd);
        that->fd=-1;
    }

    if(that->fd<0){
        that->state=socket_state_miscarried;
    }else{
        that->state=socket_state_connected;
        that->error=0;
    }
    return(that);
}

bool socket_connect(socket_t* that,
                    struct sockaddr* remote_address,
                    socklen_t remote_address_size)
{
    if ((socket_state(that)!=socket_state_born)
          || (socket_state(that)!=socket_state_bound)){
        return(false);
    }else{
        socket_state_t saved_state=that->state;
        struct sockaddr* address=checked_malloc(remote_address_size);
        /*  Ok, for now, we'll use remote_address_size, but it could be
        better to have a size depending on the domain... */
        if(address==0){
            /* should not occur */
            that->error=ENOMEM;
            return(false);
        }
        that->state=socket_state_connecting;
        free(that->remote_address);
        that->remote_address_size=remote_address_size;
        memcpy(remote_address,that->remote_address,that->remote_address_size);
        that->state=socket_state_connecting;
        if(0==connect(that->fd,that->remote_address,that->remote_address_size)){
            that->error=0;
            that->state=socket_state_connected;
            return(true);
        }else{
            that->error=errno;
            that->state=saved_state;
            return(false);
        }
    }
}


void socket_close(socket_t* that)
{
    if(that==NULL){
        return;
    }
    switch(socket_state(that)){
      case socket_state_miscarried:
      case socket_state_disconnected:
          break;
      default:
          close(that->fd);
          that->fd=(-1);
          that->state=socket_state_disconnected;
          break;
    }
}


/* Acessors: */

socket_state_t socket_state(const socket_t* that)
{
    if(that==NULL){
        return(socket_state_miscarried);
    }
    return(that->state);
}


int socket_error(const socket_t* that)
{
    if(that==NULL){
        return(ENOMEM);
    }
    return(that->error);
}


int socket_fd(const socket_t* that)
{
    switch(socket_state(that)){
      case socket_state_miscarried:
      case socket_state_born:
      case socket_state_disconnected:
          return(-1);
      default:
          return(that->fd);
    }
}


int socket_domain(const socket_t* that)
{
    if(that==NULL){
        return(PF_UNSPEC);
    }
    return(that->domain);
}


bool socket_get_local_address(const socket_t* that,
                              struct sockaddr* local_address,
                              int*             local_address_size)
{
    if((that==NULL)||(that->local_address==0)){
        return(false);
    }
    if((*local_address_size)<that->local_address_size){
        (*local_address_size)=that->local_address_size;
        return(false);
    }
    if(0<that->local_address_size){
        memcpy(local_address,
               that->local_address,that->local_address_size);
    }
    (*local_address_size)=that->local_address_size;
    return(true);
}


bool socket_get_remote_address(const socket_t* that,
                               struct sockaddr* remote_address,
                               int*             remote_address_size)
{
    if((that==NULL)||(that->remote_address==NULL)){
        return(false);
    }
    if((*remote_address_size)<that->remote_address_size){
        (*remote_address_size)=that->remote_address_size;
        return(false);
    }
    if(0<that->remote_address_size){
        memcpy(remote_address,
               that->remote_address,that->remote_address_size);
    }
    (*remote_address_size)=that->remote_address_size;
    return(true);
}


//// THE END ////
