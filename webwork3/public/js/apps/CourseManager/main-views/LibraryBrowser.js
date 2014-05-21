/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['backbone', 'underscore','views/MainView', 
        'views/library-views/LibrarySubjectView','views/library-views/LibraryDirectoryView',
        'views/library-views/LibrarySearchView','views/library-views/LocalLibraryView',
        'views/library-views/LibraryTextbookView','models/ProblemSet','moment','config','apps/util'], 
function(Backbone, _,MainView,LibrarySubjectView,LibraryDirectoryView, LibrarySearchView,LocalLibraryView,
    LibraryTextbookView,ProblemSet,moment,config,util){
    var LibraryBrowser = MainView.extend({
        messageTemplate: _.template($("#library-messages-template").html()),
    	initialize: function (options){
            MainView.prototype.initialize.call(this,options);
    		var self = this; 
            _.bindAll(this,'render','updateNumberOfProblems');

            this.currentViewname = "subjects";

            this.elements = {subjects: "library-subjects-tab",
                             directories: "library-directories-tab",
                             textbooks: "library-textbooks-tab",
                             localLibrary: "library-local-tab",
                             setDefinition: "set-definition-tab",
                             search: "library-search-tab"};

            this.dateSettings = util.pluckDateSettings(this.settings);


            //this.libraryProblemsView.on("update-num-problems",this.updateNumberOfProblems);

            this.views = {
                subjects  :  new LibrarySubjectView({libBrowserType: "subjects", problemSets: options.problemSets,
                                    settings: this.settings, messageTemplate: this.messageTemplate}),
                directories    :  new LibraryDirectoryView({libBrowserType: "directories", problemSets: options.problemSets,
                                    settings: this.settings,messageTemplate: this.messageTemplate}),
                textbooks    :  new LibraryTextbookView({libBrowserType: "textbooks", problemSets: options.problemSets,
                                    settings: this.settings,messageTemplate: this.messageTemplate}),
                localLibrary: new LocalLibraryView({libBrowserType: "localLibrary", problemSets: options.problemSets,
                                    settings: this.settings,messageTemplate: this.messageTemplate}),
                setDefinition: new LocalLibraryView({libBrowserType: "setDefinition", problemSets: options.problemSets,
                                    settings: this.settings,messageTemplate: this.messageTemplate}),
                search :  new LibrarySearchView({libBrowserType: "search", problemSets: options.problemSets,
                                    settings: this.settings,messageTemplate: this.messageTemplate})
            };
    	},
        events: {"show.bs.tab a[data-toggle='tab']": "changeView"},
    	render: function (){
            var self = this; 
        	this.$el.html(_.template($("#library-browser-template").html()));
            _.chain(this.elements).keys().each(function(key){
                self.views[key].setElement(self.$("#"+self.elements[key]));
            });
            var index = _(_.keys(this.views)).indexOf(this.currentViewname);
            this.$("#library-browser-tabs li:eq(" + index + ") a").tab("show");
            this.views[this.currentViewname].render()
                .libraryProblemsView.on("update-num-problems",this.updateNumberOfProblems);
            this.problemSets.trigger("hide-show-all-sets","show");
            MainView.prototype.render.apply(this);
            return this;
    	},
        getState: function() {
            return {subview: this.currentViewname};
        },
        setState: function(state){
            if(state){
                this.currentViewname = state.subview || "subjects";
                this.currentView = this.views[this.currentViewname];
            }
            return this;
        },
        getHelpTemplate: function(){
            return $("#library-help-template").html();
        },
        changeView: function(evt){
            var self = this;

            // search through the this.elements for selected tab
            var tabType = _(_(this.elements).invert()).pick($(evt.target).attr("href").substring(1)); 
            var viewType = _(tabType).values()[0];
            this.currentViewname = viewType;
            _(_.keys(this.views)).each(function(view){
                self.views[view].libraryProblemsView.off("update-num-problems");
            })
            this.views[viewType].libraryProblemsView.on("update-num-problems",this.updateNumberOfProblems);
            this.eventDispatcher.trigger("save-state");
            this.views[viewType].render();
        },
        sidepaneEvents: {
            "change-display-mode": function(evt) { this.views[this.currentViewname].changeDisplayMode(evt) },
            "change-target-set": function(opt) { 
                this.views[this.currentViewname].setTargetSet(_.isString(opt)? opt: $(opt.target).val());
            }, 
            "add-problem-set": function(_set_name){
                var _set = new ProblemSet({set_id: _set_name},this.dateSettings);
                _set.setDefaultDates(moment().add(10,"days")).set("assigned_users",[config.courseSettings.user]);
               this.views[this.currentViewname].allProblemSets.add(_set); 
            },
            "show-hide-tags": function(show_hide_button) {
                this.views[this.currentViewname].libraryProblemsView.toggleTags(show_hide_button);
            },
            "show-hide-path": function(button) {
                this.views[this.currentViewname].libraryProblemsView.toggleShowPath(button);
            },
            "goto-problem-set": function(_setName){
                this.eventDispatcher.trigger("show-problem-set",_setName);
            }

        },
        updateNumberOfProblems: function (text) {
            this.headerView.$(".number-of-problems").html(text);
        }
    });

    return LibraryBrowser;
});
