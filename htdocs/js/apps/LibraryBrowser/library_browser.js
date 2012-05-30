
/**
 * Global stuff
 */
// undo and redo functions
var undoing = false;
var undo_stack = new Array();
var redo_stack = new Array();

//might be able to move this to LibraryBrowser later with event listeners
function showErrorResponse(data) {
    var myWindow = window.open('', '', 'width=500,height=800');
    myWindow.document.write(data);
    myWindow.focus();
}

$(function () {
    // get usernames and keys from hidden variables and set up webwork object:
    var myUser = document.getElementById("hidden_user").value;
    var mySessionKey = document.getElementById("hidden_key").value;
    var myCourseID = document.getElementById("hidden_courseID").value;
    // check to make sure that our credentials are available.
    if (myUser && mySessionKey && myCourseID) {
        webwork.requestObject.user = myUser;
        webwork.requestObject.session_key = mySessionKey;
        webwork.requestObject.courseID = myCourseID;
    } else {
        webwork.alert("missing hidden credentials: user "
            + myUser + " session_key " + mySessionKey
            + " courseID" + myCourseID, "alert-error");
    }


    /*******************************************************************************
     * The problem object
     ******************************************************************************/
// object



    var ProblemView = Backbone.View.extend({
        tagName:"li",
        className: "problem",
        template: _.template($('#problem-template').html()),

        events:{
            "click .remove": 'clear'
        },

        initialize:function () {
            this.model.on('change:data', this.render, this);
            if(!this.options.remove_display){
                this.options.remove_display = "block";
            }
            this.model.on('destroy', this.remove, this);
        },

        render:function () {
            var problem = this.model;
            var self = this;

            if(problem.get('data')){
                var jsonInfo = this.model.toJSON();
                _.extend(jsonInfo, self.options);
                this.$el.html(this.template(jsonInfo));
            } else {
                this.$el.html('<img src="/webwork2_files/images/ajax-loader.gif" alt="loading"/>');
                problem.render();
            }

            this.el.setAttribute('data-path', problem.get('path'));
            this.el.id = this.model.cid;
            this.$el.draggable({
                helper:'clone',
                revert:true,
                handle:'.problem',
                appendTo:'body',
                cursorAt:{
                    top:0,
                    left:0
                },
                opacity:0.35
            });


            return this;
        },

        clear: function(){
            console.log("clear");
            this.model.collection.removeProblem(this.model);
            this.model.clear();
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

    //search was here


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



    var LibraryView = Backbone.View.extend({
        template:_.template($('#Library-template').html()),

        events:{
            "click .next_group": "loadNextGroup"
        },

        initialize: function(){
            this.group_size = 25;
            this.model.get('problems').on('reset', this.render, this);
        },

        render: function(){

            var self = this;

            if ($('#problems_container #' + this.model.get('name')).length == 0) {
                $('#problems_container').tabs('add', "#"+this.model.get('name'), this.model.get('name') + " (" + this.model.get('problems').length + ")"); //could move to an after?
                this.setElement(document.getElementById(this.model.get('name')));
            } else {
                //select
                $('#problems_container').tabs('select', this.model.get('name'));
                $("[href=#"+this.model.get('name')+"]").html(this.model.get('name') + " (" + this.model.get('problems').length + ")");
            }

            this.$el.addClass("library_tab");

            this.startIndex = 0;

            var jsonInfo = this.model.toJSON();
            jsonInfo['group_size'] = this.group_size;

            jsonInfo['enough_problems'] = (this.model.get('problems').length > this.startIndex)? "block" : "none";

            this.$el.html(this.template(jsonInfo));

            this.loadNextGroup();

            return this;
        },

        loadNextGroup: function(){
            console.log("load more");
            console.log(this.startIndex);
            console.log(this.group_size);

            var problems = this.model.get('problems');
            console.log(problems.length);
            for(var i = 0; i < this.group_size && this.startIndex < problems.length; i++, this.startIndex++){
                console.log("adding a problem");
                var problem = problems.at(this.startIndex);
                var view = new ProblemView({model: problem, remove_display: "none"});
                this.$(".list").append(view.render().el);
            }

            if(!(this.model.get('problems').length > this.startIndex)){
                this.$(".next_group").css('display', "none");
            }
        }

    });

    var LibraryListView = Backbone.View.extend({
        tagName:'span',
        template:_.template($('#LibraryList-template').html()),

        events: {
            'change .list': 'lib_selected'
        },

        initialize:function () {
            this.model.on("reset", this.render, this);
            this.model.on("add", this.render, this);
        },

        render:function () {

            var self = this;

            if(self.model.length > 0){
                //should show number of problems in the bar

                this.$el.html(this.template(this.model.toJSON));

                this.model.each(function (lib) {
                    var option = document.createElement("option")
                    option.value = lib.cid;
                    option.innerHTML = lib.get('name');
                    self.$('.list').append(option);//what's the null?
                });
            }
            return this;
        },

        lib_selected:function (event) {
            var self = this;
            var selectedLib = this.model.getByCid(event.target.value);
            console.log(selectedLib);
            if(selectedLib){
                selectedLib.get('children').fetch();
                var view = new LibraryListView({model:selectedLib.get('children')});
                this.$(".children").html(view.render().el);
                libToLoad = selectedLib;
            }
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





//full set view, renders all problems etc
    var SetView = Backbone.View.extend({
        template:_.template($('#set-template').html()),
        events:{
        },

        initialize:function () {
            var self = this;
            this.model.get('problems').on('add', function(model){self.addOne(model)}, this);
            this.model.get('problems').on('reset', function(){self.addAll();}, this);
            this.model.get('problems').on('all', function(){
                $("[href=#"+self.model.get('name')+"]").html(self.model.get('name') + " (" + self.model.get('problems').length + ")");
            }, this);
        },

        render:function () {

            //Template and fix up, that was just ugly
            var self = this;
            if ($('#problems_container #' + this.model.get('name')).length == 0) {
                $('#problems_container').tabs('add', "#"+this.model.get('name'), this.model.get('name') + " (" + this.model.get('problems').length + ")"); //could move to an after?
                this.setElement(document.getElementById(this.model.get('name')));
            }

            this.$el.html(self.template(self.model.toJSON()));

            //this.$el.id = this.model.get('name');
            //might have to refresh
            this.$('.list').sortable({
                //handle: $('.handle'),
                axis:'y',
                start:function (event, ui) {
                    console.log("handle test");
                    //self.previousOrder = $(this).sortable('toArray');
                },
                update:function (event, ui) {
                    //self.reorderProblems($(this).sortable('toArray'));
                    var newOrder = self.$('.list').sortable('toArray');
                    console.log(newOrder);
                    for(var i = 0; i < newOrder.length; i++){
                        var problem = self.model.get('problems').getByCid(newOrder[i]);
                        if(problem){
                            problem.set('place', i);
                        }
                    }

                    self.model.get('problems').reorder();
                }
            });

            this.addAll();
            return this;
        },

        addOne: function(problem){
            var view = new ProblemView({model:problem});
            var rendered_problem = view.render().el;
            console.log(rendered_problem);
            console.log(this.$(".list"));
            this.$(".list").append(rendered_problem);
            this.$('.list').sortable('refresh');

        },

        addAll: function(){
            var self = this;
            this.model.get('problems').each(function(model){self.addOne(model)});
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


    var SetNameView = Backbone.View.extend({
        tagName:"li",
        template:_.template($('#setName-template').html()),

        events:{
            'click':'view'
        },

        initialize:function () {
            this.bigView = false;
            var self = this;
            this.model.get('problems').on('all', function(){self.render()}, this);
            this.model.on('highlight', function(){self.$el.addClass("contains_problem")});
        },

        render:function () {
            var self = this;

            self.$el.html(self.template({name: self.model.get('name'), problem_count: self.model.get('problems').length}));
            self.$el.droppable({
                tolerance:'pointer',

                hoverClass:'drophover',

                drop:function (event, ui) {
                    var newProblem = new webwork.Problem({path:ui.draggable.attr("data-path")});
                    self.model.get("problems").addProblem(newProblem);
                }
            });

            return this;
        },

        view:function () {
            console.log("clicked " + this.model.get('name'));
            if ($('#problems_container #' + this.model.get('name')).length > 0) {
                $('#problems_container').tabs('select', this.model.get('name'));
            } else {
                console.log("rendering the set");
                var view = new SetView({model:this.model});
                //$('#problems_container').append(view.render().el);
                view.render();
            }
            //render the full tab thing, or switch to it
        }
    });

    /*******************************************************************************
     * SetList object needed variables: sets, displaybox, needed functions: create
     * set
     */




    var SetListView = Backbone.View.extend({
        tagName:"ul",
        template:_.template($('#setList-template').html()),
        className:"nav nav-list",

        initialize:function () {
            var self = this;
            this.model.bind('add', function(model){self.addOne(model);}, this);
            this.model.bind('reset', function(){self.addAll()}, this);
            //this.model.bind('all', this.render, this);
            this.render();
        },

        render:function () {
            var self = this;

            self.$el.html(self.template());

            /*this.$(".new_problem_set").droppable({
                tolerance:'pointer',

                hoverClass:'drophover',

                drop:function (event, ui) {
                    //Create a new set
                }
            });*/

            //this.addAll();
            return this;
        },

        addOne:function (added_set) {
            var view = new SetNameView({model: added_set});
            this.$el.append(view.render().el);
        },

        addAll:function () {
            var self = this;
            this.model.each(function(model){self.addOne(model)});
        }
        /*
         startCreate: function(){
         this.$("#dialog").dialog('open');
         }
         */
    });


    /*This is global in order not to confuse the poor select boxes..
      They can never tell who went last :)
     */
    var libToLoad = false;
    $("#load_problems").on("click", function(event){
        console.log(libToLoad);
        if(libToLoad){
            libToLoad.get('problems').fetch();
            var view = new LibraryView({model: libToLoad});
            view.render();
        }
    });

    //The APP!! yay!!
    var LibraryBrowser = Backbone.View.extend({
        el:$('#app_box'),

        events:{
            "click #undo_button":"undo",
            "click #redo_button":"redo",
            "hover .problem": "highlightSets",
            "click #create_set": "createHomeworkSet"
        },

        initialize:function () {
            //Set up the tabbed set lists and libraries:
            $("#problems_container").tabs(
                {
                    closable:true,
                    add:function (event, ui) {
                        //document.getElementById("library_link").removeChild(document.getElementById("library_link").lastChild);
                        console.log("adding a tab");
                        $('#problems_container').tabs('select', '#' + ui.panel.id);
                        $(".ww_selected").removeClass("ww_selected");// probably reduntant but I want to make sure nothing stays selected
                    },
                    create:function (event, ui) {
                        //document.getElementById("library_link").removeChild(document.getElementById("library_link").lastChild);
                        $(".ww_selected").removeClass("ww_selected");
                    },
                    select:function (event, ui) {
                        $(".ww_selected").removeClass("ww_selected");
                    },
                    remove:function (event, ui) {
                        //document.getElementById("library_link").removeChild(document.getElementById("library_link").lastChild);
                        $(".ww_selected").removeClass("ww_selected");
                    }
                });
            $("#problem_sets_container").resizable({
                cursor:'move',
                //animate: true,
                //ghost: true,
                delay:0
            });


            //set up our models
            this.homeworkSets = new webwork.SetList;
            this.cardCatalog = new webwork.LibraryList;
            this.cardCatalog.defaultRequestObject.xml_command = "listLibraries"

            this.homeworkSets.fetch();
            this.cardCatalog.fetch();

            this.render();
        },

        createHomeworkSet: function(){
            if(this.$("#dialog_text").val()){
                this.homeworkSets.create({name: this.$("#dialog_text").val()});
            }
            this.$("#dialog_text").val('');
        },

        highlightSets: function(event) {
            switch(event.type){
                case "mouseenter":
                    //console.log(this.getAttribute("data-path"));
                    var problemPath = event.currentTarget.getAttribute("data-path");

                    this.homeworkSets.each(function(set){
                        if(set.get('problems').find(function(problem){return problem.get('path') == problemPath})){
                            set.trigger('highlight');
                        }
                    });
                    break;
                default:
                    $(".contains_problem").removeClass("contains_problem");
                    break;
            }

        },

        render: function(){
            var homeworkSetsView = new SetListView({model: this.homeworkSets});
            this.$("#homework_sets_container").append(homeworkSetsView.render().el);

            var cardCatalogView = new LibraryListView({model: this.cardCatalog});
            this.$("#CardCatalog").append(cardCatalogView.render().el);
        },

        undo:function () {
            // pop the stack and call the function, that's it
            var undoFunc = undo_stack.pop();
            undoing = true;
            undoFunc();
        },

        redo:function () {
            var redoFunc = redo_stack.pop();
            redoFunc();
        }
    });


    var App = new LibraryBrowser;

});
