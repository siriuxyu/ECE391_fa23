# P2 Solution

## Question #1
> For each of the following messages sent from the computer to the Tux controller, briefly explain when it should be sent, what effect it has on the device, and what message or messages are returned to the computer as a result: 
__MTCP_BIOC_ON, MTCP_LED_SET.__


__MTCP_BIOC_ON__

- __When it should be sent:__ it's up to the user
- __What effect it has on the device:__ it enables Button-Interrupt-On-Change, which will then generates a MTCP_BIOC_EVT   
    including three bytes with the 0 byte as MTCP_BIOC_EVENT
- __What message or messages are returned to the computer:__ it returns a MTCP_ACK (which just a signal for sucessful
        commands)


__MTCP_LED_SET__

- __When it should be sent:__ it's up to the user
- __What effect it has on the device:__ it sets the User-set LED display values, which is displayed when the LED display
        is in USR mode
- __What message or messages are returned to the computer:__ it returns a MTCP_ACK (which just a signal for sucessful 
        commands)



## Question #2
> For each of the following messages sent from the Tux controller to the computer, briefly explain when the device sends the message and what information is conveyed by the message: MTCP_ACK, MTCP_BIOC_EVENT, MTCP_RESET.


__MTCP_ACK__

- __When the device sends the message:__ when the MTC completes a command successfully, more specifically, 
    after MTCP_BIOC_ON, MTCP_BIOC_OFF, MTCP_DBG_OFF, and MTCP_LED_SET are called
- what information is conveyed by the message: the successful completion of a command


__MTCP_BIOC_EVENT__

- __When the device sends the message:__ it's sent as the byte 0 in the packet MTCP_BIOC_EVT, which is sent when Button Interrupt-on-change mode is enabled 
    and a button is either pressed or released.
- __What information is conveyed by the message:__ Button Interrupt-on-change mode is enabled and a button is either pressed or released


__MTCP_RESET__

- __When the device sends the message:__ when the devide re-initializes itself after a power-up, a RESET button press, or an MTCP_RESET_DEV command is received
- __What information is conveyed by the message:__ the completion of the device re-initialization



## Question #3
> Now read the function header for tuxctl_handle_packet in tuxctl-ioctl.c---you will have to follow the pointer there to answer the question, too. In some cases, you may want to send a message to the Tux controller in response to a message just received by the computer (usingtuxctl_ldisc_put). 
However, if the output buffer for the device is full, you cannot do so immediately. Nor can the code (executing in tuxctl_handle_packet) wait 
(for example, go to sleep). Explain in one sentence why the code cannot wait.

- Because the tuxctl_handle_packet is called by tuxctl_ldisc_data_callback(), which is called from an interrupt context, making it unable to acquire any 
    semaphores or otherwise sleep, or access the 'current' pointer.
