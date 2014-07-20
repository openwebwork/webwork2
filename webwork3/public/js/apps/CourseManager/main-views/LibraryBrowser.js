/*
*  This is the main view for the Library Browser within the the Homework Manager.  
*
*  
*/ 


define(['backbone', 'underscore','views/TabbedMainView', 
        'views/library-views/LibrarySubjectView','views/library-views/LibraryDirectoryView',
        'views/library-views/LibrarySearchView','views/library-views/LocalLibraryView',
        'views/library-views/LibraryTextbookView','models/ProblemSet','moment','config','apps/util'], 
function(Backbone, _,TabbedMainView,LibrarySubjectView,LibraryDirectoryView, LibrarySearchView,LocalLibraryView,
    LibraryTextbookView,ProblemSet,moment,config,util){
    var LibraryBrowser = TabbedMainView.extend({
        messageTemplate: _.template($("#library-messages-template").html()),
    	initialize: function (options){
    		var self = this; 
            _.bindAll(this,'render','updateNumberOfProblems');
            this.dateSettings = util.pluckDateSettings(options.settings);
            var viewOptions = {problemSets: options.problemSets,settings: options.settings, 
                    messageTemplate: this.messageTemplate, eventDispatcher: options.eventDispatcher};
            options.views = {
                subjects : new LibrarySubjectView(_.extend(_.clone(viewOptions),{libBrowserType: "subjects"})),
                directories : new LibraryDirectoryView(_.extend(_.clone(viewOptions),{libBrowserType: "directories"})),
                textbooks : new LibraryTextbookView(_.extend(_.clone(viewOptions),{libBrowserType: "textbooks"})),
                localLibrary : new LocalLibraryView(_.extend(_.clone(viewOptions),{libBrowserType: "localLibrary"})),
                setDefinition : new LocalLibraryView(_.extend(_.clone(viewOptions),{libBrowserType: "setDefinition"})),
                search :  new LibrarySearchView(_.extend(_.clone(viewOptions),{libBrowserType: "search"})),
            };
            options.views.setDefinition.viewName = "Set Defn. files";
            TabbedMainView.prototype.initialize.call(this,options)
    	},
        events: {"show.bs.tab a[data-toggle='tab']": "changeView"},
    	render: function (){
            this.$el.empty();
        	//this.$el.html(_.template($("#library-browser-template").html()));
            TabbedMainView.prototype.render.call(this);            
            return this;
    	},
        getHelpTemplate: function(){
            return $("#library-help-template").html();
        },
        sidebarEvents: {
            "change-display-mode": function(evt) { this.views[this.currentViewName].changeDisplayMode(evt) },
            "change-target-set": function(opt) { 
                this.views[this.currentViewName].setTargetSet(_.isString(opt)? opt: $(opt.target).val());
            }, 
            "add-problem-set": function(_set_name){
                var _set = new ProblemSet({set_id: _set_name},this.dateSettings);
                _set.setDefaultDates(moment().add(10,"days")).set("assigned_users",[config.courseSettings.user]);
               this.views[this.currentViewName].allProblemSets.add(_set); 
            },
            "show-hide-tags": function(show_hide_button) {
                this.views[this.currentViewName].libraryProblemsView.toggleTags(show_hide_button);
            },
            "show-hide-path": function(button) {
                this.views[this.currentViewName].libraryProblemsView.toggleShowPath(button);
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
