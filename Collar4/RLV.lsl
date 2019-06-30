// RLV.lsl
// RLV script for Black Gazza Collar 4
// Timberwoof Lupindo, June 2019

// Receives menu commands on link number 1400

integer OPTION_DEBUG = 0;

string hudTitle = "BG Inmate Collar4 Alpha 0"; 

integer SafewordChannel = 0;
integer SafewordListen = 0;
integer Safeword = 0;

integer hudAttached = 0;    //0 = unattached; 1 = attached
integer HudFunctionState = 0;
// -3 = off with remote turn-on
// 0 = off
// 1 = on with off switch
// 2 = on with timer
// 3 = on with remote turn-off
string avatarKeyString;
string avatarName;
key primKey;
string primKeyString;

integer rlvPresent = 0;
integer RLVStatusChannel = 0;      // listen to itself for RLV responses; generated on the fly
integer RLVStatusListen = 0;

sayDebug(string message)
{
    if (OPTION_DEBUG)
    {
        llWhisper(0,"RLV:"+message);
    }
}

generateChannels() {
    if (RLVStatusChannel != 0) {
        sayDebug("remove RLVStatusChannel " + (string)RLVStatusChannel);
        llListenRemove(RLVStatusChannel);
    }
    RLVStatusChannel = (integer)llFrand(8999)+1000; // generate a sessin RLV status channel
    sayDebug("created new RLVStatusChannel " + (string)RLVStatusChannel);
    RLVStatusListen = llListen(RLVStatusChannel, "", llGetOwner(), "" );
        // listen on the newly generated rlv status channel
}

// =================================
// Communication with database
key httprequest;

registerWithDB() {
    string timestamp = llGetTimestamp( ); // format 
    string timeStampDate = llGetSubString(timestamp,0,9);
    string timeStampTime = llGetSubString(timestamp,11,18);
    string timeStampAll = timeStampDate + " " + timeStampTime;
    string url;
    
    // what  to tell the database
    integer hudActive = 0;
    if (HudFunctionState > 0) {
        hudActive = 1;
        }
    if (rlvPresent == 1) {
        hudActive = hudActive * 10;
    }
    
    if (avatarKeyString == "00000000-0000-0000-0000-000000000000") {
        // tag is not attatched
        url = "http://web.infernosoft.com/blackgazza/registerUser.php?"+
        "avatar=" + avatarKeyString + "&" + 
        "name=&" + 
        "prim=" + primKeyString + "&" + 
        "role=0&" +
        "timeSent=" + llEscapeURL(timeStampAll) + "&" +
        "commandChannel=0";
    } else {
        url = "http://web.infernosoft.com/blackgazza/registerUser.php?"+
        "avatar=" + avatarKeyString + "&" + 
        "name=" + llEscapeURL(avatarName) + "&" + 
        "prim=" + primKeyString + "&" + 
        "role=" + (string)hudActive + "&" +
        "timeSent=" + llEscapeURL(timeStampAll) + "&" +
        "commandChannel=0";// + (string)CommandChannel;
    }
    
    list parameters = [HTTP_METHOD, "GET",
        HTTP_MIMETYPE,"text/plain;charset=utf-8"];
    string body = "";
    //sayDebug(url); // *** debug
    //httprequest = llHTTPRequest(url, parameters, body );
}

sendRLVRestrictCommand(string level) {
    // level can be Off Light Medium Heavy Hardcore
    if (rlvPresent == 1) {
        sayDebug("sendRLVRestrictCommand("+level+")");
        string rlvcommand; 
        if (level == "Off") {
            rlvcommand = "@clear";
        } else if (level == "Light") {
            rlvcommand = "@tplm=n,tploc=n,tplure=y," +          
            "showworldmap=y,showminimap=y,showloc=y," + 
            "fly=n,detach=n,edit=y,rez=y," +
            "chatshout=y,chatnormal=y,chatwhisper=y,shownames=y,sittp=y,fartouch=y";
        } else if (level == "Medium") {
            rlvcommand = "@tplm=n,tploc=n,tplure=y," +          
            "showworldmap=n,showminimap=n,showloc=y," + 
            "fly=n,detach=n,edit=y,rez=y," +
            "chatshout=y,chatnormal=y,chatwhisper=y,shownames=y,sittp=n,fartouch=n";
        } else if (level == "Heavy") {
            rlvcommand = "@tplm=n,tploc=n,tplure=n," +          
            "showworldmap=n,showminimap=n,showloc=n," + 
            "fly=n,detach=n,edit=n,rez=n," +
            "chatshout=n,chatnormal=y,chatwhisper=n,shownames=n,sittp=n,fartouch=n";
        } else if (level == "Hardcore") {
            rlvcommand = "@tplm=n,tploc=n,tplure=n," +          
            "showworldmap=n,showminimap=n,showloc=n," + 
            "fly=n,detach=n,edit=n,rez=n," +
            "chatshout=n,chatnormal=y,chatwhisper=n,shownames=n,sittp=n,fartouch=n";
        }
        sayDebug(rlvcommand);
        llOwnerSay(rlvcommand);
        llSleep(2);
    } else {
        sayDebug("sendRLVRestrictCommand but no RLV present");
    }
}

// ***************************
// Safeword
SendSafewordInstructions() {
    if (SafewordChannel != 0) {
        sayDebug("remove SafewordChannel " + (string)SafewordChannel);
        llListenRemove(SafewordChannel);
    }
    SafewordChannel = (integer)llFrand(8999)+1000; 
    SafewordListen = llListen(SafewordChannel, "", llGetOwner(), "" );
    sayDebug("created new SafewordChannel " + (string)SafewordChannel);

    Safeword =(integer)llFrand(899999)+100000; // generate 6-digit number
            
    llOwnerSay("To deactivate the Prisoner HUD, say " + (string)Safeword + 
        " on channel " +  (string)SafewordChannel + " within 60 seconds.");
}

SafewordFailed() {
    llOwnerSay ("Wrong Safeword or time ran out.");
    llListenRemove(SafewordListen);
    SafewordChannel = 0;
    SafewordListen = 0;
    //HUDTimerRestart();
}

SafewordSucceeded() {
    llListenRemove(SafewordListen);
    SafewordChannel = 0;
    SafewordListen = 0;
    sendRLVRestrictCommand("Off");
    //registerWithDB(); // prisoner, off
}


// =================================
// Timer

// This timer controls how long the HUD stays active
// This works like a kitchen timer: "30 minutes from now"
// It has non-obvious states that need to be announced and displayed
integer HUDTimerInterval = 5; // 5 seconds ;for all timers
integer HUDTimeremaining = 1800; // seconds remaining on timer: half an hour by default
integer HUDTimerunning = 0; // 0 = stopped; 1 = running
integer HUDTimeStart = 1800; // seconds it was set to so we can set it again 
    // *** set to 20 for debug, 1800 for production

string HUDTimerDisplay() {
    // parameter: HUDTimeremaining global
    // returns: a string in the form of "1 Days 3 Hours 5 Minutes 7 Seconds"
    // or "(no timer)" if seconds is less than zero
    
    if (HUDTimeremaining <= 0) {
        return "";// "Timer not set."
    } else {

    // Calculate
    //llWhisper(0,"time_display received "+(string)seconds+" seconds."); // *** debug
    string display_time = ""; // "Unlocks in ";
    integer days = HUDTimeremaining/86400;
    integer hours;
    integer minutes;
    integer seconds;
    
    if (days > 0) {
        display_time += (string)days+" Days ";   
    }
    
    integer carry_over_hours = HUDTimeremaining - (86400 * days);
    hours = carry_over_hours / 3600;
    //if (hours > 0) {
        display_time += (string)hours+":"; // " Hours ";
    //}
    
    integer carry_over_minutes = carry_over_hours - (hours * 3600);
    
    minutes = carry_over_minutes / 60;
    //if (minutes > 0) {
        display_time += (string)minutes+":"; // " Minutes ";
    //}
    
    seconds = carry_over_minutes - (minutes * 60);
    
    //if (seconds > 0) {
        display_time += (string)seconds; //+" Seconds";
    //}
    
    //if (HUDTimerunning == 1) {
    //    display_time += " …";
    //} else {
    //    display_time += " .";
    //}    
    
    return display_time; 
    }
}

HUDTimerReset() {
    // reset the timer to the value previously set for it. init and finish countdown. 
    HUDTimeremaining = HUDTimeStart; 
    HUDTimerunning = 0; // timer is stopped
    //llWhisper(0,thisCell+" Timelock Has Been Cleared.");
}

HUDTimerSet(integer set_time) {
    // set the timer to the desired time, remember that time
    HUDTimeremaining = set_time; // set it to that 
    HUDTimeStart = set_time; // remember what it was set to
    // HUDTimerunning = 0; // timer is stopped *** fix bug 58. 
    //llWhisper(0,thisCell+" Timelock Has Been Set.");
}

HUDTimerRun() {
    // make the timer run. Init and finish countdown. 
    HUDTimerunning = 1; // timer is running
    llSetTimerEvent(5.0);
    //llWhisper(0,thisCell+" Timer has started.");
}

HUDTimerRestart() {
    if (HUDTimerunning == 1) {
        llSetTimerEvent(5.0);
    } else {
        llSetTimerEvent(0.0);
    }
}

HUDTimerStop() {
    // stop the timer. Nobody calls this ... yet. 
    // *** perhaps use this while prisoner is being schoked
    HUDTimerunning = 0; // timer is stopped
    //llWhisper(0,thisCell+" Timer has stopped.");
}


HUDTimerIncrement(integer interval) {
    HUDTimeremaining += interval;
    // *** use this to increase the time every time someone gets shocked for touching the box
    // perhaps ... HUDTimerIncrement(HUDTimeremaining / 10);
}

HUDTimer() {
    //llWhisper(0, "HUDTimerunning=" + (string)HUDTimerunning + " HUDTimeremaining=" + (string)HUDTimeremaining);
    if (HUDTimerunning == 1 && HUDTimeremaining <= HUDTimerInterval) {
        // time has run out...
        //llWhisper(0,thisCell+" has finished timelock. Opening.");
        sendRLVRestrictCommand("Off");
        HudFunctionState = 0;
        registerWithDB(); // prisoner, off
        HUDTimerReset();
    }   

    if (HUDTimerunning == 1) {
        // timer's on, door's closed, someone's in here
        HUDTimeremaining -= HUDTimerInterval;
    }
}


default
{
    state_entry()
    {
        sayDebug("state_entry");
        rlvPresent = 0;
        SafewordListen = 0;
        llPreloadSound("electricshock");
        sayDebug("state_entry done");
    }

     attach(key id)
     {
        if (id) {
            sayDebug("attach"); // *** debug

            hudAttached = 1;
            rlvPresent = 0;
            HudFunctionState = 0;
        
            generateChannels();
        
            string statusquery="version="+(string)RLVStatusChannel;
            sayDebug(statusquery); // *** debug
            llOwnerSay("@"+statusquery);
            llSetTimerEvent(60); 
            // "the timeout should be long enough, like 30 seconds to one minute 
            // in order to receive the automatic reply from the viewer." 

            registerWithDB();    // inmate, offline  
            llOwnerSay("Black Gazza" + hudTitle + " (development version). Click the collar for a menu.");
            sayDebug("attach done"); // *** debug
        } else {
            sayDebug("attach but no ID"); // *** debug
            hudAttached = 0;
            HudFunctionState = 0;
            sendRLVRestrictCommand("Off");
            sendRLVRestrictCommand("Light");
            registerWithDB();    // inmate, offline  
            sayDebug("attach but no ID done"); // *** debug
        }
    }

    run_time_permissions(integer permissions)
    {
        //sayDebug("run_time_permissions " + (string)theAnimation);
        if (permissions & PERMISSION_TRIGGER_ANIMATION) {
            //stop_anims(llGetOwner());
            //llStartAnimation(theAnimation);
        }
    }
    
    link_message( integer sender_num, integer num, string message, key id ){ 
    // We listen in on all ink messages and pick the ones we're interested in
        if (num == 1400) {
            if (llSubStringIndex("Off Light Medium Heavy Hardcore", message) > -1) {
                sayDebug("link_message "+(string)num+" "+message);
                sendRLVRestrictCommand("Off");
                sendRLVRestrictCommand(message);
            } else if (message == "Safeword") {
                SendSafewordInstructions();
            }
        }
    }


    // listen to objects on the command channel, 
    // rlv status messages on the status channel, 
    // and menu commands on the menuc hannel
    listen( integer channel, string name, key id, string message )
    {
        sayDebug("listen channel:" + (string)channel + " key:" + (string) id + " message:"+ message);
        
        if (channel == SafewordChannel) {
            sayDebug("safeword:" + message);   // *** debug
            if (message == (string)Safeword) {
                SafewordSucceeded();
            } else {
                SafewordFailed();
            }
        }
        
        if (channel == RLVStatusChannel) {
            sayDebug("status:" + message);   // *** debug
            rlvPresent = 1;
            llListenRemove(RLVStatusListen);
            RLVStatusListen = 0;
        }         
    }


    timer()
    {
        if (SafewordListen != 0) {
            // we are listening for a safeword, so all else loses priority
            // but this means the Safeword was allowed to time out. 
            SafewordFailed();
        } else if (RLVStatusListen != 0) {
            // we were asking local RLV status; this is the timeout
            llOwnerSay("Your SL viewer is not RLV-Enabled. You're missing out on all the fun!");
            rlvPresent = 0;
            llListenRemove(RLVStatusListen);
            RLVStatusListen = 0;
            HUDTimerRestart();
        } else {
            // can only have come from an animation event
            //handleAnimationQueue();
        } 
                   
        HUDTimer();
    }

}