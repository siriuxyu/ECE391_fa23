# P1 Solution

## Q1 Adding a non-scrolling status bar

The VGA hardware provides the ability to specify a horizontal division which divides the screen into two windows which can start at separate display memory addresses.  
In addition, it provides the facility for panning the top window independent of the bottom window.

### 1) Registers value setting

- __Start Address: set to the addr of the postion after the scan line__
  - Start Address High
  - Start Address Low  
  
- __Non-scrolling__
  - PPM(bit 5) set to 1 in attribute address register
  
- __The Line Compare field in the VGA specifies the scan line address of the horizontal division__
  - bit 9 is in the Maximum Scan Line Register
  - bit 8 is in the Overflow Register
  - bits 7-0 are in the Line Compare Register
  
### 2) How the VGA acts

- When the line counter reaches the value in the Line Compare Register, the current scan line start address is reset to 0. If the Pixel Panning Mode field is set to 1 then the Pixel Shift Count and Byte Panning fields are reset to 0 for the remainder of the display cycle allowing the top window to pan while the bottom window remains fixed. Otherwise, both windows pan by the same amount.
  
### 3) Constraints

- __The first limitation__ is that the bottom window's starting display memory address is fixed at 0. This means that the bottom screen must be located first in memory and followed by the top.  

- __The second limitation__ is that either both windows are panned by the same amount, or only the top window pans, in which case, the bottom window's panning values are fixed at 0.  

- __The third limitation__ is that the Preset Row Scan field only applies to the top window. The bottom window has an effective Preset Row Scan value of 0.



## Q2 Change the VGA's color palette

### 1) Sequence of registers operations  

- __DAC Address Write Mode Register__ \
  The value written is the index of the first DAC entry to be written
  
- __DAC State Register__ \
  The value in the entry specified by DAC Address Write Mode Register

### 2) How to change the color  

      CLI()
      spin_lock()
      write the index of first DAC entry to DAC Address Read Mode Register
      write red intensity value to DACData
      write green intensity value to DACData
      write blue intensity value to DACData
      spin_unlock()
      STI()  
