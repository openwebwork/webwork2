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
            options.views.setDefinition.tabName = "Set Defn. files";
            TabbedMainView.prototype.initialize.call(this,options);

            // make sure each of the tabs has the this.state variable
            _(options.views).chain().keys().each(function(subview){
                options.views[subview].set({state: self.state});
            })
    	},
        getHelpTemplate: function(){
            return $("#library-help-template").html();
        },
        sidebarEvents: {
            "change-display-mode": function(evt) { 
                this.views[this.state.get("tab_name")].changeDisplayMode(evt) 
            },
            "change-target-set": function(opt) { 
                this.views[this.state.get("tab_name")].setTargetSet(_.isString(opt)? opt: $(opt.target).val());
            }, 
            "add-problem-set": function(_set_name){
                var _set = new ProblemSet({set_id: _set_name},this.dateSettings);
                _set.setDefaultDates(moment().add(10,"days")).set("assigned_users",[config.courseSettings.user]);
               this.views[this.state.get("tab_name")].allProblemSets.add(_set); 
            },
            "show-hide-tags": function(show_hide_button) {
                this.views[this.state.get("tab_name")].libraryProblemsView.toggleTags(show_hide_button);
            },
            "show-hide-path": function(button) {
                console.log(button);
                this.views[this.state.get("tab_name")].libraryProblemsView.toggleShowPath(button);
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
