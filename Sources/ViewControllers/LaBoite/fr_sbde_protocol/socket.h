// -*- mode:c;coding:utf-8 -*-
//****************************************************************************
//FILE:               socket.h
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
#ifndef fr_sbde_protocol_socket_h
#define fr_sbde_protocol_socket_h
#include <stdbool.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/poll.h>
#include <netdb.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

typedef enum {
    socket_state_miscarried,
    socket_state_born,
    socket_state_bound,
    socket_state_listening,
    socket_state_connecting,
    socket_state_connected,    /*deprecated:*/socket_state_opened=socket_state_connected,
    socket_state_disconnected, /*deprecated:*/socket_state_closed=socket_state_disconnected,
}                   socket_state_t;

typedef struct socket socket_t;

/*
    There are two kind of "socket_t":

        - listening sockets, as created by socket(2) and bound by
          bind(2), and put on listening by listen(2), and

        - open sockets, as created by accept(2).

    The creation  of a listening socket  is split into  three steps to
    allow the  instanciation of socket_t object  at configuration time
    without creating  the socket(2) as  yet, then creating  the socket
    andbinding  it, allowing  for a  change  of UID  between bind  and
    listen.

        lsocket=socket_new(dom,laddr,laddrlen);
        bcobject_retain(lsocket);
        // you may abort here.
        ok=socket_bind(lsocket,max_retry);
        // you may  change UID here.
        ok=socket_listen(lsocket);
        for(;;){
            // you may poll here (using socket_build_poll(lsocket,ufds,&nfds);).
            asocket=socket_accept(lsocket);
            bcobject_retain(asocket);
            // read(socket_fd(asocket),&buf,bufsize);
            // write(socket_fd(asocket)
            socket_close(asocket);
            bcobject_release(asocket);
        }
        socket_close(lsocket);
        bcobject_release(lsocket);

    socket type is necessarily  SOCK_STREAM (otherwise, there would be
    no need to accept(2) it).

*/


extern socket_t* socket_new_bound_with_addresses(struct addrinfo* addresses);
/*
Returns a new socket bound to the first address that can be bound to.
Returns a bound socket or a miscarried one.
*/

extern socket_t* socket_new_connected_to_addresses(struct addrinfo* addresses);
/*
Returns a new socket connected to the first address that can be connected to.
Returns a connected socket or a miscarried one.
*/

extern socket_t* socket_new(int domain,
                            struct sockaddr* local_address,
                            socklen_t local_address_size);
    /*
        PRE:    domain in {PF_INET6, PF_INET, PF_UNIX},
                (local_address,local_address_size) specify a correct
                local address for a socket in the given domain.

        DOES:   Creates a new socket_t object in the given domain,
                of type SOCK_STREAM, and of protocol 0,
                ready to be bound to the given local address.

        RETURN: 0 <== out of memory,
                a new socket_t structure s such as:
                    socket_state(s)==socket_state_miscarried
                    and socket_error(s) = reported error code.
                           <== socket(2) or bind(2) reported an error.
                 or socket_state(s)==socket_state_born,
                    and socket_error(s)==0
                           <== the new socket was created successfully.

        NOTE:   socket(2) is not called until socket_bind().
    */


extern bool socket_bind(socket_t* that,int max_bind_retries);
    /*
        PRE:    socket_state(that)==socket_state_born.

        DOES:   Create a socket(2) and binds it to its local_address.

        NOTE:   Binding is tried max_bind_retries time
                with a sleep(1) inbetween each calls, so it could be nice
                to use several threads if several sockets are to be bound.

        POST:   socket_state(that)==socket_state_born.
                   and socket_error(that) = reported error code.
                           <== socket(2) or bind(2) reported an error.
                or socket_state(that)==socket_state_bound
                   and socket_error(that)==0
                           <== the new socket could be bound successfully.

        RETURN: (socket_state(that)==socket_state_bound)

        NOTE:   The socket should be retained while the file descriptor
                is to be kept open!
    */


extern bool socket_listen(socket_t* that);
    /*
        PRE:    socket_state(that)==socket_state_bound.
        POST:   socket_state(that)==socket_state_bound
                   and socket_error(that)== listen error code, or
                socket_state(that)==socket_state_listening
                   and socket_error(that)==0
        RETURN: (socket_state(that)==socket_state_listening).
    */

extern void socket_build_poll(socket_t* that,
                              struct pollfd* ufds,unsigned int* nfds);
    /*
        PRE:    N==(*nfds),
                N>=0,
                ufds points to an array of pollfd of at least N+1 entries.
        POST:   N+1==(*nfds),
                ufds[N].fd==that->fd,
                ufds[N].events==POLLIN,
                ufds[N].revents==0;
        NOTE:   This method can be used to build a ufds/nfds array
                for poll(2).
    */

extern socket_t* socket_accept(socket_t* that);
    /*
        PRE:    socket_state(that)==socket_state_listening.
        POST:   socket_state(that)==socket_state_listening.
        RETURN: 0 <== there was no pending connections on the queue, or
                the new accepted socket s such as:
                    socket_state(s)==socket_state_opened.

        NOTE:   The socket should be retained while the file descriptor
                is to be kept open!
   */

extern bool socket_connect(socket_t* that,
                           struct sockaddr* remote_address,
                           socklen_t remote_address_size);
    /*
        PRE:    socket_state(that) in {socket_state_born,socket_state_bound}.
        POST:   socket_state(that) in {socket_state_born,socket_state_bound,socket_state_opened}.
        RETURN: false <=> the connection couldn't occur. The state is unchanged.
                true <=> the connection is established, the state is socket_state_opened,
                         and socket_fd is available for I/O.

        NOTE:   The socket should be retained while the file descriptor
                is to be kept open!
   */

extern void socket_close(socket_t* that);
    /*
        PRE:    M==(socket_state(that)==socket_state_miscarried).
        POST:   M==>(socket_state(that)==socket_state_miscarried),
                !M==>(socket_state(that)==socket_state_closed).
    */


/* Acessors: */

extern socket_state_t socket_state(const socket_t* that);
    /*
        RETURN: The state of that socket.
    */

extern int socket_error(const socket_t* that);
    /*
        RETURN: The errno of the last erroneous syscall,
                or 0 if the last method was successfull.
    */

extern int socket_fd(const socket_t* that);
    /*
        PRE:    socket_state(that)!=socket_state_miscarried,
                socket_state(that)!=socket_state_closed.
        RETURN: The fd of that socket.
    */

extern int socket_domain(const socket_t* that);
    /*
        RETURN: The domain of that socket.
    */


extern bool socket_get_local_address(const socket_t* that,
                                     struct sockaddr* local_address,
                                     int* local_address_size);
    /*
        PRE:    socket_state(that)!=socket_state_miscarried,
                S=(*local_address_size),
                R=(S is large enough to hold the local_address).
        POST:   (*local_address_size)==size of a local_address,
                R==>(*local_address) is filled with the local address.
        RETURN: R
    */

 extern bool socket_get_remote_address(const socket_t* that,
                                       struct sockaddr* remote_address,
                                       int* remote_address_size);
    /*
        PRE:    socket_state(that)==socket_state_opened
                  or socket_state(that)==socket_state_closed,
                S=(*remote_address_size),
                R=(S is large enough to hold the remote_address).
        POST:   (*remote_address_size)==size of a remote_address,
                R==>(*remote_address) is filled with the remote address.
        RETURN: R
        NOTE:   If there was no remote address
                then (*remote_address_size) is set to 0.
                (for a listening socket, for example).
    */


extern void socket_delete(socket_t* that);
/* Frees the socket. */

#endif
