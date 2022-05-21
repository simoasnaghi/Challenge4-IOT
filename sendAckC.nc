/**
 *  Source file for implementation of module sendAckC in which
 *  the node 1 send a request to node 2 until it receives a response.
 *  The reply message contains a reading from the Fake Sensor.
 *
 *  @author Luca Pietro Borsani
 */

#include "sendAck.h"
#include "Timer.h"

//Definition of some parameters useful during the writing of the program
//definition of the motes
#define M1 1 //definition of mote 1
#define M2 2 //definition of mote 2

module sendAckC {

  uses {
  /****** INTERFACES *****/
	interface Boot; 
	
    //interfaces for communication
	interface Receive;
	interface AMSend;
	interface SplitControl as AMControl;
	interface Packet;
	interface PacketAcknowledgements as PacketAck;
	//interface for timer
	interface Timer<TMilli> as MilliTimer;
    //other interfaces, if needed
	
	//interface used to perform sensor reading (to get the value from a sensor)
	interface Read<uint16_t>;
  }

} implementation {

  uint8_t counter=0;
  uint8_t rec_id=0;
  message_t packet;

  const int STOPPER_CONST=1; //My person code ends with a 0 so it's 0+1=1

  bool locked; //variable to save the state of the transmission channel 

  void sendReq();
  void sendResp();
  
  
  //***************** Send request function ********************//
  void sendReq() {
	/* This function is called when we want to send a request
	 *
	 * STEPS:
	 * 1. Prepare the msg
	 * 2. Set the ACK flag for the message using the PacketAcknowledgements interface
	 *     (read the docs)
	 * 3. Send an UNICAST message to the correct node
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	 //Preparation of the message
	my_msg_t* msg_send =(my_msg_t*) (call Packet.getPayload(&packet,sizeof(my_msg_t)));
	if (msg_send == NULL)
	{
		return;
	}
	counter ++;
	msg_send -> msg_type = REQ;
	msg_send -> msg_counter = counter;
	dbg("radio_pack","radio_pack: Message is gettin ready.\n");
	//Setup of the acknowledgements flag
	call PacketAck.requestAck(&packet);
	//dbg("sendReq","sendReq: Message is requesting ack.\n");
	//Unicast Message 
	if (call AMSend.send(M2, &packet, sizeof(my_msg_t)) == SUCCESS)
	{
		locked = TRUE;
		dbg("radio_send","radio_send: Message has been sent at time: %s.\n",sim_time_string());
		//Packet recap dbg commands
		dbg("radio_pack",">>Pack\n\t Payload length %hhu \n",call Packet.payloadLength(&packet));
		dbg_clear("radio_pack","\t\t type: %hhu \n", msg_send-> msg_type);
		dbg_clear("radio_pack","\t\t counter: %hhu \n", msg_send-> msg_counter);
	}
 }        

  //****************** Task send response *****************//
  void sendResp() {
  	/* This function is called when we receive the REQ message.
  	 * Nothing to do here. 
  	 * `call Read.read()` reads from the fake sensor.
  	 * When the reading is done it raises the event read done.
  	 */
	call Read.read();
  }

  //***************** Boot interface ********************//
  event void Boot.booted() {
	dbg_clear("boot","Application booted.\n");
	dbg_clear("boot","boot: time %s.\n",sim_time_string());
	/* Fill it ... */
	//Call of the function that wakes up the radio interface of the mote
	call AMControl.start();
  }

  //***************** SplitControl interface ********************//
  event void AMControl.startDone(error_t err){
    /* Fill it ... */
	if (err == SUCCESS)
	{
		//Radio is ready.
		dbg("radio","radio: radio started on node %d.\n",TOS_NODE_ID);
		dbg("radio","radio: time %s.\n",sim_time_string());
		//Call of the timer starting function
		if (TOS_NODE_ID ==1)
		{
			call MilliTimer.startPeriodic(1000);
		}
	}
	else
	{
		dbgerror("radio","radio: radio ERROR on node %d.\n",TOS_NODE_ID);
		dbgerror("radio","radio: retry radio starting procedure on node %d.\n",TOS_NODE_ID);
		dbgerror("radio","radio: time %s.\n",sim_time_string());
		call AMControl.start();
	}
  }
  
  event void AMControl.stopDone(error_t err){
    /* Fill it ... */
	dbg_clear("boot","boot: radio stopped\n");
	
  }

  //***************** MilliTimer interface ********************//
  event void MilliTimer.fired() {
	/* This event is triggered every time the timer fires.
	 * When the timer fires, we send a request
	 * Fill this part...
	 */
	 //Check if the radio channel is occupied. If yes discard the message, otherwise proceed with the communication
	 if (locked)
	 {
		 return;
	 }
	 else
	 {
		 //Call of the function to send a request message
		 sendReq();
	 }
  }
  

  //********************* AMSend interface ****************//
  event void AMSend.sendDone(message_t* buf,error_t err) {
	/* This event is triggered when a message is sent 
	 *
	 * STEPS:
	 * 1. Check if the packet is sent
	 * 2. Check if the ACK is received (read the docs)
	 * 2a. If yes, stop the timer according to your id. The program is done
	 * 2b. Otherwise, send again the request
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	 //Check if the packet is sent
	 if (&packet == buf)
	 {
		locked = FALSE;
		dbg("radio_send","radio_send: packet sent correctly. Time: %s.\n",sim_time_string());
		//Check if the message sent by 1 has been acknowledged
		if (TOS_NODE_ID == 1)
		{
			if (call PacketAck.wasAcked(&packet))
			{
				dbg("radio_ack","radio_ack: Message acked. Time: %s.\n",sim_time_string());
				rec_id++;
				if (rec_id == STOPPER_CONST)
				{
					call MilliTimer.stop();
					dbg_clear("radio_send","radio_send: Timer stopped. Time: %s.\n",sim_time_string());
					call AMControl.stop();
				}
				else
				{
					dbg("radio_send","radio_send: New iteration upcoming. Counter: %hu.\n",counter);
					dbg("radio_send","radio_send: Time: %s.\n",sim_time_string());
					
				}
			}
		}
		
	 }

  }

  //***************************** Receive interface *****************//
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	/* This event is triggered when a message is received 
	 *
	 * STEPS:
	 * 1. Read the content of the message
	 * 2. Check if the type is request (REQ)
	 * 3. If a request is received, send the response
	 * X. Use debug statements showing what's happening (i.e. message fields)
	 */
	 //Read the incoming message and verifying that it's genuine
	 if (len != sizeof(my_msg_t))
	 {
		 dbgerror("radio_rec","radio_rec: Wrong length. Message discarded. Time: %s.\n",sim_time_string());
		 return buf;
	 }
	 else
	 {
		 //Setup of the structure of the incoming message
		 my_msg_t* msg_received =(my_msg_t*)payload;
		 //Packet recap dbg commands
		dbg("radio_pack",">>Pack\n\t Payload received length %hhu \n",call Packet.payloadLength(&packet));
		dbg_clear("radio_pack","\t\t type: %hhu \n", msg_received-> msg_type);
		dbg_clear("radio_pack","\t\t counter: %hhu \n", msg_received-> msg_counter);
		//Check the REQ status of the incoming message
		if (TOS_NODE_ID == M2)
		{
			counter = msg_received -> msg_counter;
			if (msg_received -> msg_type == REQ)
			{
				dbg("radio_rec","radio_rec: Incoming message is ok. Proceding... Time: %s.\n",sim_time_string());
				sendResp();
			}
		} 
		return buf;
	 }

  }
  
  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
	/* This event is triggered when the fake sensor finishes to read (after a Read.read()) 
	 *
	 * STEPS:
	 * 1. Prepare the response (RESP)
	 * 2. Send back (with a unicast message) the response
	 * X. Use debug statement showing what's happening (i.e. message fields)
	 */
	//Setup of the structure for the response message
	my_msg_t* msg_response = (my_msg_t*) (call Packet.getPayload(&packet,sizeof(my_msg_t)));
	dbg("radio_rec","radio_rec: read value ok. Time: %s\n",sim_time_string());
	if (msg_response == NULL)
	{
		dbgerror("radio_rec","radio_rec: Empty response message. Time: %s\n",sim_time_string());
		return;
	}
	else
	{
		msg_response -> msg_type = RESP;
		msg_response -> msg_counter = counter;
		msg_response -> value = (uint16_t) data;

		dbg("radio_ack","radio_ack: Ack request. Time: %s\n",sim_time_string());
		call PacketAck.requestAck(&packet);

		//Sending response
		if (call AMSend.send(M1, &packet, sizeof(my_msg_t)) == SUCCESS)
		{
			locked = TRUE;
			dbg("radio_send","radio_send: Msg sent. Time: %s\n",sim_time_string());
			//Packet recap dbg commands
			dbg("radio_pack",">>Pack\n\t Payload length %hhu \n",call Packet.payloadLength(&packet));
			dbg_clear("radio_pack","\t\t type: %hhu \n", msg_response-> msg_type);
			dbg_clear("radio_pack","\t\t counter: %hhu \n", msg_response-> msg_counter);
			dbg_clear("radio_pack","\t\t data: %u \n", (unsigned int)msg_response-> value); //transformation into unsigned integer to show the full data.
		}

	}
}
}

