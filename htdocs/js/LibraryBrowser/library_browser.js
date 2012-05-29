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

var problemPlaceholder = false;

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


//MOVE
function highlightSets(event) {
	//console.log(this.getAttribute("data-path"));
	var problemID = this.getAttribute("data-path");
	$(".contains_problem").removeClass("contains_problem");
	for ( var key in setList.sets) {
		if (setList.sets[key].problems.hasOwnProperty(problemID)) {
			//console.log("found one " + setList.sets[key].name + setList.sets[key].id);
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

//SMOKE
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
$(document).ready(function() {

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
	setList = new SetList();//REMOVE

	// attach function for deleting selected problems
	document.getElementById("delete_problem").addEventListener("click", function(event) {
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
	}, false);//REMOVE

	// attach undo and redo
	document.getElementById("undo_button").addEventListener("click", undo, false);
	document.getElementById("redo_button").addEventListener("click", redo, false);

	$("#dialog").dialog({
		autoOpen : false,
		modal : true
	});//MOVE
	// create set button listner
	document.getElementById("create_set").addEventListener("click", function() {
		Set.createSet(setList, false);
		$("#dialog").dialog('close');
	});//MOVE

	document.getElementById("new_problem_set").addEventListener("click", function() {
		setList.createSet();
	}, false);//MOVE

	// this stil doesn't work
	$("#new_problem_set").droppable({
		tolerance : 'pointer',
		drop : function(event, ui) {
			problemPlaceholder = ui.draggable.attr("data-path")
			$("#dialog").dialog('open');
		}
	});//MOVE
//   setup  slider for side bar
	$("#problem_sets_container").resizable({
		cursor: 'move',
		//animate: true,
		//ghost: true,
		delay: 0,
	});//MOVE


	// some window set up:
    $tabs = $("#problems_container")
        .tabs(
        {
            closable:true,
            add:function (event, ui) {
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
            create:function (event, ui) {
                document
                    .getElementById(
                    "library_link")
                    .removeChild(
                    document
                        .getElementById("library_link").lastChild);
                $(".ww_selected").removeClass(
                    "ww_selected");
            },
            select:function (event, ui) {
                $(".ww_selected").removeClass(
                    "ww_selected");
            },
            remove:function (event, ui) {
                document
                    .getElementById(
                    "library_link")
                    .removeChild(
                    document
                        .getElementById("library_link").lastChild);
                $(".ww_selected").removeClass(
                    "ww_selected");
            }
        });//MOVE


});

var CardCatalog = Library.extend({

    loadChildren:function (callback) {

        var self = this;
        listLibRequest.xml_command = "listLibraries";//MOVE

        updateMessage("Loading libraries... may take some time");//MOVE

        $.post(webserviceURL, listLibRequest,
            function(data) {
                console.log(data);
                try {
                    var response = $.parseJSON(data);
                    console.log("result: " + response.server_response);
                    updateMessage(response.server_response);
                    var libraries = response.result_data.split(",");
                    libraries.forEach(function(lib){
                        self.get('children').add({name:lib});
                    });
                } catch (err) {
                    showErrorResponse(data);
                }
            });
    }
});

    /*
	this.searchButton = document.getElementById("run_search");

	this.nextButton = document.getElementById("nextList");
	this.prevButton = document.getElementById("prevList");
	this.probsPerPage = document.getElementById("prob_per_page");
	this.topProbIndex = 0;

	var workAroundTheClosure = this;

	this.buildLibraryBox(topLibraries);
	//this.library.loadChildren(function(){workAroundTheClosure.buildSelectBox(workAroundTheClosure.library)});

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
	*/

/*
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
*/
/*
CardCatolog.prototype.buildSelectBox = function(currentLibrary) {
	var newLibList = document.createElement("select");
	newLibList.id = "libList" + (this.displayBox.childNodes.length + 1);
	newLibList.setAttribute("data-propName", currentLibrary.path);
	var workAroundTheClosure = this;
	newLibList.addEventListener("change", function(event) {
		workAroundTheClosure.onLibSelect(event, currentLibrary);
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
	$('a[href="#library_tab"] span').text("Library ("+start+" - "+ (start+limit) +" of " + this.working_library.problems.length + ") ");
	while (this.displayBox.hasChildNodes()) {
		this.displayBox.removeChild(this.displayBox.lastChild);
	}
	for(var i = start; i < start+limit && i < this.working_library.problems.length; i++){
		this.working_library.problems[i].render(this.displayBox);
	}
	this.updateMoveButtons();
};


CardCatolog.prototype.onLibSelect = function(event, currentLibrary) {
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
*/
function Search(){
	this.problems = new Array();
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

function SearchResult(){
	this.searchName = "search" + generateUniqueID();
	this.displayBox;
	this.problems;
}

SearchResult.prototype.createPageControls = function(){

	this.nextButton = document.createElement("button");
	//<button type="button" disabled=true id="nextList">Next</button>
	this.nextButton.id = this.searchName + "nextList";
	this.nextButton.type = "button";
	this.nextButton.innerHTML = "Next";
	this.nextButton.setAttribute("disabled", true);

	this.prevButton = document.createElement("button");
	//<button type="button" disabled=true id="prevList">Previous</button>
	this.prevButton.id = this.searchName + "prevList";
	this.prevButton.type = "button";
	this.prevButton.innerHTML = "Previous";
	this.prevButton.setAttribute("disabled", true);

	var thisContainer = document.getElementById(this.searchName);
	thisContainer.appendChild(this.prevButton);
	thisContainer.appendChild(this.nextButton);


	//hard coded for now
	this.probsPerPage = 10;//document.getElementById("prob_per_page");
	this.topProbIndex = 0;

	//attach event listeners:
	var workAroundTheClosure = this;
	this.nextButton.addEventListener('click', function() {
		console.log("Next Button was clicked");
		// then load new problems? yes because we shouldn't
		// even be able to click on it if we can't
		workAroundTheClosure.topProbIndex += workAroundTheClosure.probsPerPage;
		workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, workAroundTheClosure.probsPerPage);
	}, false);
	this.prevButton.addEventListener('click', function() {
		workAroundTheClosure.topProbIndex -= workAroundTheClosure.probsPerPage;
		if (workAroundTheClosure.topProbIndex < 0)
			workAroundTheClosure.topProbIndex = 0;
		workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, workAroundTheClosure.probsPerPage);
	}, false);


}


Search.prototype.go = function() {
	this.updateInputs();
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getDBListings";
	var workAroundTheClosure = this;
	$.post(webserviceURL, listLibRequest,function(data) {
		console.log(data);
		//try {
			var response = $.parseJSON(data);
			console.log("result: " + response.server_response);
			updateMessage(response.server_response);
			var results = response.result_data.split(",");

			var newSearchResult = new SearchResult();

			$tabs.tabs("add", "#"+newSearchResult.searchName, "Search (" + results.length + ")");
			var thisContainer = document.getElementById(newSearchResult.searchName);
			var displayList = document.createElement("ul");
			thisContainer.appendChild(displayList);



			newSearchResult.createPageControls();

			newSearchResult.displayBox = displayList;
			newSearchResult.problems = new Array();
			for(var i = 0; i < results.length; i++){
				newSearchResult.problems.push(new Problem(results[i]));
			}
			newSearchResult.renderProblems(newSearchResult.topProbIndex, newSearchResult.probsPerPage);
			//callback();
		/*} catch (err) {
			console.log(err);
				var myWindow = window.open('', '', 'width=500,height=800');
				myWindow.document.write(data);
				myWindow.focus();
		}*/
	});
};

SearchResult.prototype.renderProblems = function(start, limit) {
	//$('#'+this.searchName+' a').text("Other text");
	$('a[href="#'+this.searchName+'"] span').text("Search ("+start+" - "+ (start+limit) +" of " + this.problems.length + ") ");
	console.log($('#'+this.searchName+' a'));
	while (this.displayBox.hasChildNodes()) {
		this.displayBox.removeChild(this.displayBox.lastChild);
	}
	for(var i = start; i < start+limit && i < this.problems.length; i++){
		this.problems[i].render(this.displayBox);
	}
	this.updateMoveButtons();
};

SearchResult.prototype.updateMoveButtons = function() {
	if ((this.topProbIndex + this.probsPerPage) < this.problems.length) {
		this.nextButton.removeAttribute("disabled");
	} else {
		this.nextButton.setAttribute("disabled", true);
	}
	if (this.topProbIndex > 0) {
		this.prevButton.removeAttribute("disabled");
	} else {
		this.prevButton.setAttribute("disabled", true);
	}
};

Search.prototype.updateInputs = function(){
	listLibRequest.library_subjects = this.subjectBox.options[this.subjectBox.selectedIndex].value;
	listLibRequest.library_chapters = this.chaptersBox.options[this.chaptersBox.selectedIndex].value;
	listLibRequest.library_sections = this.sectionsBox.options[this.sectionsBox.selectedIndex].value;
//	listLibRequest.library_textbook = this.textbooksBox.options[this.textbooksBox.selectedIndex].value;
//	listLibRequest.library_textchapter = this.textChaptersBox.options[this.textChaptersBox.selectedIndex].value;
//	listLibRequest.library_textsection = this.textSectionsBox.options[this.textSectionsBox.selectedIndex].value;
//	listLibRequest.library_keywords = this.keywordsBox.value;
};



Search.prototype.updateSubjectBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getAllDBsubjects";
	this.update(this.subjectBox, "All Subjects");
};

Search.prototype.updateChaptersBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getAllDBchapters";
	this.update(this.chaptersBox, "All Chapters");
};

Search.prototype.updateSectionsBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getSectionListings";
	this.update(this.sectionsBox, "All Sections");
};

Search.prototype.updateTextbookBox = function(){
	listLibRequest.xml_command = "searchLib";
	listLibRequest.subcommand = "getDBTextbooks";
	this.update(this.textbooksBox, "All Textbooks");
};

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
};

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

var Library = Backbone.Model.extend({
    defaults:function () {
        return{
            name:"",
            parent:false,
            problems:new ProblemList,
            children:new LibraryList
        }
    },

    initalize:function () {
        if (this.get("parent")) {
            this.set("path", this.get('parent').get('path') + "/" + this.get('name'));
        } else {
            this.set("path", this.get("name"));
        }
    },

    loadChildren:function (callback) {

        var self = this;

        listLibRequest.xml_command = "listLib";
        listLibRequest.command = "dirOnly";
        listLibRequest.maxdepth = 0;
        listLibRequest.library_name = self.get('path');

        updateMessage("Loading libraries... may take some time");


        $.post(webserviceURL, listLibRequest,
            function (data) {
                //console.log(data);
                try {
                    var response = $.parseJSON(data);
                    console.log("result: " + response.server_response);
                    updateMessage(response.server_response);
                    for (var key in response.result_data) {
                        self.children.add({name:key, parent:self});
                    }
                    callback();
                } catch (err) {
                    showErrorResponse(data);
                }
            });
    },
    /*
     Right now this is going to store all the files under each library.
     This is reduntant!  The benifits of this should be discussed at a later date
     and a fix (or not) should be decided on.
     */
    loadProblems:function (callback) {

        var self = this;
        listLibRequest.xml_command = "listLib";
        listLibRequest.command = "files";
        listLibRequest.maxdepth = 0;
        listLibRequest.library_name = self.get('path') + "/";

        updateMessage("Loading problems");
        console.log(listLibRequest.library_name);

        $.post(webserviceURL, listLibRequest,
            function (data) {
                console.log(data);
                try {
                    var response = $.parseJSON(data);
                    console.log("result: " + response.server_response);
                    updateMessage(response.server_response);
                    //for(var key in response.result_data){
                    //	workAroundLibrary.children[key] = new Library(key, workAroundLibrary);
                    //}
                    var problemList = response.result_data.split(",");
                    self.problems.reset();
                    for (var i = 0; i < problemList.length; i++) {
                        self.problems.add({name:problemList[i]});
                    }
                    //console.log("Problems:");
                    //console.log(workAroundLibrary.problems);
                    callback();
                } catch (err) {
                    showErrorResponse(data);
                }
            });
    }
});

var LibraryList = Backbone.Collection.extend({
    model: Library
});

var LibraryView = Backbone.View.extend({
    el:$('#library_tab')
});

var LibraryListView = Backbone.View.extend({
    tagName: 'span',
    template:_.template($('#LibraryList-template').html()),
    initialize: function(){

    },

    render: function(){
        var self = this;
        this.$el.html(this.template(this.model.toJSON));
        this.model.get('children').each(function(lib){
            var option = document.createElement("option")
            option.value = lib.get('cid');
            option.innerHTML = lib.get('name');
            self.$('.list').add(option, null);//what's the null?
        });

        return this;
    },

    lib_selected: function(event){
        var selectedLib = this.model.get('children').getByCid(event.target.value);
        var view = new LibraryListView({model: selectedLib});
        this.$(".children").html(view.render().el);
    }

});



/*******************************************************************************
 * The set object
 ******************************************************************************/
// object
/*
function Set(setName) {// id might not exist..use date if nessisary
	this.id = generateUniqueID();
	this.name = setName;
	this.problems = new Object(); // a hash of problems {id: problemInfo}
	this.problemArray = new Array();// redunant but I don't have any better
									// ideas atm for keeping order
	this.displayBox;
	this.previousOrder;
}
*/
var ProblemList = Backbone.Collection.extend({
    model:Problem
/*
    comparator: function(todo) {
        return todo.get('order');
    }
*/
});

var Set = Backbone.Model.extend({
    defaults:{
        name: "defaultSet",
        problems: new ProblemList
    },

    initialize:function(){
        this.get('problems').on('add', this.addProblem, this);
        this.get('problems').on('remove', this.removeProblem, this);
    },

    addProblem: function(problem) {
        var self = this;

        listLibRequest.set = this.get('name');// switch to data attribute
        listLibRequest.problemPath = problem.get('path');
        listLibRequest.xml_command = "addProblem";

        $.post(webserviceURL, listLibRequest, function (data) {
            try {
                var response = $.parseJSON(data);
                console.log("result: " + response.server_response);
                updateMessage(response.server_response);
                // still have to test for success..everywhere
                if (undoing) {// might be a better way to do this later
                    redo_stack.push(function () {
                        self.removeProblem(probPath);
                    });
                    undoing = false;
                } else {
                    undo_stack.push(function () {
                        self.removeProblem(probPath);
                    });
                }
                //hopfully I can get rid of this
                //self.loadProblems($.contains(document.getElementById("problems_container"), document.getElementById(self.name)));
            } catch (err) {
                showErrorResponse(data);
            }
        });
    },

    removeProblem: function(problem) {
        var self = this;

        listLibRequest.set = self.get('name');// switch to data attribute
        listLibRequest.problemPath = problem.get('path');
        listLibRequest.xml_command = "deleteProblem";

        $.post(webserviceURL, listLibRequest, function (data) {
            try {
                var response = $.parseJSON(data);
                console.log("result: " + response.server_response);
                updateMessage(response.server_response);
                // still have to test for success....
                if (undoing) {
                    redo_stack.push(function () {
                        self.addProblem(probPath);
                    });
                    undoing = false;
                } else {
                    undo_stack.push(function () {
                        self.addProblem(probPath);
                    });
                }
                /*workAroundSet.loadProblems($.contains(document
                 .getElementById("problems_container"), document
                 .getElementById(self.name)));*/
            } catch (err) {
                showErrorResponse(data);
            }
        });
    },

    loadProblems: function() {
        var self = this;

        listLibRequest.xml_command = "listSetProblems";
        listLibRequest.set = self.get('name');
        $.post(webserviceURL, listLibRequest,
            function (data) {
                try {//this is the wrong way to be error checking
                    var response = $.parseJSON(data);
                    console.log("result: " + response.server_response);
                    self.problems.reset();
                    var problems = response.result_data.split(",");
                    for (var i = 0; i < problems.length; i++) {
                        if (problems[i] != "") {
                            self.problems.add({path: problems[i]});
                        }
                    }
                    //document.getElementById(workAroundTheClosure.name + workAroundTheClosure.id).innerHTML = workAroundTheClosure.name + " (" + workAroundTheClosure.problemArray.length + ")";
                } catch (err) {
                    showErrorResponse(data);
                }
            }
        );
    }

    //For reroder
    //http://localtodos.com/javascripts/todos.js (look at sortables in particular)
    /*

     reorderProblems = function(setOrder) {
     var workAroundOrder = this.previousOrder;
     var workAroundSet = this;
     if(document.getElementById(workAroundSet.displayBox.id)){
     if (undoing) {
     redo_stack.push(function() {
     // resort the list
     if(document.getElementById(workAroundSet.displayBox.id)){
     for ( var i = 0; i < workAroundOrder.length; i++) {
     var tempProblem = document.getElementById(workAroundOrder[i]);
     workAroundSet.displayBox.removeChild(tempProblem);
     workAroundSet.displayBox.appendChild(tempProblem);
     }
     $(workAroundSet.displayBox).sortable("refresh");
     }
     workAroundSet.reorderProblems(workAroundOrder);
     });
     undoing = false;
     } else {
     undo_stack.push(function() {
     // resort the list
     if(document.getElementById(workAroundSet.displayBox.id)){
     for ( var i = 0; i < workAroundOrder.length; i++) {
     var tempProblem = document.getElementById(workAroundOrder[i]);
     workAroundSet.displayBox.removeChild(tempProblem);
     workAroundSet.displayBox.appendChild(tempProblem);
     }
     $(workAroundSet.displayBox).sortable("refresh");
     }
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
     */

});

//full set view, renders all problems etc
var SetView = Backbone.View.extend({
    tagName: "div",
    template: _.template($('#setList-template').html()),
    events:{
    },

    initialize: function(){

    },

    render:function(){
        /*
         * sudo code for display stuff: create a tab next to library_box make it's
         * id setID load in the problems from the set add the nessisary listeners
         * etc to the problems switch to that tab
         *//*
        var self = this;
        if (document.getElementById(self.get('name'))
            && $.contains(document.getElementById("problems_container"),
            document.getElementById(self.get('name')))) {
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
                axis: 'y',
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
        }*/

        //Template and fix up, that was just ugly
        var self = this;
        this.$el.id = this.model.get('name');

        this.$el.sortable({
            axis: 'y',
            start : function(event, ui) {
                //self.previousOrder = $(this).sortable('toArray');
            },
            update : function(event, ui) {
                //self.reorderProblems($(this).sortable('toArray'));
            }
        });

        this.$el.html(this.template(this.model.toJSON()));

        this.model.get('problems').each(function(problem){
           var view = new ProblemView({model: problem});
           self.$(".list").append(view.render().el);
        });

        return this;
    }
});
/*
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
*/


var SetNameView = Backbone.Collection.extend({
    tagName: "li",
    template: _.template($('#setName-template').html()),

    events:{
        'click' : 'view'
    },

    initalize: function(){
        this.bigView = false;
    },

    render: function(){
        var self = this;

        self.$el.html(self.template(self.model.toJSON()));

        self.$el.droppable({
                tolerance : 'pointer',

                hoverClass: 'drophover',

                drop : function(event, ui) {
                    self.model.addProblem(ui.draggable.attr("data-path"));
                }
            });

        return this;
    },

    view: function() {
        console.log("clicked " + this.model.get('name'));
        if ($('#problems_container #'+this.model.get('name'))) {
            $('#problems_container').tabs('select', this.model.get('name'));
        } else {
            $('#problems_container').tabs('add', this.model.get('name'), this.model.get('name') + " (" + this.model.get('problems').length + ")"); //could move to an after?
            var view = new SetView({model:this.model});
            $('#problems_container').append(view.render().el);
        }
        //render the full tab thing, or switch to it
    }
});

/*******************************************************************************
 * SetList object needed variables: sets, displaybox, needed functions: create
 * set
 */

var SetList = Backbone.Collection.extend({
    model: Set,

    //think it's fetch I want to replace:
    fetch: function(){
        var self = this;

        listLibRequest.xml_command = "listSets";

        console.log("starting set list");
        $.post(webserviceURL, listLibRequest, function(data) {
            try {
                var response = $.parseJSON(data);
                console.log("result: " + response.server_response);
                var setNames = response.result_data.split(",");
                setNames.sort();
                console.log("found these sets: " + setNames);
                for ( var i = 0; i < setNames.length; i++) {
                    //workAroundSetList.renderList(workAroundSetList.setNames[i]);
                    self.add({name: setNames[i]});
                }
            } catch (err) {
                showErrorResponse(data);
            }
        });
    },

    //different from add I hope
    create: function(model){
        this.add(model);
        listLibRequest.xml_command = "createNewSet";
        listLibRequest.new_set_name = model.name?model.name:model.get("name");
        $.post(webserviceURL, listLibRequest, function(data) {
            try {
                var response = $.parseJSON(data);
                console.log("result: " + response.server_response);
                updateMessage(response.server_response);
            } catch (err) {
                showErrorResponse(data);
            }
        });
    }
});

/*
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
*/

var SetListView = Backbone.View.extend({
    tagName: "ul",
    template: _.template($('#setList-template').html()),

    initialize: function(){
        this.model.bind('add', this.addOne, this);
        this.model.bind('reset', this.addAll, this);
        this.model.bind('all', this.render, this);
    },

    render: function(){
        var self = this;

        self.$el.html(self.template());

        return this;
    },

    addOne: function(newSet){
        var view = new SetNameView({model: newSet});
        self.$el.append(view.render().el);
    },

    addAll: function() {
        this.model.each(this.addOne);
    }
/*
    startCreate: function(){
        this.$("#dialog").dialog('open');
    }
*/
});

/*
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

				hoverClass: 'drophover',

				drop : function(event, ui) {
					var recievingSet = workAroundSetList[this
							.getAttribute("data-uid")];
					recievingSet.addProblem(ui.draggable.attr("data-path"));
				}
			});
	return newSet;

};
*/


/*******************************************************************************
 * The problem object
 ******************************************************************************/
// object

var Problem = Backbone.Model.extend({
    defaults:function(){
        return{
           path: "",
           data: false,
        };
    },

    initialize: function(){

    },
    //this is a server render, different from a view render
    render: function(callback) {
        var problem = this;

        listLibRequest.set = problem.path;
        listLibRequest.problemSource = problem.path;
        listLibRequest.xml_command = "renderProblem";


        if (!problem.data) {
            //if we haven't gotten this problem yet, ask for it
            $.post(webserviceURL, listLibRequest, function(data) {
                problem.data = data;
                callback(data);
            });
        }
    }
});

var ProblemView = Backbone.View.extend({
    tagName:"li",
    template: _.template($('#probem-template').html()),

    initialize: function(){
        this.model.on('change:data', this.render, this);
    },

    render: function(){
        var problem = this.model;
        var self = this;

        this.$el.html('<img src="/webwork2_files/images/ajax-loader.gif" alt="loading"/>');

        this.el.setAttribute('data-path', problem.get('path'));

        this.$el.draggable({
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

        this.el.addEventListener("mouseover", highlightSets, false);
        //newItem.addEventListener("mouseout", unHighlightSets, false);
        //nice async loading call :)
        problem.render(function(){self.$el.html(self.template(problem.toJSON()))});

        return this;
    }
});
