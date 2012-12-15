define(['Backbone', 'underscore', './ProblemView'], function(Backbone, _, ProblemView){
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
	return LibraryView;
});