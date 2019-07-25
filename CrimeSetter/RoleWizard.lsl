// RoleWizard.lsl
// Black Gazza RPG Role Setter Upper Wizard
// Timberwoof Lupindo
// July 2019

// Takes the user through a series of questions to set up one character in the new database.
// Resulting data is sent as an upsert operation to the new database.
// JSON looks like {"name":"Flimbertwoof Utini","crime":"Stealing hubcaps off landspeeeders","class":"orange","threat":"Moderate"}

// reference: useful unicode characters
// https://unicode-search.net/unicode-namesearch.pl?term=CIRCLE

// Some parameters we want to store are free-form text from the user: name and crime
// Some paraneters are from pick-lists. The valies of the pick-lists are stored in a list and retrieved as needed. 
// primitive setUpMenu is used by MainMenu, KeyMenu, and RoleKeyDialog. 
// MainMenu lets the user choose the basic class of the new character. 
// KeyMenu uses the class established in MainMenu to generate a further menu of available parameters. 
// RoleKeyDialog handles those choices, with either another keyMenu call for picklists or a textbox for freeform items. 
// At all times the full status of the user's setup is given in the dialogs. 
// When the user selects Finish, the setup is sent to the external database. 

integer OPTION_DEBUG = 1;

integer menuChannel = 0;
integer menuListen = 0;
string menuIdentifier;
list menuChoices;
key menuAvatar;
string localState;

list PlayerRoleNames = ["inmate", "guard", "medic", "mechanic", "robot", "k9", "bureaucrat"];
list AssetPrefixes = ["P", "G", "M", "X", "R", "K", "B"];

// irregularly strided list with start and stop markers that come from list PlayerRoleNames.
// *** prefix marks the end of a section of symbols for that role.
// _text indicates that that field is free-form text and not a picklist. 
list PlayerRoleKeys = ["inmate", "name_text", "crime_text", "class", "threat", "***inmate", 
                        "guard", "name_text", "rank", "***guard", 
                        "medic", "name_text", "rank", "specialty", "***medic", 
                        "mechanic", "name_text", "rank", "**mechanic", 
                        "robot", "name_text", "***robot", 
                        "k9", "name_text", "rank", "***k9", 
                        "bureaucrat", "name_text", "rank", "***bureaucrat"];
list playerRoleKeyValues = []; // actual player info goes in here

// lists of picklist values. These are separate literals and are composed in init
list PrisonerClasses = ["white", "pink", "red", "orange", "green", "blue", "black"];
//list PrisonerClassesLong = ["Unassigned Transfer", "Sexual Deviant", "Mechanic", "General Population", "Medical Experiment", "Violent or Hopeless", "Mental"];
list PrisonerThreatLevels = ["None", "Moderate", "Dangerous", "Extreme"];
list MedicalSpecialties = ["General", "Surgery", "Neurology", "Psychiatry", "Pharmacology"];
list Ranks = ["Grunt", "Sergeant", "Officer", "Captain"]; // probably shoudl be made into unique sets
list RoleKeyValues = []; // set up during initilizaitons

string playerRole = "Unknown"; // set by first dialog and kept for subsequent context

string textBoxParameter = "";
key databaseQuery;

sayDebug(string message)
{
    if (OPTION_DEBUG)
    {
        llWhisper(0,message);
    }
}

// wrapper to set up a simple menu dialog.
setUpMenu(string identifier, key avatarKey, string message, list buttons)
{
    sayDebug("setUpMenu "+identifier);
    menuIdentifier = identifier;
    menuChoices = buttons;
    menuAvatar = avatarKey;
    menuChannel = -(llFloor(llFrand(10000)+1000));
    llDialog(avatarKey, message, buttons, menuChannel);
    menuListen = llListen(menuChannel, "", avatarKey, "");
    llSetTimerEvent(30);
}

// wrapper to set up a simple text box dialog
setUpTextBox(string identifier, key avatarKey, string message) {
    sayDebug("setUpTextBox "+identifier);
    menuIdentifier = identifier;
    menuChoices = [];
    menuAvatar = avatarKey;
    menuChannel = -(llFloor(llFrand(10000)+1000));
    llTextBox(avatarKey, message, menuChannel);
    menuListen = llListen(menuChannel, "", avatarKey, "");
    llSetTimerEvent(30);
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

confirmLogin(key avatarKey, integer status, string message) {
    sayDebug("confirmLogin("+(string)status+","+message+")");
    string playerName = llKey2Name(avatarKey);
    
    if (status == 200) {
        list identityList = llJson2List(message);
        // looks like {"roles": true, "_name_": "Timberwoof Lupindo", "_start_date_": "2009-08-10 01:39:05"}
        integer whereRoles = llListFindList(identityList, ["roles"]);
        integer whereName =  llListFindList(identityList, ["_name_"]);
        integer whereDate = llListFindList(identityList, ["_start_date_"]);
        if (whereRoles > -1  && whereDate > -1 && whereName > -1) {
            string dbName = llList2String(identityList, whereName+1);
            string startDate = llList2String(identityList, whereDate+1);
            sayDebug("dbName: "+dbName);
            sayDebug("startDate: "+startDate);
            
            if (dbName != playerName) {
                string errorMessage = "Error from RoleWizard: database name '" + dbName + "' " + 
                "did not match in-world account name '"+ playerName+"'"; 
                llInstantMessage(menuAvatar, errorMessage);
                llOwnerSay(errorMessage);
                llResetScript();
                return;
            }
            string message = "Hello, " + playerName + ". " + 
            "You are known to us since " + startDate +". " +
            "If you wish to continue setting up your Black Gazza character, please click Continue.";
            list buttons = ["Cancel", "Continue"];
            setUpMenu("confirmLogin", avatarKey, message, buttons);
            // --> getRoles
            }
        }
    }
    
getRoles(key avatarKey, string message){
    // message is "Continue" or "Cancel";
    if (message == "Continue") {
        // retrieve existing character classes. 
        localState = "GetRoles";
        string URL = "https://api.blackgazza.com/identity/"+(string)menuAvatar+"/roles";
        sayDebug("getRoles URL:"+URL);
        databaseQuery = llHTTPRequest(URL, [], "");
        // -> selectRole
        }
    else {
        llInstantMessage(menuAvatar, "Thank you.");
        llResetScript();
        }
    }

presentRoles(key avatarKey, integer status, string message) {
    sayDebug("presentRoles("+(string)status+","+message+")");
    if (status == 200) {
        list rolesList = llJson2List(message);
        list buttons = ["Cancel"];
        string message = "Please select the character type you want to set up. "+
            "☒ means you have a character of that type. "+
            "☐ means you do not have a character of that type.";
        integer i;
        for (i = 0; i < llGetListLength(rolesList); i = i + 2) {
            string theRole = llList2String(rolesList, i);
            string theTruth = llList2String(rolesList, i+1);
            sayDebug("theRole:"+theRole+" theTruth:"+theTruth);
            // Convert these into button textx with checkmarks to indicate which are active and which are not. 
            buttons = buttons + menuCheckbox(theRole, theTruth=="﷖");
            }
        setUpMenu("PresentRoles", avatarKey, message, buttons);
        }

    }

// The main menu, the first that greets whoever clicks the box. 
mainMenu(key avatarKey) {
    sayDebug("mainMenu");
    if (menuAvatar != "" & menuAvatar != avatarKey) {
        llInstantMessage(avatarKey, "The collar menu is being accessed by someone else.");
        sayDebug("Told " + llKey2Name(avatarKey) + "that the collar menu is being accessed by someone else.");
        return;
        }

    string message = "Welcome to the Black Gazza RPG Role Setter Upper Wizard. " +
        "Set up a Black Gazza character for your Second Life account. " + 
        "First, choose your Character Class:";
    
    // PlayerRoleNames is the button list and the list of messages to detect as the response
    setUpMenu("Main", avatarKey, message, PlayerRoleNames);
}

// playerRoleKeyValues maintains actual user data that will get bundled up and sent to the database. 
// upsertRoleKeyValue gets a key-value pair and inserts or updates it in that list. 
// The key-value pair is stored as a single string, key=value. 
upsertRoleKeyValue(string theKey, string theValue) {
    //sayDebug("upsertRoleKeyValue "+theKey+"="+theValue);
    // sets global PlayerRoleKeyValues
    integer where = -1;
    integer i;
    for (i = 0; i < llGetListLength(playerRoleKeyValues); i++) {
        string keyValue = llList2String(playerRoleKeyValues, i);
        integer theIndex = llSubStringIndex(keyValue, theKey);
        //sayDebug("upsertRoleKeyValue keyValue:"+keyValue+ " theIndex:"+(string)theIndex);
        if (theIndex == 0) {
            where = i;
            }
        }
        
    // generate the new key-value pair
    string newKeyValue = theKey + "=" + theValue;
    
    // is it in our list?
    if (where == -1) {
        // nope. Add it to the list.
        sayDebug("upsertRoleKeyValue adding "+newKeyValue);
        playerRoleKeyValues = playerRoleKeyValues + [newKeyValue];
    } else {
        // yup. Replace it.
        sayDebug("upsertRoleKeyValue updating "+newKeyValue);
        playerRoleKeyValues = llListReplaceList(playerRoleKeyValues, [newKeyValue], where, where);
    }
}

// gets a value out of global PlayerRoleKeyValues
string getRoleKeyValue(string lookupKey) {
    sayDebug("getRoleKeyValue(\""+lookupKey+"\")");
    string result = "";
    integer where = -1;
    integer i;
    for (i = 0; i < llGetListLength(playerRoleKeyValues); i++) {
        string onePair = llList2String(playerRoleKeyValues, i);
        list keyValue = llParseString2List(onePair, ["="], []);
        string thekey = llList2String(keyValue, 0);
        string thevalue = llList2String(keyValue, 1);
        //sayDebug("getRoleKeyValue retrieved onePair:"+onePair+ " keyValue:" + (string)keyValue + " thekey:" + thekey + " thevalue:" + thevalue);
        
        if (thekey == lookupKey){
            result = thevalue;        
        }
    }
    return result;
}

// Create the current user information text.
// This gets shown in dialogs and could get shown in floaty text. 
string CharacterInfoList() {
    sayDebug("CharacterInfoList");
    // Adds all the key-value pairs in PlayerRoleKeyValues to a string
    string message = "";
    integer i;
    for (i = 0; i < llGetListLength(playerRoleKeyValues); i++) {
        string onePair = llList2String(playerRoleKeyValues, i);
        list keyValue = llParseString2List(onePair, ["="], []);
        string thekey = llList2String(keyValue, 0);
        string thevalue = llList2String(keyValue, 1);
        message = message + thekey + ": " + thevalue + "\n";
    }
    return message;
}

// Gather up the additional keys for the playerRole.
// Gven the player's chosen role, look throgh the list of all the allowed keys. 
// Select out the section that represents this role's keys. 
keyMenu(key avatarKey, string playerRole) {
    sayDebug("keyMenu");
    string message = "Continue setting up your Black Gazza character. \n" +
        "Your setup so far: \n" + 
        CharacterInfoList() +
        "Next, choose additional parameters:";
    integer indexStart = llListFindList(PlayerRoleKeys, [playerRole]);
    integer indexEnd = llListFindList(PlayerRoleKeys, ["***"+playerRole]);
    list buttons = llList2List(PlayerRoleKeys, indexStart+1, indexEnd-1);
    buttons = buttons + ["Finish"];
    setUpMenu("Key", avatarKey, message, buttons);
}

// Handles response to keyMenu. 
// If the item ends with _text, present a text box. 
// Otherwise, present a menu of the value chocies for this specific key. 
// For example, prisoners can set their crime or their classificaiton (color). 
roleKeyDialog(key avatarKey, string parameterKey) {
    // let player enter text or select from chocies
    // Some of these are free-form text; the keys end in "_text"
    // Some of these are picklists
    string message = "Continue setting up your Black Gazza character. \n";
    
    if (llSubStringIndex(parameterKey, "_text") > -1) {
        sayDebug("roleKeyDialog ("+parameterKey+"): text");
        // get some freeform text
        textBoxParameter = llGetSubString(parameterKey, 0, -6);
        message = message + "Enter your " + textBoxParameter;
        setUpTextBox("RoleKeyText", avatarKey, message);
    } else {
        sayDebug("roleKeyDialog ("+parameterKey+"): pick");
        // pick from a picklist
        message = message + "Select a value for your " + parameterKey;
        // Gather up the additional keys for the playerRole
        integer indexStart = llListFindList(RoleKeyValues, [parameterKey]);
        integer indexEnd = llListFindList(RoleKeyValues, ["***"+parameterKey]);
        list buttons = llList2List(RoleKeyValues, indexStart+1, indexEnd-1);
        buttons = buttons + ["Finish"];
        setUpMenu("RoleKeyPick", avatarKey, message, buttons);
    }
}

// Handle player's choice of a specific key value. 
// Looks for the dialog response from the composed list of all the possible values. 
// Finds the associated key.
// Adds the key-value pair to the user's real data. 
// This implies that all the values must be unique. 
setRoleKeyValue(string theValue) {
    sayDebug("setRoleKeyValue("+theValue+")");
    // player has selected a key value; 
    // find out what it was a list of and upsert it in the player key-value pairs. 
    integer startIndex = llListFindList(RoleKeyValues,[theValue]);
    integer i;
    for (i = startIndex; i < llGetListLength(RoleKeyValues); i++) {
        string listItem = llList2String(RoleKeyValues, i);
        if (llSubStringIndex(listItem, "***") > -1) {
            string theKey = llGetSubString(listItem, 3, -1);
            upsertRoleKeyValue(theKey, theValue);
            i = 999; // break
        }
    }
}

// Create a JSON representation of the key-value list of player data.
// Split each key=value pair into two strings and added them to a list. 
// Convert the list to JSON dictionary the LSL way. 
string generateUpsertJson() {
    list values = [];
    integer i;
    for (i = 0; i < llGetListLength(playerRoleKeyValues); i++) {
        string onePair = llList2String(playerRoleKeyValues, i);
        list keyValue = llParseString2List(onePair, ["="], []);
        string thekey = llList2String(keyValue, 0);
        string thevalue = llList2String(keyValue, 1);
        values = values + [thekey, thevalue];
    }
    return llList2Json(JSON_OBJECT, values);
    // looks like {"name":"Dread Pirate Timby","crime":"Unpermitted transport of biogenic weapons, piracy, murder","class":"blue","threat":"Moderate","identity":"284ba63f-378b-4be6-84d9-10db6ae48b8d"}
}

// Put together the HTTP request and JSON body and throw it at the server. 
registerPlayer(key avatarKey) {
    string json = generateUpsertJson();
    sayDebug("registerPlayer json:"+json);
    string URL = "https://api.blackgazza.com/asset/"+(string)avatarKey;
    sayDebug("registerPlayer URL:"+URL);
    databaseQuery = llHTTPRequest(URL,[HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json"], json);
}
    
default
{
    state_entry()
    {
        sayDebug("state_entry");
        textBoxParameter = "";
        // compose the role key values list. 
        RoleKeyValues = ["class"] + PrisonerClasses + ["***class"] +
            ["threat"] + PrisonerThreatLevels + ["***threat"] +
            ["rank"] + Ranks + ["***rank"] +
            ["specialty"] + MedicalSpecialties + ["***specialty"] ;
    }

    touch_start(integer total_number)
    {
        sayDebug("touch_start");
        menuAvatar = llDetectedKey(0); 
        localState = "Touch";
        string URL = "https://api.blackgazza.com/identity/"+(string)menuAvatar;
        sayDebug("touch_start URL:"+URL);
        databaseQuery = llHTTPRequest(URL, [], "");
    }
    
    listen( integer channel, string name, key avatarKey, string message ){
        llListenRemove(menuListen);
        menuListen = 0;
        llSetTimerEvent(0);
        sayDebug("listen message:"+message);
        sayDebug("listen menuIdentifier: "+menuIdentifier);
        
        if (menuIdentifier == "confirmLogin"){
            // message is Cancel or Continue
            getRoles(avatarKey, message);
        }
            
        else if (menuIdentifier == "Main"){
            playerRole = message;
            keyMenu(avatarKey, message);
        }
            
        else if (message == "Finish") {
            registerPlayer(avatarKey);
        }
       
        else if (menuIdentifier == "Key"){
            roleKeyDialog(avatarKey, message);
        }
        
        else if (menuIdentifier == "RoleKeyPick") {
            setRoleKeyValue(message);
            keyMenu(avatarKey, playerRole);
        }

        else if (menuIdentifier == "RoleKeyText") {
            upsertRoleKeyValue(textBoxParameter, message);
            keyMenu(avatarKey, playerRole);
        }
        
        else {
            sayDebug("ERROR: did not process menuIdentifier "+menuIdentifier);
        }
    }

    timer() 
    {
        llListenRemove(menuListen);
        menuListen = 0;    
    }
    
    http_response(key request_id, integer status, list metadata, string message)
    // handle the response from the crime database
    {
        sayDebug("http_response localState:"+ localState+ " status:"+(string)status);
        sayDebug("message: "+message);
        if (request_id == databaseQuery && localState == "Touch") {
            confirmLogin(menuAvatar, status, message);
            }
        if (request_id == databaseQuery && localState == "GetRoles") {
            presentRoles(menuAvatar, status, message);
            }
      
    }

}
