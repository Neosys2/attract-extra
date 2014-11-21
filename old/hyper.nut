//load the preset configs as animation names that users can use
fe.do_nut("extended/animations/hyper/presets/presets.nut");

//push the animation name that users will use to the Animation table
Animation["hyper"] <- function(c = {} ) {
    if ("preset" in c) {
        c = Animation.hyperPresets[c.preset];
        c.which <- "hyper";
        c.when <- When.Always;
        c.duration <- 120000;
    }
    return HyperParticle(c);
}

//TODO
// speed-acceleration seem off, hacked in a bit
// cannot get it to center object with rotation
// gravity is properly implemented

class HyperParticle extends ExtendedAnimation {
    debug = false;
    resources = null;
    emitter = null;
    particles = null;
    elapsed = 0;
    current = 0;
    timePerParticle = 0;
    count = 0;
    
    //used for debugging
    debug_emitter = null;
    debug_angle_min = null;
    debug_angle_max = null;
    debug_bounds = null;
    
    constructor(config) {
        base.constructor(config);
        
        //get config and set defaults
        if ("resources" in config == false) config.resources <- [ "default.png" ];
        //emitter variables
        if ("ppm" in config == false) config.ppm <- 60;
        if ("x" in config == false) config.x <- fe.layout.width / 2;
        if ("y" in config == false) config.y <- fe.layout.height / 2;
        if ("width" in config == false) config.width <- 1;
        if ("height" in config == false) config.height <- 1;
        if ("limit" in config == false) config.limit <- 0;
        //particle variables
        if ("movement" in config == false) config.movement <- true;
        if ("angle" in config == false) config.angle <- [ 0, 0 ];
        if ("speed" in config == false) config.speed <- [ 150, 150 ];
        if ("scale" in config == false) config.scale <- [ 1.0, 1.0 ];       //scale over time
        if ("startScale" in config == false) config.startScale <- [ 1.0, 1.0 ];  //random scale
        if ("rotate" in config == false) config.rotate <- [ 0, 0 ];
        if ("rotateToAngle" in config == false) config.rotateToAngle <- false;
        if ("fade" in config == false) config.fade <- 0;
        if ("gravity" in config == false) config.gravity <- 0;
        if ("accel" in config == false) config.accel <- 0;
        if ("bound" in config == false) config.bound <- [ 0, 0, 0, 0 ];
        if ("xOscillate" in config == false) config.xOscillate <- [ 0, 0 ];
        //todo
        if ("lifespan" in config == false) config.lifespan <- 5000;
        if ("particlesontop" in config == false) config.particlesontop <- true;
        if ("pointSwarm" in config == false) config.pointSwarm <- [ 0, 0 ];
        if ("blendmode" in config == false) config.blendmode <- "none";
        if ("randomFrame" in config == false) config.randomFrame <- false;

        //set limitations
        config.lifespan = minmax(config.lifespan, 500, 20000);
        config.angle[0] = minmax(config.angle[0], 0, 360);
        config.angle[1] = minmax(config.angle[1], 0, 360);
        config.speed[0] = minmax(config.speed[0], 0, 2000);
        config.speed[1] = minmax(config.speed[1], 0, 2000);
        config.rotate[0] = minmax(config.rotate[0], -50, 50);
        config.rotate[1] = minmax(config.rotate[1], -50, 50);
        config.scale[0] = minmax(config.scale[0], 0.1, 3.0);
        config.scale[1] = minmax(config.scale[1], 0.1, 3.0);
        config.startScale[0] = minmax(config.startScale[0], 0.1, 3.0);
        config.startScale[1] = minmax(config.startScale[1], 0.1, 3.0);
        config.fade = minmax(config.fade, 0, 10000);
        config.accel = minmax(config.accel, 0, 20);
        config.gravity = minmax(config.gravity, -75, 75);
        config.xOscillate[0] = minmax(config.xOscillate[0], 0, 50);
        config.xOscillate[1] = minmax(config.xOscillate[1], 0, 1000);
        
        //setup resources
        resources = [];
        foreach (r in config.resources) {
            local img = fe.add_image("extended/animations/hyper/" + r, -1, -1, 1, 1);
                img.x = -img.texture_width;
                img.y = -img.texture_height;
                img.width = img.texture_width;
                img.height = img.texture_height;
            resources.append(img);
        }
        
        timePerParticle = (60 / config.ppm.tofloat()) * 1000;

        //setup emitter
        emitter = {};
        emitter.ppm <- config.ppm;
        emitter.width <- config.width;
        emitter.height <- config.height;
        emitter.x <- config.x; // - (emitter.width / 2);
        emitter.y <- config.y; // - (emitter.height / 2);
        emitter.limit <- config.limit;

        //setup particles
        //particles = [];
        //temporarily put a limit so we can fill the array ahead of time
        local MAX_PARTICLES = 1000;
        particles = array(MAX_PARTICLES);
        for (local i = 0; i < MAX_PARTICLES; i++) {
            local resource = randomResource();
            particles[i] = Particle(0, resource, emitter, config);
            particles[i].visible(false);
        }
        
        //used for debugging
        if (debug) setupDebug(config);
    }
    
    function setupDebug(config) {
        debug_emitter = fe.add_image("extended/animations/hyper/pixel.png", -1, -1, 1, 1);
        debug_emitter.set_rgb(0, 255, 0);
        debug_emitter.x = emitter.x; // - (emitter.width / 2);
        debug_emitter.y = emitter.y; //- (emitter.height / 2);
        //debug_emitter.x = emitter.x - (emitter.width / 2);
        //debug_emitter.y = emitter.y - (emitter.height / 2);
        debug_emitter.width = emitter.width;
        debug_emitter.height = emitter.height;
        
        debug_angle_min = fe.add_clone(debug_emitter);
        debug_angle_min.set_rgb(255, 0, 0);
        debug_angle_min.x = emitter.x;
        debug_angle_min.y = emitter.y;
        debug_angle_min.width = 100;
        debug_angle_min.height = 2;
        debug_angle_min.rotation = config.angle[0];

        debug_angle_max = fe.add_clone(debug_angle_min);
        debug_angle_max.set_rgb(0, 0, 255);
        debug_angle_max.rotation = config.angle[1];
        
        debug_bounds = fe.add_clone(debug_emitter);
        debug_bounds.set_rgb(0, 255, 0);
        debug_bounds.x = config.bound[0];
        debug_bounds.y = config.bound[1];
        debug_bounds.width = config.bound[2];
        debug_bounds.height = config.bound[3];
        debug_bounds.alpha = 40;
        
    }

    function start(obj) {
    }
    
    function create(ttime) {
        //local resource = randomResource();
        //local p = Particle(ttime, resource, emitter, config);
        //particles.append(p);
    }
    
    function frame(obj, ttime) {
        elapsed = elapsed + (ttime - current);
        current = ttime;
        
        //when to start new particles
        if (particles.len() == 0 || elapsed >= timePerParticle) {
            //create one
            //if (emitter.limit == 0 || particles.len() < emitter.limit) {
            //    create(ttime);
            //}
            //use-reuse existing particles
            if (count == particles.len() - 1) count = 0;
            particles[count].visible(true);
            particles[count].alive = true;
            particles[count].createdAt = ttime;
            count += 1;
            //reset elapsed
            elapsed = 0;
        }
        
        local msg = "";
        for (local i = 0; i < particles.len(); i++) {
            if (particles[i].alive) {
                //update
                particles[i].update(ttime);
                //kill dead ones
                if (particles[i].isDead()) {
                    particles[i].visible(false);
                    //particles.remove(i);
                    //fe.obj[#].remove
                }
                //give us some debug info
                if (i > particles.len() - 4) {
                    msg += "p" + i + " " + particles[i].toString();
                }
            }
        }
        //if (particles.len() >= 1) ExtendedDebugger.notice(particles[0].toString());
        //ExtendedDebugger.notice("time: " + current + " elapsed: " + elapsed + " particles: " + particles.len() + " ppm: " + emitter.ppm + " (" + timePerParticle + "mspp)" + "b: " + bound[0] + "," + bound[1] + ":" + bound[2] + "x" + bound[3] + "\n" + msg);
    }
    
    function random(minNum, maxNum) {
        return floor(((rand() % 1000 ) / 1000.0) * (maxNum - (minNum - 1)) + minNum);
    }
    function randomf(minNum, maxNum) {
        return (((rand() % 1000 ) / 1000.0) * (maxNum - minNum) + minNum).tofloat();
    }
    
    function randomResource() {
        return resources[random(0, resources.len() - 1)];
    }

    //if a value is less then min it will be min and if greater than max it will be max
    function minmax(value, min, max) {
        if (value < min) value = min;
        if (value > max) value = max;
        return value;
    }

    function angle(angle, radius, originX, originY) {
        return [ (radius * cos(angle.tofloat() * PI / 180)).tofloat() + originX,
                 (radius * sin(angle.tofloat() * PI / 180)).tofloat() + originY
               ];
    }

}

class Particle {
    alive = false;
    createdAt = 0;
    resource = null;
    x = 0;
    y = 0;
    w = 0;
    h = 0;
    startx = 0;
    starty = 0;
    movement = false;
    speed = null;
    angle = 0;
    scale = 1.0;
    startScale = [ 1, 1 ];
    rotate = [ 0, 0 ];
    rotateToAngle = false;
    fade = 0;
    accel = 0;
    gravity = 0;
    bound = null;
    xOscillate = null;

    //not fully implmented
    lifespan = 0;
    lifetime = 0;
    
    //other variables
    anglePoint = null;      //one-time store an angle point to the radius calculated before doing updates
    currentScale = 1.0;     //store the current scale
    currentRotation = 0;    //store the current rotation    
    currentFade = 0;        //store the current fade alpha
    currentAccel = 0;       //store the current acceleration
    currentGravity = 0;     //store the gravity
    currentSpeed = 0;       //store the current speed
    constructor(createdAt, resource, emitter, config) {
        this.createdAt = createdAt;
        this.resource = fe.add_clone(resource);

        this.x = this.startx = HyperParticle.random(emitter.x, emitter.x + emitter.width);
        this.y = this.starty = HyperParticle.random(emitter.y, emitter.y + emitter.height);
        this.w = resource.width;
        this.h = resource.height;
        
        this.movement = config.movement;
        this.lifespan = this.lifetime = config.lifespan;
        this.speed = HyperParticle.random(config.speed[0], config.speed[1]);
        this.angle = HyperParticle.random(config.angle[0], config.angle[1]);
        anglePoint = HyperParticle.angle(angle, 300, startx, starty);
        this.scale = config.scale;
        this.startScale = HyperParticle.randomf(config.startScale[0], config.startScale[1]);
        this.rotate = HyperParticle.random(config.rotate[0], config.rotate[1]);
        this.rotateToAngle = config.rotateToAngle;
        this.fade = config.fade;
        this.gravity = config.gravity;
        this.accel = config.accel;
        this.bound = config.bound;
        this.xOscillate = config.xOscillate;
    }
    
    function isDead() { if (lifespan <= 0) return true; return false; }
    
    function update(ttime) {
        ttime  = ttime - createdAt;
        lifespan = lifetime - (ttime - createdAt);
        
        if (collides()) ExtendedDebugger.notice("collision!");
        
        //the ttime/ numbers below are adjustments to attempt to match the speed of HyperTheme
        if (movement) {
            //gravity
            if (gravity != 0) {
                local gBase = 9.78;
                //local gVariation = (gravity / 75.0);
                local gVariation = gravity.tofloat();
                local gAccel = (ttime / 2000.0) * (gBase + gVariation);
                currentGravity = pow(gAccel, 2);
                if (gVariation < 0) currentGravity = -currentGravity;
            }
            
            //speed and acceleration
            currentAccel = (ttime.tofloat() / 1000.0) * accel;
            currentSpeed = speed * (1 + currentAccel);

            local dist = ((ttime.tofloat() / 1200.0) * currentSpeed);
            //local dist = ((ttime.tofloat() / 1000.0) * speed);
            local ang = [ (anglePoint[0] - startx) / 300.0, (anglePoint[1] - starty) / 300.0 ];
            resource.x = startx + dist * ang[0];
            resource.y = starty + dist * ang[1] + currentGravity;
            
            //xOscillate
            if (xOscillate[0] > 0 && xOscillate[1] > 0) {
                local amp = xOscillate[0].tofloat();
                local freq = xOscillate[1].tofloat();
                //resource.x += sin((ttime.tofloat() / freq)) * amp;
                resource.x += sin((ttime.tofloat() / 7000.0)) * 500;
            }
        } else {
            resource.x = startx;
            resource.y = starty;
        }

        //fade
        if (fade > 0 && currentFade >= 0) {
            currentFade = 255 - (ttime / fade.tofloat()) * 255;
            if (currentFade < 0) currentFade = 0;
            resource.alpha = currentFade;
        }
        
        //scale
        if (scale[0] != 1 || scale[1] != 1) {
            //scale (scale over time)
            //change * (time / duration) + start;
            currentScale = (scale[1] - scale[0]) * (ttime / lifetime.tofloat()) + scale[0];
        } else {
            //startScale (random scale)
            currentScale = startScale;
        }

        resource.width = w * currentScale;
        resource.height = h * currentScale;

        //rotate
        if (rotateToAngle) {
            resource.rotation = angle;
        } else {
            currentRotation = (rotate * (ttime.tofloat() / 1000.0)) * 10;
            resource.rotation = currentRotation;
        }
        //center on point
        //how to center on scale and rotation??
        resource.x -= resource.width / 2;
        resource.y -= resource.height / 2;
        
        //old formulas
        //resource.x = (ttime.tofloat() / abs(speed - 2050)).tofloat() * (anglePoint[0] - startx) + startx;
        //resource.y = (ttime.tofloat() / abs(speed - 2050)).tofloat() * (anglePoint[1] - starty) + starty;
        //resource.x = HyperParticle.calculate("in", "linear", ttime, startx, angle[0], 2000);
        //resource.y = HyperParticle.calculate("in", "linear", ttime, starty, angle[1], 2000);
    }
    
    function collides() {
        if (abs(x - bound[0]) * 2 < resource.width + bound[2] && abs(y - bound[1]) * 2 < resource.height + bound[3]) {
            return true;
        }
        //with rotation
        /*
        local pWidth = sqrt(resource.width * resource.width + resource.height * resource.height) * cos(angle);
        local bWidth = sqrt(bound[2] * bound[2] + bound[3] * bound[3]);
        if (abs(x - bound[0]) < (abs(pWidth + bWidth) / 2) && (abs(y - bound[1]) < (abs(resource.height + bound[3]) / 2))) {
            //collide
            return true;
        }
        */
        return false;
    }
    
    function setAlpha(a) { resource.alpha = HyperParticle.minmax(a, 0, 255); }
    function setColor(r, g, b) { resource.set_rgb(HyperParticle.minmax(r, 0, 255), HyperParticle.minmax(g, 0, 255), HyperParticle.minmax(b, 0, 255)); }
    function visible(v) { resource.visible = v; }
    function toString() { return ": " + x + "," + y + " a=" + angle + " sp: " + currentSpeed + " sca: " + currentScale + " rot: " + currentRotation + " fa: " + currentFade + " gr: " + currentGravity + " ac: " + currentAccel + "\n"; }
}
