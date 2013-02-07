/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['Backbone', 'underscore',
    '../../lib/webwork/views/ProblemListView',
	'../../lib/webwork/models/ProblemList',
	'../../lib/webwork/views/LibraryTreeView'], 
function(Backbone, _,ProblemListView, ProblemList,LibraryTreeView){
    var LibraryBrowser = Backbone.View.extend({
        className: "lib-browser",
    	tagName: "td",
    	initialize: function (){
    		var self = this; 
            _.bindAll(this,'render','changeView','showProblems');
            _.extend(this,this.options);

    		this.render();
            this.dispatcher = {};
            _.extend(this.dispatcher, Backbone.Events);

    		this.dispatcher.on("load-problems", function(path) { self.loadProblems(path);});

            // The following needs to be changed it's being called when the problem set list is shown.  

            this.dispatcher.on("num-problems-shown", function(num){
                    if (self.libraryTreeView){
                        self.libraryTreeView.$("span.library-tree-right").html(num + " of " + self.problemList.size() + " shown");
                    }
            });

            
    	},
    	events: {"change #library-selector": "changeView"},
    	render: function (){
            var self = this;
    		this.$el.html(_.template($("#library-browser-template").html()));

            console.log(this.id);
            switch(this.id){
                case "view-all-libraries":
                    this.type = "libDirectoryBrowser";
                    this.libraryTreeView = new LibraryTreeView({parent: self, type: "directory-tree"});
                    self.$(".library-viewer").append(this.libraryTreeView.el);
                    break;
                case "view-all-subjects":
                    this.type = "libSubjectBrowser";
                    this.libraryTreeView = new LibraryTreeView({parent: self, type: "subject-tree"});
                    self.$(".library-viewer").append(this.libraryTreeView.el);
                    break;
                case "search-libraries":
                case "view-local-libraries":
                    break;

            }

    		this.$(".lib-problem-viewer").height(0.8*screen.height);
    		

    	},
        showProblems: function (){
            console.log("in showProblems");
            var plv = new ProblemListView({el: this.$(".lib-problem-viewer"), type: this.type, 
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

    return LibraryBrowser;
});
