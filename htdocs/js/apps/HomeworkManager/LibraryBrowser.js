/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['Backbone', 'underscore','../../lib/views/LibraryView'], 
function(Backbone, _,LibraryView){
    var LibraryBrowser = Backbone.View.extend({
        className: "lib-browser",
    	tagName: "td",
    	initialize: function (){
    		var self = this; 
            _.bindAll(this,'render');
            _.extend(this,this.options);

            this.elements = {allLibSubjects: "library-subjects-tab",
                             allLibraries: "library-directories-tab",
                             searchLibraries: "library-search-tab"};

            this.views = {
                allLibSubjects  :  new LibraryView({libBrowserType: "allLibSubjects", errorPane: this.hwManager.errorPane, 
                                            problemSets: this.hwManager.problemSets}),
                allLibraries    :  new LibraryView({libBrowserType: "allLibraries", errorPane: this.hwManager.errorPane, 
                                            problemSets: this.hwManager.problemSets}),
                searchLibraries :  new LibraryView({libBrowserType: "searchLibraries", errorPane: this.hwManager.errorPane, 
                                            problemSets: this.hwManager.problemSets})
            }

/*            this.hwManager.problemSets.each(function(set){
                set.on('add',function(model){
                    console.log(model);
                });
            });*/
            
    	},
    	render: function (){
            var self = this; 
        	this.$el.html(_.template($("#library-browser-template").html()));
            _.chain(this.elements).keys().each(function(key){
                self.views[key].setElement(self.$("#"+self.elements[key]));
            });
            this.views.allLibSubjects.render();
    	},
        events: {"shown a[data-toggle='tab']": "changeView"},
        changeView: function(evt){

            var tabType = _(_(this.elements).invert()).pick($(evt.target).attr("href").substring(1)); // this search through the this.elements for selected tab
            this.views[_(tabType).values()[0]].render();
        }


    });

    return LibraryBrowser;
});
