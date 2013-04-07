define(['Backbone', 'underscore', 'BrowseView', '../../lib/BrowseResult'], function(Backbone, _, BrowseView, BrowseResult){
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
                var result = new BrowseResult({name: self.model.get('library_subject') + "_" + self.model.get('library_chapter') + "_" + self.model.get('library_section')});
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
	return BrowseListView;
});