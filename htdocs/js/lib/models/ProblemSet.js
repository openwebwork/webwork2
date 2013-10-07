/*
 * The core model for a ProblemSet.  A problem set has its own properties (such as due dates), but is also a collection 
 * of problems.  More specifially, it also contains a Problem List of type "Problem Set".  
 *
 * */
define(['Backbone', 'underscore','config','moment','./ProblemList','./Problem'], 
        function(Backbone, _, config,moment,ProblemList,Problem){


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
           /* open_date: {
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
            }, */
            set_id: {pattern: "setname", msg: "A name must only contain letters, numbers, _ and ."}
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
        initialize: function(_set,_assigned_users){
            _.bindAll(this,"addProblem");
            /*if (_set && _set.problems){
                var problems = new ProblemList(_set.problems);
                problems.setName = _set.set_id;
                this.set("problems",problems,{silent: true});
            } else {
                this.set("problems",new ProblemList(),{silent: true});
            }

            if(_assigned_users){
                this.set("assigned_users",_assigned_users);
            }*/

            this.saveProblems = [];   // holds added problems temporarily if the problems haven't been loaded. 
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.courseID + "/sets/" + this.get("set_id") ;
        },
        parse: function (response) {
            var self = this;
            _(_.keys(response)).each(function(key){
                if(key==="problems"){
                    self.attributes.problems = new ProblemList(response.problems);
                    self.attributes.problems.setName = response.set_id;
                } else {
                    self.attributes[key]=response[key];
                }
            });
            this.id = this.get("set_id");
        },
        save: function(opts){
            var self = this;
            var attrs = this.changedAttributes();
            if(attrs){
                this.alteredAttributes = _(_(attrs).keys()).map(function(key){
                    return {attr: key, new_value: attrs[key], old_value: self._previousAttributes[key]};
                });
            }
            ProblemSet.__super__.save.apply(this,opts);
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
            var newProblem = new Problem(prob.attributes);
            if (this.problems) {
                this.problems.add(newProblem);
                newProblem.save();
            }  else {  // the problems haven't loaded.
                console.log("Problem Set " + this.get("set_id") + " not loaded. ");
                console.log(prob);
                this.saveProblems.push(newProblem);
                this.problems = new ProblemList({setName: self.get("set_id"),   type: "Problem Set"});
                this.problems.fetch({success: function () {
                    self.problems.add(self.saveProblems);
                    var lastIndex = parseInt(self.problems.last().get("problem_id"));
                    _(self.saveProblems).each(function(_prob,i){  
                        _prob.set("problem_id",lastIndex+i+1,{silent: true});
                        _prob.save(); 
                    });
                    self.saveProblems = []; 
                } });
            }
        },
        setDate: function(attr,_date){
            var currentDate = moment.unix(this.get(attr))
                , newDate = moment.unix(_date);

            this.alteredAttributes = [{attribute: attr, old_value: currentDate.format("MM/DD/YYYY [at] h:mmA"), 
                                    new_value: newDate.format("MM/DD/YYYY [at] h:mmA")}];
            currentDate.year(newDate.year()).month(newDate.month()).date(newDate.date());
            this.set(attr,currentDate.unix());
            console.log("the date was set for " + this.get("set_id"));
            return this;

        },
/*        saveAssignedUsers: function(success){
            $.ajax({url: config.urlPrefix+"courses/" + config.courseSettings.courseID + "/sets/" + this.get("set_id") + "/users", 
                    data: JSON.stringify({assigned_users: this.get("assigned_users"), set_id: this.get("set_id")}),
                    success: success,
                    type: "PUT",
                    processData: false,
                    contentType: "application/json"});
        }*/
    });
     


    return ProblemSet;
});
    
    