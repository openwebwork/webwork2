define(['globalVariables','underscore'], function(config) {

	console.log("in globals");
	

	var globals = { };
	_.extend(globals, globalVariables);

	console.log(globals);
	return globals;

});