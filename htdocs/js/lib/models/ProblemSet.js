/*
 * The core model for a ProblemSet.  A problem set has its own properties (such as due dates), but is also a collection 
 * of problems.  More specifially, it also contains a Problem List of type "Problem Set".  
 *
 * */
define(['Backbone', 'underscore','config','moment','./ProblemList'], function(Backbone, _, config,moment,ProblemList){


    var ProblemSet = Backbone.Model.extend({
        defaults:{
            set_id: "",
            set_header: "",
            hardcopy_header: "",
            open_date: "",
            due_date: "",
            answer_date: "",
            visible: 0,
            enable_reduced_scoring: 0,
            assignment_type: "",
            attempts_per_version: -1,
            time_interval: 0,
            versions_per_interval: 0,
            version_time_limit: 0,
            version_creation_time: 0,
            problem_randorder: 0,
            version_last_attempt_time: 0,
            problems_per_page: 1,
            hide_score: "N",
            hide_score_by_problem: "N",
            hide_work: "N",
            time_limit_cap: "0",
            restrict_ip: "No",
            relax_restrict_ip: "No",
            restricted_login_proctor: "No",
            assigned_users: []
        },
        validation: {
            open_date: {
                pattern: "wwdate",
                msg: "This must be in the form mm/dd/yyyy at hh:mm AM/PM"
            },
            due_date: {
                pattern: "wwdate",
                msg: "This must be in the form mm/dd/yyyy at hh:mm AM/PM"
            },
            answer_date: {
                pattern: "wwdate",
                msg: "This must be in the form mm/dd/yyyy at hh:mm AM/PM"
            },
            set_id: {pattern: "setname"}
        },
        descriptions:  {
            set_id: "Homework Set Name",
            set_header: "Header File for Homework Set",
            hardcopy_header: "Header File for A Hardcopy of the Homework Set",
            open_date: "Date and Time that the Homework Set opens",
            due_date: "Date and Time that the Homework Set is due",
            answer_date: "Date and time that the answers are made available",
            visible: "Visible to Students",
            enable_reduced_scoring: "Is reduced scoring available?",
            assignment_type: "Type of the Assignment",
            attempts_per_version: "Number of Attempts Per Version",
            time_interval: "Time Interval for something???",
            versions_per_interval: "Versions per Interval ???",
            version_time_limit: "Version Time Limit",
            version_creation_time: "Version Creation Time",
            problem_randorder: "View Problems in a Random Order",
            version_last_attempt_time: "Version last attempt time????",
            problems_per_page: "Number of Problems Per Page",
            hide_score: "Hide the Score to the Student",
            hide_score_by_problem: "Hide the Score by Problem?",
            hide_work: "Hide the Work?",
            time_limit_cap: "Time Limit Cap???",
            restrict_ip: "Restrict by IP Address???",
            relax_restrict_ip: "Relax Restrict IP???",
            restricted_login_proctor: "Restricted to Login Proctor"
        },
        types: {
            set_id: "string",
            set_header: "filepath",
            hardcopy_header: "filepath",
            open_date: "datetime",
            due_date: "datetime",
            answer_date: "datetime",
            visible: "opt(yes,no)",
            enable_reduced_scoring: "opt(yes,no)",
            assignment_type: "opt(homework,gateway/quiz,proctored gateway/quiz)",
            attempts_per_version: "int(0+)",
            time_interval: "time(0+)",
            versions_per_interval: "int(0+)",
            version_time_limit: "time(0+)",
            version_creation_time: "time(0+)",
            problem_randorder: "opt(yes,no)",
            version_last_attempt_time: "time(0+)",
            problems_per_page: "int(1+)",
            hide_score: "opt(yes,no)",
            hide_score_by_problem: "opt(yes,no)",
            hide_work: "opt(yes,no)",
            time_limit_cap: "opt(yes,no)",
            restrict_ip: "opt(yes,no)",
            relax_restrict_ip: "opt(yes,no)",
            restricted_login_proctor: "opt(yes,no)",
        },
        initialize: function(){
            _.bindAll(this,"fetch","addProblem","update");
            this.on('change',function(){
                console.log("The Problem Set " + this.get("set_id") + " just changed.");
            });
            this.problems = null;
            this.saveProblems = [];   // holds added problems temporarily if the problems haven't been loaded. 
        },
        setDefaultDates: function (theDueDate){   // sets the dates based on the _dueDate (or today if undefined) 
                                                // as a moment object and defined settings.

            var _dueDate = theDueDate? moment(theDueDate): moment()
            , timeAssignDue = moment(config.settings.getSettingValue("pg{timeAssignDue}"),"hh:mmA")
            , assignOpenPriorToDue = config.settings.getSettingValue("pg{assignOpenPriorToDue}")
            , answerAfterDueDate = config.settings.getSettingValue("pg{answersOpenAfterDueDate}"); 

            _dueDate.hours(timeAssignDue.hours()).minutes(timeAssignDue.minutes());
            var _openDate = moment(_dueDate).subtract(parseInt(assignOpenPriorToDue),"minutes")
            , _answerDate = moment(_dueDate).add(parseInt(answerAfterDueDate),"minutes");
            this.set({due_date: _dueDate.unix(), open_date: _openDate.unix(), answer_date: _answerDate.unix()});
            return this;
        },
        addProblem: function (prob) {  
            var self = this; 
            if (this.problems) {
                this.problems.addProblem(prob);
            }  else {  // the problems haven't loaded.
                console.log("Problem Set " + this.get("set_id") + " not loaded. ");
                console.log(prob);
                this.saveProblems.push(prob);
                this.problems = new ProblemList({setName: self.get("set_id"),   type: "Problem Set"});
                this.problems.on("fetchSuccess",function () {
                    _(self.saveProblems).each(function (_prob) {
                        self.problems.addProblem(_prob);
                    });
                    this.saveProblems = new Array(); 
                });
            }
        },
        // sets the date for the field attr  in the form YYYY/MM/DD (should be more flexible)
        setDate: function(attr,_date){
            var currentDate = moment.unix(this.get(attr))
                , newDate = moment.unix(_date);

            currentDate.year(newDate.year()).month(newDate.month()).date(newDate.date());
            this.set(attr,currentDate.unix());
            console.log("the date was set for " + this.get("set_id"));
            return this;

        },
        update: function(){
            
            console.log("in ProblemSet update");
            var self = this;
            var requestObject = {
                "xml_command": 'updateSetProperties'
            };
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);

            requestObject.assigned_users = requestObject.assigned_users.join(",");

            $.post(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
                console.log("saved the ProblemSet");
      	        self.trigger("saved",self);
            });
        },
        fetch: function()  // this fetches the problems for the ProblemSet.  
        {
            var self=this;
            var requestObject = { xml_command: "getSet"};
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject, function (data) {
                    console.log("fetching problem set " + self.get("set_id"));
                    var response = $.parseJSON(data);
                    self.problems = new ProblemList({setName: self.get("set_id"), type: "Problem Set"}); 

                    self.problems.on("deleteProblem",function(place) {
                        self.trigger("deleteProblem",self.get("set_id"),place);
                    })      
                });       
        }
    });
     


    return ProblemSet;
});
    
    