//require config
require.config({
    //baseUrl: "/webwork2_files/js/",
    paths: {
        "Backbone": "/webwork2_files/js/lib/webwork/components/backbone/Backbone",
        "backbone-validation":"/webwork2_files/js/lib/vendor/backbone-validation",
        "FileSaver": "/webwork2_files/js/lib/vendor/FileSaver",
        "BlobBuilder": "/webwork2_files/js/lib/vendor/BlobBuilder",
        "jquery-ui": "/webwork2_files/js/jquery-ui-1.9.0.custom/js/jquery-ui-1.9.0.custom.min",
        "WeBWorK-ui": "/webwork2_files/js/lib/webwork/WeBWorK-ui",
        "util":"/webwork2_files/js/lib/webwork/util",
        "underscore": "/webwork2_files/js/lib/webwork/components/underscore/underscore",
        "jquery": "/webwork2_files/js/lib/webwork/components/jquery/jquery",
        "EditableGrid":"/webwork2_files/js/lib/vendor/editablegrid-2.0.1/editablegrid",
        "bootstrap":"/webwork2_files/js/lib/vendor/bootstrap/js/bootstrap",
        //"jquery-ui": "../vendor/jquery/jquery-ui-1.8.16.custom.min",
        //"touch-pinch": "../vendor/jquery/jquery.ui.touch-punch",
        //"tabs": "../vendor/ui.tabs.closable",
        //this is important:
        "XDate":'/webwork2_files/js/lib/vendor/xdate',
        "config":"config"
    },
    //deps:['EditableGrid'],
    //callback:function(){console.log(EditableGrid)},
    urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 15,
    shim: {
        //ui specific shims:
        'jquery-ui': ['jquery'],

        //required shims
        'underscore': {
            exports: '_'
        },
        'Backbone': {
            //These script dependencies should be loaded before loading
            //backbone.js
            deps: ['underscore', 'jquery'],
            //Once loaded, use the global 'Backbone' as the
            //module value.
            exports: 'Backbone'
        },
        'backbone-validation':['Backbone'],
        
        'BlobBuilder': {
            exports: 'BlobBuilder'
        },

        "FileSaver":{
            exports: 'saveAs'
        },

        'XDate':{
            exports: 'XDate'
        },

        'bootstrap':['jquery']
        
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/webwork/teacher/User', 
    '../../lib/webwork/teacher/ProblemSetList', 
    '../../lib/webwork/teacher/ProblemSetPathList',
    '../../lib/webwork/Problem',
    'FileSaver', 
    'BlobBuilder', 
    'EditableGrid', 
    '../../lib/webwork/views/WebPage',
    '../../lib/webwork/views/Closeable',
    '../../lib/webwork/views/Calendar/CalendarView',   
    'util', 
    'config', /*no exports*/, 
    'jquery-ui', 
    'bootstrap',
    'backbone-validation'], 
function(Backbone, _, User, ProblemSetList, ProblemSetPathList, Problem, saveAs, BlobBuilder, EditableGrid, WebPage, Closeable, CalendarView, util, config){

    var Property = Backbone.Model.extend({
            defaults: {
                name: "",
                internal_name: "",
                value: 0,
                unit: ""
            }
        });

    // Perhaps there is a better way to do this in order to validate the properties. 

    var PropertyList = Backbone.Collection.extend({ model: Property});

    var HomeworkEditor = {settings: new PropertyList([
            new Property({name: "Time the Assignment is Due", internal_name: "time_assign_due", value: "11:59PM"}),
            new Property({name: "When does the Assignment Open", internal_name: "assign_open_prior_to_due", value: "1 week"}),
            new Property({name: "When do the Answers Open", internal_name: "answers_open_after_due", value: "2 days"}),
            new Property({name: "Assignments have Reduced Credit", internal_name: "reduced_credit", value: true}),
            new Property({name: "Amount of time for reduced Credit", internal_name: "reduced_credit_time", value: "3 days"}),
    ])};

    var HomeworkEditorView = WebPage.extend({
        tagName: "div",
        initialize: function(){
            WebPage.prototype.initialize.apply(this);
            _.bindAll(this, 'render');  // include all functions that need the this object
            var self = this;
            this.collection = new ProblemSetList();
            
            
            this.render();
            
            
            this.collection.fetch();
            
            this.collection.on('fetchSuccess', function () {
                console.log("Yeah, downloaded successfully!");
                console.log(this.collection);
                //$("#left-column").html("<div style='font-size:110%; font-weight:bold'>Homework Sets</div><div id='probSetList' class='btn-group btn-group-vertical'></div>");
                /*this.collection.each(function (model) {
                    var setName =  model.get("set_id");
                    $("#probSetList").append("<div class='ps-drag btn' id='HW-" + setName + "'>" + setName + "</div>")
                    $("div#HW-" + setName ).click(function(evt) {
                        if (self.objectDragging) return;
                        $('#hwedTabs a[href="#details"]').tab('show');
                        self.showDetails($(evt.target).attr("id").split("HW-")[1]);
                        });
                    
                });
                $(".ps-drag").draggable({revert: "valid", start: function (event,ui) { self.objectDragging=true;},
                                        stop: function(event, ui) {self.objectDragging=false;}});
                */
                            
                this.calendarView = new CalendarView({collection: this.collection, view: "student"});

                $("#cal").append(this.calendarView.el);
            
                $(".calendar-day").droppable({  // This doesn't work right now.  
                    hoverClass: "highlight-day",
                    drop: function( event, ui ) {
                        App.dragging = true; 
                        //$(this).addClass("ui-state-highlight");
                        console.log( "Dropped on " + self.$el.attr("id"));
                    }
                });    
                
                // Set the popover on the set name
               $("span.pop").popover({title: "Homework Set Details", placement: "top", offset: 10});
                
                //self.setListView = new SetListView({collection: self.collection, el:$("div#list")});
            }, this);
        },
        render: function(){
        var self = this; 
        
        // Create an announcement pane for successful messages.
        
        //this.announce = new Closeable({id: "announce-bar"});
        //this.announce.$el.addClass("alert-success");
        //this.$el.append(this.announce.el)
        //$("button.close",this.announce.el).click(function () {self.announce.close();}); // for some reason the event inside this.announce is not working  this is a hack.
            //this.announce.delegateEvents();
        
        // Create an announcement pane for successful messages.
        
        //this.errorPane = new Closeable({id: "error-bar", classes: ["alert-error"]});
        //this.$el.append(this.errorPane.el)
        //$("button.close",this.errorPane.el).click(function () {self.errorPane.close();}); // for some reason the event inside this.announce is not working  this is a hack.
        
        
        //this.helpPane = new Closeable({display: "block",text: $("#homeworkEditorHelp").html(),id: "helpPane"});
        //this.$el.append(this.helpPane.el)
        //$("button.close",this.helpPane.el).click(function () {self.helpPane.close();}); // for some reason the event inside this.announce is not working  this is a hack.
            
            //this.$el.append("<div class='row'><div id='left-column' class='span3'>Loading Homework Sets...<img src='/webwork2_files/images/ajax-loader-small.gif'></div><div id='tab-container' class='span9'></div></div>");
            
            //$("#tab-container").append(_.template($("#tab-setup").html()));
            //$('#hwedTabs a').click(function (e) {
            //    e.preventDefault();
            //    $(this).tab('show');
            //});
            
            //$("body").droppable();  // This helps in making drags return to their original place.
            
            //new SettingsView({el: $("#settings")});

            
            
        },
        /*showDetails: function(setName)  {  // Show the details of the set with name: setName
            var self = this;
            var _model = self.collection.find(function(model) {return model.get("set_id")===setName;});
            this.detailView = new HWDetailView({model: _model, el: $("#details")});
        }*/
    });

    var App = new HomeworkEditorView({el: $("body")});
});