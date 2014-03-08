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
           'main-views/AssignmentCalendar', 'views/ModalView','main-views/LibraryBrowser', 'jquery-truncate'], 
function(Backbone, _,ProblemSetList,ProblemSet,config,SidePane,AssignmentCalendar,ModalView,LibraryBrowser){
	
    var ProblemSetListView = SidePane.extend({

    	initialize: function (options){
    		_.bindAll(this,"render");
            var self = this;

            this.setViewTemplate = $("#set-view-template").html();
            this.problemSets = options.problemSets; 
            this.users = options.users; 

            this.problemSets.on("add remove sort",this.render);
        },
        render: function ()
        {
            var self = this;
            
            this.$el.html($("#problem-set-list-template").html());
            this.problemSets.each(function (_model) {
                self.$("#probSetList").append((new ProblemSetView({model: _model, template: self.setViewTemplate,
                        numUsers: self.users.length, problemSets: self.problemSets})).render().el);
            });
            
            self.$(".set-name").truncate({width: "150"}); //if the Problem Set Names are too long.  
           

           // move the HTML below to the template file.
            if (this.problemSets.size() === 0 ) {
                $("#set-list:nth-child(1)").after("<div id='zeroShown'>0 of 0 Sets Shown</div>")
            }
            $("#problemSets").height($(window).height()-80);
            this.$(".prob-set-container").height($(window).height()-150);
            return this;
        },
        events: {"click a.sort-problem-set-option": "resort"},
        resort: function(evt){
            this.problemSets.setSortField($(evt.target).data("sortfield")).sort();
        },
        setMainView: function(view){
            this.constructor.__super__.setMainView.call(this,view);  // Call  SidePane.setMainView();
            this.$(".problem-set").draggable({disabled: true}).droppable({disabled: true});
            if(view instanceof AssignmentCalendar){
                this.$(".problem-set").draggable({ 
                    disabled: false,  
                    revert: true, 
                    scroll: false, 
                    helper: "clone",
                    appendTo: "body",
                    cursorAt: {left: 10, top: 10}
                });
            } 
            if(view instanceof LibraryBrowser){
                this.$(".problem-set").droppable({
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
                        var prob = self.views.libraryBrowser.views[source].problemList
                                            .findWhere({source_file: $(ui.draggable).data("path")});
                        set.addProblem(prob);
                    }
                });
            }
            return this;
        }
    });

    var ProblemSetView = Backbone.View.extend({
        tagName: "li",
        initialize: function(options) {
            _.bindAll(this,"render","showProblemSet");
            this.$el.addClass("problem-set").addClass("btn btn-default btn-sm");
            this.template = options.template; 
            this.numUsers = options.numUsers;
            this.problemSets = options.problemSets;
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
                    if(vals[0]==0){
                        $el.removeClass("set-reduced-credit");
                    } else {
                        $el.addClass("set-reduced-credit");
                    }
                    if(vals[1]==0){
                        $el.removeClass("set-visible");
                    } else {
                        $el.addClass("set-visible");
                    }
                }}

        },
        showProblemSet: function (evt) {
            var set = this.problemSets.findWhere({set_id: this.model.get("set_id")})
            set.trigger("show",set);
        }

    });

    return ProblemSetListView;

});