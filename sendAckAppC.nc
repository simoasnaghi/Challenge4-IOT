/**
 *  Configuration file for wiring of sendAckC module to other common 
 *  components needed for proper functioning
 *
 *  @author Luca Pietro Borsani
 */

#include "sendAck.h"

configuration sendAckAppC {}

implementation {


/****** COMPONENTS *****/
  components MainC, sendAckC as App;
  //add the other components here
  components  ActiveMessageC;
  components new AMReceiverC(AM_MY_MSG);
  components new AMSenderC(AM_MY_MSG);
  components new FakeSensorC();
  components new TimerMilliC();
  

/****** INTERFACES *****/
  //Boot interface
  App.Boot -> MainC.Boot;

  /****** Wire the other interfaces down here *****/
  //Send and Receive interfaces
  App.PacketAck -> AMSenderC;
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;

  //Radio Control
  App.AMControl -> ActiveMessageC;

  //Interfaces to access package fields
  App.Packet -> AMSenderC;

  //Timer interface
  App.MilliTimer -> TimerMilliC;

  //Fake Sensor read
  App.Read -> FakeSensorC;

}

