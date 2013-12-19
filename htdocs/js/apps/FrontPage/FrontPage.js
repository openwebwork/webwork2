//require config
require.config({
    paths: {
        "Backbone":             "/webwork2_files/js/lib/vendor/backbone-0.9.9",
        "backbone-validation":  "/webwork2_files/js/lib/vendor/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/delete-me/jquery-drag-drop/js/jquery-ui-1.9.2.custom",
        "underscore":           "/webwork2_files/js/vendor/underscore/underscore",
        "jquery":               "/webwork2_files/js/vendor/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/vendor/bootstrap/js/bootstrap",
        "util":                 "/webwork2_files/js/lib/util",
        "XDate":                "/webwork2_files/js/lib/vendor/xdate",
        "WebPage":              "/webwork2_files/js/lib/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/views/Closeable",
        "jquery-truncate":      "/webwork2_files/js/lib/vendor/jquery.truncate.min"
    },
    urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 15,
    shim: {
        'jquery-ui': ['jquery'],
        'underscore': { exports: '_' },
        'Backbone': { deps: ['underscore', 'jquery'], exports: 'Backbone'},
        'bootstrap':['jquery'],
        'backbone-validation': ['Backbone'],
        'XDate':{ exports: 'XDate'},
        'util': ['XDate'],
        'jquery-truncate' : ['jquery']
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/models/User', 
    '../../lib/models/ProblemSetList', 
    '../../lib/models/Problem', 
    '../../lib/views/WebPage',
    '../../lib/views/CalendarView',
    '../../lib/views/ProblemSetListView',   
    'util', 
    'config', /*no exports*/, 
    'bootstrap',
    'backbone-validation'], 
function(Backbone, _, User, ProblemSetList, Problem, WebPage, CalendarView, ProblemSetListView, util, config){

    var FrontPage = WebPage.extend({
        tagName: "div",
        initialize: function(){
            this.constructor.__super__.initialize.apply(this, {el: this.el});
            //WebPage.prototype.initialize.apply(this, );
            _.bindAll(this, 'render','postHWLoaded');  // include all functions that need the this object
            var self = this;
            this.dispatcher = _.clone(Backbone.Events);

            this.problemSets = new ProblemSetList({type: "Student"});
            
            
            this.problemSets.fetch();
            
            this.problemSets.on('fetchSuccess', function () {
                self.render();
                self.probSetListView.collectionLoaded = true;
                self.probSetListView.render();
                self.postHWLoaded();
            }); 



        },
        render: function(){
            this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 

            this.probSetListView = new ProblemSetListView({el: $("#left-column"), viewType: "student",
                                    collection: this.problemSets, parent: this});

            this.helpPane.open();


        },
        postHWLoaded: function () {
            var self = this;

            self.calendarView = new CalendarView({el: $("#cal"), collection: self.problemSets,  parent: this, view: "student"});

            $(".problem-set").on("click",function(evt) {
                console.log($(evt.target).data("setname"));  // Not the best way to do this, but should work. 
                location.href="./" + $(evt.target).data("setname") + "?effectiveUser=" + $("#hidden_effectiveUser").val() 
                        + "&key=" + $("#hidden_key").val() + "?user=" + $("#hidden_user").val();
            })         
            // Set the popover on the set name
        //   $("span.pop").popover({title: "Homework Set Details", placement: "top", offset: 10});
            
            //self.setListView = new SetListView({collection: self.collection, el:$("div#list")});
        }
    });

    var App = new FrontPage({el: $("#main")});
});