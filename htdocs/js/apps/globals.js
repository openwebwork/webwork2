define(['globalVariables','underscore'], function(globalVariables) {

	console.log("in globals");
	

	var globals = { };
	_.extend(globals, globalVariables);

	console.log(globals);
	return globals;

});