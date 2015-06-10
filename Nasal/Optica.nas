# Edgley OA-7 Optica
#
# Gary Neely aka 'Buckaroo'
#

								# Set up the livery machine
aircraft.livery.init("Aircraft/Optica/Models/Liveries");


								# Set up screen message windows
var Optica_screenmssg	= screen.window.new(nil, -150, 2, 5);
var Optica_screenmssg2	= screen.window.new(nil, -180, 2, 5);


								# Doors
var Optica_door_left	= aircraft.door.new("/controls/doors/left", 1);
var Optica_door_right	= aircraft.door.new("/controls/doors/right", 1);

var Optica_doors_left = func {
  if (getprop("/controls/doors/left/position-norm")) {		# Can always close an open door
    Optica_door_left.toggle();
    return 0;
  }
  if (getprop("/gear/gear[1]/wow")) {				# At least be on the ground
    Optica_door_left.toggle()
  }
  else {
    Optica_screenmssg.fg = [1, 1, 1, 1];
    Optica_screenmssg.write("What, without a parachute?!");
  }
}
var Optica_doors_right = func {
  if (getprop("/controls/doors/right/position-norm")) {
    Optica_door_right.toggle();
    return 0;
  }
  if (getprop("/gear/gear[1]/wow")) {
    Optica_door_right.toggle()
  }
  else {
    Optica_screenmssg.fg = [1, 1, 1, 1];
    Optica_screenmssg.write("What, without a parachute?!");
  }
}

								# Magneto and starter stuff:

								# Disabled keyboard engine starter message
var starter_null = func {
  Optica_screenmssg.fg = [1, 1, 1, 1];
  Optica_screenmssg.write("Use the starter switch.");
}

var Optica_magnetos	= props.globals.getNode("/engines/engine[0]/magnetos");
var Optica_ignition	= props.globals.getNode("/controls/switches/ignition");
var Optica_starter	= props.globals.getNode("/controls/engines/engine[0]/starter");
#var starter_used	defined in Optica_ammeter.nas

var ignition_switch = func(i,j) {				# i: inc/dec indicator, j: modup indicator
  var ign = Optica_ignition.getValue();
  if (j > 0) {							# Are we coming off a starter try?
    if (ign == 4) {
      Optica_starter.setValue(0);				# Disengage starter
      Optica_ignition.setValue(3);				# Return ignition to 'Both' setting
    }
    return 0;
  }
  if (i > 0) {							# Augmenting switch status?
    if (ign < 3) {						# Augmenting magneto selection?
      controls.stepMagnetos(1);
      ign = ign + 1;
    }
    else {							# Engage starter
      ign = 4;
      if (getprop("/systems/electrical/outputs/starter")) {
        Optica_starter.setValue(1);
        starter_used.setValue(600);				# See Optica_ammeter.nas
      }
    }
  }
  else {							# Decrementing switch status
    if (ign > 0 and ign < 5) {					# Augmenting magneto selection?
      controls.stepMagnetos(-1);
      ign = ign - 1;
    }
  }
  Optica_ignition.setValue(ign);
}



# Throttle mappings:

# The Optica with the Lycoming 260 HP engine is reported to have a substantial deadband in the middle
# of the throttle range where there is very little throttle response. While I don't know the exact range,
# I can build in an adjustable approximation to give a feel for the effect.


								# Mapping throttle control input to FDM output:
								# Modeled such that the normal range 0.3-0.7 has reduced effect
var t_input		= [0,	0.3,	0.7,	1];
var t_output		= [0,	0.3,	0.5,	1];

var throttle_pos	= props.globals.getNode("/controls/engines/engine[0]/throttle");
var throttle_pos_fdm	= props.globals.getNode("/controls/engines/engine[0]/throttle-fdm");

setlistener("/controls/engines/engine[0]/throttle", func {
								# Find lower and upper indices for throttle position
								# in t_input, t1 and t2:
  var t1=0;
  var t2=1;
  for(var i=1; i<size(t_input); i+=1) {
    if (throttle_pos.getValue() <= t_input[i]) {
      t2 = i; t1 = i-1;
      break;
    }
  }
								# Interpolate difference of t_pos between indices and
								# use same interpolation in t_output:
  var frac = (throttle_pos.getValue() - t_input[t1]) / (t_input[t2] - t_input[t1]);
  throttle_pos_fdm.setValue((t_output[t2] - t_output[t1]) * frac + t_output[t1]);
});



# Friction thumb-wheel
# In the real aircraft, this adjusts the friction on the mixture and throttle levers. Since that's not of concern
# in the simulator, I use this thumb-wheel to adjust the degree of mixture adjustment between course and fine.

var friction_control	= props.globals.getNode("/controls/switches/friction");
var mixture_setting	= props.globals.getNode("/controls/engines/engine[0]/mixture");

var Optica_mixture = func(i) {
  var delta = 0.01;
  if (friction_control.getValue()) { delta = 0.05; }
  var mixture = mixture_setting.getValue();
  if (i) {							# Increment mixture
    mixture += delta;
    if (mixture > 1) { mixture = 1; }
  }
  else {							# Decrement mixture
    mixture -= delta;
    if (mixture < 0) { mixture = 0; }
  }
  mixture_setting.setValue(mixture);
}

var Mixture_Report = func {
  var mixture = "fine";
  if (friction_control.getValue()) { mixture = "course"; }
  Optica_screenmssg.fg = [1, 1, 1, 1];
  Optica_screenmssg.write("Mixture adjust "~mixture~".");
}



# Flap switch
# There are no detents in the Optica, so setting flaps is a matter of engaging a double-throw switch to
# engage the electric motor that move the flaps.

var flaps_pos	= props.globals.getNode("/controls/flight/flaps");
var flaps_sw	= props.globals.getNode("/controls/switches/flaps");

#var Optica_flaps = func(i) {
#  var flaps = flaps_pos.getValue();
#  if (i) {							# Lower flaps
#    flaps += 0.01;
#    if (flaps > 1) { flaps = 1; }
#  }
#  else {							# Raise flaps
#    flaps -= 0.01;
#    if (flaps < 0) { flaps = 0; }
#  }
#  flaps_pos.setValue(flaps);
#}
								# Replaces the default controls.flapsDown function.
controls.flapsDown = func(i) {
  if (i == 0) {							# Center flap switch on mod-up control release
    flaps_sw.setValue(0);
  }
  elsif (i == 1) {						# Deploy flaps
    flaps_sw.setValue(-1);					# Switch to 'Down' position
    var flaps = flaps_pos.getValue();				# Increment flap position
    flaps += 0.01;
    if (flaps > 1) { flaps = 1; }
    flaps_pos.setValue(flaps);
  }
  else {							# -1, Retract flaps
    flaps_sw.setValue(1);					# Switch to 'Up' position
    var flaps = flaps_pos.getValue();				# Decrement flap position
    flaps -= 0.01;
    if (flaps < 0) { flaps = 0; }
    flaps_pos.setValue(flaps);
  }
}



									# Stall warning based on AoA
var stall_check = func {
  if (getprop("orientation/alpha-deg") > 13.0 and !getprop("gear/gear[1]/wow")) {
    setprop("sim/alarms/stall-warning",1);
  }
  else {
    setprop("sim/alarms/stall-warning",0);
  }
  settimer(stall_check, 0);
}


var sound_stuff = func {
  var mp = getprop("/engines/engine/mp-inhg");
  mp = mp * 0.0167 + 0.5;						# Crude re-scaling MP value for sound;

  var sound_agl = getprop("position/gear-agl-m");			# For diminished engine noise as we recede from ground
  if (sound_agl == nil) { sound_agl = 0; }
  elsif (sound_agl > 15) { sound_agl = 15; }				# max effect at 15m
  elsif (sound_agl < 0)  { sound_agl = 0; }
  setprop("sim/Optica/sound-agl",sound_agl);
  sound_agl = 1 - sound_agl * 0.024;					# Factor effect by .024 (0-0.36 volume reduction)

  var volume_engine = mp * sound_agl;
  if (volume_engine > 1) { volume_engine = 1; }
  if (volume_engine < 0) { volume_engine = 0; }
  setprop("sim/Optica/sound/volume-engine", volume_engine);
  settimer(sound_stuff, 0);
}


# Other stuff:


								# Establish which settings are saved on exit
var Optica_Savedata = func {
  aircraft.data.add("/instrumentation/oat/mode");		# Temp reporting mode C/F
}




								# Initialization:
setlistener("/sim/signals/fdm-initialized", func {
								# Start the fuel system. The Optica uses a customized
								# fuel routine. See Optica_fuel.nas
  FuelInit();
  EngineInit();							# See Optica-engines.nas
  #InstrumentationInit();					# See Optica_instrumentation_drivers.nas
  Optica_Savedata();
  sound_stuff();
  stall_check();
});


								# Fast start-up for testing purposes
var QuickStart = func{
  setprop("controls/fuel/selected-tank",0);
  setprop("engines/engine[0]/out-of-fuel",0);
  setprop("controls/engines/engine[0]/magnetos",3);
  setprop("controls/engines/engine[0]/throttle",0);
  setprop("controls/engines/engine[0]/throttle-fdm",0);
  setprop("controls/switches/ignition",3);
  setprop("controls/switches/alternator",1);
  setprop("controls/switches/battery",1);
  setprop("controls/switches/fuelpump",1);
  setprop("engines/engine[0]/fuel-press",35);
  setprop("controls/engines/engine[0]/mixture",1);
  setprop("engines/engine[0]/rpm",900);
  setprop("engines/engine[0]/running",1);
  setprop("controls/switches/avionics",1);
  setprop("controls/flight/flaps",0.2);
}


