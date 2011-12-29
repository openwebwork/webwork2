/**
 * file variables
 */
var USER = "user-needs-to-be-defined-in-hidden-variable-id=hidden_user";
var COURSE = "course-needs-to-be-defined-in-hidden-variable-id=hidden_courseID";
var SESSIONKEY = "session-key-needs-to-be-defined-in-hidden-variable-id=hidden_key"
var PASSWORD = "who-cares-what-the-password-is";
// request object, I'm naming them assuming there may be different versions
var listLibRequest = {
	"xml_command" : "listLib",
	"pw" : "",
	"password" : PASSWORD,
	"session_key" : SESSIONKEY,
	"user" : "user-needs-to-be-defined",
	"library_name" : "Library",
	"courseID" : COURSE,
	"set" : "set0",
	"new_set_name" : "new set",
	"command" : "buildtree",
}

var undoing = false;
var undo_stack = new Array();
var redo_stack = new Array();

var cardCatalog;
var setList;
var webserviceURL = "../../../instructorXMLHandler";
var tabs;

/**
 * Utilities
 */
var uniqueCounter = 0;
function generateUniqueID() {
	uniqueCounter++;
	return uniqueCounter.toString(16);
}

Object.size = function(obj) {
	var size = 0, key;
	for (key in obj) {
		if (obj.hasOwnProperty(key))
			size++;
	}
	return size;
};

/**
 * Global stuff
 */
// undo and redo functions
function undo() {
	// pop the stack and call the function, that's it
	var undoFunc = undo_stack.pop();
	undoing = true;
	undoFunc();
}

function redo() {
	var redoFunc = redo_stack.pop();
	redoFunc();
}

function highlightSets(event) {
	console.log(this.getAttribute("data-path"));
	var problemID = this.getAttribute("data-path");
	$(".contains_problem").removeClass("contains_problem");
	for ( var key in setList.sets) {
		if (setList.sets[key].problems.hasOwnProperty(problemID)) {
			console.log("found one " + setList.sets[key].name
					+ setList.sets[key].id);
			$(
					document.getElementById(setList.sets[key].name
							+ setList.sets[key].id)).addClass(
					"contains_problem");
		}
	}
}
function unHighlightSets(event) {
	$(".contains_problem").removeClass("contains_problem");
}

function updateMessage(message) {
	var messageBox = document.getElementById("messages");
	messageBox.innerHTML = message;
	$(messageBox).effect("pulsate", {
		times : 3
	}, 500);
}

function showErrorResponse(data){
	var myWindow = window.open('', '', 'width=500,height=800');
	myWindow.document.write(data);
	myWindow.focus();
}

/**
 * unobtrusively start up our javascript
 */
$(document)
		.ready(
				function() {
					// do stuff when DOM is ready

					// get usernames and keys from hidden variables:
					var myUser = document.getElementById("hidden_user").value;
					var mySessionKey = document.getElementById("hidden_key").value;
					var myCourseID = document.getElementById("hidden_courseID").value;
					// check to make sure that our credentials are available.
					if (myUser && mySessionKey && myCourseID) {
						listLibRequest.user = myUser;
						listLibRequest.session_key = mySessionKey;
						listLibRequest.courseID = myCourseID;
					} else {
						updateMessage("missing hidden credentials: user "
								+ myUser + " session_key " + mySessionKey
								+ " courseID" + myCourseID);
					}

					// get our sets
					setList = new SetList();

					// attach function for deleting selected problems
					document
							.getElementById("delete_problem")
							.addEventListener(
									"click",
									function(event) {
										var currentTabId = $("#problems_container div.ui-tabs-panel:not(.ui-tabs-hide)")[0].id;
										console.log(currentTabId);
										// only care if it's a set
										if (currentTabId != "library_tab") {

											var problems = $(".ww_selected");
											var set = setList.sets[document
													.getElementById(
															currentTabId)
													.getAttribute("data-uid")];
											console.log(problems);
											problems.each(function(index) {
												set.removeProblem($(this).attr(
														"data-path"));
											});
										}
									}, false);

					// attach undo and redo
					document.getElementById("undo_button").addEventListener(
							"click", undo, false);
					document.getElementById("redo_button").addEventListener(
							"click", redo, false);

					$("#dialog").dialog({
						autoOpen : false,
						modal : true
					});
					// create set button listner
					document.getElementById("create_set").addEventListener(
							"click", function() {
								Set.createSet(setList, false);
								$("#dialog").dialog('close');
							});

					document.getElementById("new_problem_set")
							.addEventListener("click", function() {
								setList.createSet();
							}, false);

					// this stil doesn't work
					$("#new_problem_set").droppable({
						tolerance : 'pointer',
						drop : function(event, ui) {
							$("#dialog").dialog('open');
						}
					});

					// some window set up:
					$tabs = $("#problems_container")
							.tabs(
									{
										closable : true,
										add : function(event, ui) {
											document
													.getElementById(
															"library_link")
													.removeChild(
															document
																	.getElementById("library_link").lastChild);
											console.log("adding a tab");
											$tabs.tabs('select', '#'
													+ ui.panel.id);
											$(".ww_selected").removeClass(
													"ww_selected");// probably reduntant but I want to make sure nothing stays selected
										},
										create : function(event, ui) {
											document
													.getElementById(
															"library_link")
													.removeChild(
															document
																	.getElementById("library_link").lastChild);
											$(".ww_selected").removeClass(
													"ww_selected");
										},
										select : function(event, ui) {
											$(".ww_selected").removeClass(
													"ww_selected");
										},
										remove : function(event, ui) {
											document
													.getElementById(
															"library_link")
													.removeChild(
															document
																	.getElementById("library_link").lastChild);
											$(".ww_selected").removeClass(
													"ww_selected");
										}
									});

					$("#problems_container").removeClass("ui-corner-all");

					cardCatalog = new CardCatolog();
				});

function CardCatolog() {
	this.searchBox = new Search();
	this.displayBox = document.getElementById("library_list");
	this.listBox = document.getElementById("library_list_box");
	
	this.library = new Library("Library");
	this.working_library = this.library;
	
	// set up unobtrusive controlls:
		
	this.searchButton = document.getElementById("run_search");
	
	this.nextButton = document.getElementById("nextList");
	this.prevButton = document.getElementById("prevList");
	this.probsPerPage = document.getElementById("prob_per_page");
	this.topProbIndex = 0;
	
	var workAroundTheClosure = this;
	
	this.library.loadChildren(function(){workAroundTheClosure.buildSelectBox(workAroundTheClosure.library)});
	
	this.searchButton.addEventListener('click', function() {workAroundTheClosure.searchBox.go();}, false);
	
	document.getElementById("load_problems").addEventListener('click', function(){
		if(workAroundTheClosure.working_library.problems > 0){
			console.log("loaded");
			console.log(workAroundTheClosure.working_library.problems);
			workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, parseInt(workAroundTheClosure.probsPerPage.options[workAroundTheClosure.probsPerPage.selectedIndex].value));
		} 
		else {
			workAroundTheClosure.working_library.loadProblems(function() {
				console.log("callback!");
				workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, parseInt(workAroundTheClosure.probsPerPage.options[workAroundTheClosure.probsPerPage.selectedIndex].value));
				});
			}
	}, false);
	
	this.nextButton.addEventListener('click', function() {
		console.log("Next Button was clicked");
		// then load new problems? yes because we shouldn't
		// even be able to click on it if we can't
		workAroundTheClosure.topProbIndex += parseInt(workAroundTheClosure.probsPerPage.options[workAroundTheClosure.probsPerPage.selectedIndex].value);
		workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, parseInt(workAroundTheClosure.probsPerPage.options[workAroundTheClosure.probsPerPage.selectedIndex].value));
	}, false);
	document.getElementById("prevList").addEventListener('click', function() {
		workAroundTheClosure.topProbIndex -= parseInt(workAroundTheClosure.probsPerPage.options[workAroundTheClosure.probsPerPage.selectedIndex].value);
		if (workAroundTheClosure.topProbIndex < 0)
			workAroundTheClosure.topProbIndex = 0;
		workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, parseInt(workAroundTheClosure.probsPerPage.options[workAroundTheClosure.probsPerPage.selectedIndex].value));
	}, false);
}

CardCatolog.prototype.updateMoveButtons = function() {
	if (this.topProbIndex + parseInt(this.probsPerPage.options[this.probsPerPage.selectedIndex].value) < this.working_library.problems.length) {
		this.nextButton.removeAttribute("disabled");
	} else {
		this.nextButton.setAttribute("disabled", true);
	}
	if (this.topProbIndex > 0) {
		this.prevButton.removeAttribute("disabled");
	} else {
		this.prevButton.setAttribute("disabled", true);
	}
}

CardCatolog.prototype.buildSelectBox = function(currentLibrary) {
	var newLibList = document.createElement("select");
	newLibList.id = "libList" + (this.displayBox.childNodes.length + 1);
	newLibList.setAttribute("data-propName", currentLibrary.path);
	var workAroundTheClosure = this;
	newLibList.addEventListener("change", function() {
		workAroundTheClosure.onLibSelect(currentLibrary);
	}, false);

	for ( var name in currentLibrary.children) {
		if (!name.match(/\./)) {
			var option = document.createElement("option")
			option.value = name;
			option.innerHTML = name;
			newLibList.add(option, null);
		}
	}
	if (newLibList.childNodes.length > 0) {
		var emptyOption = document.createElement("option");
		newLibList.add(emptyOption, newLibList.firstChild);
		this.listBox.appendChild(newLibList);
	}
}

// start:index to start at, limit:number of problems to list
CardCatolog.prototype.renderProblems = function(start, limit) {
	while (this.displayBox.hasChildNodes()) {
		this.displayBox.removeChild(this.displayBox.lastChild);
	}
	for(var i = start; i < start+limit && i < this.working_library.problems.length; i++){
		this.working_library.problems[i].render(this.displayBox);
	}
	this.updateMoveButtons();
};


CardCatolog.prototype.onLibSelect = function(currentLibrary) {
	this.topProbIndex = 0;
	//this.library.problems.list = new Object();
	//this.updateLibrary();
	var changedLib = event.target;// should be the select
	var listBox = event.target.parentNode;
	var libChoices = listBox.childNodes;
	//var currentObject = this.treeRoot;

	var count = 0;
	var key;
	for ( var i = 0; i < libChoices.length; i++) {
		if (libChoices[i].tagName == "SELECT") {
			count = i;
			if (libChoices[i] == changedLib)
				break;
		}
	}
	while (listBox.childNodes.length > count + 1) {
		listBox.removeChild(listBox.lastChild);
	}
	
	if (currentLibrary.children.hasOwnProperty(changedLib.options[changedLib.selectedIndex].value)) {
		var child = currentLibrary.children[changedLib.options[changedLib.selectedIndex].value];
		this.working_library = child;
		//right now this reloads if there are no subdirectories, can be fixed by a count on serverside.
		if(Object.size(child.children) > 0){
			console.log("didn't have to build");
			this.buildSelectBox(child);
		} else {
			var workAroundTheClosure = this;
			child.loadChildren(function() {
				workAroundTheClosure.buildSelectBox(child);
			});
		}
	} else {
		this.working_library = currentLibrary;
	}
};

function Search(){
	this.subjectBox = document.getElementById("subjectBox");
	this.chaptersBox = document.getElementById("chaptersBox");
	this.sectionsBox = document.getElementById("sectionsBox");
	this.textbooksBox = document.getElementById("textbooksBox");
	this.textChaptersBox = document.getElementById("textChaptersBox");
	this.textSectionsBox = document.getElementById("textSectionsBox");
	this.keywordsBox = document.getElementById("keywordsBox");
	var workAroundTheClosure = this;
	subjectBox.addEventListener("change", function() {
		//update inputs
		workAroundTheClosure.updateInputs();
		//update lists
		workAroundTheClosure.updateChaptersBox();
		workAroundTheClosure.updateSectionsBox();
	}, false);
	chaptersBox.addEventListener("change", function() {
		//update inputs
		workAroundTheClosure.updateInputs();
		//update lists
		workAroundTheClosure.updateSectionsBox();
	}, false);
	sectionsBox.addEventListener("change", function() {
		//update inputs
		workAroundTheClosure.updateInputs();
	}, false);
	/*textbooksBox.addEventListener("change", function() {
		//update inputs
		workAroundTheClosure.updateInputs();
		//update lists
		workAroundTheClosure.updateAll();
	}, false);*/
	this.updateSubjectBox();
	this.updateChaptersBox();
	this.updateSectionsBox();
	
}

Search.prototype.go = function() {
	this.updateInputs();
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getDBListings";
	$.post(webserviceURL, listLibRequest,function(data) {
		console.log(data);
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			updateMessage(response.server_response);
			var results = response.result_data.split(",");
			var newSearchName = "search" + generateUniqueID();
			$tabs.tabs("add", "#"+newSearchName, "Search (" + results.length + ")");
			var thisContainer = document.getElementById(newSearchName);
			var displayList = document.createElement("ul");
			thisContainer.appendChild(displayList);
			for(var i = 0; i < results.length; i++){
				var searchProblem = new Problem(results[i]);
				searchProblem.render(displayList);
			}
			//callback();
		} catch (err) {
			console.log(err);
				var myWindow = window.open('', '', 'width=500,height=800');
				myWindow.document.write(data);
				myWindow.focus();
		}
	});
}

Search.prototype.updateInputs = function(){
	listLibRequest.library_subjects = this.subjectBox.options[this.subjectBox.selectedIndex].value;
	listLibRequest.library_chapters = this.chaptersBox.options[this.chaptersBox.selectedIndex].value;
	listLibRequest.library_sections = this.sectionsBox.options[this.sectionsBox.selectedIndex].value;
//	listLibRequest.library_textbook = this.textbooksBox.options[this.textbooksBox.selectedIndex].value;
//	listLibRequest.library_textchapter = this.textChaptersBox.options[this.textChaptersBox.selectedIndex].value;
//	listLibRequest.library_textsection = this.textSectionsBox.options[this.textSectionsBox.selectedIndex].value;
//	listLibRequest.library_keywords = this.keywordsBox.value;
}



Search.prototype.updateSubjectBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getAllDBsubjects";
	this.update(this.subjectBox, "All Subjects");	
}

Search.prototype.updateChaptersBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getAllDBchapters";
	this.update(this.chaptersBox, "All Chapters");	
}

Search.prototype.updateSectionsBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getSectionListings";
	this.update(this.sectionsBox, "All Sections");	
}

Search.prototype.updateTextbookBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getDBTextbooks";
	this.update(this.textbooksBox, "All Textbooks");	
}

Search.prototype.update = function(box, blankName){
	$.post(webserviceURL, listLibRequest,function(data) {
		console.log(data);
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			updateMessage(response.server_response);
			
			box.options.length = 0;
			var options = response.result_data.split(",");
			for (var i = 0; i < options.length; i++) {
				if (!name.match(/\./)) {
					var option = document.createElement("option")
					option.value = options[i];
					option.innerHTML = options[i];
					box.add(option, null);
				}
			}
			if (box.childNodes.length > 0) {
				var emptyOption = document.createElement("option");
				emptyOption.innerHTML = blankName;
				emptyOption.value = "";
				box.add(emptyOption, box.firstChild);
			}
			//callback();
		} catch (err) {
			console.log(err);
				var myWindow = window.open('', '', 'width=500,height=800');
				myWindow.document.write(data);
				myWindow.focus();
		}
	});
}

/*
 * needed functions: Both: getProblems
 * 
 * Library: markInSet markRemovedFromSet
 * 
 * Set: addProblem removeProblem reorderProblem view
 * 
 * Problem: (not sure about this yet) view source view problem
 * 
 * we're kind of following an mvc, check out pure for templating should make
 * life easy
 */

/*******************************************************************************
 * The library object
 ******************************************************************************/
// object
function Library(name, parent) {
	this.name = name;
	this.parent = false;
	
	if(parent){
		this.parent = parent;
		this.path = parent.path + "/" + name;
	} else {
		this.path = name;
	}
	this.children = new Object();
	
	this.problems = new Array();
}



Library.prototype.loadChildren = function(callback){
	listLibRequest.xml_command = "listLib";
	listLibRequest.command = "dirOnly";
	listLibRequest.maxdepth = 0;
	listLibRequest.library_name = this.path;
	
	updateMessage("Loading libraries... may take some time");
	
	var workAroundLibrary = this;
	$.post(webserviceURL, listLibRequest,
			function(data) {
				//console.log(data);
				//try {
					var response = $.parseJSON(data);
					console.log("result: " + response.server_response);
					updateMessage(response.server_response);
					for(var key in response.result_data){
						workAroundLibrary.children[key] = new Library(key, workAroundLibrary);
					}
					callback();
				/*} catch (err) {
					console.log(err);
					var myWindow = window.open('', '',
							'width=500,height=800');
					myWindow.document.write(data);
					myWindow.focus();
				}*/
			});
}

/*
Right now this is going to store all the files under each library.
This is reduntant!  The benifits of this should be discussed at a later date
and a fix (or not) should be decided on.
*/
Library.prototype.loadProblems = function(callback){
	listLibRequest.xml_command = "listLib";
	listLibRequest.command = "files";
	listLibRequest.maxdepth = 0;
	listLibRequest.library_name = this.path;
	
	updateMessage("Loading problems");
	
	var workAroundLibrary = this;
	$.post(webserviceURL, listLibRequest,
			function(data) {
				console.log(data);
				try {
					var response = $.parseJSON(data);
					console.log("result: " + response.server_response);
					updateMessage(response.server_response);
					//for(var key in response.result_data){
					//	workAroundLibrary.children[key] = new Library(key, workAroundLibrary);
					//}
					var problemList = response.result_data.split(",");
					workAroundLibrary.problems = new Array();
					for(var i = 0; i < problemList.length; i++){
						workAroundLibrary.problems.push(new Problem(problemList[i]));
					}					
					console.log("Problems:");
					console.log(workAroundLibrary.problems);
					callback();
				} catch (err) {
					console.log(err);
					var myWindow = window.open('', '',
							'width=500,height=800');
					myWindow.document.write(data);
					myWindow.focus();
				}
			});
}



/*******************************************************************************
 * The set object
 ******************************************************************************/
// object
function Set(setName) {// id might not exist..use date if nessisary
	this.id = generateUniqueID();
	this.name = setName;
	this.problems = new Object(); // a hash of problems {id: problemInfo}
	this.problemArray = new Array();// redunant but I don't have any better
									// ideas atm for keeping order
	this.displayBox;
	this.previousOrder;
}
// controller
Set.prototype.renderSet = function() {
	/*
	 * sudo code for display stuff: create a tab next to library_box make it's
	 * id setID load in the problems from the set add the nessisary listeners
	 * etc to the problems switch to that tab
	 */

	if (document.getElementById(this.name)
			&& $.contains(document.getElementById("problems_container"),
					document.getElementById(this.name))) {
		// might as well reload the problems
		while (this.displayBox.hasChildNodes()) {
			this.displayBox.removeChild(this.displayBox.lastChild);
		}
		for ( var i = 0; i < this.problemArray.length; i++) {
			this.renderProblem(this.problemArray[i]);
		}
	} else {
		$tabs.tabs("add", "#" + this.name, this.name + " (" + this.problemArray.length + ")");
		var thisContainer = document.getElementById(this.name);
		thisContainer.setAttribute("data-uid", this.id);
		this.displayBox = document.createElement("ul");
		this.displayBox.id = this.name + "_list";
		var workAroundSet = this;
		$(this.displayBox).sortable({
			start : function(event, ui) {
				workAroundSet.previousOrder = $(this).sortable('toArray');
			},
			update : function(event, ui) {
				workAroundSet.reorderProblems($(this).sortable('toArray'));
			}
		});// sortable code
		thisContainer.appendChild(this.displayBox);
		for ( var i = 0; i < this.problemArray.length; i++) {
			this.renderProblem(this.problemArray[i]);
		}
	}
}

Set.prototype.renderProblem = function(problem) {
	var newSetItem = problem.render(this.displayBox);
	newSetItem.addEventListener("click", function(event) {
		if (!event.altKey) {
			$(".ww_selected").removeClass("ww_selected");
		}
		$(this).addClass("ww_selected");
	}, false);
	$(this.displayBox).sortable("refresh");
}

Set.prototype.loadProblems = function(shouldRender) {
	listLibRequest.xml_command = "listSetProblems";
	listLibRequest.set = this.name;
	this.problems = new Object();
	this.problemArray = new Array();
	var workAroundTheClosure = this;
	$
			.post(
					webserviceURL,
					listLibRequest,
					function(data) {
						try {
							var response = $.parseJSON(data);
							console.log("result: " + response.server_response);

							var problems = response.result_data.split(",");
							for ( var i = 0; i < problems.length; i++) {
								if (problems[i] != "") {
									var newProblem = new Problem(problems[i]);
									workAroundTheClosure.problems[newProblem.path] = newProblem;
									workAroundTheClosure.problemArray
											.push(newProblem);
								}
							}
							document.getElementById(workAroundTheClosure.name
									+ workAroundTheClosure.id).innerHTML = workAroundTheClosure.name
									+ " ("
									+ workAroundTheClosure.problemArray.length
									+ ")"
							if (shouldRender) {
								workAroundTheClosure.renderSet();// may want
																	// to take
																	// this out
																	// later? so
																	// that we
																	// can load
																	// problems
																	// without
																	// adding
																	// the tab
																	// idk
							}
						} catch (err) {
							var myWindow = window.open('', '',
									'width=500,height=800');
							myWindow.document.write(data);
							myWindow.focus();
						}
					});
}

Set.prototype.addProblem = function(probPath) {
	listLibRequest.set = this.name;// switch to data attribute
	listLibRequest.problemPath = probPath;
	listLibRequest.xml_command = "addProblem";
	var workAroundSet = this;
	$.post(webserviceURL, listLibRequest, function(data) {
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			updateMessage(response.server_response);
			// still have to test for success..everywhere
			if (undoing) {// might be a better way to do this later
				redo_stack.push(function() {
					workAroundSet.removeProblem(probPath);
				});
				undoing = false;
			} else {
				undo_stack.push(function() {
					workAroundSet.removeProblem(probPath);
				});
			}
			workAroundSet.loadProblems($.contains(document
					.getElementById("problems_container"), document
					.getElementById(workAroundSet.name)));
		} catch (err) {
			showErrorResponse(data);
		}
	});
}

Set.prototype.removeProblem = function(probPath) {
	listLibRequest.set = this.name;// switch to data attribute
	listLibRequest.problemPath = probPath;
	listLibRequest.xml_command = "deleteProblem";
	var workAroundSet = this;
	$.post(webserviceURL, listLibRequest, function(data) {
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			updateMessage(response.server_response);
			// still have to test for success....
			if (undoing) {
				redo_stack.push(function() {
					workAroundSet.addProblem(probPath);
				});
				undoing = false;
			} else {
				undo_stack.push(function() {
					workAroundSet.addProblem(probPath);
				});
			}
			workAroundSet.loadProblems($.contains(document
					.getElementById("problems_container"), document
					.getElementById(workAroundSet.name)));
		} catch (err) {
			showErrorResponse(data);
		}
	});
}

Set.prototype.reorderProblems = function(setOrder) {
	var workAroundOrder = this.previousOrder;
	var workAroundSet = this;
	if (undoing) {
		redo_stack.push(function() {
			// resort the list

			console.log(workAroundOrder);
			for ( var i = 0; i < workAroundOrder.length; i++) {
				var tempProblem = document.getElementById(workAroundOrder[i]);
				workAroundSet.displayBox.removeChild(tempProblem);
				workAroundSet.displayBox.appendChild(tempProblem);
			}
			$(workAroundSet.displayBox).sortable("refresh");
			workAroundSet.reorderProblems(workAroundOrder);
		});
		undoing = false;
	} else {
		undo_stack.push(function() {
			// resort the list
			for ( var i = 0; i < workAroundOrder.length; i++) {
				var tempProblem = document.getElementById(workAroundOrder[i]);
				workAroundSet.displayBox.removeChild(tempProblem);
				workAroundSet.displayBox.appendChild(tempProblem);
			}
			$(workAroundSet.displayBox).sortable("refresh");
			// $(workAroundSet.displayBox).sortable( "refreshPositions" )
			workAroundSet.reorderProblems(workAroundOrder);
		});
	}
	// load problems:
	// var problems = this.displayBox.childNodes;
	var probList = new Array();
	for ( var i = 0; i < setOrder.length; i++) {
		probList.push(document.getElementById(setOrder[i]).getAttribute(
				"data-path"));
	}
	var probListString = probList.join(",");

	listLibRequest.probList = probListString;
	listLibRequest.xml_command = "reorderProblems";
	listLibRequest.set = this.name;
	$.post(webserviceURL, listLibRequest, function(data) {
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			updateMessage(response.server_response);
		} catch (err) {
			showErrorResponse(data);
		}
	});
	this.previousOrder = $(workAroundSet.displayBox).sortable('toArray');
}

Set.createSet = function(refreshList, callback) {//change callback to work with strings..
	listLibRequest.xml_command = "createNewSet";
	listLibRequest.new_set_name = document.getElementById("dialog_text").value;
	$.post(webserviceURL, listLibRequest, function(data) {
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			updateMessage(response.server_response);
		} catch (err) {
			showErrorResponse(data);
		}
		if(refreshList){
			setList.refresh();// this is odd but no other obvious way (can't just
							// pass it in due to closure)
		}
		if(callback){
			callback();
		}
	});
}

/*******************************************************************************
 * SetList object needed variables: sets, displaybox, needed functions: create
 * set
 */

function SetList() {
	this.setNames = new Array();
	this.sets = new Object();
	this.displayBox = document.getElementById("my_sets_list");
	listLibRequest.xml_command = "listSets";
	var workAroundSetList = this;
	console.log("starting set list");
	$.post(webserviceURL, listLibRequest, function(data) {
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			workAroundSetList.setNames = response.result_data.split(",");
			workAroundSetList.setNames.sort();
			console.log("found these sets: " + workAroundSetList.setNames);
			for ( var i = 0; i < workAroundSetList.setNames.length; i++) {
				workAroundSetList.renderList(workAroundSetList.setNames[i]);
			}
		} catch (err) {
			showErrorResponse(data);
		}
	});
}

SetList.prototype.refresh = function(problemPath) {
	listLibRequest.xml_command = "listSets";
	var workAroundSetList = this;
	$.post(webserviceURL, listLibRequest, function(data) {
		try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			var newSetList = response.result_data.split(",");
			var newSets = new Array();
			for ( var i = 0; i < newSetList.length; i++) {
				if ($.inArray(newSetList[i], workAroundSetList.setNames) < 0) {
					console.log("rendering set " + newSetList[i] + "");
					newSets.push(newSetList[i]);
				}
			}
			var recievingSet;
			for ( var j = 0; j < newSets.length; j++) {
				workAroundSetList.setNames.push(newSets[j]);
				var recievingSet = workAroundSetList.renderList(newSets[j]);
			}
			if (recievingSet && problemPath) {
				recievingSet.addProblem(problemPath);
			}
		} catch (err) {
			showErrorResponse(data);
		}
	});
	// how do we check if we already have the set?
}

SetList.prototype.renderList = function(setName) {

	var addingSet = document.createElement("li");

	var newSet = new Set(setName);
	newSet.loadProblems(false);
	addingSet.innerHTML = setName;
	addingSet.setAttribute("data-uid", newSet.id);
	addingSet.id = newSet.name + newSet.id;
	this.sets[newSet.id] = newSet;

	var workAroundSetList = this.sets;
	addingSet.addEventListener("click", function(event) {
		var clickedSet = workAroundSetList[this.getAttribute("data-uid")];
		clickedSet.loadProblems(true);
		$("#problems_container").tabs("select", clickedSet.name);
	}, false);

	$(addingSet).insertBefore("#new_problem_set");
	// this.displayBox.appendChild(addingSet);
	$(addingSet).droppable(
			{
				tolerance : 'pointer',
				drop : function(event, ui) {
					var recievingSet = workAroundSetList[this
							.getAttribute("data-uid")];
					recievingSet.addProblem(ui.draggable.attr("data-path"));
				}
			});
	return newSet;

};

SetList.prototype.createSet = function() {
	$("#dialog").dialog('open');
};

/*******************************************************************************
 * The problem object
 ******************************************************************************/
// object
function Problem(path) {
	this.path = path;
	this.data = false;
	this.id = generateUniqueID();
}

Problem.prototype.render = function(displayBox) {
	var problem = this;
	listLibRequest.set = problem.path;
	listLibRequest.problemSource = problem.path;
	listLibRequest.xml_command = "renderProblem";
	var workAroundDisplayBox = displayBox;
	var newItem = document.createElement('li');
	newItem.setAttribute("data-path", problem.path);
	newItem.setAttribute("data-uid", problem.id);
	newItem.id = problem.path + problem.id;
	//set a loading image while we wait for the problem
	var loadingImage = document.createElement("img");
	loadingImage.src = '/webwork2_files/images/ajax-loader-small.gif';
	newItem.appendChild(loadingImage);
	//add the item to the box so that we dont lose our place
	workAroundDisplayBox.appendChild(newItem);

	var handle = document.createElement("div");
	handle.className = "handle";
	var container = document.createElement("div");

	if (!problem.data) {
		//if we haven't gotten this problem yet, ask for it
		$.post(webserviceURL, listLibRequest, function(data) {
			//console.log(data);
			//newItem.innerHTML = data;
			container.innerHTML = data;
			newItem.innerHTML = null;
			newItem.appendChild(handle);
			newItem.appendChild(container);
			$(newItem).draggable({
				helper : 'clone',
				handle : 'div.handle',
				revert : true,
				appendTo : 'body',
				cursorAt : {
					top : 0,
					left : 0
				},
				opacity : 0.35
			});
			problem.data = data;
		});
	} else {
		console.log("didn't have to go to the server");
		//if we've gotten it just load up the stored data
		//newItem.innerHTML = data;
		container.innerHTML = problem.data;
		newItem.innerHTML = null;
		newItem.appendChild(handle);
		newItem.appendChild(container);
		$(newItem).draggable({
			helper : 'clone',
			revert : true,
			handle : 'div.handle',
			appendTo : 'body',
			cursorAt : {
				top : 0,
				left : 0
			},
			opacity : 0.35
		});
	}

	newItem.addEventListener("mouseover", highlightSets, false);
	//newItem.addEventListener("mouseout", unHighlightSets, false);

	return newItem;
}
