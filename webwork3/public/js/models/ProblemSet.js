/*
 * The core model for a ProblemSet.  A problem set has its own properties (such as due dates), but is also a collection
 * of problems.  More specifially, it also contains a Problem List of type "Problem Set".
 *
 * */
define(['backbone', 'underscore','moment','./ProblemList','./Problem','config','apps/util'],
    function(Backbone, _,moment,ProblemList,Problem,config,util){


var ProblemSet = Backbone.Model.extend({
    defaults:{
        set_id: "",
        set_header: "",
        hardcopy_header: "",
        open_date: "",
        due_date: "",
        answer_date: "",
        reduced_scoring_date: "",
        visible: false,
        enable_reduced_scoring: false,
        assignment_type: "default",
        attempts_per_version: -1,
        time_interval: 0,
        versions_per_interval: 0,
        version_time_limit: 0,
        version_creation_time: 0,
        problem_randorder: false,
        version_last_attempt_time: 0,
        problems_per_page: 0,
        hide_score: "N",
        hide_score_by_problem: "N",
        hide_work: "N",
        hide_hint: false,
        time_limit_cap: false,
        restrict_ip: "No",
        relax_restrict_ip: "No",
        restricted_login_proctor: "No",
        assigned_users: [],
        problems: null,
        description: "",
        pg_password: "",
    },
    validation: {
       open_date: "checkDates",
        due_date: "checkDates",
        answer_date: "checkDates",
        reduced_scoring_date: "checkDates",
        set_id: {
            setNameValidator: 1 // uses a custom validator
        }
    },
    integerFields: ["open_date","reduced_scoring_date","due_date","answer_date",
                    "attempts_per_version","version_creation_time","version_time_limit",
                    "problems_per_page","versions_per_interval","version_last_attempt_time","time_interval"],
    idAttribute: "_id",
    initialize: function (opts,dateSettings) {
        var self = this;
        _.bindAll(this,"addProblem");
        this.dateSettings = dateSettings;
        opts.problems = opts.problems || [];
        this.set(this.parse(opts),{silent: true});
    },
    save: function(attrs, options) {
      options || (options = {});
      attrs || (attrs = _(this.attributes).clone());
      delete attrs.problems;

      console.log("in ProblemSet.save");

      // this prevents all of the rendered problems to be sent back to the server
      var probs = this.problems.clone();
      probs.each(function(p){
        p.unset("data",{silent: true});
      });
      attrs.problems=probs.models;

      return  Backbone.Model.prototype.save.call(this, attrs, options);
    },
    parse: function (response) {
        if (response.problems){
            if (typeof(this.problems)=="undefined"){
                this.problems = new ProblemList();
            }
            this.problems.set(response.problems);
            this.attributes.problems = this.problems;
        }
        response.assignment_type = response.assignment_type || "default";
        response = util.parseAsIntegers(response,this.integerFields);
        return _.omit(response, 'problems');
    },
    url: function () {
        return config.urlPrefix + "courses/" + config.courseSettings.course_id + "/sets/" + this.get("set_id") ;
    },
    setDefaultDates: function (theDueDate){   // sets the dates based on the _dueDate (or today if undefined)
                                            // as a moment object and defined settings.

        var _dueDate = theDueDate? moment(theDueDate): moment()
        , timeAssignDue = moment(this.dateSettings["pg{timeAssignDue}"],"hh:mmA")
        , assignOpenPriorToDue = this.dateSettings["pg{assignOpenPriorToDue}"]
        , answerAfterDueDate = this.dateSettings["pg{answersOpenAfterDueDate}"]
        , reducedScoringPeriod = this.dateSettings["pg{ansEvalDefaults}{reducedScoringPeriod}"];

        _dueDate.hours(timeAssignDue.hours()).minutes(timeAssignDue.minutes());
        var _openDate = moment(_dueDate).subtract(parseInt(assignOpenPriorToDue),"minutes")
            , _answerDate = moment(_dueDate).add(parseInt(answerAfterDueDate),"minutes")
            , _reducedScoringDate = moment(_dueDate).subtract(parseInt(reducedScoringPeriod),"minutes");
        this.set({due_date: _dueDate.unix(), open_date: _openDate.unix(), answer_date: _answerDate.unix(),
                    reduced_scoring_date: _reducedScoringDate.unix()});
        return this;
    },
    addProblem: function (prob) {
        var self = this;
        var lastProblem = this.get("problems").last();
        //var prob = new Problem();
        var attrs = _.extend({},prob.attributes,
                                    { problem_id: lastProblem ? parseInt(lastProblem.get("problem_id"))+1:1});
        this.get("problems").add(_(attrs).omit("_id"));;
        this.set("_add_problem",true);
        this.save();
        this.unset("_add_problem",{silent: true});
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
            , answerDate = moment.unix(computedState.answer_date)
            , reducedScoringDate = moment.unix(computedState.reduced_scoring_date);

        // the following prevents the rest of the code from checking more than once per validation.
        // since there are 4 fields that use this method for validation, it gets called 4 times.
        this.numChecks = this.numChecks? this.numChecks+=1: 1;
        if(this.numChecks==4){ delete this.numChecks;}
        if(this.numChecks>1) { return;}

        if(openDate.isAfter(dueDate)){
            this.trigger("set_date_error",{type: "date_error", set_id: this.get("set_id"), date1: "open date",
                    date2: "due date"},this);
            return "open date is after due date";
        }
        if (dueDate.isAfter(answerDate)){
            this.trigger("set_date_error",{type: "date_error", set_id: this.get("set_id"), date1: "due date",
                    date2: "answer date"},this);
            return "due date is after answer date";
        }
        if(computedState.enable_reduced_scoring==1){
            if(reducedScoringDate.isAfter(dueDate)){
                this.trigger("set_date_error",{type: "date_error", set_id: this.get("set_id"),
                    date1: "reduced scoring date", date2: "due date"},this);
                    return "reduced scoring date is after due date";
            }
            if(openDate.isAfter(reducedScoringDate)){
                this.trigger("set_date_error",{type: "date_error", set_id: this.get("set_id"), date1: "open date",
                    date2: "reduced scoring date"},this);
                    return "due date is after reduced scoring date";
            }
        }
    },
    // this checks if the problem set is open.  Using current time to determine this.
    isOpen: function(){
        var openDate = moment.unix(this.get("open_date"))
            , dueDate = moment.unix(this.get("due_date"))
            , now = moment();
        return now.isBefore(dueDate) && now.isAfter(openDate);
    },
    // this adjusts all of the dates to make sure that they don't trigger an error.
    adjustDates: function (){
        var self = this;

        // this only works in a single date is changed.
        if(_(this.changed).keys().length!=1){
            return;
        }
        var prevAttr = _.object([[_(this.changed).keys()[0],moment.unix(this._previousAttributes[_(this.changed).keys()[0]])]])


        var prevDates = _(util.parseAsIntegers(this._previousAttributes,this.integerFields))
                                             .pick("answer_date","due_date","reduced_scoring_date","open_date");
        // convert all of the dates to Moment objects.
        // dates1 is the moment objects of the previous dates
        // dates2 is the moment objects of the new dates.
        var dates1 = _(prevDates).mapObject(function(val,key) { return moment.unix(val);});
        var dates2 = _(this.pick("answer_date","due_date","reduced_scoring_date","open_date")).chain()
                        .mapObject(function(val,key) { return moment.unix(val);}).value();

        var mins_a_d = dates1.answer_date.diff(dates1.due_date,'minutes');
        var mins_d_r = dates1.due_date.diff(dates1.reduced_scoring_date,'minutes');
        var mins_r_o = dates1.reduced_scoring_date.diff(dates1.open_date,'minutes');
        if(mins_a_d < 0) {mins_a_d=0;}
        if(mins_d_r < 0){mins_d_r=0;}
        if(mins_r_o < 0){mins_r_o=0;}

        if(this.changed.answer_date){
            if(dates2.answer_date.isBefore(dates2.due_date)){
                dates2.due_date = moment(dates2.answer_date).subtract(mins_a_d,"minutes");
            }
            if(dates2.due_date.isBefore(dates2.reduced_scoring_date)){
                dates2.reduced_scoring_date = moment(dates2.due_date).subtract(mins_d_r,"minutes");
            }
            if(dates2.reduced_scoring_date.isBefore(dates2.open_date)){
                dates2.open_date = moment(dates2.reduced_scoring_date).subtract(mins_r_o,"minutes");
            }
        } else if(this.changed.due_date){
            if(dates2.due_date.isAfter(dates2.answer_date)){
                dates2.answer_date = moment(dates2.due_date).add(mins_a_d,"minutes");
            }
            if(dates2.due_date.isBefore(dates2.reduced_scoring_date)){
                dates2.reduced_scoring_date = moment(dates2.due_date).subtract(mins_d_r,"minutes");
            }
            if(dates2.reduced_scoring_date.isBefore(dates2.open_date)){
                dates2.open_date = moment(dates2.reduced_scoring_date).subtract(mins_r_o,"minutes");
            }
        } else if(this.changed.reduced_scoring_date) {
            if(dates2.reduced_scoring_date.isAfter(dates2.due_date)){
                dates2.due_date = moment(dates2.reduced_scoring_date).add(mins_d_r,"minutes");
            }
            if(dates2.due_date.isAfter(dates2.answer_date)){
                dates2.answer_date = moment(dates2.due_date).add(mins_a_d,"minutes");
            }
            if(dates2.reduced_scoring_date.isBefore(dates2.open_date)){
                dates2.open_date = moment(dates2.reduced_scoring_date).subtract(mins_r_o,"minutes");
            }
        } else if(this.changed.open_date){
            if(dates2.open_date.isAfter(dates2.reduced_scoring_date)){
                dates2.reduced_scoring_date = moment(dates2.open_date).add(mins_r_o,"minutes");
            }
            if(dates2.reduced_scoring_date.isAfter(dates2.due_date)){
                dates2.due_date = moment(dates2.reduced_scoring_date).add(mins_d_r,"minutes");
            }
            if(dates2.due_date.isAfter(dates2.answer_date)){
                dates2.answer_date = moment(dates2.due_date).add(mins_a_d,"minutes");
            }
        }

        var changedKeys = _(dates1).chain().keys().filter(function(key)
                                                {return !dates1[key].isSame(dates2[key]);}).value();
        // get the unix dates of the dates that have changed.
        var newUnixDates =  _(dates2).chain().pick(changedKeys)
                                .mapObject(function(val,key) { return val.unix();}).value();

        this.set(newUnixDates);
    }

});



return ProblemSet;
});
