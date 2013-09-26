define(['Backbone','moment','backbone-validation','stickit','jquery-ui'], function(Backbone,moment){

    
    var config = {
        courseSettings: {
            "session_key": $("#hidden_key").val(),
            "user": $("#hidden_user").val(),
            "courseID": $("#hidden_courseID").val(),
        },
        /*requestObject: {
            "session_key": $("#hidden_key").val(),
            "user": $("#hidden_user").val(),
            "courseID": $("#hidden_courseID").val(),
        },
        webserviceURL: "/webwork2/instructorXMLHandler",
        printOtherParams: function () {
            return "?course=" + this.requestObject.courseID + "&user=" + this.requestObject.user 
                + "&session_key=" + this.requestObject.session_key;

        },*/
        checkForError: function(response){
            if (response && response.error){
                console.log("need to handle this somehow");
                console.log(response);
            }
        },
            
    
    // Note: these are in the order given in the classlist format for LST files.  
    
        userProps: [{shortName: "student_id", longName: "Student ID", regexp: "student"},
                     {shortName: "last_name", longName: "Last Name", regexp: "last"},
                     {shortName: "first_name", longName: "First Name", regexp: "first"},
                     {shortName: "status", longName: "Status", regexp: "status"},
                     {shortName: "comment", longName: "Comment", regexp: "comment"},
                     {shortName: "section", longName: "Section", regexp: "section" },
                     {shortName: "recitation", longName: "Recitation", regexp: "recitation"},
                     {shortName: "email_address", longName: "Email", regexp: "email"},
                     {shortName: "user_id", longName: "Login Name", regexp: "login"},
                     {shortName: "userpassword", longName: "Password", regexp: "pass"},
                     {shortName: "permission", longName: "Permission Level", regexp: "permission"}
                     ],
    
        userTableHeaders : [
            { name: "Select", datatype: "boolean", editable: true},
            { name: "Action", datatype: "string", editable: true,
                        values: {"action1":"Change Password",
                            "action2":"Delete User","action3":"Act as User",
                            "action4":"Student Progess","action5":"Email Student"}
                    },
                { label: "Login Name", name: "user_id", datatype: "string", editable: false },
                { label: "Assigned Sets", name: "num_user_sets", datatype: "string", editable: false },
                { label: "First Name", name: "first_name", datatype: "string", editable: true },
                { label: "Last Name", name:"last_name", datatype: "string", editable: true },
                { label: "Email", name: "email_address", datatype: "string", editable: true },
                { label: "Student ID", name: "student_id", datatype: "string", editable: true },
                { label: "Status", name: "status", datatype: "string", editable: true,
                    values : {
                        "en":"Enrolled",
                        "noten":"Not Enrolled"
                    }
                },
                { label: "Section", name: "section", datatype: "integer", editable: true },
                { label: "Recitation", name: "recitation", datatype: "integer", editable: true },
                { label: "Comment", name: "comment", datatype: "string", editable: true },
                { label: "Permission", name: "permission", datatype: "integer", editable: true,
                    values : {
                        "-5":"guest","0":"Student","2":"login proctor",
                        "3":"grade proctor","5":"T.A.", "10": "Professor",
                        "20":"Admininistrator"
            }
        }
        
                ],
        problemSetHeaders : [
            {name: "set_id", label: "Name", datatype: "string", editable: false},
            {name: "enable_reduced_scoring", label: "Reduced Scoring", datatype: "string",editable: true,
                values: {"0": "No", "1": "Yes"}},
            {name: "visible", label: "Visible", datatype: "string",editable: true,
                values: {"0": "No", "1": "Yes"}},
            {name: "open_date", label: "Open Date", datatype: "date", editable: true},
            {name: "due_date", label: "Due Date", datatype: "date", editable: true},
            {name: "answer_date", label: "Answer Date", datatype: "date", editable: true}
            ],
        permissions : [{value: -5, label: "guest"},{value: 0, label: "student"},{value: 2, label: "login proctor"}, 
                        {value: 3, label: "T.A."},{value: 10, label: "professor"}, {value: 20, label: "administrator"}],

        regexp : {
            wwDate:  /^((\d?\d)\/(\d?\d)\/(\d{4}))\sat\s((0?[1-9]|1[0-2]):([0-5]\d)([aApP][mM]))\s([a-zA-Z]{3})/,
            number: /^\d*(\.\d*)?$/
        },
        parseWWDate: function(str) {
            // this parses webwork dates in the form MM/DD/YYYY at HH:MM AM/PM TMZ
            // and returns the date (as a moment object) and the timezone (as a string)

            var parsedDate = config.regexp.wwDate.exec(str);



            if (parsedDate) {
                var timePart = moment(parsedDate[5],"hh:mmA");
                var date = moment(parsedDate[1],"MM/DD/YYYY").hours(timePart.hours()).minutes(timePart.minutes());
                        
                return {"date": date, "time_zone": parsedDate[9]};
            }
        }
    }

    // These are additional validation patterns to be available to Backbone Validation

    _.extend(Backbone.Validation.patterns, { "wwdate": config.regexp.wwDate}); 
    _.extend(Backbone.Validation.patterns, { "setname": /^[\w\d\_\.]+$/});
    _.extend(Backbone.Validation.patterns, { "loginname": /^[\w\d\_]+$/});
    _.extend(Backbone.Model.prototype, Backbone.Validation.mixin);  

    // This implements a stickit handler for elements of type wwdate
    // see https://github.com/NYTimes/backbone.stickit for more info.
    //
    // This takes a webwork date-time (for open_date, due-date, etc.) and creates a pair of html spans to handle 
    // the date and time separately

    Backbone.Stickit.addHandler({
      selector: '.ww-datetime',
      initialize: function($el, model, options) {
        var setModel = function (evt) {
            console.log("saving the model");
            var datePart = evt.data.$el.children(".wwdate").val();
            var timePart = evt.data.$el.children(".wwtime").text().trim();
            var timeZone = config.parseWWDate(evt.data.model.get(evt.data.options.observe)).time_zone;

            evt.data.model.set(evt.data.options.observe,datePart + " at " + timePart + " " + timeZone);
            
        }; 
        $el.children(".wwdate").on("change",{"$el": $el, "model": model, "options": options}, setModel);
        $el.children(".wwtime").on("blur",{"$el": $el, "model": model, "options": options}, setModel);
        $el.children(".wwdate").datepicker();

      },
      updateMethod: 'html',
      //update: function($el, val, model, options) { $el.val(val); }
      onGet: function(val) { 

        var theDate = config.parseWWDate(val);
        return '<input class="wwdate" size="12" value="' + theDate.date.format("MM/DD/YYYY") + '"> at ' +
                '<span class="wwtime" contenteditable="true"> ' + theDate.date.format("hh:mmA") + '</span>'; 
        }
    });

    // pstaab:  clean this up a bit.  Try to put the html into a template. 

    Backbone.Stickit.addHandler({
        selector: '.edit-datetime',
        initialize: function($el,model,options){
            var setModel = function(evt,timeStr){
                console.log("in edit-datetime, setModel");
                var dateTimeStr = evt.data.$el.children(".wwdate").val() + " " + 
                        (timeStr ? timeStr : evt.data.$el.children(".wwtime").text().trim());
                var date = moment(dateTimeStr,"MM/DD/YYYY hh:mmA");

                // not sure what's going on here.  
                evt.data.model.set(evt.data.options.observe,""+date.unix()); 
                //console.log(evt.data.model.attributes);
            };
            var popoverHTML = "<div><input class='wwtime' value='" + 
                moment.unix(model.get(options.observe)).format("h:mm a") + "'>" + 
                "<br><button class='btn'>Save</button></div>";
            var timeIcon = $el.children(".open-time-editor");
            timeIcon.popover({title: "Change Time:", html: true, content: popoverHTML,
                trigger: "manual"});
            timeIcon.parent().delegate(".btn","click",{$el:$el.closest(".edit-datetime"), model: model, options: options},
                function (evt) {
                    timeIcon.popover("hide");
                    setModel(evt,$(this).siblings(".wwtime").val());
            })
            $el.children(".wwdate").on("change",{"$el": $el, "model": model, "options": options}, setModel);
            $el.children(".wwtime").on("blur",{"$el": $el, "model": model, "options": options}, setModel);
            timeIcon.parent().on("click",".open-time-editor", function() {
                timeIcon.popover("toggle");
            });
            $el.children(".wwdate").datepicker();

        },
        updateMethod: 'html',
        
        onGet: function(val) { // this is passed in as a moment Object
            var theDate = moment.unix(val);
            var tz = (theDate.toDate() + "").match(/\((.*)\)/)[1];
            return "<input class='wwdate' size='12' value='" + theDate.format("MM/DD/YYYY") + "''>" +
            "<span class='open-time-editor'><i class='icon-time'></i></span>";
            //'<span class="wwtime" contenteditable="true"> ' + theDate.format("hh:mmA") + '</span>';
        }
    });

    Backbone.Stickit.addHandler({
        selector: ".show-datetime",
        onGet: function(val) {  // this is passed in as a moment Object
            console.log(val);
            var theDate = moment.unix(val);
            var tz = (theDate.toDate() + "").match(/\((.*)\)/)[1];
            return theDate.format("MM/DD/YYYY") + " at " + theDate.format("hh:mmA") + " " + tz;
        }
      
    });

    Backbone.Stickit.addHandler({
        selector: '.select-with-disables',
        getVal: function($el) { 
                return $el.val(); 
        }, 

        update: function($el, val, model, options) { 
            $el.html("");

            var disabledOptions  = eval(options.selectOptions.disabledCollection);

           _(eval(options.selectOptions.collection)).each(function(item){
                $el.append("<option value='"+item.value+"' >" + item.label + "</option>");
            });

            _(disabledOptions).each(function(user){
                $el.children("option[value='" + user + "']").prop("disabled",true);
            })

            _(val).each(function(user){
              $el.children("option[value='" + user + "']").prop("selected",true);  
            })


            }
    });

    return config;
});