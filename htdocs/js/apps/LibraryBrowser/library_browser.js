
// #Library Browser 3
//
// This is the current iteration of the library browser for webwork.
// It's built out of models contained in the `webwork.*` framework that
// you can find in the `js/lib/webwork` folder.
//
// The idea was to use this as a proof of concept of how to write single page
// webapps for webwork out of a general client side framework quickly, easily
// and in a way that's maintainable.
//
// The javascript framework is currently written with extensibility in mind.
// So base models in the webwork.js file are added too and additional models are
// provided for different situations.  For instance since library browser is used
// by teachers we include the files in the `teacher` subdirectory and add in features
// like adding and remove problems from a sets ProblemList and browsing a Library.

//Start things off by wrapping everything in jquery so it will load after the dom is ready.
$(function () {

    //Since many of the views we'll define will all want to post alerts and messages to the same place
    //we define a global template and alert function for them.

    var alert_template = _.template('<div class="alert <%= classes %> fade in"><a class="close" data-dismiss="alert" href="#">×</a><%= message %></div>');

    //set up alerts to close
    $().alert();

    var alert = function(message, classes){
        $('#messages').html(alert_template({message: message, classes: classes}));
        setTimeout(function(){$(".alert").alert('close')}, 5000);
    };



    //##The problem View

    //A view defined for the browser app for the webwork Problem model.
    //There's no reason this same view couldn't be used in other pages almost as is.
    var ProblemView = Backbone.View.extend({
        //We want the problem to render in a `li` since it will be included in a list
        tagName:"li",
        //Add the 'problem' class to every problem
        //className: "problem",
        //This is the template for a problem, the html is defined in SetMaker3.pm
        template: _.template($('#problem-template').html()),

        //Register events that a problem's view should listen for,
        //in this case it removes the problem if the button with class 'remove' is clicked.
        events:{
            "click .remove": 'clear'
        },

        //In most model views initialize is used to set up listeners
        //on the views model.
        initialize:function () {
            this.model.on('change:data', this.render, this);
            if(!this.options.remove_display){
                this.options.remove_display = false;
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
            } else {
                this.$el.html('<img src="/webwork2_files/images/ajax-loader.gif" alt="loading"/>');
                problem.render();
            }

            this.el.id = this.model.cid;
            this.el.setAttribute('data-path', this.model.get('path'));


            return this;
        },

        clear: function(){
            this.model.collection.remove(this.model);
            this.model.clear();
        }
    });



    //##The library View
    var LibraryView = Backbone.View.extend({
        template:_.template($('#Library-template').html()),

        events:{
            "click .next_group": "loadNextGroup"
        },

        initialize: function(){
            var self = this;
            this.group_size = 25;
            this.model.get('problems').on('reset', this.render, this);
            this.model.get('problems').on('syncing', function(value){
                if(value){
                    $("[href=#"+self.model.get('name')+"]").addClass("syncing");
                } else {
                    $("[href=#"+self.model.get('name')+"]").removeClass("syncing");
                }
            }, this);
            this.model.get('problems').on('alert', function(message){alert(message);});

            if(!(this.model.get('problems').length > 0)){
                this.model.get('problems').fetch();
            }
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

            if(self.model.get('problems').syncing){
                $("[href=#"+self.model.get('name')+"]").addClass("syncing");
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
        //Define a new function loadNextGroup so that we can just load a few problems at once,
        //otherwise things get unwieldy :P
        loadNextGroup: function(){
            console.log("load more");
            console.log(this.startIndex);
            console.log(this.group_size);

            var problems = this.model.get('problems');
            console.log(problems.length);
            for(var i = 0; i < this.group_size && this.startIndex < problems.length; i++, this.startIndex++){
                console.log("adding a problem");
                var problem = problems.at(this.startIndex);
                var view = new ProblemView({model: problem, remove_display: true});
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
            //'change .list': 'lib_selected'
        },

        initialize:function () {
            var self = this;
            this.model.on("reset", this.render, this);
            this.model.on("add", this.addOne, this);
            this.model.on('alert', function(message){alert(message);}, this);
            this.model.on('syncing', function(value){
                if(value){
                    self.$el.addClass("syncing white");
                } else {
                    self.$el.removeClass("syncing white");
                }
            }, this);
            //not the strongest solution but it will do
            if(!(this.model.length > 0)){
                this.model.fetch();
            }
        },

        render:function () {

            var self = this;
            if(self.model.syncing){
                self.$el.addClass("syncing white");
            }
            this.$el.html(this.template({name: this.options.name}));
            self.$("."+this.options.name+".list").on('change', function(event){self.lib_selected(event)});
            this.addAll();
            return this;
        },

        addOne: function(lib){
            var self = this;
            var option = document.createElement("option")
            option.value = lib.cid;
            option.innerHTML = lib.get('name');
            this.$('.'+this.options.name + '.list').append(option);//what's the null?
        },

        addAll: function(){
            var self = this;
            if(this.model.length > 0){
                //should show number of problems in the bar
                this.model.each(function(lib){self.addOne(lib)});
            } else {
                this.$('.'+this.options.name+".list").css("display", "none");
            }
        },

        lib_selected:function (event) {
            var self = this;
            self.$el.removeClass("syncing white");
            var selectedLib = this.model.getByCid(event.target.value);
            if(selectedLib){
                var view = new LibraryListView({model:selectedLib.get('children'), name: selectedLib.cid});
                this.$('.'+this.options.name+".children").html(view.render().el);
                libToLoad = selectedLib;
            }
        }

    });


    //##The browse View
    var BrowseView = Backbone.View.extend({
        template:_.template($('#Library-template').html()),

        events:{
            "click .next_group": "loadNextGroup"
        },

        initialize: function(){
            var self = this;
            this.group_size = 25;
            this.model.get('problems').on('reset', this.render, this);
            this.model.get('problems').on('syncing', function(value){
                if(value){
                    $("[href=#"+self.model.get('name')+"]").addClass("syncing");
                } else {
                    $("[href=#"+self.model.get('name')+"]").removeClass("syncing");
                }
            }, this);
            this.model.get('problems').on('alert', function(message){alert(message);});

            if(!(this.model.get('problems').length > 0)){
                this.model.get('problems').fetch();
            }
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

            if(self.model.get('problems').syncing){
                $("[href=#"+self.model.get('name')+"]").addClass("syncing");
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
        //Define a new function loadNextGroup so that we can just load a few problems at once,
        //otherwise things get unwieldy :P
        loadNextGroup: function(){

            var problems = this.model.get('problems');
            console.log(problems.length);
            for(var i = 0; i < this.group_size && this.startIndex < problems.length; i++, this.startIndex++){
                console.log("adding a problem");
                var problem = problems.at(this.startIndex);
                var view = new ProblemView({model: problem, remove_display: true});
                this.$(".list").append(view.render().el);
            }

            if(!(this.model.get('problems').length > this.startIndex)){
                this.$(".next_group").css('display', "none");
            }
        }

    });

    var BrowseListView = Backbone.View.extend({
        tagName:'span',
        template:_.template($('#BrowseList-template').html()),

        events: {
            'change .list' : 'section_selected',
            'click .load_browse_problems': 'load_problems'
        },

        initialize:function () {
            var self = this;
            this.model.on("change:library_subjects", this.render, this);
            this.model.on("change:library_chapters", this.render, this);
            this.model.on("change:library_sections", this.render, this);
        },

        render:function () {
            
            var self = this;
            if(self.model.syncing){
                self.$el.addClass("syncing white");
            }
            this.$el.html(this.template(this.model.toJSON()));
            console.log(this.model.toJSON());
            return this;
        },
        
        load_problems: function(){
            var self = this;
            console.log('running search');
            this.model.go(function(problems){
                console.log(problems);
                var result = new webwork.BrowseResult({name: self.model.get('library_subject') + "_" + self.model.get('library_chapter') + "_" + self.model.get('library_section')});
                result.get('problems').reset(problems);
                var view = new BrowseView({model: result});
                view.render();
            });
        },

        section_selected:function (event) {
            var self = this;
            self.$el.removeClass("syncing white");
            /*get the value of the changed section and update the model..
            the rerender should happen automatically
            should be able to get which of the browseable catagories was changed by the
            value of the events input box?
            */
            this.model.set(event.target.id, event.target.value);
        }

    });


    //##The main Set view
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
            this.model.get('problems').on('alert', function(message){alert(message);});

            this.model.get('problems').on('syncing', function(value){
                if(value){
                    $("[href=#"+self.model.get('name')+"]").addClass("syncing");
                } else {
                    $("[href=#"+self.model.get('name')+"]").removeClass("syncing");
                }
            }, this);

        },

        render:function () {

            var self = this;
            if ($('#problems_container #' + this.model.get('name')).length == 0) {
                $('#problems_container').tabs('add', "#"+this.model.get('name'), this.model.get('name') + " (" + this.model.get('problems').length + ")"); //could move to an after?
                this.setElement(document.getElementById(this.model.get('name')));
            }

            this.$el.html(self.template(self.model.toJSON()));

            if(self.model.get('problems').syncing){
                $("[href=#"+self.model.get('name')+"]").addClass("syncing");
            }

            this.$('.list').sortable({
                axis:'y',
                start:function (event, ui) {
                    //self.previousOrder = $(this).sortable('toArray');
                },
                update:function (event, ui) {
                    //self.reorderProblems($(this).sortable('toArray'));
                    var newOrder = self.$('.list').sortable('toArray');
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
            var view = new ProblemView({model:problem, remove_display: false});
            var rendered_problem = view.render().el;
            this.$(".list").append(rendered_problem);
            this.$('.list').sortable('refresh');

        },

        addAll: function(){
            var self = this;
            this.model.get('problems').each(function(model){self.addOne(model)});
        }
    });

    //##The Set view for the setlists
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
            this.model.get('problems').on('alert', function(message){alert(message);});
            this.model.on('highlight', function(){console.log("highlight "+self.model.get('name')); self.$el.addClass("contains_problem")});
        },

        render:function () {
            var self = this;

            self.$el.html(self.template({name: self.model.get('name'), problem_count: self.model.get('problems').length}));
            self.$el.droppable({
                tolerance:'pointer',

                hoverClass:'drophover',

                drop:function (event, ui) {
                    //var newProblem = new webwork.Problem({path:ui.draggable.attr("data-path")});
                    self.model.get("problems").add({path:ui.draggable.attr("data-path")});
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

    //##The SetList view
    var SetListView = Backbone.View.extend({
        tagName:"ul",
        template:_.template($('#setList-template').html()),
        className:"nav nav-list",

        initialize:function () {
            var self = this;
            this.model.bind('add', function(model){self.addOne(model);}, this);
            this.model.bind('reset', function(){self.addAll()}, this);
            //this.model.bind('all', this.render, this);

            if(!(this.model.length > 0)){
                this.model.fetch();
            }
        },

        render:function () {
            var self = this;

            self.$el.html(self.template());

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


    //This is global in order not to confuse the poor select boxes..
    //They can never tell who went last :)
    var libToLoad = false;
    $("#load_problems").on("click", function(event){
        if(libToLoad){
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
            var self = this;

            //Some default ajax stuff we can keep it or not
            $(document).ajaxError(function(e, jqxhr, settings, exception) {
                alert(exception, "alert-error");
            });

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
                alert("missing hidden credentials: user "
                    + myUser + " session_key " + mySessionKey
                    + " courseID" + myCourseID, "alert-error");
            }


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


            //set up our models
            this.homeworkSets = new webwork.SetList;
            this.cardCatalog = new webwork.LibraryList;
            this.cardCatalog.defaultRequestObject.xml_command = "listLibraries";
            this.browser = new webwork.Browse;

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

            var cardCatalogView = new LibraryListView({model: this.cardCatalog, name: "root"});
            this.$("#CardCatalog").append(cardCatalogView.render().el);
            
            var browserView = new BrowseListView({model: this.browser});
            this.$("#Browser").append(browserView.render().el);
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

    //instantiate an instance of our app.
    var App = new LibraryBrowser;

});
