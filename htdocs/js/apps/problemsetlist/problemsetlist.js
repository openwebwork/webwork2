/*  problemsetlist.js:
   This is the base javascript code for the ProblemSetList.pm (Homework Editor3).  This sets up the View and ....
  
*/


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
        }
        
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/webwork/teacher/User', 
    '../../lib/webwork/teacher/ProblemSetList', 
    '../../lib/webwork/teacher/ProblemPathList',
    '../../lib/webwork/Problem',
    'FileSaver', 
    'BlobBuilder', 
    'EditableGrid', 
    'WeBWorK-ui', 
    'util', 
    'config', /*no exports*/, 
    'jquery-ui', 
    'backbone-validation'], 
function(Backbone, _, User, ProblemSetList, ProblemPathList, Problem, saveAs, BlobBuilder, EditableGrid, ui, util, config){
    // get usernames and keys from hidden variables and set up webwork object:
    /*var myUser = document.getElementById("hidden_user").value;
    var mySessionKey = document.getElementById("hidden_key").value;
    var myCourseID = document.getElementById("hidden_courseID").value;
    // check to make sure that our credentials are available.
    if (myUser && mySessionKey && myCourseID) {
        webwork.requestObject.user = myUser;
        webwork.requestObject.session_key = mySessionKey;
        webwork.requestObject.courseID = myCourseID;
    } else {
        alert("missing hidden credentials: user "
            + myUser + " session_key " + mySessionKey
            + " courseID" + myCourseID, "alert-error");
    }*/

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

    var HomeworkEditorView = ui.WebPage.extend({
	tagName: "div",
        initialize: function(){
	    ui.WebPage.prototype.initialize.apply(this);
	    _.bindAll(this, 'render');  // include all functions that need the this object
	    var self = this;
            this.collection = new ProblemSetList();
            
            
            this.render();
            
            
            this.collection.fetch();
            
            this.collection.on('fetchSuccess', function () {
                console.log("Yeah, downloaded successfully!");
                console.log(this.collection);
                $("#left-column").html("<div style='font-size:110%; font-weight:bold'>Homework Sets</div><div id='probSetList' class='btn-group btn-group-vertical'></div>");
                this.collection.each(function (model) {
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
                
                            
            this.calendarView = new ui.CalendarView({collection: this.collection, view: "student"});

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
                
                self.setListView = new SetListView({collection: self.collection, el:$("div#list")});
                }, this);
        },
        render: function(){
	    var self = this; 
	    
	    // Create an announcement pane for successful messages.
	    
	    this.announce = new ui.Closeable({id: "announce-bar"});
	    this.announce.$el.addClass("alert-success");
	    this.$el.append(this.announce.el)
	    $("button.close",this.announce.el).click(function () {self.announce.close();}); // for some reason the event inside this.announce is not working  this is a hack.
            //this.announce.delegateEvents();
	    
   	    // Create an announcement pane for successful messages.
	    
	    this.errorPane = new ui.Closeable({id: "error-bar", classes: ["alert-error"]});
	    this.$el.append(this.errorPane.el)
	    $("button.close",this.errorPane.el).click(function () {self.errorPane.close();}); // for some reason the event inside this.announce is not working  this is a hack.
	    
	    
   	    this.helpPane = new ui.Closeable({display: "block",text: $("#homeworkEditorHelp").html(),id: "helpPane"});
	    this.$el.append(this.helpPane.el)
	    $("button.close",this.helpPane.el).click(function () {self.helpPane.close();}); // for some reason the event inside this.announce is not working  this is a hack.
            
            this.$el.append("<div class='row'><div id='left-column' class='span3'>Loading Homework Sets...<img src='/webwork2_files/images/ajax-loader-small.gif'></div><div id='tab-container' class='span9'></div></div>");
            
            $("#tab-container").append(_.template($("#tab-setup").html()));
            $('#hwedTabs a').click(function (e) {
                e.preventDefault();
                $(this).tab('show');
            });
            
            $("body").droppable();  // This helps in making drags return to their original place.
            
            new SettingsView({el: $("#settings")});

            
            
        },
        showDetails: function(setName)  {  // Show the details of the set with name: setName
            var self = this;
            var _model = self.collection.find(function(model) {return model.get("set_id")===setName;});
            this.detailView = new HWDetailView({model: _model, el: $("#details")});
        }
    });
    
    var HWDetailRowView = Backbone.View.extend({
        className: "set-detail-row",
        tagName: "tr",
        initialize: function () {
            _.bindAll(this,'render','edit');
            this.property = this.options.property;
            this.dateRE =/(\d\d\/\d\d\/\d\d\d\d)\sat\s((\d\d:\d\d)([apAP][mM])\s([a-zA-Z]{3}))/;
            this.render();
            return this;
        },
        render: function() {
            this.$el.html("<td>" + this.property + "</td><td id='value-col'> " + this.model.get(this.property) + "</td><td><button class='edit-button'>Edit</button>");
        }
        ,
        events: {
            "click .edit-button": "edit"
        },
        edit: function(evt){
            var value; 
            switch(this.property){
                case "set_header":
                case "hardcopy_header":
                    value = this.$("#value-col").html();
                    this.$("#value-col").html("<input type='text' size='20' id='edit-box'></input>");
                    this.$("input#edit-box").val(value);
                break;
                case "open_date":
                case "due_date":
                case "answer_date":

                    var dateParts = this.dateRE.exec(this.$("#value-col").html());
                    theDate = dateParts[1];
                    theTime = dateParts[2];
                    this.$("#value-col").html("<input type='text' size='20' id='edit-box'></input>");
                    this.$("input#edit-box").val(theDate);
                    this.$("input#edit-box").datepicker({showButtonPanel: true});
                    
                    break;
            
            }
        }
        });
    
    var HWProblemView = Backbone.View.extend({
        className: "set-detail-problem-view",
        tagName: "div",
        
        initialize: function () {
            _.bindAll(this,"render");
            var self = this;
            this.render();
            this.model.on('rendered', function () {
                self.$el.html(self.model.get("data"));
            })
        },
        render: function () {
            this.$el.html(this.model.get("path"));
            this.model.render();
        }
    
    
    });
    
    var HWDetailView = Backbone.View.extend({
        className: "set-detail-view",
        tagName: "div",
        initialize: function () {
            _.bindAll(this,'render');
            var self = this;
            this.render();
            this.problemPathList = new ProblemSetPathList();
            this.problemPathList.fetch(this.model.get("set_id"));
            this.problemPathList.on("fetchSuccess",function () {
                var hwDetailDiv = $("#hw-detail-problems");
                self.problemPathList.each(function(_problem){
                    var hwpv = new HWProblemView({model: new Problem({path: _problem.get("path")})});
                    hwDetailDiv.append(hwpv.el);
//                $("#hw-detail-problems").html((self.problemPathList.map(function(ProblemSet) {return ProblemSet.get("path");})).join(","));
                });
            
            });
            return this;
        },
        render: function () {
            var self = this;
            this.$el.html(_.template($("#HW-detail-template").html()))
            _(this.model.attributes).each(function(value,key) { $("#detail-table").append((new HWDetailRowView({model: self.model, property: key})).el)});
            return this;
        }
    });
    
    var SetListRowView = Backbone.View.extend({
        className: "set-list-row",
        tagName: "tr",
        initialize: function () {
            _.bindAll(this,'render');
            var self = this;
            this.render();
            return this;
        },
        render: function () {
            var self = this;
            this.$el.append((_(["set_id","open_date","due_date","answer_date"]).map(function(v) {return "<td>" + self.model.get(v) + "</td>";})).join(""));
        }
        });
    
    var SetListView = Backbone.View.extend({
        className: "set-list-view",
        initialize: function () {
            _.bindAll(this, 'render');  // include all functions that need the this object
            var self = this;
        
            this.render();
            return this;
        },
        render: function () {
            var self = this;
            this.$el.append("<table id='set-list-table' class='table table-bordered'><thead><tr><th>Name</th><th>Open Date</th><th>Due Date</th><th>Answer Date</th></tr></thead><tbody></tbody></table>");
            var tab = $("#set-list-table");
            this.collection.each(function(m){
                tab.append((new SetListRowView({model: m})).el);
            });
            
        }
    });


    var SettingsRowView = Backbone.View.extend({
        tagName: "tr",
        initialize: function () {
            _.bindAll(this, 'render','editRow');  // include all functions that need the this object
            this.render();
        },
        render: function () {
            this.$el.html("<td class='srv-name'> " + this.model.get("name") + "</td><td class='srv-value'> " + this.model.get("value") + "</td>");
            return this;
            
        },
        events: {"click .srv-value": "editRow"},
        editRow: function () {
            var tableCell = this.$(".srv-value");
            var value = tableCell.html();
            tableCell.html("<input class='srv-edit-box' size='20' type='text'></input>");
            var inputBox = this.$(".srv-edit-box");
            inputBox.val(value);
            inputBox.click(function (event) {event.stopPropagation();});
            this.$(".srv-edit-box").focusout(function() {
                tableCell.html(inputBox.val());
                model.set("value",inputBox.val());  // should validate here as well.  
                
                // need to also set the property on the server or 
                });
        }
        
        
        });
    
    var SettingsView = Backbone.View.extend({
        className: "settings-view",
        initialize: function () {
            _.bindAll(this, 'render');  // include all functions that need the this object
            this.render();
        },
        render: function () {
            this.$el.html("<table class='table bordered-table'><thead><tr><th>Property</th><th>Value</th></tr></thead><tbody></tbody></table>");
            var tab = this.$("table");
            HomeworkEditor.settings.each(function(setting){ tab.append((new SettingsRowView({model: setting})).el)});
            
        }
        });
    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});
