/**
*  This view is the interface to the Library Tree and allows the user to easier navigate the Library. 
*
*  The this.collection object is a ProblemSetList
*  The following must be passed on initialization
*       users:  A UserList Backbone.Collection
*       problemSets: A ProblemSet Backbone.Colleciton
*
*/

define(['backbone', 'underscore','models/ProblemSetList','models/ProblemSet','config','views/SidePane',
           'main-views/AssignmentCalendar', 'views/ModalView','main-views/LibraryBrowser'], 
function(Backbone, _,ProblemSetList,ProblemSet,config,SidePane,AssignmentCalendar,ModalView,LibraryBrowser){
	
    var ProblemSetListView = SidePane.extend({

    	initialize: function (options){
    		_.bindAll(this,"render");
            var self = this;

            this.setViewTemplate = $("#set-view-template").html();
            this.problemSets = options.problemSets; 
            this.users = options.users; 
            this.settings = options.settings;

            this.problemSets.on("add remove sort",this.render);
            console.log(this.problemSets.pluck("set_id"));
            console.log(this.problemSets.pluck("enable_reduced_scoring"));
            console.log(this.problemSets.pluck("visible"));
        },
        render: function ()
        {
            var self = this;
            if(!this.mainView){ // if this isn't a sidepane 
                return;
            }
            this.$el.html($("#problem-set-list-template").html());
            var ul = this.$(".btn-group-vertical");
            //var ul = this.$(".prob-set-container ul");
            this.problemSets.each(function (_model) {
                ul.append((new ProblemSetView({model: _model, template: self.setViewTemplate,
                        numUsers: self.users.length, problemSets: self.problemSets,
                        eventDispatcher: self.mainView.eventDispatcher,
                        settings: self.settings})).render().el);
            });

           // move the HTML below to the template file.
            if (this.problemSets.size() === 0 ) {
                $("#set-list:nth-child(1)").after("<div id='zeroShown'>0 of 0 Sets Shown</div>")
            }
            this.setDragDrop();
            SidePane.prototype.render.apply(this);
            return this;
        },
        events: {"click a.sort-problem-set-option": "resort"},
        resort: function(evt){
            this.problemSets.setSortField($(evt.target).data("sortfield")).sort();
        },
        setMainView: function(view){
            SidePane.prototype.setMainView.call(this,view);  // Call  SidePane.setMainView();
            return this;
        },
        setDragDrop: function(){
            var self = this;

            // The following allows a problem set (on the sidepane to be dragged onto the Calendar)
            if(this.mainView instanceof AssignmentCalendar){
                this.$(".sidepane-problem-set").draggable({ 
                    disabled: false,  
                    revert: true, 
                    scroll: false,
                    cancel: false, 
                    helper: "clone",
                    appendTo: "body",
                    cursorAt: {left: 10, top: 10}
                });
            } else {
                this.$(".problem-set.ui-draggable").draggable("destroy");
            }
            if(this.mainView instanceof LibraryBrowser){
                this.$(".sidepane-problem-set").droppable({
                    disabled: false,
                    hoverClass: "btn-info",
                    accept: ".problem",
                    tolerance: "pointer",
                    drop: function( evt, ui ) { 
                        console.log("Adding a Problem to HW set " + $(evt.target).data("setname"));
                        console.log($(ui.draggable).data("path"));
                        var source = $(ui.draggable).data("source");
                        console.log(source);
                        var set = self.problemSets.findWhere({set_id: $(evt.target).data("setname")})
                        var prob = self.mainView.views[source].problemList
                                            .findWhere({source_file: $(ui.draggable).data("path")});
                        set.addProblem(prob);
                    }
                });
            } else {
                this.$(".problem-set.ui-droppable").droppable("destroy");
            }
        }
    });

    var ProblemSetView = Backbone.View.extend({
        tagName: "button",
        className: "btn btn-default sidepane-problem-set",
        initialize: function(options) {
            _.bindAll(this,"render","showProblemSet");
            this.$el.addClass("btn btn-default btn-sm");
            this.template = options.template; 
            this.numUsers = options.numUsers;
            this.problemSets = options.problemSets;
            this.eventDispatcher = options.eventDispatcher;
            this.settings = options.settings;
        },
        render: function(){
            this.$el.html(this.template);
            this.$el.data("setname",this.model.get("set_id"));
            this.stickit();
            return this;
        },
        events: {"click": "showProblemSet"},
        bindings: {".set-name": "set_id", 
            ".num-users": { observe: ["assigned_users", "problems"],  
                onGet: function(vals) { return "(" +vals[0].length + "/" + this.numUsers 
                        + ";" + vals[1].length + ")"; }},  // prints the assigned users and the number of problems.
            ":el": { observe: ["enable_reduced_scoring","visible"],
                update: function($el, vals, model, options) { 
                    if(vals[0]){
                        $el.addClass("set-reduced-scoring");
                    } else {
                        $el.removeClass("set-reduced-scoring");
                    }
                    if(vals[1]){
                        $el.addClass("set-visible").removeClass("set-not-visible");
                    } else {
                        $el.addClass("set-not-visible").removeClass("set-visible");
                    }
                    if(! this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")) {
                        $el.removeClass("set-reduced-scoring");
                    }
                }}

        },
        showProblemSet: function (evt) {
            this.eventDispatcher.trigger("show-problem-set",this.model.get("set_id"));
        }

    });

    return ProblemSetListView;

});