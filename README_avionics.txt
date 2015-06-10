Avionics

The package includes my simulations of the Bendix/King KMA24, KX155, KR87, KT76c, and KN62a. These were entirely made by me, so blame me for any problems.


KMA 24 Audio Panel

Currently this doesn't do much. You can play with the knob, test the marker beacon lights, and toggle the marker beacon sound on/off.


KX 155 NavComm (x2)

Should be self-explanatory and works more or less like the real thing. The frequency knobs adjust the USE frequency. The left hotspot adjusts MHz portion, while the right hotspot adjusts the KHz portion. Use the middle mouse button to decrement these values. The arrow buttons swap the USE and STANDBY frequencies. Use the IDENT knob to enable the audio station identification beeps.

The top NavComm (Nav1) is tied to the CDI, while the lower NavComm (Nav2) is tied to the RMI (the skinny pointer). This lets you follow two beacons at once.


KR 87 ADF

Includes basic frequency tuning functionality for the primary and standby frequencies. Tuning works similar to the KX 155 hotspots. Output is tied to the fat RMI needle and the ADF intrument. Other functions are not implemented.


KT 76c Transponder

Since Flightgear ATC systems currently don't use a real transponder system, this unit doesn't really do much. But you can turn it on and squawk all you want for practice, or use it on ALT mode as an altitude display. If Flightgear ever did adopt a transponder scheme, the unit can easily be set up to send the values over MP-- all the necessary properties are already set up.


KN 62A DME

Works pretty close to the real thing. It can be internally tuned to a nav frequency, or it can use the Nav1 frequency set by the topmost KX 155. The two finger buttons control mode and power. (I'm sorry that these controls are a bit hard to see, but this is what they look like in real life.)

The unit defaults to FREQ mode, which uses its own internal nav setting. This can be tuned using the knob, similar to my other units. In this mode the unit displays distance to the beacon and the internal frequency. Click on the mode button to move the switch to the right to GS/T setting. This selects GroundSpeed/Time mode which displays distance, groundspeed, and time to the beacon in minutes. The unit retains your selected frequency in this mode, and disables the tuning knobs. Use the middle mouse button to move the mode switch all the way to the left to RMT (Remote) mode. This slaves the unit to the Nav1 frequency. The internal frequency is retained, so you can always switch back. In RMT mode, distance, groundspeed and time are displayed.

Note that the real unit has a somewhat complex method of using the knobs to tune the unit, pushing and pulling the two knobs for various levels of tuning refinement. This would be difficult and cumbersome to simulate, so I didn't bother, instead keeping the method consistent with my other units.
 
