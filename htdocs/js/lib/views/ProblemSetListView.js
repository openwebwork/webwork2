/**
*  This view is the interface to the Library Tree and allows the user to easier navigate the Library. 
*
*  The this.collection object is a ProblemSetList
*  The following must be passed on initialization
*       users:  A UserList Backbone.Collection
*       problemSets: A ProblemSet Backbone.Colleciton
*
*/

define(['backbone', 'underscore','models/ProblemSetList','models/ProblemSet','config',
            'views/ModalView', 'jquery-truncate'], 
function(Backbone, _,ProblemSetList,ProblemSet,config,ModalView){
	
    var ProblemSetListView = Backbone.View.extend({

    	initialize: function (options){
    		_.bindAll(this,"render");
            var self = this;

            this.setViewTemplate = $("#set-view-template").html();
            this.problemSets = options.problemSets; 
            this.users = options.users; 

            this.problemSets.on("add",this.render);
            this.problemSets.on("remove",this.render);
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
            $("#problem-set-list-container").height($(window).height()-200);
            this.$(".prob-set-container").height($(window).height()-260);
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