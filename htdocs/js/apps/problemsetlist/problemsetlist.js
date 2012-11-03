/*  problemsetlist.js:
   This is the base javascript code for the ProblemSetList.pm (Homework Editor3).  This sets up the View and ....
  
*/


//require config
require.config({
    //baseUrl: "/webwork2_files/js/",
    paths: {
        Backbone: "/webwork2_files/js/lib/webwork/components/backbone/Backbone",
        "backbone-validation":"/webwork2_files/js/lib/vendor/backbone-validation",
        //"backbone-validation":"/webwork2_files/js/lib/vendor/backbone-validation-amd",
        "FileSaver": "/webwork2_files/js/lib/vendor/FileSaver",
        "BlobBuilder": "/webwork2_files/js/lib/vendor/BlobBuilder",
        "jquery-ui": "/webwork2_files/js/lib/vendor/jquery-drag-drop/js/jquery-ui-1.9.0.custom",
        "WeBWorK-ui": "/webwork2_files/js/lib/webwork/WeBWorK-ui",
        "webwork": "/webwork2_files/js/lib/webwork/webwork",
        "Settings": "/webwork2_files/js/lib/webwork/Settings",
        "util":"/webwork2_files/js/lib/webwork/util",
        "underscore": "/webwork2_files/js/lib/webwork/components/underscore/underscore",
        "jquery": "/webwork2_files/js/lib/webwork/components/jquery/jquery",
        "EditableGrid":"/webwork2_files/js/lib/vendor/editablegrid-2.0.1/editablegrid",
        "bootstrap":"/webwork2_files/js/lib/vendor/bootstrap/js/bootstrap",
        "datepicker": "/webwork2_files/js/lib/vendor/datepicker/js/bootstrap-datepicker",
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
        'datepicker': ['bootstrap'],
        'backbone-validation': ['Backbone'],
        'BlobBuilder': {
            exports: 'BlobBuilder'
        },

        "FileSaver":{
            exports: 'saveAs'
        },

        'XDate':{
            exports: 'XDate'
        },

        'bootstrap':['jquery'],

        
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/webwork/teacher/User',
    '../../lib/webwork/teacher/UserList',
    '../../lib/webwork/teacher/ProblemSetList', 
    '../../lib/webwork/teacher/ProblemSetPathList',
    '../../lib/webwork/Problem',
    '../../lib/webwork/views/Closeable',
    '../../lib/webwork/views/Calendar/CalendarView',
    '../../lib/webwork/views/HWDetailView',
    'FileSaver', 
    'BlobBuilder', 
    'EditableGrid',
    'Settings', 
    'WeBWorK-ui', 
    'util', 
    'config', /*no exports*/, 
    'jquery-ui', 
    'bootstrap',
    'datepicker',
    'backbone-validation'], 
function(Backbone, _, User, UserList, ProblemSetList, ProblemSetPathList, Problem, Closeable,CalendarView,
         HWDetailView,saveAs, BlobBuilder, EditableGrid, Settings,ui, util, config, webwork){
    

    var HomeworkEditorView = ui.WebPage.extend({
	tagName: "div",
        initialize: function(){
	    ui.WebPage.prototype.initialize.apply(this);
	    _.bindAll(this, 'render','postFetch');  // include all functions that need the this object
	    var self = this;
        this.dispatcher = _.clone(Backbone.Events);
        this.collection = new ProblemSetList();
        this.settings = new Settings();  // need to get other settings from the server.  

        this.users = new UserList();
        this.users.fetch();
        this.users.on("fetchSuccess", function (data){ console.log("users loaded");});
        this.render();
        this.collection.fetch();
        this.collection.on('fetchSuccess', function () { this.postFetch(); }, this);
        this.dispatcher.on("calendar-change",function () {self.setDropToEdit();});
        this.collection.on("success",function(str) {
            if (str==="problem_set_changed") {
                self.calendarView.updateAssignments();
                self.calendarView.render();
            }

        });
            
    },
    render: function(){
	    var self = this; 
	    
    // Create an announcement pane for successful messages.
        this.announce = new Closeable({el:$("#announce-pane"),classes: ["alert-success"]});
        
        // Create an announcement pane for error messages.
        this.errorPane = new Closeable({el:$("#error-pane"),classes: ["alert-error"]});
        
        // This is the help Pane
        this.helpPane = new Closeable({display: "block",el:$("#help-pane"), closeableType : "Help",
                    text: $("#homeworkEditorHelp").html()});
        


//	    $("button.close",this.helpPane.el).click(function () {self.helpPane.close();}); // for some reason the event inside this.announce is not working  this is a hack.
            
        this.$el.append("<div class='row'><div id='left-column' class='span3'>Loading Homework Sets...<img src='/webwork2_files/images/ajax-loader-small.gif'></div><div id='tab-container' class='span9'></div></div>");
        
        $("#tab-container").append(_.template($("#tab-setup").html()));
        $('#hwedTabs a').click(function (e) {
            e.preventDefault();
            $(this).tab('show');
        });
        
        //$("body").droppable();  // This helps in making drags return to their original place.
        
        new ui.PropertyListView({el: $("#settings"), model: self.settings});

        this.HWDetails = new HWDetailView({parent: this});

        
        
    },
    postFetch: function (){
        var self = this;

        /** Build the homework set column.  We may want to sort this according to open date (or alphabetize). 
        * Also, we may want to make this its own view to be used other places. 
        */

        $("#left-column").html("<div style='font-size:110%; font-weight:bold'>Homework Sets</div><div id='probSetList' class='btn-group btn-group-vertical'></div>");
            this.collection.each(function (model) {
            var setName =  model.get("set_id");
            $("#probSetList").append("<div class='ps-drag btn' id='HW-" + setName + "'>" + setName + "</div>")
            $("div#HW-" + setName ).click(function(evt) {
                if (self.objectDragging) return;
                $('#hwedTabs a[href="#details"]').tab('show');
                var setName = $(evt.target).attr("id").split("HW-")[1] ;
                self.HWDetails.changeHWSet(setName); 

            });
            
        });

          
            // Adds the CalendarView 
        
                        
        self.calendarView = new CalendarView({el: $("#cal"), parent: this, view: "instructor"});

        //$("#cal").append(self.calendarView.el);
        
        self.setDropToEdit();        
        

        // Set the popover on the set name
        $("span.pop").popover({title: "Homework Set Details", placement: "top", offset: 10});
        
        // Create the HW list view.  

        self.setListView = new SetListView({collection: self.collection, el:$("div#list")});

        // Create the HW details pane. 

        $("#details").html(_.template($("#HW-detail-template").html()));    

    },
            // This allows the homework sets generated above to be dragged onto the Calendar to set the due date. 

    setDropToEdit: function ()
    {
        var self = this;
        $(".ps-drag").draggable({revert: "valid", start: function (event,ui) { self.objectDragging=true;},
                                stop: function(event, ui) {self.objectDragging=false;}});
             
        $(".calendar-day").droppable({
            hoverClass: "highlight-day",
            accept: ".ps-drag",
            greedy: true,
            drop: function(ev,ui) {
                var setName = $(ui.draggable).attr("id").split("HW-")[1];
                var theDueDate = /date-(\d{4})-(\d\d)-(\d\d)/.exec($(this).attr("id"));
                var wwDueDate = theDueDate[2]+"/"+theDueDate[3] +"/"+theDueDate[1] + " at " + self.settings.get("time_assign_due") + " " + self.settings.get("timezone");

                var HWset = self.collection.find(function (_set) { return _set.get("set_id") === setName;});
                console.log("Changing HW Set " + setName + " to be due on " + wwDueDate);
                console.log(HWset.isValid("due_date",wwDueDate));
                console.log(self.convertTimeToMinutes(self.settings.get("assign_open_prior_to_due")));
                var _openDate = new XDate(wwDueDate);
                _openDate.addMinutes(-1*self.convertTimeToMinutes(self.settings.get("assign_open_prior_to_due")));
                var tz = /\((\w{3})\)/.exec(_openDate.toString());
                var wwOpenDate = _openDate.toString("MM/dd/yyyy") + " at " + _openDate.toString("hh:mmtt")+ " " + tz[1];

                console.log(HWset.isValid("open_date",wwOpenDate));


                HWset.set({due_date:wwDueDate, open_date: wwOpenDate});
                ev.stopPropagation();
            },
        });


        $("body").droppable({accept: ".ps-drag", drop: function () { console.log("dropped");}});

    },
    convertTimeToMinutes: function(timeStr){
        var vals = /(\d+)\s(day|days|week|weeks)/.exec(timeStr);
        var num = parseInt(vals[1]);
        var unit = vals[2];
        switch(unit){
            case "days": case "day": num *= 24*60;  break;
            case "weeks": case "week": num *= 24*7*60; break;
        }
        return num;
    }
});

 /*   var HWDetailRowView = Backbone.View.extend({
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
        });*/ 
    
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


    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});
