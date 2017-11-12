////////////////////////////////////
//  Animate v2
//
// This program comes with ABSOLUTELY NO WARRANTY.  It is licensed under
// the terms of the GNU General Public License, version 3 or later.
//
//  About:
//  Provides AttractMode with animation capabilities
//
//  Description:
//  See animate2/README for a detailed explanation of use
//  See animate2/CHANGELOG for changes from v1
//
////////////////////////////////////

class Interpolator {
    constructor(arg = null) {

    }

    function interpolate( from, to, progress ) {

    }

    //print messages in debug mode
    function print(msg) {
        if ( Animation.GLOBALS.DEBUG ) {
            ::print( "Interpolator: " + msg + "\n" );
        }
    }
}

fe.do_nut(FeConfigDirectory + "modules/animate2/interpolators/cubicbezier.nut");
fe.do_nut(FeConfigDirectory + "modules/animate2/interpolators/penner.nut");

class Animation {
    static VERSION = 2.0;
    GLOBALS = {
        DEBUG = false,
        COUNT = 0
    }

    running = false;               //is the animation running
    last_update = 0;               //time of last update
    elapsed = 0;                   //time elapsed since animation started
    tick = 0;                      //time since last update
    started = 0;                   //time animation started
    progress = 0;                  //current animation progress, 0 to 1
    play_count = 0;                //number of times animation has played

    opts = null;                   //the current animation options
    _from = null;                  //values we are animating from
    _to = null;                    //values we are animating to

    states = null;                 //predefined states
    callbacks = null;              //registered callbacks for animation events
    yoyoing = false;               //is animation yoyoing
    
    // predefined duration shortcuts
    durations = {
        "slow": "750ms",
        "normal": "400ms",
        "fast": "200ms"
    }
    
    //predefined speed aliases
    speeds = {
        "half": 0.5,
        "normal": 1.0,
        "double": 2.0
    }

    default_config = {
        debug = false,              //is debug enabled for this animation
        target = null,              //target object to animate
        from = null,                //state (values) we will animate from
        to = null,                  //state (values) we will animate to
        triggers = [],              //array of transitions that will trigger the animation
        trigger_restart = true,     //when a trigger occurs, the animation is restarted
        default_state = "start"     //default state if no 'from' or 'to' is specified
        then = null,                //a function or state that is applied at the end of the animation
        duration = 0,               //duration of animation (if timed)
        speed = 1,                  //speed multiplier of animation
        smoothing = 0.033,          //smoothing ( magnifies speed )
        delay = 0,                  //delay before animation begins
        delay_from = true,          //delay setting the 'from' values until the animation begins
        loops = 0,                  //loop count (-1 is infinite)
        loops_delay = 0,            //separate delay that is applied only to a looped playback
        loops_delay_from = true,    //delay setting 'from' values until the loop delay finishes
        yoyo = false,               //bounce back and forth the 'from' and 'to' states
        reverse = false,            //reverse the animation
        interpolator = CubicBezierInterpolator("linear"),
        time_unit = "ms"            //default time unit for duration or delay - ms or s
    }

    constructor(...) {
        GLOBALS.COUNT++;

        //set defaults
        callbacks = [];
        states = {};
        defaults(vargv);

        //add callbacks
        fe.add_ticks_callback( this, "on_tick" );
        fe.add_transition_callback( this, "on_transition" );

        //initialize the animation
        init();
    }

    //reset animation options to defaults
    function defaults(params) {
        opts = clone( default_config );
        opts.name <- "anim" + GLOBALS.COUNT
        //if opts are provided, merge them
        if ( params.len() > 0 ) {
            if ( typeof(params[0]) == "table" ) {
                opts = merge_opts(opts, params[0]);
                //set the target if its in the config
                if ( "target" in opts && opts.target != null )
                    target(opts.target);
                //sanitize - initialize some option values
                foreach( key, val in opts ) {
                    if ( key == "duration" || key == "delay" || key == "loopsDelay" )
                        opts[key] <- parse_time( val );
                    if ( key == "speed" )
                        opts[key] <- parse_speed( val );
                }
            } else if ( typeof(params[0]) != "array" && typeof(params[0]) != "string" ) {
                //assume this is a target object instance
                target(params[0]);
            }
        }
        return this;
    }
    
    //set the target object for the animation
    function target( ref ) {
        opts.target <- ref;
        return this;
    }

    //listen to AM ticks
    function on_tick(ttime) {
        if ( running ) {
            if ( progress == 1 ) {
                stop();
            } else {
                tick = ::clock() * 1000 - last_update;
                elapsed += tick;
                last_update = ::clock() * 1000;
                //update animation progress
                update();
                if ( elapsed > opts.delay ) {
                    //increase progress
                    if ( opts.duration <= 0 ) {
                        progress = clamp( progress + ( opts.smoothing * opts.speed ), 0, 1);
                    } else {
                        //use time
                        local current = last_update;
                        local min = started;
                        local max = started + opts.delay + opts.duration;
                        progress = clamp( ( current - min ) / ( max - min ) , 0, 1 );
                    }
                } else {
                    print("DELAYED START: " + opts.delay );
                }
            }
        }
    }

    //listen to AM transitions
    function on_transition( ttype, var, ttime ) {
        //start an animation on matching transition
        foreach( t in opts.triggers ) {
            if ( t == ttype )
                if ( opts.trigger_restart )
                    restart();
                else
                    play();
        }
        return false;
    }

    //*** CHAINABLE METHODS ***
    function name( str ) { opts.name = str; return this; }
    function debug( bool ) { opts.debug = bool; return this; }
    function from( val ) { if ( typeof(val) == "string" && val in states ) opts.from = states[val]; else opts.from = val; return this; }
    function to( val ) { if ( typeof(val) == "string" && val in states ) opts.to = states[val]; else opts.to = val; return this; }
    function loops( count ) { opts.loops = count; return this; }
    function reverse( bool = true ) { opts.reverse = bool; return this; }
    function yoyo( bool = true ) { opts.yoyo = bool; return this; }
    function interpolator( i ) { opts.interpolator = i; return this; }
    function triggers( triggers ) { opts.triggers = triggers; return this; }
    function then( then ) { opts.then = then; return this; }
    function speed( s ) { opts.speed = s; return this; }
    function smoothing( s ) { opts.smoothing = s; return this; }
    function delay( length ) { opts.delay = length; return this; }
    function duration( d ) { opts.duration = d; return this; }
    function time_unit( unit ) { opts.time_unit = unit; return this; }
    function state( name, state ) { states[name] <- state; return this }
    function default_state( state ) { opts.default_state = state; return this; }
    function easing( e ) { if ( e.find("elastic") != null || e.find("bounce") != null ) return interpolator( PennerInterpolator(e) ); else return interpolator( CubicBezierInterpolator(e) ); }
    
    //NOT VERIFIED/WORKING YET!
    function delay_from( bool ) { opts.delay_from = bool; return this; }
    function loops_delay( delay ) { opts.loops_delay = delay; return this; }
    function loops_delay_from( bool ) { opts.loops_delay_from = bool; return this; }
    function trigger_restart( restart ) { opts.trigger_restart = restart; return this; }
    
    //add an event handler
    function on( event, param1, param2 = null ) {
        callbacks.push({
            event = event,
            env = ( param2 == null ) ? null : param1,
            func = ( param2 == null ) ? param1 : param2
        });
        return this;
    }

    //remove an event handler
    function off( event, param1, param2 = null ) {
        for( local i = 0; i < callbacks.len(); i++ )
            if ( param2 == null && callbacks[i].func == param1 )
                callbacks.remove(i);
            else
                if ( callbacks[i].env == param1 && callbacks[i].func == param2 )
                    callbacks.remove(i);
        return this;
    }

    //copy another animation
    function copy( anim ) {
        opts = clone( anim.opts );
        //will need to copy other values too ( time_unit, interpolator, etc )
        return this;
    }

    function init() {
        run_callback( "init", this );
    }

    //play the animation
    function play() {
        print(table_as_string(opts));
        start();
    }

    //start the animation
    function start() {
        //convert alias and time unit values
        opts.speed = parse_speed( opts.speed );
        opts.duration = parse_time( opts.duration );
        opts.delay = parse_time( opts.delay );
        opts.loops_delay = parse_time(opts.loops_delay);

        //reverse from and to if reverse is enabled
        if ( opts.reverse ) {
            _from = ( "to" in states == false ) ? opts.to : states["to"];
            _to = ( "from" in states == false ) ? opts.from : states["from"];
        } else {
            _from = ( "from" in states == false ) ? opts.from : states["from"];
            _to = ( "to" in states == false ) ? opts.to : states["to"];
        }

        //update times
        started = last_update = ::clock() * 1000;
        elapsed = 0;
        tick = 0;
        progress = 0;

        running = true;
        run_callback( "start", this );
    }

    //update the animation
    function update() {
        print( "p: " + progress + "\te: " + elapsed + " t: " + tick + "\tpc: " + play_count + " l: " + opts.loops + " r: " + opts.reverse + " y: " + yoyoing );
        run_callback( "update", this );
    }

    //pause animation at specified step (progress)
    function step(progress) {
        if ( running ) pause();
        this.progress = clamp(progress, 0, 1);
        update();
    }

    //pause the animation
    function pause() {
        running = false;
        run_callback( "pause", this );
    }

    //unpause the animation
    function unpause() {
        running = true;
        run_callback( "unpause", this );
    }

    //restart the animation
    function restart() {
        run_callback( "restart", this );
        play();
    }

    //stop animation (depending on options)
    function stop() {
        if ( opts.yoyo ) {
            //flip yoyoing, reverse animation
            yoyoing = !yoyoing;
            opts.reverse = !opts.reverse;
        }
        if ( yoyoing ) {
            //first half of 'yoyo' finished, restart to play second half
            restart();
        } else {
            if ( opts.loops == -1 || ( opts.loops > 0 && play_count < opts.loops ) ) {
                //play loop
                play_count++;
                restart();
            } else {
                //run a final update
                update();
                //finished animation
                running = false;
                run_callback( "stop", this );
                play_count = 0;
                //run then function or set state if either exist
                if ( "then" in opts && opts.then != null )
                    if ( typeof(opts.then) == "function" ) {
                        opts.then(this);
                        //don't keep running it .then()
                        opts.then = null;
                    }
                print( "DONE. " + " p: " + progress + " e: " + elapsed + " tick: " + tick + " u: " + last_update + " c: " + play_count + " l: " + opts.loops + " r: " + opts.reverse + " y: " + yoyoing );
            }
        }
    }

    //cancel the animation
    function cancel() {
        running = false;
        progress = 1.0;
        run_callback( "cancel", this );
    }

    //*****  Helper Functions  *****

    //save a state
    function save_state( name, table ) {
        if ( name in states == false ) states[name] <- {};
        if ( typeof(table) == "table" )
            foreach( key, val in table )
                states[ name ][ key ] <- val;
    }

    //run callbacks for an event
    function run_callback( event, params = {} ) {
        foreach( cb in callbacks )
            if ( cb.event == event )
                if ( cb.env != null )
                    cb.env[ cb.func ]( params );
                else
                    cb.func( params );
    }

    //print messages in debug mode
    function print(msg) {
        if ( Animation.GLOBALS.DEBUG || opts.debug ) {
            ::print( "animate2: " + ( ( opts.name != null ) ? opts.name + " : " : "" ) + msg + "\n" );
        }
    }

    //clamp a value from min to max
    function clamp(value, min, max) {
        if (value < min) value = min; if (value > max) value = max; return value
    }

    //parses for string time values ( i.e. "300ms", "2s" ), defaults float/integer to ms
    static function parse_time( value )
    {
        if ( typeof( value ) == "integer" || typeof( value ) == "float" )
          //use the default time unit for the number
          return ( opts.time_unit == "s" ) ? value.tofloat() * 1000 : value.tofloat();
        if ( typeof( value ) == "string" )
            //look for a predefined time string
            foreach( key, val in Animation.durations )
                if ( value == key ) value = Animation.durations[key];
        if ( typeof( value ) == "string" ) {
            //parse other strings
            if ( value.slice( value.len() - 2, value.len() ) == "ms" )
                //get ms string
                value = ( value.slice( 0, value.len() - 2 ) ).tofloat();
            else if ( value.slice( value.len() - 1, value.len() ) == "s" )
                //get s string
                value = ( value.slice( 0, value.len() - 1 ) ).tofloat() * 1000;
            else
                //force string to float
                value = ( opts.time_unit == "s" ) ? value.tofloat() * 1000 : value.tofloat();
        }
        if ( typeof( value ) == "string" ) {
            //if its still a string, don't recognized it
            value = 0;
            print( "unrecognized time value: " + value );
        }
        return value;
    }

    //parses for string speed values ( i.e. "half", "double" ), float/integer is the speed factor ( 0.0 = stopped, 0.5 = half, 1.0 = normal )
    static function parse_speed( value )
    {
        if ( typeof( value ) == "integer" || typeof( value ) == "float" )
            //use the direct numeric value for speed
            return value.tofloat();
        if ( typeof( value ) == "string" )
            //look for a predefined speed string
            foreach( key, val in Animation.speeds )
                if ( value == key ) value = Animation.speeds[key];
        if ( typeof( value ) == "string" ) {
            //try to cast string to a float
            try
            {
                value = value.tofloat()
                return value
            } catch( err ) { print("unrecognized speed value: " + value ) }
        }
        return value.tofloat()
    }
    
    //values in table b will be inserted into table a, overwriting existing values
    static function merge_opts(a, b) {
        foreach( key, value in b ) {
            if ( typeof(b[key]) == "table" )
                a[key] <- merge_opts(a[key], b[key]);
            else
                a[key] <- b[key];
        }
        return a;
    }

    //convert a squirrel table to a string
    static function table_as_string( table )
    {
        if ( table == null ) return ""
        local str = ""
        foreach ( name, value in table )
            if ( typeof(value) == "table" )
                str += "[" + name + "] -> " + table_as_string( value )
            else
                str += name + ": " + value + " "
        return str
    }
}

fe.do_nut(FeConfigDirectory + "modules/animate2/animations/property.nut");
fe.do_nut(FeConfigDirectory + "modules/animate2/animations/sprite.nut");
fe.do_nut(FeConfigDirectory + "modules/animate2/animations/particles/module.nut");
fe.do_nut(FeConfigDirectory + "modules/animate2/animations/timeline.nut");