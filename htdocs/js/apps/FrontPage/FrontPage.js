//require config
require.config({
    paths: {
        "Backbone":             "/webwork2_files/js/lib/vendor/backbone/backbone",
        "backbone-validation":  "/webwork2_files/js/lib/vendor/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/lib/vendor/jquery-drag-drop/js/jquery-ui-1.9.2.custom",
        "underscore":           "/webwork2_files/js/lib/vendor/underscore/underscore",
        "jquery":               "/webwork2_files/js/lib/vendor/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/lib/vendor/bootstrap/js/bootstrap",
        "util":                 "/webwork2_files/js/lib/webwork/util",
        "XDate":                "/webwork2_files/js/lib/vendor/xdate",
        "WebPage":              "/webwork2_files/js/lib/webwork/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":             "/webwork2_files/js/lib/webwork/views/Closeable"
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
        'util': ['XDate']
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/webwork/models/User', 
    '../../lib/webwork/models/ProblemSetList', 
    '../../lib/webwork/models/Problem', 
    '../../lib/webwork/views/WebPage',
    '../../lib/webwork/views/CalendarView',
    '../../lib/webwork/views/ProblemSetListView',   
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
            
            this.dispatcher.on('problem-sets-loaded',this.postHWLoaded); 

            this.render();



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