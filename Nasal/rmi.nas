# RMI Support
#
# Gary Neely aka 'Buckaroo'
#
# Support to calculate RMI needle deflections based on mode (VOR/ADF)
# and beacon range. The main function is to set default needle positions
# for out-of-range situations.
#
# Function writes to two custom properties:
#  /instrumentation/rmi-needle[0]/value
#  /instrumentation/rmi-needle[1]/value
#
# These are read by the RMI instrument animations.
#



var UPDATE_PERIOD	= 0;						# How often to update in seconds (0 = framerate)

var rmi1	= props.globals.getNode("/instrumentation/rmi-needle[0]");
var rmi2	= props.globals.getNode("/instrumentation/rmi-needle[1]");
var adf1	= props.globals.getNode("/instrumentation/adf[0]");
var nav2	= props.globals.getNode("/instrumentation/nav[1]");
var heading	= props.globals.getNode("/instrumentation/heading-indicator/indicated-heading-deg");

var rmi_update = func {

  var needle1 = 90;						# Needle default off or out-of-range positions
  var needle2 = 270;

								# Needle 1:
  if (nav2.getNode("in-range").getValue() and !nav2.getNode("has-gs").getValue()) {
    needle1 = nav2.getNode("heading-deg").getValue() - heading.getValue(); 
  }

								# Needle 2:
  if(adf1.getNode("in-range").getValue()) {
    needle2 = adf1.getNode("indicated-bearing-deg").getValue();
  }

  rmi1.getNode("value").setValue(needle1);
  rmi2.getNode("value").setValue(needle2);

  settimer(rmi_update, UPDATE_PERIOD);
}



# Nasal code to push FALSE values into the adf[0] and adf[1] in-range properties
# on a 4 second interval - this is a hack to make ADF work correctly since there
# is an issue where the in-range does not go back to FALSE on its own.  If you
# truly ARE in range it will flip back to TRUE instantly on its own, but will stay
# at FALSE if you are indeed out of range
#
# Thanks to Wolfram Gottfried aka 'Yakko' for this fix.
#

#var adf0_inrange = props.globals.getNode("/instrumentation/adf[0]/in-range");
#var adf1_inrange = props.globals.getNode("/instrumentation/adf[1]/in-range");
#
#var adf_reset = func {
#  adf0_inrange.setValue(0);
#  adf1_inrange.setValue(0);
#  settimer(adf_reset, 4);
#}



settimer(rmi_update, 2);				# Delay startup a bit to allow things to initialize
#settimer(adf_reset, 2);				# Delay startup a bit to allow things to initialize
