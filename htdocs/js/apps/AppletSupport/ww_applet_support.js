// ################################################################################
// # WeBWorK Online Homework Delivery System
// # Copyright &copy; 2000-2009 The WeBWorK Project, http://openwebwork.sf.net/
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

// Applet lists

// List of web applets on the page.
var ww_applet_list = {};

// Time delay between successive checks for applet readiness.
var TIMEOUT = 800;

// DEBUGGING tools
var jsDebugMode = 0; // Set this to 1 when needed for major debugging (puts all applets in debugMode).
var debugText = "";
function debug_add(str) {
	debugText += "\n" + str;
}

// Utility functions

// Applet can set isReady flag by calling applet_loaded(appletName, loaded);
// If loaded is 0, it means the applet is not loaded.
function applet_loaded(appletName, ready) {
	debug_add("Applet reporting that it has been loaded.  Ready status: " + ready );
	ww_applet_list[appletName].reportsLoaded = ready;
	ww_applet_list[appletName].isReady = ready;
}

function getApplet(appletName) {
	var obj;
	if (ww_applet_list[appletName].type == 'geogebraweb') {
		// Geogebra web applet
		obj = document[appletName];
	} else if (ww_applet_list[appletName].type == 'html5canvas') {
		// html5 canvas applet
		obj = appletName; // Define fake applet for this object
	} else {
		// Flash or Java applet
		obj = window.document[appletName];
		if (!obj) { obj = document.getElementById(appletName); }
	}
	return obj;
}

function listQuestionElements() { // list all HTML input and textarea elements in main problem form
	var elementList = document.problemMainForm.getElementsByTagName("input");
	var str = elementList.length + " Question Elements\n type | name = value < id >\n";
	for(var i = 0; i < elementList.length; ++i) {
		str += " " + i + " " + elementList[i].type
			+ " | " + elementList[i].name
			+ " = " + elementList[i].value +
			" <" + elementList[i].id + ">\n";
	}
	elementList = document.problemMainForm.getElementsByTagName("textarea");
	for (var i = 0; i < elementList.length; ++i) {
		str = str + " " + i + " " + elementList[i].type
			+ " | " + elementList[i].name
			+ " = " + elementList[i].value +
			" <" + elementList[i].id + ">\n";
	}
	alert(str);
}

// Determine whether an XML string has been base64 encoded.
function base64Q(str) {
	if (!str) {
		// The empty string is not a base64 string.
		return 0;
	} else if (str.match(/[<>]+/)) {
		// base64 can't contain < or > and xml strings contain lots of them
		return 0;
	} else {
		// Its probably a non-empty base64 string.
		return 1;
	}
}

// Set the state stored on the HTML page
function setHTMLAppletState(appletName, newState) {
	if (typeof(newState) === 'undefined') newState = "<xml>restart_applet</xml>";
	var stateInput = ww_applet_list[appletName].stateInput;
	getQE(stateInput).value = newState;
	getQE("previous_" + stateInput).value = newState;
}

// Get Question Element in problemMainForm by name
function getQE(name1) {
	var obj = document.getElementById(name1);
	if (!obj) {obj = document.problemMainForm[name1]}

	if (!obj || obj.name != name1) {
		var msg = "Can't find element " + name1;
		if (jsDebugMode == 1) {
			debug_add(msg + "\n ( Place listQuestionElements() at end of document in order to get all form elements! )\n" );
		} else {
			alert(msg); listQuestionElements();
		};
	} else {
		return obj;
	}
}

function getQuestionElement(name1) {
	return getQE(name1);
}

// WW_Applet class definition

function ww_applet(appletName) {
	this.appletName                = appletName;
	this.type                      = '';
	this.code                      = '';
	this.codebase                  = '';
	this.base64State               = '';
	this.initialState              = '';
	this.configuration             = '';
	this.getStateAlias             = '';
	this.setStateAlias             = '';
	this.setConfigAlias            = '';
	this.getConfigAlias            = '';
	this.initializeActionAlias     = '';
	this.submitActionAlias         = '';
	this.submitActionScript        = '';
	this.answerBoxAlias            = '';
	this.maxInitializationAttempts = 5;
	this.debugMode                 = 0;
	this.isReady                   = 0;
	this.reportsLoaded             = 0;
	this.onInit                    = 0;
};

// Make sure that the applet has this function available
ww_applet.prototype.methodDefined = function(methodName) {
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	if (!methodName) {
		// methodName is not defined
		return false;
	}
	try {
		if (typeof(applet[methodName]) == "function") {
			this.debug_add("Method " + methodName + " is defined in " + appletName );
			return true;
		} else {
			this.debug_add("Method " + methodName + " is not defined in " + appletName);
			throw("undefined applet method");
		}
	} catch(e) {
		this.debug_add("Error in accessing " + methodName + " in applet " + appletName + "\n  *Error: " + e);
	}
	return false;
};

// CONFIGURATIONS
// Configurations are "permanent"
ww_applet.prototype.setConfig = function () {
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	var setConfigAlias = this.setConfigAlias;

	try {
		if (this.methodDefined(this.setConfigAlias)) {
			applet[setConfigAlias](this.configuration);
			this.debug_add("  Configuring applet: Calling " + appletName + "." +
				setConfigAlias + "( " + this.configuration + " )");
		} else {
			this.debug_add("  Configuring applet: Unable to execute command |" +
				setConfigAlias + "| in the applet " + appletName + " with data ( \"" + this.configuration + "\" ) " );
		}
	} catch(e) {
		alert("Error in configuring applet " + appletName + " using command " + setConfigAlias + " : " + e);
	}
};

// Gets the configuration from the applet.  Used for debugging purposes.
ww_applet.prototype.getConfig = function() {
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	var getConfigAlias = this.getConfigAlias;

	try {
		if (this.methodDefined(getConfigAlias)) {
			alert(applet[getConfigAlias]());
		} else {
			this.debug_add("  Unable to execute " + appletName + "." + getConfigAlias + "( " + this.configuration + " )");
		}
	} catch(e) {
		alert("    Error in getting configuration from applet " + appletName + " " + e);
	}
};

// STATE:
// State can vary as the applet is manipulated.  It is reset from the questions _state values.
ww_applet.prototype.setState = function(state) {
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	var setStateAlias = this.setStateAlias;
	console.log("Into setState for applet " + appletName);
	this.debug_add("\n++++++++++++++++++++++++++++++++++++++++\nBegin process of setting state for applet " + appletName);


	// Obtain the state which will be sent to the applet and if it is encoded place it in plain xml text.
	// Communication with the applet is in plain text, not in base64 code.

	if (state) {
		this.debug_add("Obtain state from calling parameter:\n " + state.substring(0, 200) + "\n");
	} else {
		this.debug_add("Obtain state from " + this.stateInput);

		// Hidden answer box preserving applet state
		var ww_preserve_applet_state = getQE(this.stateInput);
		state = ww_preserve_applet_state.value;
		this.debug_add("Immediately on grabbing state from HTML cache state is " + (state.substring(0, 200) ) + "...");
	}

	if (base64Q(state)) {
		state = Base64.decode(state);
		this.debug_add("Decodes to:  " + state.substring(0, 200));
		if (this.debugMode >= 1) {
			// Decode text for the text area box
			ww_preserve_applet_state.value = state;

		}
		this.debug_add("Decoded to " + ww_preserve_applet_state.value);
	}

	// Handle the exceptional cases:
	// If the state is blank, undefined, or explicitly defined as restart_applet,
	// then we will not simply be restoring the state of the applet from HTML "memory".
	//
	// 1. For a restart we wipe the HTML state cache so that we won't restart again.
	// 2. In the other "empty" cases we attempt to replace the state with the contents of the
	//    initialState variable.

	// Exceptional cases
	if (state.match(/^<xml>restart_applet<\/xml>/) ||
		state.match(/^\s*$/) ||
		state.match(/^<xml>\s*<\/xml>/)) {
		this.debug_add("Beginning handling exceptional cases when the state is not simply restored " +
			"from the HTML cache. State is: " + state.substring(0, 100));

		if (typeof(this.initialState) == "undefined") { this.initialState = "<xml></xml>"; }
		debug_add("Restart_applet has been called. the value of the initialState is " + this.initialState);
		if (this.initialState.match(/^<xml>\s*<\/xml>/) || this.initialState.match(/^\s*$/)) {
			// If the initial state is empty
			debug_add("The applet " + appletName +
				" has been restarted. There was no non-empty initialState value. \n" +
				"Nothing is sent to the applet.\n  Done setting state");
			if (state.match(/^<xml>restart_applet<\/xml>/)) {
				alert("The applet is being restarted with empty initialState");
			}
			// So that the submit action will not be overridden by restart_applet.
			setHTMLAppletState(appletName, "<xml></xml>");

			// Don't call the setStateAlias function.
			// Quit because we know we will not transmitting any starting data to the applet
			console.log("Out of setState for applet " + appletName);
			return;
		} else {
			state = this.initialState;
			if (base64Q(state)) state = Base64.decode(state);

			debug_add("The applet " + appletName + "has been set to its virgin state value." + state.substring(0, 200));
			if (state.match(/^<xml>restart_applet<\/xml>/)) {
				alert("The applet is being reset to its initialState.");
			}
			// Store the state in the HTML variables just for safetey
			setHTMLAppletState(appletName, this.initialState);

			// If there was a viable state in the initialState variable we can
			// now continue as if we had found a valid state in the HTML cache.
		}
		this.debug_add("Completed handling the exceptional cases.");
	}

	if (state.match(/\<xml/i) || state.match(/\<\?xml/i)) {
		// State MUST be an xml string in plain text
		this.debug_add("Grab data from the HTML cache and set state for " + appletName +
			" to the data between the lines:"
			+ "\n------------------------------\n"
			+ state.substring(0, 200) + "\n------------------------------\n");
		try {
			if (this.methodDefined(setStateAlias)) {
				var result = applet[setStateAlias](state);
				this.debug_add("State of applet " + appletName + "set from HTML cache");
			}
		} catch(err) {
			// Catching false positives?
			alert("Error in setting state of " + appletName + " using command " +
				setStateAlias + " : " + err + err.number + err.description);
		}
	} else {
		this.debug_add("  New state was empty string or did not begin with <xml> -- Applet state was not reset");
	}

	this.debug_add("Done setting state");
	if (this.debugMode >= 2) { console.log("DebugText:\n" + debugText); debugText = ""; }
	console.log("Out of setState for applet " + appletName);
};

ww_applet.prototype.getState = function () {
	var state = "<xml>foobar</xml>";
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	var getStateAlias = this.getStateAlias;
	console.log("Into getState for applet " + appletName);
	this.debug_add("   Begin getState from applet " + appletName );

	try {
		if (this.methodDefined(getStateAlias)) {
			// There may be no state function
			state = applet[getStateAlias](); // Get state in xml format
			this.debug_add("    state has type " + typeof(state));
			// Geogebra returns an object type instead of a string type
			state = String(state);
			// This insures that we can view the state as a string
			this.debug_add("    state converted to type " + typeof(state));
		} else {
			this.debug_add("    Applet does not have a getState method named: " + getStateAlias + ".");
			state ="<xml>undefined_state</xml>";
		}

	} catch (e) {
		alert("Error in getting state from applet " + appletName + " " + e);
	}

	// Replace state by encoded version unless in debug mode
	if (this.debugMode == 0) {
		if (!base64Q(state)) state = Base64.encode(state);
	};

	this.debug_add("  state is\n    " + state.substring(0, 20) + "\n"); // state should still be in plain text

	// Answer box preserving applet state (jsDebugMode: textarea, otherwise: hidden)
	var ww_preserve_applet_state = getQE(this.stateInput);
	// Place state in input item (jsDebugMode: textarea, otherwise: hidden)
	ww_preserve_applet_state.value = state;
	this.debug_add("State stored in answer box " + this.stateInput + " and getState is finished.");
	console.log("Out of getState for applet " + appletName);
};

// Sets debug mode in the applet
// Applet's method must be called debug
ww_applet.prototype.setDebug = function(debugMode) {
	var appletName = this.appletName;
	var applet = getApplet(appletName);
	debugMode = jsDebugMode || debugMode ;

	try{
		if (this.methodDefined("debug")) {
			// Set the applet's debug functions on.
			applet.debug(debugMode);
		} else {
			this.debug_add("  Unable to set debug state in applet " + appletName + ".");
		}
	} catch(e) {
		alert("Unable to set debug mode for applet " + appletName);
	}
};

// INITIALIZE
ww_applet.prototype.initializeAction = function () {
	this.setState();
};

ww_applet.prototype.submitAction = function () {
	var appletName = this.appletName;
	console.log("Into submitAction for " + appletName);
	// Don't do anything if the applet is hidden.
	if (!ww_applet_list[appletName].visible) return;
	this.debug_add("submitAction");

	// Hidden HTML input element preserving applet state
	var ww_preserve_applet_state = getQE(this.stateInput);
	var saved_state = ww_preserve_applet_state.value;

	// Check to see if we want to restart the applet
	if (saved_state.match(/^<xml>restart_applet<\/xml>/)) {
		this.debug_add("Restarting the applet " + appletName);
		// Replace the saved state with <xml>restart_applet</xml>
		setHTMLAppletState(appletName);
		if (this.debugMode >= 2) { console.log("DebugText:\n" + debugText); debugText = ""; }
		return;
	}
	// If we are not restarting the applet save the state and submit
	this.debug_add("Not restarting.");
	this.debug_add("Begin submit action for applet " + appletName);
	var applet = getApplet(appletName);
	if (!this.isReady) {
		alert(appletName + " is not ready. " +
			"The isReady flag is false which is strange since we are resubmitting this page. " +
			"There should have been plenty of time for the applet to load.");
		this.initializeAction();
	}

	this.debug_add("About to get state");

	// Have ww_applet retrieve state from applet and store in HTML cache
	this.getState();

	this.debug_add("Submit Action Script " + this.submitActionScript + "\n");
	eval(this.submitActionScript);

	this.debug_add("Completed submitAction(" + this.submitActionScript + ") \nfor applet " + appletName + "\n");

	// Because the state has not always been perfectly preserved when storing the state in text
	// area boxes we take a "belt && suspenders" approach by converting the value of the text
	// area state cache to base64 form.

	saved_state = ww_preserve_applet_state.value;
	this.debug_add("Saved state looks like before encoding " + saved_state.substring(0, 200));
	if (!base64Q(saved_state)) {
		// Preserve html entities untranslated!  Yeah!!!!!!!
		// FIXME -- this is not a perfect fix -- things are confused for a while when
		// you switch from debug to non debug modes
		saved_state = Base64.encode(saved_state);
	}

	// On submit the value of ww_preserve_applet_state.value is always in Base64.
	ww_preserve_applet_state.value = saved_state;
	this.debug_add("just before submitting saved state looks like " + ww_preserve_applet_state.value.substring(0, 200));

	if (this.debugMode >= 2) { console.log("DebugText:\n" + debugText); debugText = ""; }
};

// This function returns 0 unless:
// applet has already been flagged as ready
// applet.config is defined (or alias for .config)
// applet.setState is defined
// applet.isActive is defined and returns 1;
// applet reported that it is loaded by calling applet_loaded()
ww_applet.prototype.checkLoaded = function() {
	var ready = 0;
	var appletName = this.appletName;
	var applet = getApplet(appletName);

	// Memorize readiness in non-debug mode
	if (this.debugMode == 0 && this.isReady) return 1;

	this.debug_add("*Test 4 methods to see if the applet " + appletName + " has been loaded:\n");

	try {
		if (this.methodDefined(this.setConfigAlias)) ready = 1;
	} catch(e) {
		this.debug_add("*Unable to find setConfig command in applet " + appletName + "\n" + e);
	}

	try {
		if (this.methodDefined(this.setStateAlias)) ready = 1;
	} catch(e) {
		this.debug_add("*Unable to setState command in applet " + appletName + "\n" + e);
	}

	if (typeof(this.reportsLoaded) != "undefined" && this.reportsLoaded != 0) {
		this.debug_add("    *" + appletName + " applet self reports that it has completed loading. ");
		ready = 1;
	}

	// The return value of the isActive() method, when defined, overrides the other indications
	// that the applet is ready.
	if (this.methodDefined("isActive")) {
		if (applet.isActive()) {
			// This could be zero if applet is loaded, but it is loading auxiliary data.
			this.debug_add("*Applet " + appletName + " signals it is active.\n");
			ready = 1;
		} else {
			this.debug_add("*Applet " + appletName + " signals it is not active. -- \n it may still be loading data.\n");
			ready = 0;
		}
	}
	this.isReady = ready;
	return(ready);
};

ww_applet.prototype.debug_add = function(str) {
	if (this.debugMode >= 2) {
		debugText += "\n" +str;
	}
};

ww_applet.prototype.safe_applet_initialize = function(i) {
	var appletName = this.appletName;
	console.log("Into safe_applet_initialize for applet " + appletName + " i = " + i);
	var failed_attempts_allowed = 3;

	--i;

	// Check whether the applet is has already loaded
	this.debug_add("*  Try to initialize applet " + appletName + ". Count down: " + i + ".\n" );
	this.debug_add("Entering checkLoaded subroutine");
	var applet_loaded = this.checkLoaded();
	if ((applet_loaded != 0) && (applet_loaded != 1)) {
		alert("Error: The applet_loaded variable has not been defined. " + applet_loaded);
	}
	this.debug_add("Returning from checkLoaded subroutine with result " + applet_loaded);

	// If applet has not loaded try again, or announce that the applet can't be loaded

	if (applet_loaded == 0 && i > 0) {
		// Wait until applet is loaded
		this.debug_add("*Applet " + appletName + " is not yet ready try again\n");
		if (this.debugMode >= 2) { console.log("DebugText:\n" + debugText ); debugText = ""; }
		setTimeout(function() { ww_applet_list[appletName].safe_applet_initialize(i); }, TIMEOUT);
		// Warn about loading after failed_attempts_allowed failed attempts or if there is only one attempt left.
		if (i <= 1 || i < ww_applet_list[appletName].maxInitializationAttempts-failed_attempts_allowed) {
			console.log("Oops, applet is not ready. " + (i-1) + " tries left")
		};
		console.log("Out of safe_applet_initialize for applet " + appletName);
		return;
	} else if (applet_loaded == 0 && i <= 0) {
		// Its possible that the isActive() response of the applet is not working properly.
		console.log("*We haven't been able to verify that the applet " + appletName +
			" is loaded.  We'll try to use it anyway but it might not work.\n");
		i = 1;
		applet_loaded = 1; // FIXME -- give a choice as to whether to continue or not
		this.isReady = 1;
		console.log("Out of safe_applet_initialize for applet " + appletName);
		return;
	}

	// If the applet is loaded try to configure it.
	if (applet_loaded) {
		this.debug_add("  applet is ready = " + applet_loaded);

		this.debug_add("*Applet " + appletName + " initialization completed\n   with " + i
			+ " possible attempts remaining. \n" +
			"------------------------------\n");
		if (this.debugMode >= 2) { console.log("DebugText:\n" + debugText ); debugText = ""; }
		// In-line handler -- configure and initialize
		try {
			this.setDebug(this.debugMode ? 1 : 0);
		} catch(e2) {
			var msg = "*Unable set debug in " + appletName + " \n " + e2;
			if (this.debugMode >= 2) { this.debug_add(msg); } else { alert(msg) };
		}
		try{
			// For applets that define their own configuration
			this.setConfig();
		} catch(e4) {
			var msg = "*Unable to configure " + appletName + " \n " +e4;
			if (this.debugMode >= 2) { this.debug_add(msg); } else { alert(msg) };
		}

		try{
			// This is often the setState action.
			this.initializeAction();
		} catch(e) {
			var msg = "*Unable to perform an explicit initialization action (e.g. setState) on applet " +
				appletName + " because \n " + e;
			if (this.debugMode >= 2) { this.debug_add(msg); } else { alert(msg); }
		}
	} else {
		alert("Error: applet " + appletName + " has not been loaded");
		this.debug_add("*Error: timed out waiting for applet " + appletName + " to load");
		if (this.debugMode >= 2) { console.log(" in safe applet initialize: " + debugText ); debugText = "";
		}
	}
	console.log("Out of safe_applet_initialize for applet " + appletName);
	return;
};

// Initialize applet support and the applets.
function initializeAppletSupport() {
	// Be careful that this function is only executed once.
	if (typeof initializeAppletSupport.hasRun == 'undefined') initializeAppletSupport.hasRun = true;
	else return;

	console.log("Into initializeAppletSupport");

	// This should be the only ggbOnInit method defined.  Unfortunately some older problems define a
	// ggbOnInit so we check for that here.  Those problems should be updated, and newly written
	// problems should not define a javascript function by that name.
	// This caches the ggbOnInit from the problem, and calls it in the ggbOnInit function defined
	// here.  This will only work if there is only one of these old problems on the page.
	var ggbOnInitFromProblem = window.ggbOnInit ? window.ggbOnInit : null;

	window.ggbOnInit = function(appletName) {
		if (ggbOnInitFromProblem) {
			console.log("Calling cached ggbOnInit from problem.");
			ggbOnInitFromProblem(appletName);
		}
		if (appletName in ww_applet_list && ww_applet_list[appletName].onInit &&
			ww_applet_list[appletName].onInit != 'ggbOnInit') {
			if (window[ww_applet_list[appletName].onInit] &&
				typeof(window[ww_applet_list[appletName].onInit]) == 'function') {
				console.log("Calling onInit function for " + appletName + " in ggbOnInit.");
				window[ww_applet_list[appletName].onInit](appletName);
			} else {
				console.log("Calling onInit code for " + appletName + " in ggbOnInit.");
				eval(ww_applet_list[appletName].onInit);
			}
		}
	};

	// Called from the submit event listener defined below.
	function submitAction() {
		console.log("Submit button pushed. Calling submit action routines.");
		if (jsDebugMode == 0) {
			debugText = "Call submitAction() function on each applet.\n";
		}

		for (var appletName in ww_applet_list) {
			ww_applet_list[appletName].submitAction();
		}
		if (jsDebugMode == 1) { debug_add("\nDone calling submitAction() on each applet.\n"); }
		if (jsDebugMode == 1) { console.log("DebugText:\n" + debugText); debugText = ""; };
		console.log("Done calling submit action routines");
	}

	// Connect the form submitAction handler.
	if (document.problemMainForm) document.problemMainForm.addEventListener('submit', submitAction);
	if (document.gwquiz) document.gwquiz.addEventListener('submit', submitAction);

	for (var appletName in ww_applet_list) {
		if (!ww_applet_list[appletName].onInit) {
			console.log("Applet " + appletName + " has no onInit function. Initializing with safe_applet_initialize.");
			var maxInitializationAttempts = ww_applet_list[appletName].maxInitializationAttempts;
			this.debug_add("Initializing " + appletName);
			ww_applet_list[appletName].safe_applet_initialize(maxInitializationAttempts);
		} else {
			// If onInit is defined, then the onInit function will handle the initialization.
			console.log("Applet " + appletName + " has onInit function. No further initialization required.");
		}
	}
	this.debug_add("End of applet initialization");
	console.log("Out of initializeAppletSupport");
}

window.addEventListener('load', initializeAppletSupport);
