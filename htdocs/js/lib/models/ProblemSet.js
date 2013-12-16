/*
 * The core model for a ProblemSet.  A problem set has its own properties (such as due dates), but is also a collection 
 * of problems.  More specifially, it also contains a Problem List of type "Problem Set".  
 *
 * */
define(['Backbone', 'underscore','config','moment','./ProblemList','./Problem','config'], 
        function(Backbone, _, config,moment,ProblemList,Problem,config){


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
            assigned_users: [],
            problems: null
        },
        validation: {
           open_date: "checkDates",
            due_date: "checkDates",
            answer_date: "checkDates",
            set_id: {  
                setNameValidator: 1 // uses your custom validator
            }
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
        idAttribute: "set_id",
        initialize: function (opts) {
            _.bindAll(this,"addProblem");
            var pbs = (opts && opts.problems) ? opts.problems : [];
            this.problems = new ProblemList(pbs);
            this.attributes.problems = this.problems;
            this.saveProblems = [];   // holds added problems temporarily if the problems haven't been loaded. 
        },
        parse: function (response) {
            if (response.problems){
                this.problems.set(response.problems);
                this.attributes.problems = this.problems;
            }
            return _.omit(response, 'problems');
        },
        url: function () {
            return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.get("set_id") ;
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
            var lastProblem = this.get("problems").last();
            newProblem.set("problem_id",lastProblem ? parseInt(lastProblem.get("problem_id"))+1:1);
            this.get("problems").add(newProblem);
            this.trigger("change:problems",this); // 
            this.save();
        },
        setDate: function(attr,_date){ // sets the date of open_date, answer_date or due_date without changing the time
            var currentDate = moment.unix(this.get(attr))
                , newDate = moment.unix(_date);
            currentDate.year(newDate.year()).month(newDate.month()).date(newDate.date());
            this.set(attr,currentDate.unix());
            return this;

        },
        checkDates: function(value, attr, computedState){
            var openDate = moment.unix(computedState.open_date)
                , dueDate = moment.unix(computedState.due_date)
                , answerDate = moment.unix(computedState.answer_date);

            if(openDate.isAfter(dueDate)){ 
                return config.msgTemplate({type: "openDate_after_dueDate"});
            }
            if (dueDate.isAfter(answerDate)){
                return config.msgTemplate({type: "dueDate_after_answerDate"});
            }
        }
    });
     


    return ProblemSet;
});
    
    