# Optica
#
# Ammeter support
#
# This is a very simple charge meter simulation. The idea is to use the ammeter to give a
# visual clue to what is happening with the battery/alternator, not to accurately simulate
# charging/discharing. Since this is rather abstract, the ammeter is dimensionless.
#
# The ammeter is assumed to be in charge-mode not load-mode; in other words, in series between
# the battery and the load rather than in series with the alternator and the load. It monitors
# the load from the master bus.
#
# Gary Neely aka 'Buckaroo'
#


var CHARGE_UPDATE	= 1;						# This needs to be 1 second.
var BATT_CHARGE_RATE	= 600;						# Seconds to 'recharge' battery after using starter

var battery_charge	= props.globals.getNode("/systems/electrical/battery-charge");
var sw_battery		= props.globals.getNode("/controls/switches/battery");
var sw_alternator	= props.globals.getNode("/controls/switches/alternator");
var sw_avionics		= props.globals.getNode("/controls/switches/avionics");
var sw_pitot		= props.globals.getNode("/controls/switches/pitotheat");
var sw_ltland		= props.globals.getNode("/controls/lighting/landing");
var sw_lttaxi		= props.globals.getNode("/controls/lighting/taxi");
var starter_used	= props.globals.getNode("/systems/electrical/starter-used");



var charge_update_loop = func {
  if (!sw_battery.getValue()) {						# Meter reads zero if battery circuit open
    battery_charge.setValue(0);						# Update the ammeter
  }
  else {
    if (sw_alternator.getValue() and getprop("/systems/electrical/suppliers/alternator") > 23.5) {
									# Alternator is supplying current:
      var load = 2;							# Assume an arbitrary trickle charge to battery
      var starter_deficit = starter_used.getValue();
      if (starter_deficit) {
        load += 10 * starter_deficit/BATT_CHARGE_RATE;			# Accounts for charging battery after a start
      }
      battery_charge.setValue(load);					# Update the ammeter
      if (starter_deficit > 0) {					# Decrement starter deficit to
        starter_used.setValue(starter_deficit - 1);			# simulate charging
      }
    }
    else {
      var load = -3;							# An arbitrary base system load
      if (sw_avionics.getValue())	{ load -= 1; }			# Add a little if avionics are on
      if (sw_ltland.getValue())		{ load -= 3; }			# Landing light draws a fair amount
      if (sw_lttaxi.getValue())		{ load -= 2; }			# Taxi light draw
      if (sw_pitot.getValue())		{ load -= 2; }			# Pitot heat draw
      battery_charge.setValue(load);					# Update the ammeter
    }
  }

  settimer(charge_update_loop, CHARGE_UPDATE);
}


settimer(charge_update_loop, 2);					# Delay startup a bit to allow things to initialize

