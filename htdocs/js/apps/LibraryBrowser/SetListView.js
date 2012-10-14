define(['Backbone', 'underscore', './SetNameView'], function(Backbone, _, SetNameView){
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
	return SetListView;
});