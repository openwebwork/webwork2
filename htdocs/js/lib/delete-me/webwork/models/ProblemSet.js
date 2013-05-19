/*
 * The core model for a ProblemSet.  A problem set has its own properties (such as due dates), but is also a collection 
 * of problems.  More specifially, it also contains a Problem List of type "Problem Set".  
 *
 * */
define(['Backbone', 'underscore','config','XDate','./ProblemList'], function(Backbone, _, config,XDate,ProblemList){


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
            _.bindAll(this,"fetch","addProblem","update","getAssignedUsers");
            this.on('change',this.update);
            this.assignedUsers = null; 
            this.saveProblems = new Array();   // holds added problems temporarily if the problems haven't been loaded. 
            
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
        update: function(){
            
            console.log("in ProblemSet update");
            var self = this;
            var requestObject = {
                "xml_command": 'updateSetProperties'
            };
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);

            console.log(requestObject);

            $.post(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);
      	        self.collection.trigger("problem-set-changed",self)
            });
        },
        fetch: function()
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
        },

        /* This returns a boolean if the current hw set is open.  The date can be passed in either as a native 
        * Date object, XDate object or webwork date object. The parameter reducedCredit is the number of mins of reduced 
        * credit time available. 
        */
        isDueOn: function (_date,reducedCredit){
            var date = new XDate(_date);
            var dueDate = new XDate(this.get("due_date"));
            var reducedDate = new XDate(dueDate.getTime()-1000*60*reducedCredit);
            return ((date.getMonth()===reducedDate.getMonth()) && (date.getDate()===reducedDate.getDate()) && (date.getFullYear() ===reducedDate.getFullYear()));
        },
        isOpen: function (_date,reducedCredit){
            var date = new XDate(_date);
            var openDate = new XDate(this.get("open_date"));
            var dueDate = new XDate(this.get("due_date"));
            var reducedDate = new XDate(dueDate.getTime()-1000*60*reducedCredit);
            return ((date >openDate) && (date < reducedDate));

        },
        isInReducedCredit: function (_date,reducedCredit){
            //console.log(this.get("set_id") + " " + this.);
            if (this.get("enable_reduced_scoring")==="no") {return false;}
            var date = new XDate(_date);
            var openDate = new XDate(this.get("open_date"));
            var dueDate = new XDate(this.get("due_date"));
            var reducedDate = new XDate(dueDate.getTime()-1000*60*reducedCredit);
            return ((date >reducedDate) && (date < dueDate));

        },
        overlaps: function (_set){
            var openDate1 = new XDate(this.get("open_date"));
            var dueDate1 = new XDate(this.get("due_date"));
            var openDate2 = new XDate(_set.get("open_date"));
            var dueDate2 = new XDate(_set.get("due_date"));
            return (openDate1<openDate2)?(dueDate1>openDate2):(dueDate2>openDate1);
        },
        getAssignedUsers: function ()
        {
            var self=this;
            
            var requestObject = { xml_command: "listSetUsers"};
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject, function (data) {

                var response = $.parseJSON(data);
                self.assignedUsers = response.result_data;
                self.trigger("usersLoaded", self);                

            });        
        },

        // Currently, the list of users assigned to this set (stored in this.assignedUsers) is just an array
        // of user_id's.  Perhaps, we should consider making this a UserList instead.  (Have to think about the pros and cons)
        assignToUsers: function (_users){  // assigns this problem set to the users that come in as an array of usernames.  
            var self = this;

            console.log("Assigning Problem Set " + this.get("set_id") + " to " + _users.join(" ")); 
            var requestObject = {xml_command: "assignSetToUsers", users: _users.join(","), set_id: this.get("set_id")};
            _.defaults(requestObject,config.requestObject);

            $.post(config.webserviceURL, requestObject, function(data) {
                var response = $.parseJSON(data);

                console.log(response);
                self.trigger("usersAssigned", _users, self.get("set_id"));

            });

        },
        updateUserSet: function(_users,_openDate,_dueDate,_answerDate){
            var self = this;
            console.log("Updating the dates to users " + _users);
            var requestObject = {xml_command: "updateUserSet", users: _users.join(","), set_id: this.get("set_id"),
                                    open_date: _openDate, due_date: _dueDate, answer_date: _answerDate};
            console.log(requestObject);
            _.defaults(requestObject, config.requestObject);
            $.post(config.webserviceURL, requestObject, function (data){
                var response = $.parseJSON(data);
                console.log(response);
            });
        },
        unassignUsers: function(_users){
            var self = this;
            console.log("Unassigning users " + _users + " from set " + this.get("set_id"));
            var requestObject = {xml_command: "unassignSetFromUsers", users: _users.join(","), set_id: this.get("set_id")};
            _.defaults(requestObject, config.requestObject);
            $.post(config.webserviceURL, requestObject, function (data){
                var response = $.parseJSON(data);
                console.log(response);
            });  
        }


    });
     


    return ProblemSet;
});
    
    