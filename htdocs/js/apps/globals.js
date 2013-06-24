define(['globalVariables','underscore'], function(globalVariables) {

	var globals = { };
	_.extend(globals, globalVariables);
	return globals;

});