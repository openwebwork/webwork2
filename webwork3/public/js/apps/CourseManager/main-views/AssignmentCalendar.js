/**
  * This is the assignment calendar view. 
  *
  */


define(['backbone', 'underscore', 'moment','views/MainView', 'views/CalendarView','models/UserSetList',
    'models/ProblemSetList','models/ProblemSet','models/AssignmentDateList','models/AssignmentDate', 'config'], 
    function(Backbone, _, moment,MainView, CalendarView,UserSetList,ProblemSetList,ProblemSet,
        AssignmentDateList,AssignmentDate,config) {
	
    var AssignmentCalendar = CalendarView.extend({
        template: this.$("#calendar-date-bar").html(),
        messageTemplate: _.template($("#calendar-messages").html()),
        popupTemplate: _.template(this.$("#calendar-date-popup-bar").html()),
    	initialize: function (options) {
            var self = this;
            CalendarView.prototype.initialize.call(this,options);
    		_.bindAll(this,"render","renderDay","update","showHideAssigns","fetchUserCalendars");

            this.collection = this.problemSets;
            this.collection.on({sync: this.render});

            this.state.on("change:reduced_scoring_date change:answer_date change:due_date change:open_date",
                    this.showHideAssigns);
            this.state.on("change",this.render);
            this.buildAssignmentDates();
            return this;
    	},
    	render: function (){
    		CalendarView.prototype.render.apply(this);
            this.update();

            this.$(".users-container").addClass("hidden"); // hides the container lisiting the users for the Users' Calendar
    		this.$(".assign").popover({html: true});


            // set up the calendar to scroll correctly
            this.$(".calendar-container").height($(window).height()-160);
            $('.show-date-types input, .show-date-types label').click(function(e) {
                e.stopPropagation();
            });

            // show/hide the desired date types
            if(this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")){
                this.$(".assign-reduced-scoring").removeClass("hidden");
            } else {
                this.$(".assign-reduced-scoring").addClass("hidden");
            }

            MainView.prototype.render.apply(this);

            // hides any popover clicked outside.
            $('body').on('click', function (e) {
                $('[data-toggle="popover"]').each(function () {
                    //the 'is' for buttons that trigger popups
                    //the 'has' for icons within a button that triggers a popup
                    if (!$(this).is(e.target) && $(this).has(e.target).length === 0 
                                && $('.popover').has(e.target).length === 0) {
                        $(this).popover('hide');
                    }
                });
            });

            this.stickit(this.state,this.bindings);
            this.showHideAssigns(this.state);
            return this;
    	},
        bindings: {
            ".show-open-date": "open_date",
            ".show-due-date": "due_date",
            ".show-reduced-scoring-date": "reduced_scoring_date",
            ".show-answer-date": "answer_date"
        },
    	renderDay: function (day){
    		var self = this;
            var assignments = this.assignmentDates.where({date: day.model.format("YYYY-MM-DD")});
            _(assignments).each(function(assign){
                var _model = _.extend({assign_type: assign.get("type"),total_users: self.users.length,
                    eventDispatcher: self.eventDispatcher,popupTemplate: self.popupTemplate},
                    assign.get("problemSet").attributes);
                day.$el.append( new DateInfoBar({template: self.template, model: _model}).render().el);
            });

    	},
        getHelpTemplate: function (){
            return $("#calendar-help-template").html();
        },
        update:  function (){
            var self = this;
            // The following allows each day in the calendar to allow a problem set to be dropped on. 
                 
            this.$(".calendar-day").droppable({
                hoverClass: "highlight-day",
                accept: ".sidebar-problem-set, .assign",
                greedy: true,
                drop: function(ev,ui) {
                    ev.stopPropagation();
                    if($(ui.draggable).hasClass("sidebar-problem-set")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"all");
                    } else if ($(ui.draggable).hasClass("assign-open")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"open_date");
                    } else if ($(ui.draggable).hasClass("assign-due")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"due_date");
                    } else if ($(ui.draggable).hasClass("assign-answer")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"answer_date");
                    } else if ($(ui.draggable).hasClass("assign-reduced-scoring")){
                        self.setDate($(ui.draggable).data("setname"),$(this).data("date"),"reduced_scoring_date");
                    }

                }
            });

            // The following allows an assignment date (due, open) to be dropped on the calendar

            this.$(".assign-due,.assign-open,.assign-answer,.assign-reduced-scoring").draggable({
                revert: true,
                start: function () {
                    $(this).children(".show-set-popup-info").popover("destroy")
                }
            });
        },
        // This travels through all of the assignments and determines the days that assignment dates fall
        buildAssignmentDates: function () {
            var self = this;
            this.assignmentDates = new AssignmentDateList();
            this.collection.each(function(_set){
                self.assignmentDates.add(new AssignmentDate({type: "open", problemSet: _set,
                        date: moment.unix(_set.get("open_date")).format("YYYY-MM-DD")}));
                self.assignmentDates.add(new AssignmentDate({type: "due", problemSet: _set,
                        date: moment.unix(_set.get("due_date")).format("YYYY-MM-DD")}));
                self.assignmentDates.add(new AssignmentDate({type: "answer", problemSet: _set,
                        date: moment.unix(_set.get("answer_date")).format("YYYY-MM-DD")}));
                if(parseInt(_set.get("reduced_scoring_date"))>0 && _set.get("enable_reduced_scoring")) {
                    self.assignmentDates.add(new AssignmentDate({type: "reduced-scoring", problemSet: _set,
                        date: moment.unix(_set.get("reduced_scoring_date")).format("YYYY-MM-DD")}) );
                }
            });
            this.collection.on({remove:  function (_set){
                    // update the assignmentDates to delete the proper assignments
                    self.assignmentDates.remove(self.assignmentDates.filter(function(assign) { 
                        return assign.get("problemSet").get("set_id")===_set.get("set_id");}));
                },
                "change:due_date change:open_date change:answer_date change:reduced_scoring_date": function(_set){
                    self.assignmentDates.chain().filter(function(assign) { 
                            return assign.get("problemSet").get("set_id")===_set.get("set_id");})
                        .each(function(assign){
                            assign.set("date",moment.unix(assign.get("problemSet").get(assign.get("type").replace("-","_")+"_date"))
                                .format("YYYY-MM-DD"));
                        });
            } });
    
        },
        fetchUserCalendars: function(_users){
            var self = this, userCalendarsFetched = 0;
            this.selectedUsers = _users;
            if(this.selectedUsers.length==0){
                this.collection = this.problemSets;
                this.buildAssignmentDates();
                this.render();
                return;
            }
            if(typeof(this.userCalendars)==="undefined"){
                this.userCalendars = {};
            }

            _(this.selectedUsers).each(function(_userID){
                if(! _(self.userCalendars).has(_userID)){
                    (self.userCalendars[_userID] = new UserSetList([],{type: "sets", user: _userID}))
                            .fetch({success: function() {self.fetchUserCalendars(self.selectedUsers)}});
                } else {
                    userCalendarsFetched++;
                }
            });
            if(this.selectedUsers.length > 0 && userCalendarsFetched==this.selectedUsers.length){
                this.displayUserSets();
            }
        },
        /* From all of the selected users, 
         *   1) find all those with common sets 
         *   2) make sure the dates on all sets are equal
         *   and only shown those sets with both
         */
        displayUserSets: function(){
            var self = this
                , commonSets = this.problemSets.pluck("set_id")
                , fields = ["enable_reduced_scoring","reduced_scoring_date","answer_date","open_date","due_date"]
                , sent = {}
                , received = {};
            // find all sets in common with all selected users
            _(this.selectedUsers).each(function(_userID){
                commonSets = _(self.userCalendars[_userID].pluck("set_id")).intersection(commonSets);
                self.userCalendars[_userID].off().on({
                    sync: function(model){
                        if(model instanceof UserSetList){return;} // which occurs on a fetch
                        received[_userID] = true;
                        if(_(sent).isEqual(received)){
                            self.render(); 
                            var _key = _(model.changingAttributes).keys()[0]
                            var obj = { 
                                set_id: model.get("set_id"),
                                key: _key,
                                oldValue: moment.unix(model.changingAttributes[_key]).format("MM-DD-YYYY [at] hh:mmA"),
                                newValue: moment.unix(model.get(_key)).format("MM-DD-YYYY [at] hh:mmA")
                            };
                            self.showUserSetSavedMessage(obj);   
                        }
                    },
                    request: function(){
                        sent[_userID]=true;
                    },             
                    change: function(_userSet){
                        _userSet.changingAttributes=_.pick(_userSet._previousAttributes,_.keys(_userSet.changed));
                    }
                });
            })

            this.collection = new ProblemSetList([],{date_settings: this.problemSets.date_settings});
            // eliminate sets with dates that aren't the same as the rest of the sets
            _(commonSets).each(function(_setID){
                var _dates =_.object(fields,["","","","",""]);
                var tmp = [];
                _(self.selectedUsers).each(function(_userID){
                    var fieldDates = _(self.userCalendars[_userID].findWhere({set_id: _setID}).pick(fields)).values();
                    tmp.push(fieldDates);
                });
                var tmp2 = _(_.zip.apply(_,tmp)).map(function(arr) { return _.uniq(arr)});  // transposed tmp
                // if all of the dates are equal, then add this set to the collection.
                if(_(tmp2).chain().map(function(arr) { return arr.length==1;}).every(_.identity).value()){
                    var attrs = _.extend({set_id: _setID},_.object(fields,_.zip.apply(_,tmp2)[0]));
                    self.collection.add(new ProblemSet(attrs));
                }
            });
            console.log(commonSets);
            this.buildAssignmentDates();
            this.collection.on("change", function(model){
                        sent =  {};
                        received = {};
                        console.log("changing the collection");
                        console.log(model);
                        var _dates =model.pick("reduced_scoring_date","answer_date","open_date","due_date"); 
                        _(self.selectedUsers).each(function(_userID){
                            self.userCalendars[_userID].findWhere({set_id: model.get("set_id")}).set(_dates).save();
                        })
                    });

            this.render();
            this.$(".users-container").removeClass("hidden").text(this.messageTemplate({type: "user_calendar_list", 
                    opts: {users: this.selectedUsers}}));

        },
        showUserSetSavedMessage: function(options){
            this.eventDispatcher.trigger("add-message",{type: "success", 
                    short: this.messageTemplate({type:"set_saved",opts:{setname:options.set_id, 
                        users: this.selectedUsers}}),
                    text: this.messageTemplate({type:"set_saved_details",opts:{setname: options.set_id,key: options.key,
                        oldValue: options.oldValue, newValue: options.newValue,
                        users: this.selectedUsers }})});
        },
        showHideAssigns: function(model){
            // define the mapping between fields in the model and assignment classes. 
            var obj = {
                reduced_scoring_date: "assign-reduced-scoring",
                due_date: "assign-due",
                open_date: "assign-open",
                answer_date: "assign-answer"
            }
            var keys;
            if(_(model.changed).chain().keys().contains("first_day").value()){
                return;
            }
            if(_.isEqual(model.changed,{})){
               keys = ["answer_date","open_date","reduced_scoring_date","due_date"]; 
            } else {
               keys = _(model.changed).chain().keys().without("view","first_day").value();
            }
            _(keys).each(function(key){
                if(model.get(key)){
                    $(".assign." + obj[key]).removeClass("hidden");
                } else {
                    $(".assign."+obj[key]).addClass("hidden");
                }
            });
        },
        setDate: function(_setName,_date,type){  // sets the date in the form YYYY-MM-DD
            var problemSet = this.collection.findWhere({set_id: _setName.toString()});
            if(type==="all") {
                problemSet.setDefaultDates(_date).save({success: this.update()});
            } else {
                problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix());
            }

        },
        sidebarEvents: {
            "selected-users-changed": function(arg) {this.fetchUserCalendars(arg);}
        },

    });

    var DateInfoBar = Backbone.View.extend({
        className: "assign",
        initialize: function(options){
            this.template = options.template;
            this.model = new Backbone.Model(options.model);
            var assignType = this.model.get("assign_type").replace("-","_") + "_date";
            this.model.set("assign_time",moment.unix(this.model.get(assignType))
                    .format("hh:mm A"));
        },
        render: function(){
            this.$el.html(this.template);
            this.$el.addClass("assign-"+this.model.get("assign_type"));
            this.$el.data("setname",this.model.get("set_id"));
            this.stickit();
            return this;
        },
        bindings: {
            ".assign-calendar-name": "set_id",
            ".assign-info": "set_id"  // this seems to be a hack to get stickit to add the handler. 
        }
    });

	return AssignmentCalendar;
});
