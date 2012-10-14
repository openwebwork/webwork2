define(['Backbone', 'underscore', './LibraryView'], function(Backbone, _, LibraryView){
	//This is global in order not to confuse the poor select boxes..
    //They can never tell who went last :)
    var libToLoad = false;
    $("#load_problems").on("click", function(event){
        if(libToLoad){
            var view = new LibraryView({model: libToLoad});
            view.render();

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
	return LibraryListView;
});