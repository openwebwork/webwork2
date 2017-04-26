// ################################################################################
// # WeBWorK Online Homework Delivery System
// # Copyright © 2000-2009 The WeBWorK Project, http://openwebwork.sf.net/
// # $CVSHeader: webwork2/htdocs/js/apps/AppletSupport/ww_applet_support.js,v 1.12 2009/07/12 23:37:10 gage Exp $
// # 
// # This program is free software; you can redistribute it and/or modify it under
// # the terms of either: (a) the GNU General Public License as published by the
// # Free Software Foundation; either version 2, or (at your option) any later
// # version, or (b) the "Artistic License" which comes with this package.
// # 
// # This program is distributed in the hope that it will be useful, but WITHOUT
// # ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// # FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
// # Artistic License for more details.
// ################################################################################



//////////////////////////////////////////////////////////
// applet lists
//////////////////////////////////////////////////////////


	var  ww_applet_list                  = new Object;  // holds  java script version (jsApplet) ww_applet objects
	
	var TIMEOUT                          = 800;         // time delay between successive checks for applet readiness

    
//////////////////////////////////////////////////////////
// DEBUGGING tools
//////////////////////////////////////////////////////////
	var jsDebugMode=0; // set this to one when needed for major debugging -- puts all applets in debugMode
	var debugText = "";
	function debug_add(str) { 
			debugText = debugText + "\n" +str;
	}
	
//////////////////////////////////////////////////////////
// INITIALIZE and SUBMIT actions
//////////////////////////////////////////////////////////

function submitAction()  {    // called from the submit button defined in Problem.pm
    console.log("Submit button pushed.");
	if (jsDebugMode==0) {
		debugText = "Call submitAction() function on each applet\n";
	}

	for (var appletName in ww_applet_list ) {
			 ww_applet_list[appletName].submitAction();
	}
	if (jsDebugMode==1) { debug_add("\n Done calling submitAction() on each applet.\n");}
	if (jsDebugMode==1) {
		console.log("DebugText:\n"+debugText); debugText="";
	};
	console.log("Done calling submit action routines");
}

function initializeAction() {  // deprecated call -- removed
	alert("You might be using an old template (stored at webwork2/conf/templates). The <body> tag in the system.template calls a function 'initializeAction()' instead of 'intializeWWquestion()'-- this function name should be replaced by 'initializeWWquestion()'. Please update to a recent version of system.template");
	initializeWWquestion();
}

function initializeWWquestion() {    // called from <body> tag defined in the webwork2/conf/template
    console.log("Into initializeWWquestion");
	for (var appletName in ww_applet_list)  {	
	    if (!ww_applet_list[appletName].onInit) { 
	        console.log("Applet " + appletName + " has no onInit function. Initializing with safe_applet_initialize");
	    	var maxInitializationAttempts = ww_applet_list[appletName].maxInitializationAttempts;
	    	//alert("Initialize each applet. \nUse up to " +maxInitializationAttempts + " cycles to load" +"\n");
	    	this.debug_add("initializing " + appletName);
			ww_applet_list[appletName].safe_applet_initialize(maxInitializationAttempts);
		} else {
	        console.log("Applet " + appletName + " has  onInit function. No further initialization required.");
		} 
		// if onInit is defined then the onInit function will handle the initialization
	}
    this.debug_add("end of applet initialization");
    console.log("Out of initializeWWquestion");
}

// applet can set isReady flag by calling applet_loaded(appletName, loaded);
function applet_loaded(appletName,ready) {
	debug_add("applet reporting that it has been loaded = " + ready );
	ww_applet_list[appletName].reportsLoaded = ready; // 0 means not loaded
	ww_applet_list[appletName].isReady = ready;
}


// insures that applet is loaded before initializing it



///////////////////////////////////////////////////////
// Utility functions
///////////////////////////////////////////////////////   
    


//  This has been replaced by defining the function in the classes
// function getApplet(appletName) {
// 	  var isIE = navigator.appName.indexOf("Microsoft") != -1;
// 	  var obj = (isIE) ? window[appletName] : window.document[appletName];
// 	  //return window.document[appletName];
// 	  if (obj && (obj.name == appletName)) {   //RECENT FIX to ==
// 		  return( obj );
// 	  } else {
// 		  alert ("can't find applet " + appletName);		  
// 	  }
//  }	

function listQuestionElements() { // list all HTML input and textarea elements in main problem form
   var isIE = navigator.appName.indexOf("Microsoft") != -1;
   var elementList = (isIE) ?  document.getElementsByTagName("input") : document.problemMainForm.getElementsByTagName("input");
   var str=elementList.length +" Question Elements\n type | name = value  < id > \n";
   for( var i=0; i< elementList.length; i++) {
	   str = str + " "+i+" " + elementList[i].type 
					   + " | " + elementList[i].name 
					   + "= " + elementList[i].value + 
					   " <" + elementList[i].id + ">\n";
   }
   elementList = (isIE) ?  document.getElementsByTagName("textarea") : document.problemMainForm.getElementsByTagName("textarea");
   for( var i=0; i< elementList.length; i++) {
	   str = str + " "+i+" " + elementList[i].type 
					   + " | " + elementList[i].name 
					   + "= " + elementList[i].value + 
					   " <" + elementList[i].id + ">\n";
   }
   var msg = "    ( Place listQuestionElements() at end of document in order to get all form elements! )\n"+str;
   alert(msg);
}

function base64Q(str) {   /// determine whether an XML string has been base64 encoded.
    if (! str ) {
          return( 0 ); // the empty string is not a base64 string.
    } else if (str.match(/[<>]+/ ) ) {
    	  return( 0 );  // base64 can't contain <  or >  and xml strings contain lots of them
    } else {
    	  return(1);   // it's probably a non-empty base64 string.
    }
}
function setHTMLAppletStateToRestart(appletName){ // resets the state stored on HTML page not in the applet
	var newState = "<xml>restart_applet</xml>";
	getQE(appletName+"_state").value = newState;
	getQE("previous_" + appletName + "_state").value = newState;
}
function setHTMLAppletState(appletName, newState){ // resets the state stored on the HTML page
	var newState = "<xml></xml>";
	getQE(appletName+"_state").value = newState;
	getQE("previous_" + appletName + "_state").value = newState;
}
function getQE(name1) { // get Question Element in problemMainForm by name
	//var isIE = navigator.appName.indexOf("Microsoft") != -1;
	//var obj = (isIE) ? document.getElementById(name1)
	//					:document.problemMainForm[name1]; 
	
	var obj = document.getElementById(name1);
	if (!obj) {obj = document.problemMainForm[name1]}
	
	// needed for IE -- searches id and name space so it can be unreliable if names are not unique
	if (!obj || obj.name != name1) {
	    var msg = "Can't find element " + name1;
		if (jsDebugMode==1) {
			debug_add(msg + "\n ( Place listQuestionElements() at end of document in order to get all form elements! )\n" );
		} else {
			alert(msg);  listQuestionElements(); 
		};
				
	} else {
		return( obj );
	}
	
}


function getQuestionElement(name1) {
	return getQE(name1);
}
	
	
///////////////////////////////////////////////////////
// WW_Applet   class definition
///////////////////////////////////////////////////////   
    
function ww_applet(appletName) {
	this.appletName              = appletName;
	this.code                    = '';
	this.codebase                = '';
	this.appletID                = '';
//	this.base64_state            = '';
//	this.base64_config           = '';
    this.configuration           = '';
    this.initialState            = '';
	this.getStateAlias           = '';
	this.setStateAlias           = '';
	this.configAlias             = '';
	this.initializeActionAlias   = '';
	this.submitActionAlias       = '';
	this.submitActionScript      = '';
	this.getAnswerAlias          = '';
	this.answerBox               = '';
	this.debugMode               = 0 ;
	this.isReady                 = 0 ;
	this.reportsLoaded           = 0 ;
};
//////////////////////////////////////////////////////////
// methodDefined
//
// make sure that the applet has this function available
//////////////////////////////////////////////////////////

ww_applet.prototype.methodDefined = function(methodName) {
	var appletName = this.appletName;
	var applet     = getApplet(appletName);
	//alert("applet is undefined = " + (typeof(applet)=="undefined"));
	//alert("applet["+methodName+ "] is undefined " + (  typeof(applet[methodName]) == "undefined"  )      );
	//alert ("applet method has type of " +typeof(applet[methodName]) );
	if (!methodName) {  // no methodName is defined
		return(false);
	}
	try {
		if (typeof(applet[methodName]) != "undefined" ) {  
		    // ie8 returns "unknown" instead of "function" so we check for anything but "undefined"
			this.debug_add("Method " + methodName + " is defined in " + appletName );
			return(true);
		} else {
			this.debug_add("Method " + methodName + " is not defined in " + appletName); 
			throw("undefined applet method");
		}
	} catch(e) {
		var msg = "Error in accessing " + methodName + " in applet " +appletName + "\n  *Error: " +e ;
		this.debug_add(msg);
	}
	return(false);
}

//////////////////////////////////////////////////////////
//CONFIGURATIONS
//
// configurations are "permanent"
//////////////////////////////////////////////////////////
ww_applet.prototype.setConfig = function () {
        
        var appletName  = this.appletName;
		var applet      = getApplet(appletName);
		var setConfigAlias = this.setConfigAlias;

       
	   try {
		    if ( this.methodDefined(this.setConfigAlias) ) {
    			applet[setConfigAlias](this.configuration);
    			this.debug_add("  Configuring applet: Calling " + appletName +"."+ setConfigAlias +"( " + this.configuration + " ) " );
    		} else {
    		    this.debug_add("  Configuring applet: Unable to execute command |" + setConfigAlias + "| in the applet "+ appletName +" with data ( \"" + this.configuration + "\" ) " );
    		}
    	
    	} catch(e) {
    	
    	    var msg = "Error in configuring applet  " + appletName + " using command " + setConfigAlias + " : " + e ;
			alert(msg);
    	}
    	
  
 };
 
 ww_applet.prototype.getConfig = function() {                    // used for debugging purposes -- gets the configuration from the applet
 

	var appletName     = this.appletName;
	var applet         = getApplet(appletName);	
	var getConfigAlias = this.getConfigAlias;
	

	try {
		if (this.methodDefined(getConfigAlias) ) {
  			alert( applet[getConfigAlias]() );
 		} else {
    		    this.debug_add("  unable to execute " + appletName +"."+ getConfigAlias +"( " + this.configuration + " ) " );
  		}
    } catch(e) {
    	var msg = "    Error in getting configuration from applet " + appletName + " " + e;
    	alert(msg);
    }  
}
	
 
 
////////////////////////////////////////////////////////////
//
//STATE:
// state can vary as the applet is manipulated -- it is reset from the questions _state values
//
////////////////////////////////////////////////////////// 


ww_applet.prototype.setState = function(state) { 
	
	var appletName      = this.appletName;
	var applet          = getApplet(appletName);
	var setStateAlias   = this.setStateAlias;
	console.log("Into setState for applet " + appletName);
	this.debug_add("\n++++++++++++++++++++++++++++++++++++++++\nBegin process of setting state for applet " + appletName);
////////////////////////////////////////////////////////// 
// Obtain the state which will be sent to the applet and if it is encoded place it in plain xml text
// Communication with the applet is in plain text,not in base64 code.
////////////////////////////////////////////////////////// 
	if (state) {
		this.debug_add("Obtain state from calling parameter:\n " + state.substring(0,200) + "\n");
	} else {
		this.debug_add("Obtain state from " + appletName +"_state");
	
		var ww_preserve_applet_state = getQE(appletName + "_state"); // hidden answer box preserving applet state
		state =   ww_preserve_applet_state.value;
		var str = state;
		this.debug_add("immediately on grabbing state from HTML cache state is " + (state.substring(0,200) ) + "...");
	}
	
	if ( base64Q(state) ) { 
		state=Base64.decode(state);
		this.debug_add("decodes to:  " +state.substring(0,200));
		if (this.debugMode>=1) { //decode text for the text area box
			ww_preserve_applet_state.value = state;
			
		}
        this.debug_add("decoded to " + ww_preserve_applet_state.value);	
	}
	
//////////////////////////////////////////////////////////
// Handle the exceptional cases:
//
//If the state is blank, undefined, or explicitly defined as restart_applet
// then we will not simply be restoring the state of the applet from HTML "memory"
//
// 1. For a restart we wipe the HTML state cache so that we won't restart again
// 2. In the other "empty" cases we attempt to replace the state with the contents of the 
// initialState variable. 
//////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////
// Exceptional cases
//////////////////////////////////////////////////////////
	if (state.match(/^<xml>restart_applet<\/xml>/) || 
	    state.match(/^\s*$/) ||
	    state.match(/^<xml>\s*<\/xml>/ ) ) { 
	    
	       this.debug_add("Beginning handling exceptional cases when the state is not simply restored from the HTML cache. State is: "+state.substring(0,100));
		
//		if (state.match(/^<xml>restart_applet<\/xml>/) ) {
		    if (typeof(this.initialState) == "undefined") {this.initialState = "<xml></xml>";}
		         debug_add("restart_applet has been called. the value of the initialState is " + this.initialState );
		    if(  this.initialState.match(/^<xml>\s*<\/xml>/)  || this.initialState.match(/^\s*$/)  ){ // if the initial state is empty
		    	 debug_add("The applet " +appletName + " has been restarted. There was no non-empty initialState value. \n  Nothing is sent to the applet.  \n  Done setting state");
		    	 if (state.match(/^<xml>restart_applet<\/xml>/) ) {
		    	 	alert("the applet is being restarted with empty initialState");
		    	 }
		    	 setHTMLAppletState(appletName,"<xml></xml>");  // so that the submit action will not be overridden by restart_applet.
				 return(''); // don't call the setStateAlias function at all.
				 /// quit because we know we will not transmitting any starting data to the applet
			} else {		     
				 state = this.initialState;
				if ( base64Q(state) ) { 
					state=Base64.decode(state);
				}
			     debug_add("The applet " +appletName + "has been set to its virgin state value." +state.substring(0,200));
			     if (state.match(/^<xml>restart_applet<\/xml>/) ) {
			     	alert(" The applet is being reset to its initialState.");
			     }
			     setHTMLAppletState(appletName,this.initialState);   // store the state in the HTML variables just for safetey
				
				// if there was a viable state in the initialState variable we Can.
				// now continue as if we had found a valid state in the HTML cache

		    }
//		}
	this.debug_add("Completed handling the exceptional cases.");
	}
	
	
	if (state.match(/\<xml/i) || state.match(/\<\?xml/i) ) {  // state MUST be an xml string in plain text
	
		this.debug_add("Grab data from the HTML cache and set state for " + appletName + " to the data between the lines:" 
		               + "\n------------------------------\n" 
		               +  state.substring(0,200) + "\n------------------------------\n");
		try {
		    
			if ( this.methodDefined(setStateAlias)   ) {
		        var result = applet[setStateAlias]( state );
		        this.debug_add("State of applet " +appletName + "set from HTML cache");
			} 
		} catch(err) {  // catching false positives?
			var msg = "Error in setting state of " + appletName + " using command " + setStateAlias + " : " +err+err.number+ err.description ;
			alert(msg);
		}
	} else  {                
		this.debug_add("  new state was empty string or did not begin with <xml> --  Applet state was not reset");
	}
//////////////////////////////////////////////////////////
// Nothing is returned from this subroutine.  There are only side-effects.
//////////////////////////////////////////////////////////
    this.debug_add("Done setting state");
    if (this.debugMode>=2){
       console.log("DebugText:\n"+debugText); debugText="";}
       console.log("Out of setState for applet " + appletName);
	return('');
};
	
ww_applet.prototype.getState = function () {  
	
	var state ="<xml>foobar</xml>";
	var appletName      = this.appletName;
	var applet          = getApplet(appletName);
	var getStateAlias   = this.getStateAlias;
	console.log("Into getState for applet " + appletName);
	this.debug_add("   Begin getState from applet " + appletName );

	try {
		if (this.methodDefined(getStateAlias)) {  // there may be no state function
			state  = applet[getStateAlias]();                     // get state in xml format
			this.debug_add("      state has type " + typeof(state));
			state  = String(state);                          // geogebra returned an object type instead of a string type
			                                                 // this insures that we can view the state as a string
			this.debug_add("      state converted to type " + typeof(state));
		} else {
			this.debug_add("    Applet does not have a getState method named: "+ getStateAlias + ".");
			state ="<xml>undefined_state</xml>";
		}
		
	} catch (e) {
	    var msg = "    Error in getting state from applet " + appletName + " " + e;
	    alert(msg);
	}
	
	if (this.debugMode==0) {
	     //alert("encode1 " +state);
	    if (! base64Q(state) ){    
	        //alert("start the encoding")
		state = Base64.encode(state);	
		}
		//alert("state encoded to" + state);
	};   // replace state by encoded version unless in debug mode

	this.debug_add("  state is \n    "+ state.substring(0,20) + "\n");                // state should still be in plain text
	var ww_preserve_applet_state = getQE(appletName + "_state"); // answer box preserving applet state (jsDebugMode: textarea, otherwise: hidden)
	ww_preserve_applet_state.value = state;                      //place state in input item  (jsDebugMode: textarea, otherwise: hidden)
	this.debug_add("State stored in answer box "+ appletName + "_state and getState is finished.");
    console.log("Out of setState for applet " + appletName);
};	

ww_applet.prototype.setDebug = function(debugMode) {
	// sets debug mode in the flash or java applet
	// applet's method must be called   debug
	
	var appletName = this.appletName;
	var applet     = getApplet(appletName);
	debugMode      = jsDebugMode || debugMode ;
	
    try{ 
		if (this.methodDefined("debug") ) {
			applet.debug(debugMode);  // set the applet's debug functions on.
		} else {
			this.debug_add( "  Unable to set debug state in applet " + appletName + ".");
		
		}
	} catch(e) {
		var msg = "Unable to set debug mode for applet " + appletName;
        alert(msg);
	}


}


	
////////////////////////////////////////////////////////////
//
//INITIALIZE
//
////////////////////////////////////////////////////////////
    	
ww_applet.prototype.initializeAction = function () {
     this.setState();
};
	
ww_applet.prototype.submitAction = function () { 
	var appletName = this.appletName;
    // var getAnswer = this.getAnswerAlias;
    console.log("Into submitAction for " + appletName);
    // Don't do anything if the applet is hidden.
    if(!ww_applet_list[appletName].visible) {return('')};   
    this.debug_add("submitAction" );
    var ww_preserve_applet_state = getQE(appletName + "_state"); // hidden HTML input element preserving applet state
	var saved_state =   ww_preserve_applet_state.value;
	

	
	if (saved_state.match(/^<xml>restart_applet<\/xml>/) )  {
		this.debug_add("Restarting the applet "+appletName);
		setHTMLAppletStateToRestart(appletName);   // replace the saved state with <xml>restart_applet</xml>
		if (this.debugMode>=2){console.log("DebugText:\n"+debugText); debugText="";}
		return('');      
	}
	this.debug_add("not restarting");
    this.debug_add("Begin submit action for applet " + appletName);
    var applet = getApplet(appletName);
	if (! this.isReady  ) {
		alert(appletName + " is not ready. The .isReady flag is false which is strange since we are resubmitting this page. There should have been plenty of time for the applet to load.");
		this.initializeAction();
	}
	// Check to see if we want to restart the applet
	
    this.debug_add("about to get state");
	// if we are not restarting the applet save the state and submit
	
	this.getState();      // have ww_applet retrieve state from applet and store in HTML cache
	
	
	this.debug_add("Submit Action Script " + this.submitActionScript + "\n");
	eval(this.submitActionScript);
	//getQE(this.answerBox).value = applet.[getAnswer]();  //FIXME -- not needed in general?
	

	this.debug_add("Completed submitAction(" + this.submitActionScript + ") \nfor applet " + appletName+ "\n");

	// because the state has not always been perfectly preserved when storing the state in text area boxes
	// we take a "belt && suspenders" approach by converting the value even of the text area state cache
	// to base64 form

	ww_preserve_applet_state = getQE(appletName + "_state"); // hidden HTML input element preserving applet state
	saved_state =   ww_preserve_applet_state.value;
	this.debug_add ("saved state looks like before encoding" +(saved_state.substring(0,200)));
	if (! base64Q(saved_state) ) {
	    // preserve html entities untranslated!  Yeah!!!!!!!
	    // FIXME -- this is not a perfect fix -- things are confused for a while when
	    // you switch from debug to non debug modes
	    //saved_state = saved_state.replace(/&quot;/g, '&amp;&quot;');	    
	    //alert("encode " +saved_state);
		saved_state = Base64.encode(saved_state);		
		//alert("saved state encoded to " +saved_state);
	}
	ww_preserve_applet_state = getQE(appletName + "_state"); // hidden HTML input element preserving applet state
	
	ww_preserve_applet_state.value = saved_state;  // on submit the value of ww_preserve_applet_state.value is always in Base64.
      this.debug_add("just before submitting saved state looks like " + ww_preserve_applet_state.value.substring(0,200));
	

	if (this.debugMode>=2){console.log("DebugText:\n"+debugText); debugText="";}


}
ww_applet.prototype.checkLoaded = function() {  // this function returns 0 unless:
									  // applet has already been flagged as ready in applet_isReady_list
									  // applet.config is defined  (or alias for .config)
									  // applet.setState is defined
									  // applet.isActive is defined and returns 1;
									  // applet reported that it is loaded by calling applet_loaded()
	var ready = 0;
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	
	// alert("2 jsDebugMode " + jsDebugMode + " applet debugMode " + this.debugMode + " local debugMode " + debugMode);
	
	if (this.debugMode==0 && this.isReady) {return(1)}; // memorize readiness in non-debug mode
	
	this.debug_add("*Test 4 methods to see if the applet " + appletName + " has been loaded: \n"); 

	try {
		if ( this.methodDefined(this.setConfigAlias) ) {
			ready = 1;
		}
	} catch(e) {
		var msg = "*Unable to find setConfig command in applet " + appletName+ "\n" +e;
        this.debug_add(msg);
	}
	
	try {
		if ( this.methodDefined(this.setStateAlias) ) {
			ready =1;
		} 
	} catch(e) {
		var msg = "*Unable to setState command in applet " + appletName + "\n" +e;
        this.debug_add(msg);
	}


	if (typeof(this.reportsLoaded) !="undefined" && this.reportsLoaded != 0 ) {
		this.debug_add( "    *" + appletName + " applet self reports that it has completed loading. " );
		ready =1;
	}
	
	// the return value of the isActive() method, when defined, overrides the other indications
	// that the applet is ready
	
	if ( this.methodDefined("isActive") ) {
		if (applet.isActive()) {   //this could be zero if applet is loaded, but it is loading auxiliary data.
			this.debug_add( "*Applet " +appletName + " signals it is active.\n"); 
			ready =1;
		} else {
			this.debug_add( "*Applet " + appletName + " signals it is not active. -- \n it may still be loading data.\n");
			ready = 0;
		}
	} 
    //alert("set applet ready state to " +ready);
	this.isReady = ready;
	return(ready);
}
ww_applet.prototype.debug_add = function(str) {
	if (this.debugMode>=2) {
		debugText = debugText + "\n" +str; // a global text string
	}
}
ww_applet.prototype.safe_applet_initialize = function(i) {    
    //alert("begin safe_applet_initialize");
    var appletName = this.appletName;
    console.log("Into safe_applet_initialize for applet " + appletName + " i= " + i);
    var failed_attempts_allowed = 3;
    
    i--;
    
    /////////////////////////////////////////////////    
    // Check whether the applet is has already loaded
    /////////////////////////////////////////////////
	this.debug_add("*  Try to initialize applet " + appletName +  ". Count down: " + i + ".\n" );
	this.debug_add("entering checkLoaded subroutine");
	var applet_loaded = this.checkLoaded();
	if ( ( applet_loaded != 0 ) && ( applet_loaded != 1 ) ) {
		alert("Error: The applet_loaded variable has not been defined. " + applet_loaded);
	}
	this.debug_add("returning from checkLoaded subroutine with result " + applet_loaded);

    /////////////////////////////////////////////////    
    // If applet has not loaded try again -- or announce that the applet can't be loaded
    /////////////////////////////////////////////////
	
	if ( applet_loaded==0 && (i> 0) ) { // wait until applet is loaded
		this.debug_add("*Applet " + appletName + " is not yet ready try again\n");
		if (this.debugMode>=2) {
			console.log("DebugText:\n"+debugText ); 
			debugText="";
		}
		setTimeout( "ww_applet_list[\""+ appletName + "\"].safe_applet_initialize(" + i +  ")",TIMEOUT);	
		// warn about loading after failed_attempts_allowed failed attempts or if there is only one attempt left
        if (i<=1 || i< (ww_applet_list[appletName].maxInitializationAttempts-failed_attempts_allowed)) { console.log("Oops, applet is not ready. " +(i-1) +" tries left")};
     	console.log("Out of safe_applet_initialize for applet " + appletName);
        return "";
	} else if (applet_loaded==0 && !(i> 0) ) {
		// it's possible that the isActive() response of the applet is not working properly
		console.log("*We haven't been able to verify that the applet " +appletName + " is loaded.  We'll try to use it anyway but it might not work.\n");
		i=1;
		applet_loaded=1; // FIXME -- give a choice as to whether to continue or not
		this.isReady=1;
     	console.log("Out of safe_applet_initialize for applet " + appletName);
		return "";
	} 
	
	
    /////////////////////////////////////////////////    
    // If the applet is loaded try to configure it.
    /////////////////////////////////////////////////
	
	if( applet_loaded) {                // now that applet is loaded configure it and initialize it with saved data.
	    // alert("configuring applet");
	    this.debug_add("  applet is ready = " + applet_loaded  );

		this.debug_add("*Applet "+ appletName + " initialization completed\n   with " + i 
		               +  " possible attempts remaining. \n" +
		               "------------------------------\n");  
		if (this.debugMode>=2) {
			console.log("DebugText:\n"+debugText ); 
			debugText="";
		}
		// in-line handler -- configure and initialize
		 /////////////////////////////////////////////////
		 //alert("setDebug")
		 /////////////////////////////////////////////////
		try{
		
			this.setDebug((this.debugMode) ? 1:0); 
			
		} catch(e2) {
			var msg = "*Unable set debug in " + appletName + " \n " +e2;  
			if (this.debugMode>=2) {this.debug_add(msg);} else {alert(msg)};
		}
		 /////////////////////////////////////////////////
		 //alert("config applet");
		 /////////////////////////////////////////////////
		try{ 
	        //alert("setting configuration");
			this.setConfig();         // for applets that require a configuration (which doesn't change for a given WW question
			//alert("finished setting the configuration");
			
		} catch(e4) {
			var msg = "*Unable to configure " + appletName + " \n " +e4;  
			if (this.debugMode>=2) {this.debug_add(msg);} else {alert(msg)};
		}

		/////////////////////////////////////////////////
		//alert("initializeAction");
		/////////////////////////////////////////////////
		try{
		    
			this.initializeAction();  // this is often the setState action.
			
		} catch(e) {
			var msg = "*unable to perform an explicit initialization action (e.g. setState) on applet  " + appletName + " because \n " +e; 
			if (this.debugMode>=2) {
				this.debug_add(msg);
			} else {
				alert(msg);
			}
		}

	} else {
	    alert("Error: applet "+ appletName + " has not been loaded");
		this.debug_add("*Error: timed out waiting for applet " +appletName + " to load");
		//alert("4 jsDebugMode " + jsDebugMode + " applet debugMode " +ww_applet.debugMode + " local debugMode " +debugMode);
		if (this.debugMode>=2) {
			console.log(" in safe applet initialize: " + debugText ); 
			debugText="";
		}
	}
	console.log("Out of safe_applet_initialize for applet " + appletName);
	return "";
}

function iamhere() {
	alert( "javaScript loaded.  functions still work");
}

//Initialize the WWquestion.

function initWW(){
    if (typeof initWW.hasRun == 'undefined') {
	initWW.hasRun = true;
    } else {
	return;
    }	

    console.log("Into initWW");
	if (typeof(initializeWWquestion) == 'function') {
		initializeWWquestion();
	}
	console.log("Out of initWW");
}
// be careful that initWW is not called from more than one place.
addOnLoadEvent(initWW);
