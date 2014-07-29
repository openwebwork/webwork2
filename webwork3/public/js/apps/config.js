/***
 *  This object contains many common things needed by all other objects
 *
 **/


define(['backbone','underscore','moment','backbone-validation','stickit','jquery-ui'], function(Backbone,_,moment){

    $(document).ajaxError(function (e, xhr, options, error) {
        if(xhr.status==503){
            alert("It doesn't appear that Dancer is running. See the installation guide at http://webwork.maa.org to fix this.");
        }
    });
    
    var config = {
        urlPrefix: "/webwork3/",

        // This is temporary to get the handshaking set up to dancer. 
        // in the future this should be taken care of with dancer
        courseSettings: {
            "session_key": $("#hidden_key").val(),
            "user": $("#hidden_user").val(),
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
    

        permissions : [{value: -5, label: "guest"},{value: 0, label: "student"},{value: 2, label: "login proctor"}, 
                        {value: 3, label: "T.A."},{value: 10, label: "professor"}, {value: 20, label: "administrator"}],

        regexp : {
            wwDate:  /^((\d?\d)\/(\d?\d)\/(\d{4}))\sat\s((0?[1-9]|1[0-2]):([0-5]\d)([aApP][mM]))\s([a-zA-Z]{3})/,
            number: /^\d*(\.\d*)?$/,
            loginname: /^[\w\d\_]+$/
        },
        displayFloat: function(val,digits){
            return Math.round(val*Math.pow(10,digits))/Math.pow(10,digits);
        }
    } 

    config.messageTemplate= _.template($("#general-messages").html());

    // These are additional validation patterns to be available to Backbone Validation

    _.extend(Backbone.Validation.patterns, { "wwdate": config.regexp.wwDate}); 
    _.extend(Backbone.Validation.patterns, { "setname": /^[\w\d\_\.]+$/});
    _.extend(Backbone.Validation.patterns, { "loginname": config.regexp.loginname});
    //_.extend(Backbone.Validation.patterns, { "loginname": /^[\w\d\_]+$/});
    _.extend(Backbone.Validation.validators, {
        setNameValidator: function(value, attr, customValue, model) {
            if(!Backbone.Validation.patterns["setname"].test(value))
                return config.msgTemplate({type:"set_name_error"});
            },
        checkLogin: function(value,attr,customValue,model){
            if(!value.match(config.regexp.loginname)){
                return "Value must be a valid login name"; // add to messageTemplate
            }
            if(model.collection.courseUsers && model.collection.courseUsers.findWhere({user_id: value})){
                return "The user with login " + value + " already exists in this course.";
            }
        }

    });

    _.extend(Backbone.Model.prototype, Backbone.Validation.mixin);  

    // This implements a stickit handler for elements of type wwdate
    // see https://github.com/NYTimes/backbone.stickit for more info.
    //
    // This takes a webwork date-time (for open_date, due-date, etc.) and creates a pair of html spans to handle 
    // the date and time separately
    //
    // note, pstaab: I think the Handler ".edit-datetime" is better.  Need to check where .ww-datetime is used

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
      onGet: function(val) { 

        var theDate = config.parseWWDate(val);
        return '<input class="wwdate" size="12" value="' + theDate.date.format("MM/DD/YYYY") + '"> at ' +
                '<span class="wwtime" contenteditable="true"> ' + theDate.date.format("hh:mmA") + '</span>'; 
        }
    });

    Backbone.Stickit.addHandler({
        selector: '.show-datetime',
        onGet: function(val){
            return moment(val).format("MM/DD/YYYY [at] hh:mmA");
        }
    });

    // The following is a stickit handler that will display the time from now (or ago) in a human readable way.

    Backbone.Stickit.addHandler({
        selector:".show-datetime-timeago",
        onGet: function(val){
            return moment.unix(val).from(moment());
        }
    });

    // The main stickit handler for any editable date-time class.

    Backbone.Stickit.addHandler({
        selector: '.edit-datetime',
        update: function($el, val, model, options){
            // hide this for sets in which the reduced_scoring date should not be shown. 
            if(options.observe==="reduced_scoring_date" && ! model.get("enable_reduced_scoring") 
                    && ! model.show_reduced_scoring){
                $el.html("");
            } else {
                $el.html(_.template($("#edit-date-time-template").html(),{date: moment.unix(val).format("MM/DD/YYYY")}));        
            }
            
            var setDate = function(evt){
                var newDate = moment(evt.data.$el.children(".wwdate").val(),"MM/DD/YYYY");
                var theDate = moment.unix(evt.data.model.get(evt.data.options.observe));
                theDate.year(newDate.year()).months(newDate.months()).date(newDate.date());
                evt.data.model.set(evt.data.options.observe,""+theDate.unix()); 
            };
            var setTime = function(evt,timeStr){
                var newDate = moment(timeStr,"hh:mmA");
                var theDate = moment.unix(evt.data.model.get(evt.data.options.observe));
                theDate.hours(newDate.hours()).minutes(newDate.minutes());
                evt.data.model.set(evt.data.options.observe,""+theDate.unix()); 
            };

            var popoverHTML = _.template($("#time-popover-template").html(),
                        {time : moment.unix(model.get(options.observe)).format("h:mm a")});
            var timeIcon = $el.children(".open-time-editor");
            timeIcon.popover({title: "Change Time:", html: true, content: popoverHTML,
                trigger: "manual"});
            timeIcon.parent().delegate(".save-time-button","click",{$el:$el.closest(".edit-datetime"),
                             model: model, options: options},
                function (evt) {
                    timeIcon.popover("hide");
                    setTime(evt,$(this).siblings(".wwtime").val());
            });
            timeIcon.parent().delegate(".cancel-time-button","click",{},function(){timeIcon.popover("hide");});
            $el.children(".wwdate").on("change",{"$el": $el, "model": model, "options": options}, setDate);
            $el.children(".wwtime").on("blur",{"$el": $el, "model": model, "options": options}, setTime);
            timeIcon.parent().on("click",".open-time-editor", function() {
                timeIcon.popover("toggle");
            });
            $el.children(".wwdate").datepicker({changeMonth: true, changeYear: true});
        },
        updateMethod: 'html'
    });

    Backbone.Stickit.addHandler({
        selector: ".show-datetime",
        onGet: function(val) {  // this is passed in as a moment Object
            var theDate = moment.unix(val);
            var tz = (theDate.toDate() + "").match(/\((.*)\)/)[1];
            return theDate.format("MM/DD/YYYY") + " at " + theDate.format("hh:mmA") + " " + tz;
        }
      
    });

    Backbone.Stickit.addHandler({
        selector: '.show-set-popup-info',
        update: function($el, val, model, options){
            var popoverHTML = model.get("popupTemplate")(model.attributes);
            var _title = model.get("assign_type").replace("_"," ") + " Date";
            $el.popover({title: _title.charAt(0).toUpperCase() + _title.slice(1), html: true, 
                        content: popoverHTML, container: "body"});
            $el.on("shown.bs.popover",function(){
                $("a.goto-problem-set-button[data-setname='"+model.get("set_id")+"']").off()
                    .on("click",function(evt){
                        $el.popover("hide");
                        model.get("eventDispatcher").trigger("show-problem-set",$(evt.target).data("setname"));
                })
            });
            var info = "";
            switch (model.get("assign_type")){
                case "due":
                    info = "D";
                    break;
                case "reduced-scoring":
                    info = "R";
                    break;
                case "answer":
                    info = "A";
                    break;
                case "open":
                    info = "O";
                    break;
            }
            $el.text(info);
        },
        updateMethod: 'html'
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

    // need to include the yes/no or true/false in the template for I18n

    Backbone.Stickit.addHandler({
        selector: ".TF-boolean-select",
        selectOptions: { collection : ["true","false"]},
        onGet: function(val){
            return val ? "true" : "false";
        },
        onSet: function(val){
            return val==="true";
        }
    })

    Backbone.Stickit.addHandler({
        selector: ".yes-no-boolean-select",
        selectOptions: { collection : ["yes","no"]},
        onGet: function(val){
            return val ? "yes" : "no";
        },
        onSet: function(val){
            return val==="yes";
        }
    })


    return config;
});