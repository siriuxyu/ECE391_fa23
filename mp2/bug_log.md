# Bug_log of mp2
- Hengjia Yu
- hengjia2@illinois.edu

---

# MP2-1

 ## Bug 01
 - __Problem__
  
    - the status bar was blinking on the top of the screen
  

 - __Reason__
    - As the code below shows, I didn't modify the position of first screen on video memory.
    - Since the bar is also at 0x0000 on video memory. VGA will scan the first screen(with a top bar), switch to second(without top bar), thus making the top bar blinking.
    - in **set_mode_X()** in ***modex.c***

            target_img = 0x0000;



 - __Method Used to Fix__

    - Simply modify the mapping location of screen 1 to 0x1000, they will no longer overlap.
  
            target_img = 0x1000;



 ## Bug 02
 - __Problem__
  
    >adventure.c:263: warning: pointer targets in passing argument 1 of 'strncpy' dif fer in signedness \
    >adventure c263; warning: pointer targets in passing argument 2 of 'strncpy' differ in signedness \
    >adventure.c:268: warning: pointer targets in passing argument 1 of 'strncpy' differ in signedness \
    >adventure.c:268: warning: pointer targets in passing argument 2 of 'strncpy' dif fer in signedness


 - __Reason__
  
    - I used different type of variable from the function requires:
  
    - eg: 

          unsigned char* new_bar; 
          char* name; 
          room_len = strlen(name); 
          strncpy(new_bar, name, room_len);

 - __Method Used to Fix__

    - Just change them to the same type of variable can fix.

 ## Bug 03
 - __Problem__
    - when I typed in more than 20 characters (I set a limit of 20 words of input), The status bar will become a mess. But the status_msg is showed correctly.



 - __Reason__
    - In  ***text.c***, I calculated the **strlen** of the input string. But in ***adventure.c***, I initiallized a **char[40]**, and filled all the 40 elements without a **'\0'** at the end.
  
    - So the **strlen()** in ***text.c*** doesn't know how to calculate the strlen of the input, thus wrongly positioned the words.

    - For why it didn't mess up when input<20, I would just say "lucky".



 - __Method Used to Fix__
    - Put an extra char **'\0'** in the end.
  
            char[41] new_bar;
            new_bar[40] = '\0';
            ... // copy other things into new_bar


--- 


# MP2-2

## Bug01 - Palette
- __Problem__
  - Some black holes on my image


- __Reason__
  - Forgot to initiallize discovered[4096] all to 0
  - Thus there are some colors that are wrongly not included into the level2


- __Method Used to Fix__
  - Initiallize all elements to 0 (as not discovered in level4)





## Bug02 - TUX
- __Problem__
  - everytime in a new program (i.e relaunch **./adventure**) the LEDs in tux won't change before I press **reset**


- __Reason__
  - in **tux_ioctl_init()**, I have code like this:

         if (ack_flag == 0)   // did not recieve ACK
            return 0;

  - this preveneted me from initializing every tux.

- __Method Used to Fix__
  - Simply delete this line of code
  - 






## Bug03
- __Problem__
  - I could once never use the tux, it has no response.


- __Reason__
  - in my **tux_ioctl_init()**, I sent a 4-byte packet to tux. But it should be 8-byte, including LED_patterns


- __Method Used to Fix__
      
      int tuxctl_ioctl_init(struct tty_struct* tty) {
    	unsigned char packet[8] = {MTCP_BIOC_ON, MTCP_LED_USR, MTCP_LED_SET, 0x0F, 0, 0, 0, 0};
    	LED_pattern[0] = 0;
    	LED_pattern[1] = 0;
    	LED_pattern[2] = 0;
    	LED_pattern[3] = 0;
      }