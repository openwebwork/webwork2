// ################################################################################
// # WeBWorK Online Homework Delivery System
// # Copyright © 2000-2009 The WeBWorK Project, http://openwebwork.sf.net/
// # $CVSHeader: webwork2/htdocs/js/ww_applet_support.js,v 1.7 2009/03/10 12:07:15 gage Exp $
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

//     var  applet_initializeAction_list = new Object;  // functions for initializing question with an applet
//     var  applet_submitAction_list     = new Object;  // functions for submitting question with applet
//     var  applet_setState_list         = new Object;  // functions for setting state (XML) from applets
//     var  applet_getState_list         = new Object;  // functions for getting state (XML) from applets
//     var  applet_config_list           = new Object;  // functions for  configuring on applets
// 	   var  applet_checkLoaded_list      = new Object;  // functions for probing the applet to see if it is loaded
// 	   var  applet_reportsLoaded_list    = new Object;  // flag set by applet
// 	   var  applet_isReady_list          = new Object;  // flag set by javaScript in checkLoaded 

	var  ww_applet_list                  = new Object;  // holds  intelligent ww_applet objects

    
//////////////////////////////////////////////////////////
// DEBUGGING tools
//////////////////////////////////////////////////////////
	var jsDebugMode;
	var debugText = "";
	function set_debug(num) { // setting debug for any applet sets it for all of them
		if (num) {
			jsDebugMode =1;
		}
	}
	function debug_add(str) {
		if (jsDebugMode) {
			debugText = debugText + "\n" +str;
		}
	}
	
//////////////////////////////////////////////////////////
// INITIALIZE and SUBMIT actions
//////////////////////////////////////////////////////////

function submitAction()  {    // called from the submit button defined in Problem.pm
	
	if (jsDebugMode) {
		debugText = "Call submitAction() function on each applet\n";
	}

	for (var appletName in ww_applet_list ) {
			 ww_applet_list[appletName].submitAction();
	}
	debug_add("\n Done calling submitAction() on each applet.\n");
	if (jsDebugMode) {
		alert(debugText); debugText="";
	};
}

function initializeAction() {  // deprecated call -- removed
	alert("You might be using an old template (stored at webwork2/conf/templates). The <body> tag in the system.template calls a function 'initializeAction()' -- this function name should be replaced by 'initializeWWquestion()'. Please update to a recent version of system.template");
	initializeWWquestion();
}

function initializeWWquestion() {    // called from <body> tag defined in the webwork2/conf/template
	var iMax = 5;
	debugText="Initialize each applet. \nUse up to " +iMax + " cycles to wait for each applet to load\n";
	for (var appletName in ww_applet_list)  {		
		safe_applet_initialize(appletName, iMax);
	}

}

// applet can set isReady flag by calling applet_loaded(appletName, loaded);
function applet_loaded(appletName,loaded) {
	debug_add("applet reporting that it has been loaded = " + loaded );
	ww_applet_list[appletName].reportsLoaded = loaded; // 0 means not loaded
}


// insures that applet is loaded before initializing it


function safe_applet_initialize(appletName, i) {
    i--;
	debug_add("  Try to initialize applet " + appletName +  ". Count down: " + i + ".\n" );
	

	var ww_applet = ww_applet_list[appletName];
	var applet_loaded = ww_applet.checkLoaded();
	if (applet_loaded=="still_loading" && !(i> 0) ) {
		// it's possible that the isActive() response of the applet is not working properly
		alert("The isActive() method of applet " +appletName + " claims it is still loading! We'll ignore this.");
		i=1;
		applet_loaded=1;
	} else if (applet_loaded=="still_loading") {
		applet_loaded=0;  // keep trying
	}
		
	
	debug_add("  applet is ready = " + applet_loaded  );

	if ( 0 < i && !applet_loaded ) { // wait until applet is loaded
		debug_add("    applet " + appletName + " is not yet ready try again");
		window.setTimeout( "safe_applet_initialize(\"" + appletName + "\"," + i +  ")",1);
	} else if( 0 < i ){  // now that applet is loaded configure it and initialize it with saved data.
		debug_add(appletName + " initialization completed with " + i +  " possible attempts remaining. \n"); 
		
		// in-line handler -- configure and initialize
		try{
			ww_applet.setDebug(jsDebugMode);
		} catch(e) {
			var msg = "Unable set debug in " + appletName + " \n " +e;  
			if (jsDebugMode) {debug_add(msg);} else {alert(msg)};
		}
		try{ 
		
			ww_applet.config();
			
		} catch(e) {
			var msg = "Unable to configure " + appletName + " \n " +e;  
			if (jsDebugMode) {debug_add(msg);} else {alert(msg)};
		}
		try{
		    
			ww_applet.initializeAction();
			
		} catch(e) {
			var msg = "unable to initialize " + appletName + " \n " +e; 
			if (jsDebugMode) {debug_add(msg);} else {alert(msg)};
		}
		
	} else {
		if (jsDebugMode) {debug_add("Error: timed out waiting for applet " +appletName + " to load");}
	}
	if (jsDebugMode) {alert(debugText); debugText="";};
}

///////////////////////////////////////////////////////
// Utility functions
///////////////////////////////////////////////////////   
    

function getApplet(appletName) {
	  var isIE = navigator.appName.indexOf("Microsoft") != -1;
	  var obj = (isIE) ? window[appletName] : window.document[appletName];
	  //return window.document[appletName];
	  if (obj && (obj.name = appletName)) {
		  return( obj );
	  } else {
		  alert ("can't find applet " + appletName);		  
	  }
 }	

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
	return ( !str.match(/<XML/i) && !str.match(/<?xml/i));
}
function setAppletStateToRestart(appletName){
	var newState = "<xml>restart_applet</xml>";
	//ww_applet_list[appletName].setState(newState);
	getQE(appletName+"_state").value = newState;
	getQE("previous_" + appletName + "_state").value = newState
}

function getQE(name1) { // get Question Element in problemMainForm by name
	var isIE = navigator.appName.indexOf("Microsoft") != -1;
	var obj = (isIE) ? document.getElementById(name1)
						:document.problemMainForm[name1]; 
	// needed for IE -- searches id and name space so it can be unreliable if names are not unique
	if (!obj || obj.name != name1) {
	    var msg = "Can't find element " + name1;
		if (jsDebugMode) {
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
	this.base64_state            = '';
	this.base64_config           = '';
	this.getStateAlias           = '';
	this.setStateAlias           = '';
	this.configAlias             = '';
	this.initializeActionAlias   = '';
	this.submitActionAlias       = '';
	this.submitActionScript      = '';
	this.getAnswerAlias          = '';
	this.answerBox               = '';
	this.debug                   = '';
	this.isReady                 = 0 ;
	this.reportsLoaded           = 0 ;
};


//////////////////////////////////////////////////////////
//CONFIGURATIONS
//
// configurations are "permanent"
//////////////////////////////////////////////////////////
ww_applet.prototype.config = function () {
        
        var appletName  = this.appletName;
		var applet      = getApplet(appletName);
		var setConfigAlias = this.setConfigAlias;
        debug_add("   Calling " + appletName +"."+ setConfigAlias +"( " + Base64.decode(this.base64_config) + " ) " );
    	try {  
    	    if ( this.methodDefined(setConfigAlias) ) {
    			applet[setConfigAlias](Base64.decode(this.base64_config));
    		} 
    	} catch(e) {
    	    var msg = "Error in configuring  " + appletName + " using command " + setConfigAlias + " : " + e ;
			alert(msg);
    	}
 };
////////////////////////////////////////////////////////////
//
//STATE:
// state can vary as the applet is manipulated -- it is reset from the questions _state values
//
////////////////////////////////////////////////////////// 
ww_applet.prototype.methodDefined = function(methodName) {
	var appletName = this.appletName;
	var applet     = getApplet(appletName);
	try {
		if (typeof(applet[methodName]) == "function" ) {
			debug_add("Method " + methodName + " is defined in " + appletName );
			return(true);
		} else {
			debug_add("Method " + methodName + " is not defined in " + appletName); 
			return(false);
		}
	} catch(e) {
		var msg = "Error in accessing " + methodName + " in applet " +appletName + "Error: " +e ;
		alert(msg);
	}
	return(false);
}

ww_applet.prototype.setState = function(state) { 
   
	var appletName      = this.appletName;
	var applet          = getApplet(appletName);
	var setStateAlias   = this.setStateAlias;

	debug_add("\nBegin process of setting state for applet " + appletName);
	
	if (state) {
		debug_add("   Obtain state from calling parameter:\n " + state + "\n");
	} else {
		debug_add("  Obtain state from " + appletName +"_state");
	
		var ww_preserve_applet_state = getQE(appletName + "_state"); // hidden answer box preserving applet state
		state =   ww_preserve_applet_state.value;
	}
	
	if ( base64Q(state) ) { 
		state=Base64.decode(state);
	}
	// if we are restarting the applet bail -- we don't want to set the state.
	
	if (state.match(/^<xml>restart_applet<\/xml>/) )  {
		alert("The applet " +appletName + "has been reset to its virgin state.");
		ww_preserve_applet_state.value ="";  //Fixme? should we set the last answer to blank as well?
		return(''); 
	}
	if (state.match(/<xml/i) || state.match(/<?xml/i) ) {  // if state starts with <?xml
	
		debug_add("  Set (decoded) state for " + appletName + " to \n\n" + 
				 state +"\n\n  Check that applet's setState method " +setStateAlias + " is a function: " +typeof(applet[setStateAlias])
		);
		
		try {
			if ( this.methodDefined(setStateAlias)   ) {
				applet[setStateAlias]( state );    // change the applets current state
			} 
		} catch(e) {
			msg = "Error in setting state of " + appletName + " using command " + setStateAlias + " : " + e ;
			alert(msg);
		}
	} else if (jsDebugMode) {
		debug_add("  new state was empty string or did not begin with <xml> --  Applet state was not reset");
	}
	return('');
};
	
ww_applet.prototype.getState = function () {  
		
	var state ="<xml>foobar</xml>";
	var appletName      = this.appletName;
	var applet          = getApplet(appletName);
	var getStateAlias   = this.getStateAlias;
	
	debug_add("   Begin getState for applet " + appletName );

	try {
		if (this.methodDefined(getStateAlias)) {  // there may be no state function
			state  = applet[getStateAlias]();                     // get state in xml format
			debug_add("      state has type " + typeof(state));
			state  = String(state);                          // geogebra returned an object type instead of a string type
			                                                 // this insures that we can view the state as a string
			debug_add("      state converted to type " + typeof(state));
		} else {
			debug_add("    Applet does not have a getState method named: "+ getStateAlias + ".");
			state ="<xml>undefined_state</xml>";
		}
		
	} catch (e) {
	    var msg = "    Error in getting state from applet " + appletName + " " + e;
	    alert(msg);
	}
	
	if (!jsDebugMode) {
		state = Base64.encode(state);	
	};   // replace state by encoded version unless in debug mode

	debug_add("  state is \n    "+ state + "\n");                // state should still be in plain text
	var ww_preserve_applet_state = getQE(appletName + "_state"); // answer box preserving applet state (jsDebugMode: textarea, otherwise: hidden)
	ww_preserve_applet_state.value = state;                      //place state in input item  (jsDebugMode: textarea, otherwise: hidden)
	debug_add("State stored in answer box "+ appletName + "_state and getState is finished.");

};	

ww_applet.prototype.setDebug = function(debugMode) {
	
	var appletName = this.appletName;
	var applet     = getApplet(appletName);
	debugMode = debugMode || this.debug;
	
    try{ 
		if (this.methodDefined("debug") ) {
			applet.debug(1);  // turn the applet's debug functions on.
		} else {
			debug_add( "  Unable to set debug state in applet " + appletName + ".");
		
		}
	} catch(e) {
		var msg = "Unable to set debug mode for applet " + appletName;
        alert(msg);
	}


}
ww_applet.prototype.getConfig = function() {                    // used for debugging purposes -- gets the configuration from the applet
	var config = "foobar";
	var appletName     = this.appletName;
	var applet         = getApplet(appletName);	
	var getConfigAlias = this.getConfigAlias;
	try {
		if (this.methodDefined(getConfigAlias) ) {
  			alert( applet[getConfigAlias]() );
 		} else {
  			alert(debugText);
  		}
    } catch(e) {
    	var msg = "    Error in getting configuration from applet " + appletName + " " + e;
    	alert(msg);
    }  
}
	

	
////////////////////////////////////////////////////////////
//
//INITIALIZE
//
////////////////////////////////////////////////////////////
    	
ww_applet.prototype.initializeAction = function () {
     var state = '';
     this.setState();
};
	
ww_applet.prototype.submitAction = function () {  
	var appletName = this.appletName;
    // var getAnswer = this.getAnswerAlias;
    var ww_preserve_applet_state = getQE(appletName + "_state"); // hidden answer box preserving applet state
	var saved_state =   ww_preserve_applet_state.value;

    if (jsDebugMode) {debug_add("Begin submit action for applet " + appletName);}
    var applet = getApplet(appletName);
	if (! this.isReady  ) {
		alert(appletName + " is not ready");
		initializeAction();
	}
	// Check to see if we want to restart the applet
	
	if (saved_state.match(/^<xml>restart_applet<\/xml>/) )  {
		if (jsDebugMode) { debug_add("Restarting the applet "+appletName);}
		setAppletStateToRestart(appletName);   // erases all of the saved state
		return('');      
	}
	// if we are not restarting the applet save the state and submit
	
	this.getState();      // have ww_applet retrieve state from applet and store in answerbox
	if (jsDebugMode) {debug_add("Submit Action Script " + this.submitActionScript + "\n");}
	eval(this.submitActionScript);
	//getQE(this.answerBox).value = applet.[getAnswer]();  //FIXME -- not needed in general?
	if (jsDebugMode) {debug_add("Completed submitAction() for applet " + appletName+ "\n");}
};


ww_applet.prototype.checkLoaded = function() {  // this function returns 0 unless:
									  // applet has already been flagged as ready in applet_isReady_list
									  // applet.config is defined  (or alias for .config)
									  // applet.setState is defined
									  // applet.isActive is defined and returns 1;
									  // applet reported that it is loaded by calling applet_loaded()
	var ready = 0;
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	if (!jsDebugMode && this.isReady) {return(1)}; // memorize readiness in non-debug mode
	debug_add("Test 4 methods to see if the applet " + appletName + " has been loaded: \n");
	if ( this.methodDefined(this.setConfigAlias) ) {
		ready = 1;
	}
	if ( this.methodDefined(this.setStateAlias) ) {
		ready =1;
	} 

	if ( this.methodDefined("isActive") ) {
		if (applet.isActive()) {   //this could be zero if applet is loaded, but it is loading auxiliary data.
			debug_add( "Applet " +appletName + " signals it is active.");
			ready =1;
		} else {
			debug_add( "Applet " + appletName + " signals it is not active. -- \n it may still be loading data.");
			ready = "still_loading";
		}
	} 
	if (typeof(this.reportsLoaded) !="undefined" && this.reportsLoaded != 0 ) {
		debug_add( "    " + appletName + " applet self reports that it has completed loading. " );
		ready =1;
	}
	this.isReady = ready;
	return(ready);
}


function iamhere() {
	alert( "javaScript loaded.  functions still work");
}