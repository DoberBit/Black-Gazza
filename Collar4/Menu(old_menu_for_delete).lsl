// Menu.lsl
// Menu script for Black Gazza Collar 4
// Timberwoof Lupindo
// June 2019
string version = "2021-12-29";

// Handles all the menus for the collar. 
// State is kept here and transmitted to interested scripts by link message calls. 

// reference: useful unicode characters
// https://unicode-search.net/unicode-namesearch.pl?term=CIRCLE

integer OPTION_DEBUG = 0;

//key sWelcomeGroup="49b2eab0-67e6-4d07-8df1-21d3e03069d0";
//key sMainGroup="ce9356ec-47b1-5690-d759-04d8c8921476";
//key sGuardGroup="b3947eb2-4151-bd6d-8c63-da967677bc69";
//key sBlackGazzaRPStaff="900e67b1-5c64-7eb2-bdef-bc8c04582122";
//key sOfficers="dd7ff140-9039-9116-4801-1f378af1a002";

integer menuChannel = 0;
integer menuListen = 0;
string menuIdentifier;
key menuAgentKey;

integer wearerChannel = 1;
integer wearerListen = 0;
string menuPhrase;

// Punishments
integer allowZapLow = 1;
integer allowZapMed = 1;
integer allowZapHigh = 1;
integer allowVision = 1;

list assetNumbers;
string mood;
string class = "white";
list classes = ["white", "pink", "red", "orange", "green", "blue", "black"];
list classesLong = ["Unassigned Transfer", "Sexual Deviant", "Mechanic", "General Population", "Medical Experiment", "Violent or Hopeless", "Mental"];

string RLV = "RLV";
string lockLevel;
list lockLevels = ["Off", "Light", "Medium", "Heavy", "Hardcore"];
string lockLevelOff = "Off";
integer rlvPresent = 0;
integer renamerActive = 0;
integer DisplayTokActive = 0;
integer relayCheckboxState = 0;
string RelayLockState = "Off"; // what the relay told us
string RelayOFF = "Off";
string RelayASK = "Ask";
string RelayON = "On";

integer speechPenaltyDisplay = 0;
integer speechPenaltyGarbleWord = 0;
integer speechPenaltyGarbleTime = 0;
integer speechPenaltyBuzz = 0;
integer speechPenaltyZap = 0;

string crime = "Unknown";
string assetNumber = "P-00000";
string threat = "Moderate";
integer batteryActive = 0;
integer batteryPercent = 100;
string batteryGraph = "";
integer badWordsActive = 0;
integer titlerActive = TRUE;

key approveAvatar;

string menuMain = "Main";
string moodDND = "DnD";
string moodOOC = "OOC";
string moodLockup = "Lockup";
string moodSubmissive = "Submissive";
string moodVersatile = "Versatile";
string moodDominant = "Dominant";
string moodNonsexual = "Nonsexual";
string moodStory = "Story";

string buttonBlank = " ";
string buttonInfo = "Info";
string buttonSettings = "Settings";
//string buttonHack = "Hack";
string buttonPunish = "Punish";
string buttonLeash = "Leash";
string buttonSpeech = "Speech";
string buttonPenalties = "Penalties";
string buttonForceSit = "ForceSit";
string buttonSafeword = "Safeword";
string buttonRelease = "Release";
string buttonTitler = "Titler";
string buttonBattery = "Battery";
string buttonCharacter = "Character";
string buttonSetCrime = "SetCrime";

key guardGroupKey = "b3947eb2-4151-bd6d-8c63-da967677bc69";

// Utilities *******

sayDebug(string message)
{
    if (OPTION_DEBUG)
    {
        llOwnerSay("Menu: "+message);
    }
}

sendJSON(string jsonKey, string value, key avatarKey){
    llMessageLinked(LINK_THIS, 0, llList2Json(JSON_OBJECT, [jsonKey, value]), avatarKey);
}
    
sendJSONCheckbox(string jsonKey, string value, key avatarKey, integer ON) {
    if (ON) {
        sendJSON(jsonKey, value+"ON", avatarKey);
    } else {
        sendJSON(jsonKey, value+"OFF", avatarKey);
    }
}
    
sendJSONinteger(string jsonKey, integer value, key avatarKey){
    llMessageLinked(LINK_THIS, 0, llList2Json(JSON_OBJECT, [jsonKey, (string)value]), avatarKey);
}
    
string getJSONstring(string jsonValue, string jsonKey, string valueNow){
    string result = valueNow;
    string value = llJsonGetValue(jsonValue, [jsonKey]);
    if (value != JSON_INVALID) {
        result = value;
    }
    return result;
}
    
integer getJSONinteger(string jsonValue, string jsonKey, integer valueNow){
    integer result = valueNow;
    string value = llJsonGetValue(jsonValue, [jsonKey]);
    if (value != JSON_INVALID) {
        result = (integer)value;
    }
    return result;
}

/**
    since you can't directly check the agent's active group, this will get the group from the agent's attached items
*/
integer agentHasGuard(key agent)
{
    list attachList = llGetAttachedList(agent);
    integer item;
    while(item < llGetListLength(attachList))
    {
        if(llList2Key(llGetObjectDetails(llList2Key(attachList, item), [OBJECT_GROUP]), 0) == guardGroupKey) return TRUE;
        item++;
    }
    return FALSE;
}

setUpMenu(string identifier, key avatarKey, string message, list buttons)
// wrapper to do all the calls that make a simple menu dialog.
// - adds required buttons such as Close or Main
// - displays the menu command on the alphanumeric display
// - sets up the menu channel, listen, and timer event 
// - calls llDialog
// parameters:
// identifier - sets menuIdentifier, the later context for the command
// avatarKey - uuid of who clicked
// message - text for top of blue menu dialog
// buttons - list of button texts
{
    sayDebug("setUpMenu "+identifier);
    
    if (identifier != menuMain) {
        buttons = buttons + [menuMain];
    }
    buttons = buttons + ["Close"];
    
    sendJSON("DisplayTemp", "menu access", avatarKey);
    menuIdentifier = identifier;
    menuAgentKey = avatarKey; // remember who clicked
    string completeMessage = assetNumber + " Collar: " + message;
    menuChannel = -(llFloor(llFrand(10000)+1000));
    menuListen = llListen(menuChannel, "", avatarKey, "");
    llSetTimerEvent(30);
    llDialog(avatarKey, completeMessage, buttons, menuChannel);
}

string menuCheckbox(string title, integer onOff)
// make checkbox menu item out of a button title and boolean state
{
    string checkbox;
    if (onOff)
    {
        checkbox = "☒";
    }
    else
    {
        checkbox = "☐";
    }
    return checkbox + " " + title;
}

list menuRadioButton(string title, string match)
// make radio button menu item out of a button and the state text
{
    string radiobutton;
    if (title == match)
    {
        radiobutton = "●";
    }
    else
    {
        radiobutton = "○";
    }
    return [radiobutton + " " + title];
}

list menuButtonActive(string title, integer onOff)
// make a menu button be the text or the Inactive symbol
{
    string button;
    if (onOff)
    {
        button = title;
    }
    else
    {
        button = "["+title+"]";
    }
    return [button];
}

integer getLinkWithName(string name) {
    integer i = llGetLinkNumber() != 0;   // Start at zero (single prim) or 1 (two or more prims)
    integer x = llGetNumberOfPrims() + i; // [0, 1) or [1, llGetNumberOfPrims()]
    for (; i < x; ++i)
        if (llGetLinkName(i) == name) 
            return i; // Found it! Exit loop early with result
    return -1; // No prim with that name, return -1.
}

// Menus and Handlers ****************

mainMenu(key avatarKey) {
    string message = menuMain + "\n";

    if (assetNumber == "P-00000") {
        sendJSON("database", "getupdate", avatarKey);
    }
    
    if (menuAgentKey != "" & menuAgentKey != avatarKey) {
        llInstantMessage(avatarKey, "The collar menu is being accessed by someone else.");
        sayDebug("Told " + llKey2Name(avatarKey) + "that the collar menu is being accessed by someone else.");
        return;
        }
    
    // assume some things are not available
    integer doPunish = 0;
    integer doForceSit = 0;
    integer doLeash = 0;
    integer doSpeech = 0;
    integer doSafeword = 0;
    integer doRelease = 0;
    
    // Collar functions controlled by Mood: punish, force sit, leash, speech
    if (mood == moodDND | mood == moodLockup) {
        if (avatarKey == llGetOwner()) {
            doPunish = 1;
            doForceSit = 1;
            doLeash = 1;
            doSpeech = 1;
        }
    } else if (mood == moodOOC) {
            // everyone can do everything (but you better ask)
            doPunish = 1;
            doForceSit = 1;
            doLeash = 1;
            doSpeech = 1;
    } else { // mood == anything else
        if (avatarKey == llGetOwner()) {
            // wearer can't do anything
        } else if (llSameGroup(avatarKey)) {
            // other prisoners can leash and force sit
            doForceSit = 1;
            doLeash = 1;
        } else {
            // Guards can do anything
            doPunish = 1;
            doForceSit = 1;
            doLeash = 1;
            doSpeech = 1;
        }
    }
    
    // Collar functions overridden by lack of RLV
    if (!rlvPresent) {
        doForceSit = 0;
        doLeash = 0;
        doSpeech = 0;
        message = message + "\nSome functions are available ony when RLV is present.";
    }
    
    // Collar functions controlled by locklevel: Safeword and Release
    if (lockLevel == "Hardcore" && !llSameGroup(avatarKey)) {
        doRelease = 1;
    } else {
        message = message + "\nRelease command is available to a Guard when prisoner is in RLV Hardcore mode.";
    }
    
    if (avatarKey == llGetOwner() && lockLevel != "Hardcore" && lockLevel != lockLevelOff) {
        doSafeword = 1;
    } else {
        message = message + "\nSafeword is availavle to the Prisoner in RLV levels Medium and Heavy.";
    }
    
    list buttons = [];
    buttons = buttons + menuButtonActive(buttonSafeword, doSafeword);
    buttons = buttons + menuButtonActive(buttonRelease, doRelease);
    buttons = buttons + buttonBlank;    
    buttons = buttons + menuButtonActive(buttonPunish, doPunish);
    buttons = buttons + menuButtonActive(buttonLeash, doLeash);
    buttons = buttons + menuButtonActive(buttonForceSit, doForceSit);
    buttons = buttons + buttonSettings; 
    buttons = buttons + buttonInfo;
    
    setUpMenu(menuMain, avatarKey, message, buttons);
}

doMainMenu(key avatarKey, string message) {
        //sendJSON(RLV, "Status", avatarKey); // this asks for RLV status update all the damn time. 
        if (message == buttonInfo){
            infoGive(avatarKey);
        }
        else if (message == buttonSettings){
            settingsMenu(avatarKey);
        }
        //else if (message == buttonHack){
        //    hackMenu(avatarKey);
        //}
        else if (message == buttonPunish){
            punishMenu(avatarKey);
        }
        else if (message == buttonForceSit){
            sendJSON(buttonLeash, buttonForceSit, avatarKey);
        }
        else if (message == buttonLeash){
            sendJSON(buttonLeash, buttonLeash, avatarKey);
        }
        else if (message == buttonSpeech){
            speechMenu(avatarKey);
        }
        else if (message == buttonSafeword){
            sendJSON(RLV, buttonSafeword, avatarKey);
        }
        else if (message == buttonRelease){
            sendJSON(RLV, lockLevelOff, avatarKey);
        }
    }

// Action Menus and Handlers **************************
// Top-level menu items for immediate use in roleplay:
// Zap, Leash, Info, Hack, Safeword, Settings

punishMenu(key avatarKey)
{
    // the zap menu never includes radio buttons in front of the Zap word
    string message = buttonPunish;
    list buttons = [];
    buttons = buttons + menuButtonActive("Zap Low", allowZapLow);
    buttons = buttons + menuButtonActive("Zap Med", allowZapMed);
    buttons = buttons + menuButtonActive("Zap High", allowZapHigh);
    //buttons = buttons + menuButtonActive("Vision" , allowVision);
    setUpMenu(buttonPunish, avatarKey, message, buttons);
}

string class2Description(string class) {
    return llList2String(classes, llListFindList(classes, [class])) + ": " +
        llList2String(classesLong, llListFindList(classes, [class]));
}

infoGive(key avatarKey){
    // Prepare text of collar settings for the information menu
    string message = "Prisoner Information \n" +
    "\nNumber: " + assetNumber + "\n";
    if (!llSameGroup(avatarKey) || avatarKey == llGetOwner()) {
        string ZapLevels = "";
        ZapLevels = menuCheckbox("Low", allowZapLow) + "  " +
        menuCheckbox("Medium", allowZapMed) +  "  " +
        menuCheckbox("High", allowZapHigh);
        // allowVision
        message = message + 
        "Crime: " + crime + "\n" +
        "Class: "+class2Description(class)+"\n" +
        "Threat: " + threat + "\n" +
        "Punishment: shock " + ZapLevels + "\n"; 
    } else {
        string restricted = "RESTRICTED INFO";
        message = message + 
        "Crime: " + restricted + "\n" +
        "Class: "+restricted+"\n" +
        "Threat: " + restricted + "\n" +
        "Punishment: " + restricted + "\n"; 
    }
    message = message + "Battery Level: " + batteryGraph + "\n";
    message = message + "\nOOC Information:\n";
    message = message + "Version: " + version + "\n";
    message = message + "Mood: " + mood + "\n";
    message = message + "RLV Relay: " + RelayLockState + "\n";
    if (rlvPresent) {
        message = message + "RLV Active: " + lockLevel + "\n";
    } else {
        message = message + "RLV not detected.\n";
    }
    
    if (OPTION_DEBUG) {
        message = message + "Used Memory: " + (string)llGetUsedMemory() + ".\n";
    }

    // Prepare a list of documents to hand out 
    list buttons = []; 
    integer numNotecards = llGetInventoryNumber(INVENTORY_NOTECARD);
    if (numNotecards > 0) {
        message = message + "\nChoose a Notecard:";
        integer index;
        for (index = 0; index < numNotecards; index++) {
            integer inumber = index+1;
            string title = llGetSubString(llGetInventoryName(INVENTORY_NOTECARD,index), 0, 20);
            message += "\n" + (string)inumber + " - " + title;
            buttons += ["Doc "+(string)inumber];
        }
    }

    message = llGetSubString(message, 0, 511);
    setUpMenu(buttonInfo, avatarKey, message, buttons);
}

speechMenu(key avatarKey)
{
    integer itsMe = avatarKey == llGetOwner();
    integer locked = lockLevel != lockLevelOff;
    
    string message = buttonSpeech + "\n";
    list buttons = [];
    
    // assume we can do nothing
    integer doRenamer = 0;
    //integer doGag = 1;
    integer doBadWords = 0;
    integer doWordList = 0;
    integer doDisplayTok = 0;
    integer doPenalties = 0;
    
    // work out what menu items are available
    if (rlvPresent) {
        if (itsMe) {
            doRenamer = 1;
            doWordList = 1;
            doPenalties = 1;
            if (renamerActive) {
                doBadWords = 1;
                doDisplayTok = 1;
            } else {
                message = message + "\BadWords and Displaytok (Display-Talk) work only when Renamer is active.";
            }
        } else {
            message = message + "\Only the prisoner may access some functions.";
        }
    } else {
        message = message + "\nRenamer, BadWords, and Displaytok (Display-Talk) work only when RLV is active.";
    }
    if (itsMe) {
        if (mood == moodOOC) {
            doWordList = 1;
        } else {
            message = message + "\nYou can only change your word list while OOC.";
        }
    } else {
        if (llSameGroup(avatarKey)) {
            message = message + "\nOnly Guards can change the word list";
        } else {
            doWordList = 1;
            if ((lockLevel == "Hardcore" || lockLevel == "Heavy")) {
                doBadWords = 1;
                doDisplayTok = 1;
                doPenalties = 1;
            } else {
                message = message + "\nGuards can set speech options only in Heavy or Hardcore mode.";
            }
        }
    }
    
    if (lockLevel == "Heavy" | lockLevel == "Hardcore") {
        doRenamer = 0;
        }
    
    buttons = buttons + menuButtonActive(menuCheckbox("Renamer", renamerActive), doRenamer);
    buttons = buttons + menuButtonActive(menuCheckbox("BadWords", badWordsActive), doBadWords);
    buttons = buttons + menuButtonActive(menuCheckbox("DisplayTok", DisplayTokActive), doDisplayTok);
    buttons = buttons + menuButtonActive("WordList", doWordList);
    buttons = buttons + menuButtonActive("Penalties", doPenalties);
    buttons = buttons + [buttonBlank, buttonSettings];
    
    setUpMenu(buttonSpeech, avatarKey, message, buttons);
}

doSpeechMenu(key avatarKey, string message, string messageButtonsTrimmed) 
{
    if (messageButtonsTrimmed == "Renamer") {
        renamerActive = !renamerActive;
        sendJSONCheckbox(buttonSpeech, "Renamer", avatarKey, renamerActive);
        speechMenu(avatarKey);
    } else if (message == "WordList") {
        sendJSON(buttonSpeech,"WordList", avatarKey);
    } else if (messageButtonsTrimmed == "BadWords") {
        badWordsActive = !badWordsActive;
        sendJSONCheckbox(buttonSpeech, "BadWords", avatarKey, badWordsActive);
        speechMenu(avatarKey);
    } else if (messageButtonsTrimmed == "DisplayTok") {
        DisplayTokActive = !DisplayTokActive;
        sendJSONCheckbox(buttonSpeech, "DisplayTok", avatarKey, DisplayTokActive);
        speechMenu(avatarKey);
    } else if (message == "Penalties") {
        PenaltyMenu(avatarKey);
    } else if (message == RLV) {
        lockMenu(avatarKey);
    } else {
        speechMenu(avatarKey);
    }
}

characterMenu(key avatarKey) {
    // tell database to give the character menu and choose the character stuff. 
    sendJSON("database", "setcharacter", avatarKey);
}

characterSetCrimeTextBox(key avatarKey)
{
    sendJSON("database","setcrimes",avatarKey); // tell database to give the character set Crime TextBox and guard can to change the crime. 
}

PenaltyMenu(key avatarKey) {
    string message = "Set the penalties for speaking bad words:";
    list buttons = [];
    buttons = buttons + menuCheckbox("Buzz", speechPenaltyBuzz);
    buttons = buttons + menuCheckbox("Zap", speechPenaltyZap);
    buttons = buttons + [buttonBlank, buttonSpeech];
    setUpMenu(buttonPenalties, avatarKey, message, buttons);
}
    
doPenaltyMenu(key avatarKey, string message, string messageButtonsTrimmed) {
    if (messageButtonsTrimmed == "Buzz") {
        speechPenaltyBuzz = !speechPenaltyBuzz;
        sendJSONCheckbox(buttonPenalties, "Buzz", avatarKey, speechPenaltyBuzz);
        PenaltyMenu(avatarKey);
    } else if (messageButtonsTrimmed == "Zap") {
        speechPenaltyZap = !speechPenaltyZap;
        sendJSONCheckbox(buttonPenalties, "Zap", avatarKey, speechPenaltyZap);
        PenaltyMenu(avatarKey);
    } else if (messageButtonsTrimmed == buttonSpeech) {
        speechMenu(avatarKey);
    }
}




// Settings Menus and Handlers ************************
// Sets Collar State: Mood, Threat, Lock, Zap levels 

settingsMenu(key avatarKey) {
    // What this menu can present depends on a number of things: 
    // who you are - self or guard
    // IC/OOC mood - OOC, DnD or other
    // RLV lock level - Off, Light, Medium, Heavy, Lardcore
    
    string message = buttonSettings;

    // 1. Assume nothing is allowed
    integer setClass = 0;
    integer setMood = 0;
    integer setThreat = 0;
    integer setLock = 0;
    integer setPunishments = 0;
    //integer setTimer = 0;
    //integer setAsset = 0;
    integer setBadWords = 0;
    integer setSpeech = 0;
    integer setTitle = 0;
    integer setBattery = 0;
    integer setCharacter = 0;
    integer setCrimes = FALSE;
    
    // Add some things depending on who you are. 
    // What wearer can change
    if (avatarKey == llGetOwner()) {
        // some things you can always cange
        sayDebug("settingsMenu: wearer");
        setMood = 1;
        setLock = 1;
        setSpeech = 1;
        //setTimer = 1;
        setTitle = 1;
        setBattery = 1;
        
        // Some things you can only change OOC
        if ((mood == moodOOC) || (mood == moodDND)) {
            sayDebug("settingsMenu: ooc");
            // IC or DnD you change everything
            setClass = 1;
            setThreat = 1;
            setPunishments = 1;
            //setAsset = 1;
            setBadWords = 1;
            setCharacter = 1;
        }
        else {
            message = message + "\nSome settings are not available while you are IC.";
        }
    }
    // What a guard can change
    else if(agentHasGuard(avatarKey))
    { // (avatarKey != llGetOwner())
        // guard can always set some things
        sayDebug("settingsMenu: guard");
        setThreat = 1;
        setSpeech = 1;
        setCrimes = TRUE;
        
        // some things guard can change only OOC
        if (mood == moodOOC) {
            sayDebug("settingsMenu: ooc");
            // OOC, guards can change some things
            // DnD means Do Not Disturb
            setClass = 1;
            setCrimes = FALSE;
        }
        else {
            message = message + "\nSome settings are not available while you are OOC.";
        }
    }
    
    // Lock level changes some privileges
    if ((lockLevel == "Hardcore" || lockLevel == "Heavy")) {
        if (avatarKey == llGetOwner()) {
            sayDebug("settingsMenu: heavy-owner");
            setPunishments = 0;
            setThreat = 0;
            //setTimer = 0;
            setSpeech = 0;
            setBattery = 0;
            message = message + "\nSome settings are not available while your lock level is Heavy or Hardcore.";
        } 
        else if(agentHasGuard(avatarKey))
        {
            
            sayDebug("settingsMenu: heavy-guard");
            setPunishments = 1;
            setThreat = 1;
            //setTimer = 1;
        }
    }

    if ((lockLevel == "Hardcore") && (avatarKey == llGetOwner())) {
        setLock = 0;
    }
        
    list buttons = [];
    //buttons = buttons + menuButtonActive("Asset", setAsset);
    buttons = buttons + menuButtonActive("Class", setClass);
    buttons = buttons + menuButtonActive("Threat", setThreat);
    buttons = buttons + menuButtonActive(RLV, setLock);
    //buttons = buttons + menuButtonActive("Timer", setTimer);
    buttons = buttons + menuButtonActive("Punishment", setPunishments);
    buttons = buttons + menuButtonActive("Mood", setMood);
    buttons = buttons + menuButtonActive(buttonSpeech, setSpeech);
    buttons = buttons + menuButtonActive(menuCheckbox(buttonTitler, titlerActive), setTitle);
    buttons = buttons + menuButtonActive(menuCheckbox(buttonBattery, batteryActive), setBattery);
    if(avatarKey == llGetOwner()) // replace Character button to SetCrimes for guards
    {
        buttons = buttons + menuButtonActive(buttonCharacter, setCharacter);
    }
    else
    {
        buttons += menuButtonActive(buttonSetCrime, setCrimes);
    }
    
    setUpMenu(buttonSettings, avatarKey, message, buttons);
}
    
doSettingsMenu(key avatarKey, string message, string messageButtonsTrimmed) {
    sayDebug("doSettingsMenu("+message+")");
        if (message == "Mood"){
            moodMenu(avatarKey);
        }
        else if (message == RLV){
            if (rlvPresent) {
                lockMenu(avatarKey);
            } else {
                // get RLV to check RLV again 
                llOwnerSay("RLV was off nor not detected. Attempting to register with RLV.");
                sendJSON(RLV, "Register", avatarKey);
            }
        }
        else if (message == "Class"){
            classMenu(avatarKey);
        }
        else if (message == "Threat"){
            threatMenu(avatarKey);
        }
        else if (message == "Punishment"){
            PunishmentLevelMenu(avatarKey);
        }
        //else if (message == "Asset"){
        //    assetMenu(avatarKey);
        //}
        //else if (message == "Timer"){
        //    llMessageLinked(LINK_THIS, 3000, "TIMER MODE", avatarKey);
        //}
        else if (message == buttonSpeech){
            speechMenu(avatarKey);
        }
        else if (messageButtonsTrimmed == buttonTitler) {
            titlerActive = !titlerActive;
            sendJSONCheckbox(buttonTitler, "", avatarKey, titlerActive);
            settingsMenu(avatarKey);
        }
        else if (messageButtonsTrimmed == buttonBattery) {
            batteryActive = !batteryActive;
            sendJSONCheckbox(buttonBattery, "", avatarKey, batteryActive);
            settingsMenu(avatarKey);
        }
        else if (message == buttonCharacter){
            characterMenu(avatarKey);
        }
        else if(message == buttonSetCrime)
        {
            characterSetCrimeTextBox(avatarKey);
        }
            
}

//assetMenu(key avatarKey)
//{
//    string message = "Choose which Asset Number your collar will show.";
//    setUpMenu("Asset", avatarKey, message, assetNumbers);
//}

PunishmentLevelMenu(key avatarKey)
{
    // the zap Level Menu always includes checkboxes in front of the Zap word. 
    // This is not a maximum zap radio button, it is checkboxes. 
    // An inmate could be set to most severe zap setting only. 
    string message = "Set Permissible Zap Levels";
    list buttons = [];
    buttons = buttons + menuCheckbox("Zap Low", allowZapLow);
    buttons = buttons + menuCheckbox("Zap Med", allowZapMed);
    buttons = buttons + menuCheckbox("Zap High", allowZapHigh);
    //buttons = buttons + menuCheckbox("Vision", allowVision);
    buttons = buttons + buttonSettings;
    setUpMenu("Punishments", avatarKey, message, buttons);
}

doSetPunishmentLevels(key avatarKey, string message)
{
    if (avatarKey == llGetOwner()) 
    {
        sayDebug("wearer sets allowable zap level: "+message);
        if (message == "") {
            allowZapLow = 1;
            allowZapMed = 1;
            allowZapHigh = 1;
            allowVision = 1;
        }
        else if (message == "Zap Low") {
            allowZapLow = !allowZapLow;
        } else if (message == "Zap Med") {
            allowZapMed = !allowZapMed;
        } else if (message == "Zap High") {
            allowZapHigh = !allowZapHigh;
        //} else if (message == "Vision") {
        //    allowVision = !allowVision;
        }
        if (allowZapLow + allowZapMed + allowZapHigh == 0) {
            allowZapHigh = 1;
        }
        string zapJsonList = llList2Json(JSON_ARRAY, [allowZapLow, allowZapMed, allowZapHigh]);
        sendJSON("ZapLevels", zapJsonList, avatarKey);
        sendJSONinteger("allowVision", allowVision, avatarKey);
    }
}

classMenu(key avatarKey)
{
    sayDebug("classMenu");
    string message = "Set your Prisoner Class";
    list buttons = [];
    integer index = 0;
    integer length = llGetListLength(classes);
    for (index = 0; index < length; index++) {
        string thisClass = llList2String(classes, index);
        buttons = buttons + menuRadioButton(thisClass, class);
    }
    buttons = buttons + [buttonBlank, buttonBlank, buttonSettings];
    setUpMenu("Class", avatarKey, message, buttons);
}

moodMenu(key avatarKey)
{
    if (avatarKey == llGetOwner())
    {
        string message = "Set your Mood";
        list buttons = [];
        buttons = buttons + menuRadioButton(moodDND, mood);
        buttons = buttons + menuRadioButton(moodOOC, mood);
        buttons = buttons + menuRadioButton(moodLockup, mood);
        buttons = buttons + menuRadioButton(moodSubmissive, mood);
        buttons = buttons + menuRadioButton(moodVersatile, mood);
        buttons = buttons + menuRadioButton(moodDominant, mood);
        buttons = buttons + menuRadioButton(moodNonsexual, mood);
        buttons = buttons + menuRadioButton(moodStory, mood);
        buttons = buttons + [buttonBlank, buttonSettings];
        setUpMenu("Mood", avatarKey, message, buttons);
    }
    else
    {
        ; // no one else gets a thing
    }
}

integer RelayState() {
    if (RelayLockState == RelayOFF) return 0; else return 1;
}

// Based on the lockLevel and the RelayLockState, turn the relay off or on 
setRelayState(integer on) {
    sayDebug("setRelayState("+(string)on+")");
    key avatarKey = llGetOwner();
    if (on) {
        integer level = llListFindList(lockLevels, [lockLevel]);
        if (level < 3) {
            sayDebug("setRelayState: "+(string)level+" "+RelayASK);
            sendJSON("relayCommand", RelayASK, avatarKey);
        } else {
            // Heavy or hardcore
            relayCheckboxState = 1;
            sayDebug("setRelayState: "+(string)level+" "+RelayON);
            sendJSON("relayCommand", RelayON, avatarKey);
        }
    }  else {
        sayDebug("setRelayState: "+RelayOFF);
        sendJSON("relayCommand", RelayOFF, avatarKey);
    }
}


lockMenu(key avatarKey)
{
    if (avatarKey == llGetOwner())
    {
        string message = "Set your Lock Level\n\n" +
            "Each level applies heavier RLV restrictions.\n"+ 
            "• Off has no RLV restrictions.\n" +
            "• Light and Medium can be switched Off any time.\n" +
            "• Heavy requires you to acitvely Safeword out.\n" +
            "• Hardcore has no safeword. To be released, you must ask a Guard.";
            
        // lockLevels: 0=Off 1=Light 2=Medium 3=Heavy 4=Hardcore
        // convert our locklevel to an integer
        sayDebug("lockMenu lockLevel:"+lockLevel);
        integer iLockLevel = llListFindList(lockLevels, [lockLevel]);
        sayDebug("lockMenu iLocklevel:"+(string)iLockLevel);
        // make a list of wjether each lock level is available from that lock level
        // lockLevel: 0=off, 1=light, 2=medium, 3=heavy, 4=hardcore
        list lockListOff = [0, 1, 1, 1, 0];
        list lockListLight = [1, 0, 1, 1, 0];
        list lockListMedium = [1, 1, 0, 1, 0];
        list lockListHeavy = [0, 0, 0, 0, 1];
        list lockListHardcore = [0, 0, 0, 0, 0];
        list lockLists = lockListOff + lockListLight + lockListMedium + lockListHeavy + lockListHardcore; // strided list
        list lockListMenu = llList2List(lockLists, iLockLevel*5, (iLockLevel+1)*5); // list of lock levels to add to menu
        sayDebug("lockMenu lockListMenu:"+(string)lockListMenu); 
                
        //make the button list
        list buttons = [];
        integer levelIndex;
        for (levelIndex = 0; levelIndex < 5; levelIndex++) {
            integer buttonActive =  llList2Integer(lockListMenu, levelIndex);
            string buttonText = llList2String(lockLevels, levelIndex);
            string radioButton = llList2String(menuRadioButton(buttonText, lockLevel), 0);
            buttons = buttons + menuButtonActive(radioButton, buttonActive);
            // It may seem stupid to have ([•] something) but in this case choosing it again is stupider. 
        }

        // Relay button
        buttons = buttons + menuButtonActive(menuCheckbox("Relay", relayCheckboxState), iLockLevel < 3);

        // Settings button
        buttons = buttons + [buttonSettings];
        
        setUpMenu(RLV, avatarKey, message, buttons);
    }
}

doLockMenu(key avatarKey, string message, string messageButtonsTrimmed) {
    sayDebug("doLockMenu("+message+","+messageButtonsTrimmed+")");
    // Initial Hardcore
    if (message == "○ Hardcore") {
        confirmHardcore(avatarKey);

    // Confirm Hardcore
    } else if (message == "⨷ Hardcore") {
        sayDebug("listen set lockLevel:\""+lockLevel+"\"");
        sendJSON(RLV, "Hardcore", avatarKey);
        relayCheckboxState = 1;
        setRelayState(relayCheckboxState);
        
    // Relay
    } else if (message == menuCheckbox("Relay", relayCheckboxState)) {
        // RelayState() now returns what the state is now, 
        // which the wearer wants to change to the opposite. 
        if (relayCheckboxState == 1) {
            relayCheckboxState = 0;
        } else {
            relayCheckboxState = 1;
        }
        sayDebug("listen set relayCheckboxState:"+(string)relayCheckboxState);
        setRelayState(relayCheckboxState);
        
    // Locklevels
    } else if (llListFindList(lockLevels, [messageButtonsTrimmed]) > -1) {
        sayDebug("listen set lockLevel:\""+lockLevel+"\"");
        sendJSON(RLV, messageButtonsTrimmed, avatarKey);
        if (messageButtonsTrimmed == "Heavy") {
            sayDebug("listen lockLevel Heavy, so turn on renamer");
            renamerActive = 1;
            sendJSONCheckbox(buttonSpeech, "Renamer", avatarKey, renamerActive);
            relayCheckboxState = 1;
            }
        setRelayState(relayCheckboxState);
        settingsMenu(avatarKey);
        
    // Ignore
    } else {
        sayDebug("doLockMenu ignoring "+message);
    }
}

confirmHardcore(key avatarKey) {
    sayDebug("confirmHardcore");
    if (avatarKey == llGetOwner()) {
        string message = "Set your Lock Level to Hardcore?\n"+
        "• Hardcore has the Heavy restrictions\n"+
        "• Hardcore has no safeword.\n"+
        "• To be released from Hardcore, you must ask a Guard.\n\n"+
        "Confirm that you want the Hardcore lock.";
        list buttons = ["⨷ Hardcore"];
        setUpMenu(RLV, avatarKey, message, buttons);
    }
}

threatMenu(key avatarKey) {
    string message = "Threat";
    list buttons = [];
    buttons = buttons + menuRadioButton("None", threat);
    buttons = buttons + menuRadioButton("Moderate", threat);
    buttons = buttons + menuRadioButton("Dangerous", threat);
    buttons = buttons + menuRadioButton("Extreme", threat);
    buttons = buttons + [buttonBlank, buttonBlank, buttonSettings];
    setUpMenu("Threat", avatarKey, message, buttons);
}

attachStartup(string calledby) {
    sayDebug("attachStartup("+calledby+")");
    // set up chanel 1 menu command
    string canonicalName = llToLower(llKey2Name(llGetOwner()));
    list canoncialList = llParseString2List(llToLower(canonicalName), [" "], []);
    string initials = llGetSubString(llList2String(canoncialList,0),0,0) + llGetSubString(llList2String(canoncialList,1),0,0);
    menuPhrase = initials + "menu";
    llOwnerSay("Access the collar menu by typing /1"+menuPhrase);
    wearerListen = llListen(wearerChannel, "", "", menuPhrase);
}

// Event Handlers ***************************

default
{
    state_entry() // reset
    {
        sayDebug("state_entry");
        menuAgentKey = "";
        mood = moodOOC;
        lockLevel = lockLevelOff; 
        renamerActive = 0;       

        // Initialize Unworn
        if (llGetAttached() == 0) {
            sendJSON("assetNumber", assetNumber, "");
            sendJSON("class", "white", "");
            sendJSON("crime", "unknown", "");
            sendJSON("threat", "None", "");
            sendJSON("mood", moodOOC, "");            
            doSetPunishmentLevels(llGetOwner(),""); // initialize
        } else {
            attachStartup("state_entry");
        }
        sayDebug("state_entry done");
    }
    
    attach(key avatar) {
        sayDebug("attach");
        attachStartup("attach");
        sayDebug("attach done");
    }

    touch_start(integer total_number)
    {
        key whoClicked  = llDetectedKey(0);
        integer touchedLink = llDetectedLinkNumber(0);
        integer touchedFace = llDetectedTouchFace(0);
        vector touchedUV = llDetectedTouchUV(0);
        sayDebug("Link "+(string)touchedLink+", Face "+(string)touchedFace+", UV "+(string)touchedUV);
        mainMenu(whoClicked);
    }
    
    listen(integer channel, string name, key avatarKey, string message){
        sayDebug("listen name:"+name+" message:"+message);
        
        // listen for the /1flmenu command
        if (channel == wearerChannel & message == menuPhrase) {
            sayDebug("listen menuAgentKey:'"+(string)menuAgentKey+"'");
            if (menuAgentKey != avatarKey) {
                mainMenu(avatarKey);
                menuAgentKey = "";
            } else {
                llInstantMessage(avatarKey, "The collar menu is being accessed by someone else.");
            }
            return;
        }
        
        string messageButtonsTrimmed = message;
        list striplist = ["☒ ","☐ ","● ","○ "];
        integer i;
        for (i=0; i < llGetListLength(striplist); i = i + 1) {
            string thing = llList2String(striplist, i);
            integer whereThing = llSubStringIndex(messageButtonsTrimmed, thing);
            if (whereThing > -1) {
                integer thingLength = llStringLength(thing)-1;
                messageButtonsTrimmed = llDeleteSubString(messageButtonsTrimmed, whereThing, whereThing + thingLength);
                }
            }
        sayDebug("listen messageButtonsTrimmed:"+messageButtonsTrimmed+" menuIdentifier: "+menuIdentifier);
        
        // display the menu item
        if (llGetSubString(message,1,1) == " ") {
            sendJSON("DisplayTemp", messageButtonsTrimmed, avatarKey);
        } else {
            sendJSON("DisplayTemp", message, avatarKey);
        }    

        // reset the menu setup
        llListenRemove(menuListen);
        menuListen = 0;
        menuChannel = 0;
        menuAgentKey = "";
        llSetTimerEvent(0);
        
        if (message == "Close") {
            return;
        }
        
        // Main button
        if (message == menuMain) {
            mainMenu(avatarKey);
        }
        
        //Main Menu
        else if ((menuIdentifier == menuMain) || (message == buttonSettings)) {
            sayDebug("listen: Main:"+message);
            doMainMenu(avatarKey, message);
        }
        
        //Settings
        else if (menuIdentifier == buttonSettings){
            sayDebug("listen: Settings:"+message);
            doSettingsMenu(avatarKey, message, messageButtonsTrimmed);
        }

        //Speech
        else if (menuIdentifier == buttonSpeech){
            sayDebug("listen: Speech:"+message);
            doSpeechMenu(avatarKey, message, messageButtonsTrimmed);
        }

        //Speech Penalties
        else if (menuIdentifier == "Penalties"){
            sayDebug("listen: Speech Penalties:"+message);
            doPenaltyMenu(avatarKey, message, messageButtonsTrimmed);
        }

        // Asset
        //else if (menuIdentifier == "Asset") {
        //    sayDebug("listen: Asset:"+message);
        //    if (message != "OK") {
        //        assetNumber = message;
        //        // The wearer chose this asset number so transmit it and display it
        //        sendJSON("assetNumber", assetNumber, avatarKey);
        //        settingsMenu(avatarKey);
        //    }
        //}
        
        // Class
        else if (menuIdentifier == "Class") {
            sayDebug("listen: Class:"+messageButtonsTrimmed);
            class = messageButtonsTrimmed;
            sendJSON("class", class, avatarKey);
            settingsMenu(avatarKey);
        }
        
        // Mood
        else if (menuIdentifier == "Mood") {
            sayDebug("listen: Mood:"+messageButtonsTrimmed);
            mood = messageButtonsTrimmed;
            sendJSON("mood", mood, avatarKey);
            settingsMenu(avatarKey);
        }
        
        // Hack
        //else if (menuIdentifier == buttonHack) {
        //    sayDebug("listen: Hack:"+messageButtonsTrimmed);
        //    doHackMenu(avatarKey, message, messageButtonsTrimmed);
        //}
        
        // Zap the inmate
        else if (menuIdentifier == buttonPunish) {
            sayDebug("listen: Zap:"+message);
            sendJSON(RLV, message, avatarKey);
        }

        // Set Zap Level
        else if (menuIdentifier == "Punishments") {
            sayDebug("listen: Set Zap:"+message);
            if (message == buttonSettings) {
                settingsMenu(avatarKey);
            } else {
                doSetPunishmentLevels(avatarKey, messageButtonsTrimmed);
                PunishmentLevelMenu(avatarKey);
            }
        }

        // Lock Level
        else if (menuIdentifier == RLV) {
            sayDebug("listen Lock: message:"+message);
            doLockMenu(avatarKey, message, messageButtonsTrimmed);
        }

        // Threat Level
        else if (menuIdentifier == "Threat") {
            sayDebug("listen: threat:"+messageButtonsTrimmed);
            threat = messageButtonsTrimmed;
            sendJSON("threat", threat, avatarKey);
            settingsMenu(avatarKey);
        }
        
        // Document
        else if (menuIdentifier == buttonInfo) {
            integer inumber = (integer)llGetSubString(message,4,4) - 1;
            sayDebug("listen: message:"+message+ " inumber:"+(string)inumber);
            if (inumber > -1) {
                llOwnerSay("Offering '"+llGetInventoryName(INVENTORY_NOTECARD,inumber)+"' to "+llGetDisplayName(avatarKey)+".");
                llGiveInventory(avatarKey, llGetInventoryName(INVENTORY_NOTECARD,inumber));    
            }        
        }
        
        else {
            sayDebug("ERROR: did not process menuIdentifier "+menuIdentifier);
        }
    }
    
    link_message(integer sender_num, integer num, string json, key avatarKey){ 
    // We listen in on link status messages and pick the ones we're interested in
        //sayDebug("link_message json "+json);
        assetNumber = getJSONstring(json, "assetNumber", assetNumber);
        crime = getJSONstring(json, "crime", crime);
        class = getJSONstring(json, "class", class);
        threat = getJSONstring(json, "threat", threat);
        mood = getJSONstring(json, "mood", mood);
        lockLevel = getJSONstring(json, "lockLevel", lockLevel);
        RelayLockState = getJSONstring(json, "RelayLockState", RelayLockState);
        renamerActive = getJSONinteger(json, "renamerActive", renamerActive);
        badWordsActive = getJSONinteger(json, "badWordsActive", badWordsActive);
        DisplayTokActive = getJSONinteger(json, "DisplayTokActive", DisplayTokActive);
        batteryPercent = getJSONinteger(json, "batteryPercent", batteryPercent);
        batteryGraph = getJSONstring(json, "batteryGraph", batteryGraph);
        rlvPresent = getJSONinteger(json, "rlvPresent", rlvPresent);
        if (rlvPresent == 0) {
            renamerActive = 0;
            badWordsActive = 0;
            DisplayTokActive = 0;
        }
        if ((lockLevel == "Hardcore" || lockLevel == "Heavy")) {
            batteryActive = 1;
        }
    }
    
    timer() 
    {
        // reset the menu setup
        llListenRemove(menuListen);
        menuListen = 0;   
        menuAgentKey = "";
    }
}
