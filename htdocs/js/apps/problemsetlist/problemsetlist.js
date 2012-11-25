/*  problemsetlist.js:
   This is the base javascript code for the ProblemSetList.pm (Homework Editor3).  This sets up the View and ....
  
*/


//require config
require.config({
    //baseUrl: "/webwork2_files/js/",
    paths: {
        "Backbone":             "/webwork2_files/js/lib/webwork/components/backbone/Backbone",
        "backbone-validation":  "/webwork2_files/js/lib/vendor/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/lib/vendor/jquery-drag-drop/js/jquery-ui-1.9.0.custom",
        "underscore":           "/webwork2_files/js/lib/webwork/components/underscore/underscore",
        "jquery":               "/webwork2_files/js/lib/webwork/components/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/lib/vendor/bootstrap/js/bootstrap",
        "WebPage":              "/webwork2_files/js/lib/webwork/views/WebPage",
        "webwork":              "/webwork2_files/js/lib/webwork/webwork",
        "WeBWorKProperty":      "/webwork2_files/js/lib/webwork/models/WeBWorKProperty",
        "Settings":             "/webwork2_files/js/lib/webwork/models/Settings",
        "util":                 "/webwork2_files/js/lib/webwork/util",
        "datepicker":           "/webwork2_files/js/lib/vendor/datepicker/js/bootstrap-datepicker",
        "LibraryViewer":        "/webwork2_files/js/lib/webwork/views/LibraryViewer",
        "XDate":                "/webwork2_files/js/lib/vendor/xdate",
        "ProblemList" :         "/webwork2_files/js/lib/webwork/models/ProblemList",
        "Problem" :             "/webwork2_files/js/lib/webwork/models/Problem",
        "ProblemView" :         "/webwork2_files/js/lib/webwork/views/ProblemView",
        "config":               "config"
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

        'XDate':{
            exports: 'XDate'
        },

        'bootstrap':['jquery'],
        
    }
});

require(['Backbone', 
    'underscore',
    '../../lib/webwork/models/UserList',
    '../../lib/webwork/models/ProblemSetList',
    '../../lib/webwork/models/ProblemSetPathList', 
    'Problem',
    '../../lib/webwork/views/Closeable',
    '../../lib/webwork/views/CalendarView',
    '../../lib/webwork/views/HWDetailView',
    './LibraryBrowser',
    'Settings', 
    'WebPage', 
    'util', 
    'config', 
    'backbone-validation',
    'jquery-ui',
    'bootstrap' 
    ], 
function(Backbone, _, UserList, ProblemSetList, ProblemSetPathList, Problem, Closeable,CalendarView,
         HWDetailView, LibraryBrowser, Settings,WebPage, util, config){

    var HomeworkEditorView = WebPage.extend({
	    tagName: "div",
        initialize: function(){
    	    WebPage.prototype.initialize.apply(this);
    	    _.bindAll(this, 'render','postFetch');  // include all functions that need the this object
    	    var self = this;
            this.dispatcher = _.clone(Backbone.Events);



            this.collection = new ProblemSetList();
            this.collection.fetch();
            this.collection.on('fetchSuccess', function () { this.postFetch(); }, this);
            this.collection.on("success",function(str) {
                if (str==="problem_set_changed") {
                    self.calendarView.updateAssignments();
                    self.calendarView.render();
                    self.setListView.updateSetInfo();
                }

            });

          
            this.dispatcher.on("calendar-change",function () {self.setDropToEdit();});
            
            this.settings = new Settings();  // need to get other settings from the server.  
            this.settings.fetch();
            this.settings.on("fetchSuccess", function (data){
                new HWSettingsView({parent: self, el: $("#settings-table")});

            },this);


            this.users = new UserList();
            this.users.fetch();
            this.users.on("fetchSuccess", function (data){ console.log("users loaded");});
            this.render();
                
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
        
        $("#settings").html(_.template($("#settings-template").html()));


        //$("body").droppable();  // This helps in making drags return to their original place.
        
        //new ui.PropertyListView({el: $("#settings"), model: self.settings});

        this.HWDetails = new HWDetailView({parent: this});

        // 

        new LibraryBrowser({el:  $("#library")});


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

        self.setListView = new SetListView({parent: self, el:$("div#list")});

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
                var timeAssignDue = self.settings.getSettingValue("pg{timeAssignDue}");
                var timezone = self.settings.find(function(v) { return v.get("var")==="timezone"}).get("value");
                var theDueDate = /date-(\d{4})-(\d\d)-(\d\d)/.exec($(this).attr("id"));
                var assignOpenPriorToDue = self.settings.getSettingValue("pg{assignOpenPriorToDue}");
                var answerAfterDueDate = self.settings.getSettingValue("pg{answersOpenAfterDueDate}");
                
                var wwDueDate = theDueDate[2]+"/"+theDueDate[3] +"/"+theDueDate[1] + " at " + timeAssignDue + " " + timezone;
                var HWset = self.collection.find(function (_set) { return _set.get("set_id") === setName;});

                console.log("Changing HW Set " + setName + " to be due on " + wwDueDate);
                console.log(HWset.isValid("due_date",wwDueDate));
                console.log(assignOpenPriorToDue);
                var _openDate = new XDate(wwDueDate);
                _openDate.addMinutes(-1*assignOpenPriorToDue);
                var _answerDate = new XDate(wwDueDate);
                _answerDate.addMinutes(answerAfterDueDate);
                var tz = /\((\w{3})\)/.exec(_openDate.toString());
                var wwOpenDate = _openDate.toString("MM/dd/yyyy") + " at " + _openDate.toString("hh:mmtt")+ " " + tz[1];
                var wwAnswerDate = _answerDate.toString("MM/dd/yyyy") + " at " + _answerDate.toString("hh:mmtt") + " " + tz[1];

                HWset.set({due_date:wwDueDate, open_date: wwOpenDate, answer_date: wwAnswerDate});
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



/* This View provides the super class for any Settings in WebWork.  The list of Settings should be included by 
    setting the "settings" field and providing it an array of WeBWorKProperty models. 
    */

var WWSettingsView = Backbone.View.extend({

    initialize: function () {
        _.bindAll(this,'render');
        this.render();
    },
    render: function ()
    {
        var self = this;
        _(this.settings).each(function(setting){
            var settingView =new WWSettingRowView({property: setting}); 
            self.$el.append(settingView.el);
        });
    }


});

var HWSettingsView = WWSettingsView.extend({
    initialize: function () {
//        _.bindAll(this,'render','edit');
        this.parent = this.options.parent; 
        this.settings = this.parent.settings.filter(function (setting) {return setting.get("category")==='PG - Problem Display/Answer Checking'});
        WWSettingsView.prototype.initialize.apply(this);
     }

});



var WWSettingRowView = Backbone.View.extend({
    className: "set-detail-row",
    tagName: "tr",
    initialize: function () {
        _.bindAll(this,'render','update');
        this.property = this.options.property;
        //this.dateRE =/(\d\d\/\d\d\/\d\d\d\d)\sat\s((\d\d:\d\d)([apAP][mM])\s([a-zA-Z]{3}))/;
        this.render();
        return this;
    },
    render: function() {
        var self = this; 
        this.$el.html("<td>" + this.property.get("doc") + "</td>");
        switch(this.property.get("type")){
            case "text":
            case "number":
                this.$el.append("<td><input type='text' value='" + this.property.get("value") + "'></input></td>");
                break;
            case "checkboxlist":
                var opts = _(self.property.get("values")).map(function(v) {return "<li><input type='checkbox' value='"+v+"'>" + v + "</li>";});
                this.$el.append("<td id='prop-" + self.property.cid + "'><ul style='list-style: none'>" + opts.join("") + "</ul></td>");
                _(self.property.get("value")).each(function(v){
                    self.$("#prop-" + self.property.cid + " input:checkbox[value='" + v + "']").attr("checked","checked");
                })
                break;
            case "popuplist":
                var opts = _(self.property.get("values")).map(function(v) {return "<option value='" + v + "'>" + v + "</option>";});
                this.$el.append("<td id='prop-" + self.property.cid + "'><select class='popuplist'>" + opts + "</select>");
                self.$("#prop-" + self.property.cid + " select.popuplist option[value='" + self.property.get("value") + "']").attr("selected","selected");
                break;
            case "boolean":
                this.$el.append("<td id='prop-" + self.property.cid + "'>" + 
                                "<select class='bool'><option value='1'>true</option><option value='0'>false</option></select");
                //this.$("#prop-" + self.property.cid + " select.bool option[value='0']").attr("selected","selected")
                this.$("#prop-" + self.property.cid + " select.bool option[value='" + self.property.get("value") +  "']").attr("selected","selected");
 
               break;
            default: 
                this.$el.append("<td id='value-col'> " + this.property.get("value") + "</td>");

        }

    
    },
    events: {
        "change input": "update",
        "change select": "update"
    },
    update: function(evt){
        var self = this;
        console.log("updating " + self.property.get("var"));
        console.log("new value: " + $(evt.target).val());
        switch(this.property.get("type")){
            case "text":
            case "number":
                self.property.set("value",$(evt.target).val());
                break;
            case "checkboxlist":

                break;
            case "boolean":
 
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
            this.$el.append((_(["set_id","open_date","due_date","answer_date"]).map(function(v) {
                return "<td>" + self.model.get(v) + "</td>"; })).join(""));
        }
        });
    
    var SetListView = Backbone.View.extend({
        className: "set-list-view",
        initialize: function () {
            _.bindAll(this, 'render','updateSetInfo');  // include all functions that need the this object
            this.parent = this.options.parent; 
            this.render();
            return this;
        },
        render: function () {
            var self = this;
            this.$el.html("<table id='set-list-table' class='table table-bordered'><thead><tr><th>Name</th><th>Open Date</th><th>Due Date</th><th>Answer Date</th></tr></thead><tbody></tbody></table>");
            var tab = $("#set-list-table");
            this.parent.collection.each(function(m){
                tab.append((new SetListRowView({model: m})).el);
            });
            
        },
        updateSetInfo: function () {
            this.render();
        }


    });


    
    var App = new HomeworkEditorView({el: $("div#mainDiv")});
});
