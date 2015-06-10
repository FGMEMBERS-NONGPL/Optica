# Optica
#
# Fuel Update routines
#
# The Optica has two 33 gallon tanks located in the leading edge of the wings forward of the flaps.
# There is no sump tank, at least none listed on certification sheets.
# Control is via a single tank selection swtich having the positions Left, Right, and Off. There is
# no setting for Both. One documented procedure was to feed from one tank for half an hour, then
# switch over to the other tank for half an hour, etc.
#
# Gary Neely aka 'Buckaroo'
#
# Standard fuel densities:
# JetA 6.72 (6.47-7.01) lb/gal, 0.775-0.840 kg/l @15C
# Avgas 6.02 lb/gal, 0.721 kg/l @15C
#


var FUEL_UPDATE		= 0.3;						# Update interval in secs for main fuel routine
var FUEL_UPDATE_LONG	= 10;						# Update interval if fuel state frozen
var PPG			= 6.02;						# Standard fuel density
var MAX_TANKS		= 1;						# Standard tanks to consider, 0..MAX_TANKS
var FUEL_PRESS_MIN	= 12;						# Minimum fuel pressure requirements
var FUEL_PRESS_TARGET	= 35;						# Best fuel pressure

var tank_list		= [];
var engine		= nil;
var fuel_freeze		= nil;
var total_gals		= nil;
var total_lbs		= nil;
var total_norm		= nil;

var selected_tank	= props.globals.getNode("/controls/fuel/selected-tank");
var fuel_pump		= props.globals.getNode("/systems/electrical/outputs/fuelpump");


								# Map tank selector switch to tanks
								# -1 = off, 0 = left, 1 = right
var tank_switch = func(i) {					# i: inc/dec indicator
  var s = selected_tank.getValue();
  if (i > 0) {							# Move selector knob counter-clockwise
    if (s == -1)	{ s = 1; }				# off moves to right
    elsif (s == 1)	{ s = 0; }				# right moves to left
  }
  else {							# Move selector clockwise
    if (s == 0)		{ s = 1; }				# left moves to right
    elsif (s == 1)	{ s = -1; }				# right moves to off
  }
  selected_tank.setValue(s);
}



var fuel_update_loop = func {						# Subtract consumed fuel from tanks

  if (fuel_freeze) {							# Fuel simulation frozen, engines consume no fuel
    engine.getNode("fuel-consumed-lbs").setDoubleValue(0);		# Reset engine's consumed fuel
    settimer(fuel_update_loop, FUEL_UPDATE_LONG);			# Update leisurely
    return 0;
  }

  var selected = selected_tank.getValue();				# Get tank selection & fuel cutoff status

									# Fuel pressure:
									# A Lycoming 260 has a mechanical pump and is typically provided
									# with an electric boost pump. The mechanical pump is always on
									# (unless it fails), and the electric pump is effectively a back-up, 
									# but is likely required for cold-start priming of the system.

  var fp = engine.getNode("fuel-press").getValue();
  if (fp > 0) {								# Fuel pressure present:
									# Kill pressure if fuel off
    if (selected == -1) {
      interpolate(engine.getNode("fuel-press"), 0, (fp/FUEL_PRESS_TARGET) * 10);
    }
									# Kill pressure if selected tank is empty
    elsif (tank_list[selected].getChild("level-gal_us").getValue() == 0 ) {
      interpolate(engine.getNode("fuel-press"), 0, (fp/FUEL_PRESS_TARGET) * 10);
    }
									# Kill pressure if no pumps active
    elsif (!fuel_pump.getValue() and !engine.getNode("running").getValue()) {
      interpolate(engine.getNode("fuel-press"), 0, (fp/FUEL_PRESS_TARGET) * 45);
    }
    elsif (fp < FUEL_PRESS_TARGET) {					# All good, make sure pressure is rising
      interpolate(engine.getNode("fuel-press"), FUEL_PRESS_TARGET, (FUEL_PRESS_TARGET - fp)/FUEL_PRESS_TARGET * 3)
    }
  }
  else {								# No fuel pressure:
									# Good fuel pressure if fueled and 1+ pump active
    if (selected > -1 and
        tank_list[selected].getChild("level-gal_us").getValue() > 0 and
        (fuel_pump.getValue() or engine.getNode("running").getValue())) {
      interpolate(engine.getNode("fuel-press"), FUEL_PRESS_TARGET, (FUEL_PRESS_TARGET - fp)/FUEL_PRESS_TARGET * 3);
    }
  }


									# Fuel consumption:

  if (engine.getNode("fuel-press").getValue() < FUEL_PRESS_MIN) {	# No fuel pressure
    engine.getNode("out-of-fuel").setBoolValue(1);			# Kill engine
  }
  elsif (selected == -1) {						# Switch set to fuel cutoff position
    engine.getNode("out-of-fuel").setBoolValue(1);			# Kill engine
  }
  else {								# Attempt to draw fuel from a tank:
    var consumed = engine.getNode("fuel-consumed-lbs").getValue();	# Fuel consumed in lbs from FDM calculation
									# Get tank's initial fuel load in lbs:
    #var tank_lbs = tank_list[selected].getChild("level-gal_us").getValue() * PPG; # Deprecated by FG 2.4
    var tank_lbs = tank_list[selected].getChild("level-lbs").getValue();
									# Update engine's OOF status based on fuel pressure
    if (engine.getNode("out-of-fuel").getValue() and
        tank_lbs > 0 and
        engine.getNode("fuel-press").getValue() >= FUEL_PRESS_MIN) {
      engine.getNode("out-of-fuel").setBoolValue(0);			# Reset fueled status
    }

    if (engine.getNode("running").getValue()) {
      var satisfied = 0;						# Value of 1 will indicate engine's fuel needs met

									# Subtract consumed fuel from tank. We might get a little freebie fuel
									# usage when a tank is almost empty, but it will be very small.
      tank_lbs -= consumed;
      if (tank_lbs < 0) {						# Test for empty tank; fuel usage was not satisfied
        tank_lbs = 0;							# Reset tank as empty (no negative fuel values)
      }
      else {
        satisfied = 1;							# Tank satisfied fuel needs
      }
									# Update tank properties
      #tank_list[selected].getChild("level-gal_us").setDoubleValue(tank_lbs/PPG);	# Deprecated by FG 2.4
      tank_list[selected].getChild("level-lbs").setDoubleValue(tank_lbs);


      if (!satisfied) {							# Engine's fuel needs met?
        engine.getNode("out-of-fuel").setBoolValue(1);			# If not, kill engine
      }
    }
  }
  engine.getNode("fuel-consumed-lbs").setDoubleValue(0);		# Reset engine's consumed fuel

									# Total fuel properties
  var lbs = 0;
  var gals = 0;
  var cap = 0;
  for(var i=0; i<=MAX_TANKS; i+=1) {
    lbs += tank_list[i].getNode("level-lbs").getValue();
    gals += tank_list[i].getNode("level-gal_us").getValue();
    cap += tank_list[i].getNode("capacity-gal_us").getValue();
  }
  total_lbs.setDoubleValue(lbs);
  total_gals.setDoubleValue(gals);
  total_norm.setDoubleValue(gals / cap);				# Capacity will never reasonably be 0

  settimer(fuel_update_loop, FUEL_UPDATE);				# You go back, Jack, do it again...
}



var fuel_startup = func {
									# Deal with fuel menu select boxes
									# Note that these are not cutoff valves;
									# Listeners are used to re-enable oof status
									# if the user plays with the selection boxes

  var tank0_select	= props.globals.getNode("/consumables/fuel/tank[0]/selected");
  var tank1_select	= props.globals.getNode("/consumables/fuel/tank[1]/selected");
  
  setlistener(tank0_select, func {
    if (tank0_select.getValue() or tank1_select.getValue()) { engine.getNode("out-of-fuel").setBoolValue(0); }
  });
  setlistener(tank1_select, func {
    if (tank0_select.getValue() or tank1_select.getValue()) { engine.getNode("out-of-fuel").setBoolValue(0); }
  });
									# Reset oof on tank selection:
  setlistener("/controls/fuel/selected-tank", func() {
    if (selected_tank.getValue() > -1 and
        (tank_list[0].getChild("level-gal_us").getValue() or 
         tank_list[1].getChild("level-gal_us").getValue()))
      { engine.getNode("out-of-fuel").setBoolValue(0); }
  });

  fuel_update_loop();							# Initiate fuel update sequence
}


									# Support for clean property initialization
									# For backward compatibility; FG 2+ has a better method
var init_double_prop = func(node, prop, val) {
  if (node.getNode(prop) != nil) {
    val = num(node.getNode(prop).getValue());
  }
  node.getNode(prop,1).setDoubleValue(val);
}


var FuelInit = func {
  fuel.update = func{};							# Remove default fuel fuel system
									# Listen for sim suspended fuel usage toggle
  setlistener("/sim/freeze/fuel", func(n) { fuel_freeze = n.getBoolValue() }, 1);
  									# Set up fuel summary properties
  total_gals = props.globals.getNode("/consumables/fuel/total-fuel-gals",1);
  total_lbs = props.globals.getNode("/consumables/fuel/total-fuel-lbs",1);
  total_norm = props.globals.getNode("/consumables/fuel/total-fuel-norm",1);
									# Set up fuel-related engine properties
  engine = props.globals.getNode("engines/engine[0]");
  engine.getNode("fuel-consumed-lbs",1).setDoubleValue(0);
  engine.getNode("out-of-fuel",1).setBoolValue(1);			# Begin with engines shutdown

									# Fetch the tank list:
  tank_list = props.globals.getNode("/consumables/fuel",1).getChildren("tank");
									# Set up tank properties
									# We only need to deal with the tanks that matter (0-MAX_TANKS),
									# the rest are FDM zombie tanks
  for(var i=0; i<=MAX_TANKS; i+=1) {
    init_double_prop(tank_list[i], "level-gal_us", 0);
    init_double_prop(tank_list[i], "level-lbs", 0);
    init_double_prop(tank_list[i], "capacity-gal_us", 0.01);		# Not zero (div/zero issue)
    # init_double_prop(tank_list[i], "density-ppg", PPG);		# Deprecated by FG 2.4
    if (tank_list[i].getNode("selected") == nil)			# This value should always be true
      tank_list[i].getNode("selected",1).setBoolValue(1);
  }

  settimer(fuel_startup, 2);						# Delay startup a bit to allow things to initialize
}
