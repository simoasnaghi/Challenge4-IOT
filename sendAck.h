/**
 *  @author Luca Pietro Borsani
 */

#ifndef SENDACK_H
#define SENDACK_H

//payload of the msg
typedef nx_struct my_msg {
	//field1
	nx_uint8_t msg_type; 
	//field 2
	nx_uint8_t msg_counter;
	//field 3
	nx_uint32_t value;
} my_msg_t;

#define REQ 1
#define RESP 2 

enum{
AM_MY_MSG = 6,
};

#endif
