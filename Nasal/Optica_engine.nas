# Edgley Optica
#
# Engine management routines
#
# Gary Neely aka 'Buckaroo'
#



var UPDATE_INTERVAL	= 0.2;					# Update engines every 0.2 secs
var MAX_RPM		= 2200;					# Above this the engine starts to accumulate strain
								# from over-rev issues if MAX_RPM_T exceeded
var MAX_RPM_CLK		= 60;					# Secs; Time up to this value doesn't count toward strain
var MAX_IDLE		= 1200;					# Above this the engine starts to accumulate strain
								# from oil viscosity issues
var MAX_STRAIN		= 20000;				# Arbitrary strain value, when exceeded, engine fails
var OILV_DELTA_WARMUP	= 0.002;				# Viscosity increment per cycle when warming up
var OILV_DELTA_COOLDN	= 0.0002;				# Viscosity decrement per cycle when cooling down
var VISC_PENALTY	= 40;					# Maximum reduction of oil pressure for viscosity
var COLD_OIL_FACTOR	= 25;					# Arbitrary strain value for running engine over idle when cold;
								# this is killer, so keep value small or users will whine
var MAX_OK_OILT		= 118;					# Maximum best oil temperature
var MIN_OK_OILT		= 60;					# Minimum best oil temperature
var MIN_OILP		= 25;					# Minimum acceptable oil pressure
var MAX_OILP		= 115;					# Highest value oil pressure will register
var MAX_OK_OILP		= 95;					# Maximum best oil pressure
var MIN_OK_OILP		= 55;					# Minimum best oil pressure

var CYLT_MAX		= 260;					# Engine always takes damage above this temp
var TARGET_CYLT_HIGH	= 220;					# Target best cylinder head temp, high end
								# Engine takes damage above this temp after a time interval
var TARGET_CYLT_LOW	= 150;					# Target best cylinder head temp, low end
var CYLT_MIN		= 100;					# Low end of operating cylinder head temp
var MAX_CYLT_STRAIN_CLK	= 60;					# Time in secs that must pass before engine under CYLT_MAX
								# but over CYLT_HIGH starts taking damage
var DELTA_T_F		= 0.1;					# Change in temperature master factor,
								# inc to make changes faster, dec to slow temp changes
var DELTA_T_ENV		= 0.014;				# Change in temp due to ambient air factor
var DELTA_T_THRUST	= 0.0075;				# Change in temp due to power factor
var DELTA_T_AS		= 0.022;				# Change in temp due to airspeed-induced air factor
var MIXTURE_CUTOFF	= 0.8;					# Mixture setting: below this value, no cooling benefits
var MIXTURE_FACTOR	= 14;					# Mixture cooling benefits multiplier
var OPOH		= 50;					# Engine operational overhead value
var PROP_AIR		= 0.01;					# Factor for prop air moving over engine
var AMBIENT_REDUCTION	= 0.25;					# Factor for reduction of ambient cooling under max operating range
var MIXTURE_PEAK	= 0.74;					# Observed mixture setting for peak power
var MIXTURE_BIAS	= 10;					# Max degrees C to augment cyl temp at mixture peak
var ENGINE_MASS		= 1;					# Engine mass factor; not currently used, but the idea is to
								# inc this to slow temperature changes


var eng_checks	= props.globals.getNode("/sim/Optica/engine-checks");
var eng_warns	= props.globals.getNode("/sim/Optica/engine-warns");
#var tanks	= props.globals.getNode("/consumables/fuel").getChildren("tank");
var engine	= props.globals.getNode("/engines/engine[0]");
var engcontrols	= props.globals.getNode("controls/engines/engine[0]");
var airspeed	= props.globals.getNode("/velocities/airspeed-kt");
var envtemp	= props.globals.getNode("/environment/temperature-degc");
# Defined under Optica-fuel.nas:
#var fuel_scalar	= props.globals.getNode("consumables/fuel/consumption-scalar").getValue();


var oilt_target = (MAX_OK_OILT-MIN_OK_OILT)/2 + MIN_OK_OILT;	# Calculate a nice mid-range temp value to seek
var oilp_target = (MAX_OK_OILP-MIN_OK_OILP)/2 + MIN_OK_OILP;	# Calculate a nice mid-range pressure value to seek


								# Functions for enabling engine options:

var eng_checks_set = func {
  if (eng_checks.getValue()) { eng_checks.setValue(0); var mssg = "Engine parameter checks disabled."; }
  else			     { eng_checks.setValue(1); var mssg = "Engine parameter checks enabled."; }
  Optica_screenmssg.fg = [1, 1, 1, 1];
  Optica_screenmssg.write(mssg);
}
var eng_warns_set = func {
  if (eng_warns.getValue())  { eng_warns.setValue(0); var mssg = "Engine parameter warnings disabled."; }
  else			     { eng_warns.setValue(1); var mssg = "Engine parameter warnings enabled."; }
  Optica_screenmssg.fg = [1, 1, 1, 1];
  Optica_screenmssg.write(mssg);
}

								# Engine warning messages:

var eng_checks_overrev = func {
  var mssg = "Engine over-rev warning.";
  Optica_screenmssg.fg = [1, 0.5, 0, 1];
  Optica_screenmssg.write(mssg);
}
var eng_checks_overheat = func {
  var mssg = "Engine over-heating warning.";
  Optica_screenmssg.fg = [1, 0.5, 0, 1];
  Optica_screenmssg.write(mssg);
}
var eng_checks_oilcold = func {
  var mssg = "Engine oil temperature warning.";
  Optica_screenmssg.fg = [1, 0.5, 0, 1];
  Optica_screenmssg.write(mssg);
}
var eng_checks_damage = func(y) {
  var mssg = "Engine has passed 25% damage.";
  if (y > MAX_STRAIN * 0.9)		{ mssg = "Engine is critical."; }
  elsif (y > MAX_STRAIN * 0.75)		{ mssg = "Engine has passed 75% damage."; }
  elsif (y > MAX_STRAIN * 0.5)		{ mssg = "Engine has passed 50% damage."; }
  Optica_screenmssg2.fg = [1, 0.5, 0, 1];
  Optica_screenmssg2.write(mssg);
}
var eng_checks_failure = func {
  var mssg = "Engine failure.";
  Optica_screenmssg2.fg = [1, 0, 0, 1];
  Optica_screenmssg2.write(mssg);
}


var FtoC = func (f) {						# Fahrenheit to Celsius
  return (f-32) * 5 / 9;
}


								# Primary engine loop:

var engine_update = func {

  if (engine.getNode("running").getValue() == 1) {		# Is engine running?

								# Simplified oil temp, viscosity, pressure
								# Note that viscosity is a dimensionless normalized value,
								# not a true viscosity number
    var oilv = engine.getNode("oil-visc").getValue();
    if (oilv > 0) {
      oilv = oilv - OILV_DELTA_WARMUP;				# Determine new oilv as necessary
      engine.getNode("oil-visc").setValue(oilv);		# Save viscosity
      var oilp =  ((MAX_OILP - oilp_target) * oilv) + oilp_target;# Viscosity determines position between max oilp and target best oilp
      engine.getNode("oil-press").setValue(oilp);		# Save oilp, probably not necessary to interpolate
								# Oilt rises from ambient as viscosity falls
      var oilt = (oilt_target - envtemp.getValue()) * (1-oilv) + envtemp.getValue();
      engine.getNode("oiltempc").setValue(oilt);		# Save oilt as deg C

								# Oil pressure check:
      if (oilp > MAX_OK_OILP and engine.getNode("rpm").getValue() > MAX_IDLE) {
        if (eng_checks.getValue()) {
          engine.getNode("strain").setValue(engine.getNode("strain").getValue() + (COLD_OIL_FACTOR/oilv));
        }
        if (eng_warns.getValue()) { eng_checks_oilcold(i); }	# Notice to user
      }
    }


								# Cyl head temp change calculations:
								# Currently this accounts for environmental cooling,
								# airflow cooling, and thrust/rpm heating.
    var cyl_temp	= engine.getNode("cyltempc").getValue();
    var thrust		= engine.getNode("prop-thrust").getValue();
    var mixture		= engcontrols.getNode("mixture").getValue();
    var throttle	= engcontrols.getNode("throttle").getValue();
    var dT_env		= (envtemp.getValue() - cyl_temp) * DELTA_T_ENV;
    var dT_thrust	= (thrust + OPOH) * DELTA_T_THRUST;
    var dT_airspeed	= airspeed.getValue() * DELTA_T_AS;
    var dT_mixture	= mixture - MIXTURE_CUTOFF;
    if (dT_mixture < 0) { dT_mixture = 0; }			# DeltaT due to rich mixture benefits
    else		{ dT_mixture = dT_mixture * MIXTURE_FACTOR; }
    if (cyl_temp <= TARGET_CYLT_LOW) {				# When below best operating low temp:
      dT_env = dT_env * AMBIENT_REDUCTION;			# DeltaT due to ambient reduction benefits
      dT_airspeed = 0;						# No airspeed benefits below best operating temp low range
								# Linearly reduce mixture benefits down to ambient temp
      dT_mixture = 0;						# No significant mixture benefits in this range
    }
    elsif (cyl_temp < TARGET_CYLT_HIGH) {			# When within best operating temp range:
								# Normalize temperature range:
      var temp_norm = (cyl_temp - TARGET_CYLT_LOW) / (TARGET_CYLT_HIGH - TARGET_CYLT_LOW);
								# Linearly reduce ambient benefits from full to AMBIENT_REDUCTION over range
      dT_env = dT_env * (AMBIENT_REDUCTION + (AMBIENT_REDUCTION * temp_norm));
								# Linearly reduce airspeed benefits from full to none
      dT_airspeed = dT_airspeed * temp_norm;
								# Linearly reduce mixture benefits from full to none
      if (dT_mixture > 0) { dT_mixture = dT_mixture * temp_norm; }
    }
    var delta_cyl_temp	= (dT_env + dT_thrust - dT_airspeed - dT_mixture) * DELTA_T_F;
    cyl_temp = cyl_temp + delta_cyl_temp;
    engine.getNode("cyltempc").setValue(cyl_temp);


    
								# For testing and debugging:
    #engine.getNode("cyl-dt").setValue(delta_cyl_temp);
    #engine.getNode("cyl-dte").setValue(dT_env);
    #engine.getNode("cyl-dtt").setValue(dT_thrust);
    #engine.getNode("cyl-dta").setValue(dT_airspeed);
    #engine.getNode("cyl-dtm").setValue(dT_mixture);


  }
  else {							# Engine not running
								# Cyl temp cool-down:
    var cyl_temp	= engine.getNode("cyltempc").getValue();
    var dT_env		= (envtemp.getValue() - cyl_temp) * DELTA_T_ENV;
    var dT_airspeed	= airspeed.getValue() * DELTA_T_AS;
    if (cyl_temp <= TARGET_CYLT_LOW) {				# When below best operating low temp:
      dT_env = dT_env * AMBIENT_REDUCTION;			# Reduce ambient cooling
      dT_airspeed = 0;						# No airspeed benefits below best operating temp low range
    }
    elsif (cyl_temp < TARGET_CYLT_HIGH) {			# When withing best operating temp range:
								# Normalize range:
      var temp_norm = (cyl_temp - TARGET_CYLT_LOW) / (TARGET_CYLT_HIGH - TARGET_CYLT_LOW);
								# Linearly reduce ambient benefits from full to AMBIENT_REDUCTION over range
      dT_env = dT_env * (AMBIENT_REDUCTION + (AMBIENT_REDUCTION * temp_norm));
      dT_airspeed = dT_airspeed * temp_norm;			# Linearly reduce airspeed benefits from full to none
    }
    var delta_cyl_temp	= (dT_env - dT_airspeed) * DELTA_T_F;
    cyl_temp = cyl_temp + delta_cyl_temp;
    engine.getNode("cyltempc").setValue(cyl_temp);
    engine.getNode("cyltempc-biased").setValue(cyl_temp);

								# Oil cool-down; see main oil section for notes
    var oilv = engine.getNode("oil-visc").getValue();
    if (oilv < 1) {
      var oilt = (oilt_target - envtemp.getValue()) * (1-oilv) + envtemp.getValue();
      engine.getNode("oiltempc").setValue(oilt);
      var oilp = ((MAX_OILP - oilp_target) * oilv) + oilp_target;
      engine.getNode("oil-press").setValue(oilp);
      engine.getNode("oil-visc").setValue(oilv + OILV_DELTA_COOLDN);
    }

  } # end engines-not-running

  settimer(engine_update, UPDATE_INTERVAL);
}



var engine_setup = func {
								# Set engines to ambient temp on startup
  engine.getNode("cyltempc").setValue(envtemp.getValue());
  engine.getNode("oiltempc").setValue(envtemp.getValue());
								# Uncomment to pre-warm engines for testing:
  #engine.getNode("cyltempc").setValue((TARGET_CYLT_HIGH-TARGET_CYLT_LOW)/2+TARGET_CYLT_LOW);
  engine_update();
}


var EngineInit = func {
  settimer(engine_setup, 1);					# Give a few seconds for environment vars to initialize
}
