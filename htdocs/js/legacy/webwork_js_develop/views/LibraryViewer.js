define(['Backbone', 'underscore','LibraryList'], function(Backbone, _,LibraryList){
	//,function(Backbone,_){
    var LibraryTreeView = Backbone.View.extend({
    	initialize: function (){
    		_.bindAll(this,"render");
            var self = this;
            this.parent = this.options.parent;
            this.collection = new LibraryList();
            this.collection.fetch();

            this.collection.on("fetchSuccess", function () {
                console.log(self.collection);
                self.buildTreeView();
            });
    		this.render();

    	},
    	render: function(){
    		this.$el.html("This is the LibraryViewer");
            //var cardCatalogView = new LibraryListView({model: this.parent.cardCatalog, name: "root"});
            //this.$("#CardCatalog").append(cardCatalogView.render().el);

    	},
        buildTreeView: function (){
            var self = this;

            var opts = self.collection.map(function(lib){return "<option>" + lib.get("name") + "</option>";});
            this.$el.append("<select>" + opts + "</select>");
        }


    });


    return LibraryTreeView;

});
