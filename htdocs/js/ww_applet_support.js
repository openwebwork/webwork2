// ################################################################################
// # WeBWorK Online Homework Delivery System
// # Copyright © 2000-2009 The WeBWorK Project, http://openwebwork.sf.net/
// # $CVSHeader: webwork2/htdocs/js/ww_applet_support.js,v 1.8 2009/03/10 20:49:56 gage Exp $
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

	if (jsDebugMode==1) {
		debugText = "Call submitAction() function on each applet\n";
	}

	for (var appletName in ww_applet_list ) {
			 ww_applet_list[appletName].submitAction();
	}
	if (jsDebugMode==1) { debug_add("\n Done calling submitAction() on each applet.\n");}
	if (jsDebugMode==1) {
		alert(debugText); debugText="";
	};
}

function initializeAction() {  // deprecated call -- removed
	alert("You might be using an old template (stored at webwork2/conf/templates). The <body> tag in the system.template calls a function 'initializeAction()' -- this function name should be replaced by 'initializeWWquestion()'. Please update to a recent version of system.template");
	initializeWWquestion();
}

function initializeWWquestion() {    // called from <body> tag defined in the webwork2/conf/template
	for (var appletName in ww_applet_list)  {	
	    var maxInitializationAttempts = ww_applet_list[appletName].maxInitializationAttempts;
	    // alert("Initialize each applet. \nUse up to " +maxInitializationAttempts + " cycles to load" +"\n");
		ww_applet_list[appletName].safe_applet_initialize(maxInitializationAttempts);
	}

}

// applet can set isReady flag by calling applet_loaded(appletName, loaded);
function applet_loaded(appletName,loaded) {
	debug_add("applet reporting that it has been loaded = " + loaded );
	ww_applet_list[appletName].reportsLoaded = loaded; // 0 means not loaded
}


// insures that applet is loaded before initializing it



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
	try {
		if (typeof(applet[methodName]) == "function" ) {
			this.debug_add("Method " + methodName + " is defined in " + appletName );
			return(true);
		} else {
			this.debug_add("Method " + methodName + " is not defined in " + appletName); 
			return(false);
		}
	} catch(e) {
		var msg = "Error in accessing " + methodName + " in applet " +appletName + "Error: " +e ;
		alert(msg);
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
    	    if ( this.methodDefined(setConfigAlias) ) {
    			applet[setConfigAlias](this.configuration);
    		} 
    	
    	} catch(e) {
    	
    	    var msg = "Error in configuring  " + appletName + " using command " + setConfigAlias + " : " + e ;
			alert(msg);
    	}
    	this.debug_add("   Calling " + appletName +"."+ setConfigAlias +"( " + this.configuration + " ) " );
  
 };
 
 ww_applet.prototype.getConfig = function() {                    // used for debugging purposes -- gets the configuration from the applet
 

	var appletName     = this.appletName;
	var applet         = getApplet(appletName);	
	var getConfigAlias = this.getConfigAlias;
	

	try {
		if (this.methodDefined(getConfigAlias) ) {
  			alert( applet[getConfigAlias]() );
 		} else {
  			alert("in getConfig " + debugText);
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

	debug_add("\n++++++++++++++++++++++++++++++++++++++++\nBegin process of setting state for applet " + appletName);
	
	if (state) {
		debug_add("Obtain state from calling parameter:\n " + state + "\n");
	} else {
		this.debug_add("Obtain state from " + appletName +"_state");
	
		var ww_preserve_applet_state = getQE(appletName + "_state"); // hidden answer box preserving applet state
		state =   ww_preserve_applet_state.value;
	}
	
	if ( base64Q(state) ) { 
		state=Base64.decode(state);
	}
	
	if (state.match(/^<xml>restart_applet<\/xml>/) )  {
		alert("The applet " +appletName + "has been reset to its virgin state." + this.initialState);
		ww_preserve_applet_state.value =this.initialState;  //Fixme? should we set the last answer to blank as well?
		state = ww_preserve_applet_state.value;
	}
	if (state.match(/<xml/i) || state.match(/<?xml/i) ) {  // if state starts with <?xml
	
		this.debug_add("Set state for " + appletName + " to \n------------------------------\n" 
		               +  state + "\n------------------------------\n");
		
		try {
		    
			if ( this.methodDefined(setStateAlias)   ) {
				applet[setStateAlias]( state );    // change the applets current state
			} 
		} catch(e) {
			msg = "Error in setting state of " + appletName + " using command " + setStateAlias + " : " + e ;
			alert(msg);
		}
	} else if (jsDebugMode==1) {
		this.debug_add("  new state was empty string or did not begin with <xml> --  Applet state was not reset");
	}
	return('');
};
	
ww_applet.prototype.getState = function () {  
		
	var state ="<xml>foobar</xml>";
	var appletName      = this.appletName;
	var applet          = getApplet(appletName);
	var getStateAlias   = this.getStateAlias;
	
	this.debug_add("   Begin getState for applet " + appletName );

	try {
		if (this.methodDefined(getStateAlias)) {  // there may be no state function
			state  = applet[getStateAlias]();                     // get state in xml format
			debug_add("      state has type " + typeof(state));
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
		state = Base64.encode(state);	
	};   // replace state by encoded version unless in debug mode

	this.debug_add("  state is \n    "+ state + "\n");                // state should still be in plain text
	var ww_preserve_applet_state = getQE(appletName + "_state"); // answer box preserving applet state (jsDebugMode: textarea, otherwise: hidden)
	ww_preserve_applet_state.value = state;                      //place state in input item  (jsDebugMode: textarea, otherwise: hidden)
	this.debug_add("State stored in answer box "+ appletName + "_state and getState is finished.");

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
     var state = '';
     this.setState();
};
	
ww_applet.prototype.submitAction = function () { 
	var appletName = this.appletName;
    // var getAnswer = this.getAnswerAlias;
    var ww_preserve_applet_state = getQE(appletName + "_state"); // hidden HTML input element preserving applet state
	var saved_state =   ww_preserve_applet_state.value;

    this.debug_add("Begin submit action for applet " + appletName);
    var applet = getApplet(appletName);
	if (! this.isReady  ) {
		alert(appletName + " is not ready");
		this.initializeAction();
	}
	// Check to see if we want to restart the applet
	
	if (saved_state.match(/^<xml>restart_applet<\/xml>/) )  {
		this.debug_add("Restarting the applet "+appletName);
		setAppletStateToRestart(appletName);   // erases all of the saved state
		return('');      
	}
	// if we are not restarting the applet save the state and submit
	
	this.getState();      // have ww_applet retrieve state from applet and store in answerbox
	this.debug_add("Submit Action Script " + this.submitActionScript + "\n");
	eval(this.submitActionScript);
	//getQE(this.answerBox).value = applet.[getAnswer]();  //FIXME -- not needed in general?
	this.debug_add("Completed submitAction(" + this.submitActionScript + ") \nfor applet " + appletName+ "\n");
	if (this.debugMode){alert(debugText); debugText="";}
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
	
	// alert("2 jsDebugMode " + jsDebugMode + " applet debugMode " + this.debugMode + " local debugMode " + debugMode);
	
	if (this.debugMode==0 && this.isReady) {return(1)}; // memorize readiness in non-debug mode
	
	this.debug_add("Test 4 methods to see if the applet " + appletName + " has been loaded: \n"); 

	
	if ( this.methodDefined(this.setConfigAlias) ) {
		ready = 1;
	}
	if ( this.methodDefined(this.setStateAlias) ) {
		ready =1;
	} 


	if (typeof(this.reportsLoaded) !="undefined" && this.reportsLoaded != 0 ) {
		this.debug_add( "    " + appletName + " applet self reports that it has completed loading. " );
		ready =1;
	}
	
	// the return value of the isActive() method, when defined, overrides the other indications
	// that the applet is ready
	
	if ( this.methodDefined("isActive") ) {
		if (applet.isActive()) {   //this could be zero if applet is loaded, but it is loading auxiliary data.
			this.debug_add( "Applet " +appletName + " signals it is active."); 
			ready =1;
		} else {
			this.debug_add( "Applet " + appletName + " signals it is not active. -- \n it may still be loading data.");
			ready = "still_loading";
		}
	} 

	this.isReady = ready;
	return(ready);
}
ww_applet.prototype.debug_add = function(str) {
	if (this.debugMode) {
		debugText = debugText + "\n" +str; // a global text string
	}
}
ww_applet.prototype.safe_applet_initialize = function(i) {    
    //alert("begin safe_applet_initialize");
    var appletName = this.appletName;
    i--;
	this.debug_add("  Try to initialize applet " + appletName +  ". Count down: " + i + ".\n" );

	//alert("1 jsDebugMode " + jsDebugMode + " applet debugMode " +this.debugMode);
		
	var applet_loaded = this.checkLoaded();
	
	if (applet_loaded=="still_loading" && !(i> 0) ) {
		// it's possible that the isActive() response of the applet is not working properly
		alert("The isActive() method of applet " +appletName + " claims it is still loading! We'll ignore this.");
		i=1;
		applet_loaded=1;
	} else if (applet_loaded=="still_loading") {
		applet_loaded=0;  // keep trying
	}
	

	if ( 0 < i && !applet_loaded ) { // wait until applet is loaded
		this.debug_add("Applet " + appletName + " is not yet ready try again\n");
		if (this.debugMode) {
			alert(debugText ); 
			debugText="";
		}
		window.setTimeout( "ww_applet_list[\""+ appletName + "\"].safe_applet_initialize(" + i +  ")",100);	
	} else if( 0 < i ) {                // now that applet is loaded configure it and initialize it with saved data.
	    
	    this.debug_add("  applet is ready = " + applet_loaded  );

		this.debug_add("Applet "+ appletName + " initialization completed\n   with " + i 
		               +  " possible attempts remaining. \n" +
		               "------------------------------\n");  
		
		// in-line handler -- configure and initialize
		//alert("setDebug")
		try{
		
			this.setDebug(this.debugMode); 
			
		} catch(e) {
			var msg = "Unable set debug in " + appletName + " \n " +e;  
			if (this.debugMode) {this.debug_add(msg);} else {alert(msg)};
		}

		//alert("config applet");
		try{ 
	
			this.setConfig();         // for applets that require a configuration (which doesn't change for a given WW question
			
		} catch(e) {
			var msg = "Unable to configure " + appletName + " \n " +e;  
			if (this.debugMode) {this.debug_add(msg);} else {alert(msg)};
		}

		
		//alert("initializeAction");
		try{
		    
			this.initializeAction();  // this is often the setState action.
			
		} catch(e) {
			var msg = "unable to initialize " + appletName + " \n " +e; 
			if (this.debugMode) {
				this.debug_add(msg);
			} else {
				alert(msg);
			}
		}
		if (this.debugMode) {
			alert("\nBegin debugmode\n " + debugText ); 
			debugText="";
		};
	} else {
		this.debug_add("Error: timed out waiting for applet " +appletName + " to load");
		//alert("4 jsDebugMode " + jsDebugMode + " applet debugMode " +ww_applet.debugMode + " local debugMode " +debugMode);
		if (this.debugMode) {
			alert(" in safe applet " + debugText ); 
			debugText="";
		}
	}
	
}

function iamhere() {
	alert( "javaScript loaded.  functions still work");
}