/**
*  This view is the interface to the Library Tree and allows the user to easier navigate the Library. 
*
*  The this.collection object is a ProblemSetList
*  The following must be passed on initialization
*       users:  A UserList Backbone.Collection
*       problemSets: A ProblemSet Backbone.Colleciton
*
*/

define(['Backbone', 'underscore','models/ProblemSetList','models/ProblemSet','config',
            'views/ModalView', 'jquery-truncate'], 
function(Backbone, _,ProblemSetList,ProblemSet,config,ModalView){
	
    var ProblemSetListView = Backbone.View.extend({

    	initialize: function (){
    		_.bindAll(this,"render");
            var self = this;

            this.setViewTemplate = $("#set-view-template").html();
            this.template = _.template($("#problem-set-list-template").html());
            this.problemSets = this.options.problemSets; 
            this.users = this.options.users; 

            this.problemSets.on("add",this.render);
            this.problemSets.on("remove",this.render);
        },
        render: function ()
        {
            var self = this;
            console.log("in PSLV render");
            
            this.$el.html(this.template({loading: false}));
            this.problemSets.each(function (_model) {
                self.$("#probSetList").append((new ProblemSetView({model: _model, template: self.setViewTemplate,
                        numUsers: self.users.length, problemSets: self.options.problemSets})).render().el);
            });
            var _width = self.$el.width() - 70; 
            self.$(".set-name").truncate({width: _width}); //if the Problem Set Names are too long.  
           
            if (this.problemSets.size() === 0 ) {
                $("#set-list:nth-child(1)").after("<div id='zeroShown'>0 of 0 Sets Shown</div>")
            }

            //self.$(".prob-set-container").height($(window).height()*.80);
        }
    });

    var ProblemSetView = Backbone.View.extend({
        tagName: "li",
        initialize: function() {
            _.bindAll(this,"render","showProblemSet");
            this.$el.addClass("problem-set").addClass("btn").addClass("btn-small");
            this.template = this.options.template; 
            this.numUsers = this.options.numUsers;
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
            var set = this.options.problemSets.findWhere({set_id: this.model.get("set_id")})
            set.trigger("show",set);
        }

    });

    return ProblemSetListView;

});