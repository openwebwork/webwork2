/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['Backbone', 'underscore','./ProblemListView','../models/ProblemList','./LibraryTreeView'], 
function(Backbone, _,ProblemListView, ProblemList,LibraryTreeView){
    var LibraryView = Backbone.View.extend({
        className: "lib-browser",
    	tagName: "td",
    	initialize: function (){
    		var self = this; 
            _.bindAll(this,'render','changeView','showProblems');
            _.extend(this,this.options);
            this.dispatcher = {};
            _.extend(this.dispatcher, Backbone.Events);

    		this.dispatcher.on("load-problems", function(path) { self.loadProblems(path);});

            // The following needs to be changed it's being called when the problem set list is shown.  

            this.dispatcher.on("num-problems-shown", function(num){
                    if (self.libraryTreeView){
                        self.libraryTreeView.$("span.library-tree-right").html(num + " of " + self.problemList.size() + " shown");
                    }
            });
            this.libraryTreeView = new LibraryTreeView({parent: self, type: this.libBrowserType});

            
    	},
    	events: {"change #library-selector": "changeView"},
    	render: function (){
            var self = this;
            var allProblemSets = this.parent.parent.problemSets;



    		this.$el.html(_.template($("#library-view-template").html()));
            this.libraryTreeView.render();
            this.$(".library-viewer").append(this.libraryTreeView.el);

    		this.$(".lib-problem-viewer").height(0.8*screen.height);

            var targetSetSelect = self.$(".target-set")
    		
            allProblemSets.each(function(set){
                    targetSetSelect.append(_.template($("#target-set-template").html(),set.attributes)) });

    	},
        showProblems: function (){
            console.log("in showProblems");
            var plv = new ProblemListView({el: this.$(".lib-problem-viewer"), type: this.libBrowserType, 
                                            parent: this.parent, collection: this.problemList, showPoints: false,
                                            reorderable: false, deletable: false, draggable: true});
            plv.render();
        },
    	changeView: function (evt) {
    		var self = this;
            $(".lib-problem-viewer").html("");

    	},
    	loadProblems: function (_path)
    	{
    		console.log(_path);
			this.problemList = new ProblemList({path:  _path, type: "Library Problems"});
            this.problemList.on("fetchSuccess",this.showProblems,this);
    	}

    });

    return LibraryView;
});
