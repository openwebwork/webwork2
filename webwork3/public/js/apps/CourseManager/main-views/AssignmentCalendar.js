/**
  * This is the assignment calendar view. 
  *
  */


define(['backbone', 'underscore', 'moment','views/MainView', 'views/CalendarView','config'], 
    function(Backbone, _, moment,MainView, CalendarView,config) {
	
    var AssignmentCalendar = CalendarView.extend({
        template: this.$("#calendar-date-bar").html(),
        popupTemplate: _.template(this.$("#calendar-date-popup-bar").html()),
        headerInfo: {template: "#calendar-header", events: 
                { "click .previous-week": "viewPreviousWeek",
                    "click .next-week": "viewNextWeek",
                    "click .view-week": "showWeekView",
                    "click .view-month": "showMonthView"}
        },
    	initialize: function (options) {
            var self = this;
            CalendarView.prototype.initialize.call(this,options);
    		_.bindAll(this,"render","renderDay","update","showHideAssigns");

            this.problemSets.on({sync: this.render});
            
            this.model = new DateTypeModel();
            this.model.on({
                "change:reduced_scoring_date change:answer_date change:due_date change:open_date": this.showHideAssigns,
                "change": function () {
                    self.eventDispatcher.trigger("save-state");
                }
            })
            return this;
    	},
    	render: function (){
    		CalendarView.prototype.render.apply(this);
            this.update();


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

            this.model.set("first_day",this.first_day.format("YYYY-MM-DD"));
            this.stickit();
            this.showHideAssigns(this.model);
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
        // perhaps this should go in the MainView class
        set: function (options) {
            CalendarView.prototype.set.call(this,options);
            return this;
        },
        getState: function () {
            return this.model.attributes;
        },
        setState: function(_state){
            if(_state){
                this.model.set(_state);
                this.set({first_day: _state.first_day});
            }
            return this;
        },
        update:  function (){
            var self = this;
            // The following allows each day in the calendar to allow a problem set to be dropped on. 
                 
            this.$(".calendar-day").droppable({
                hoverClass: "highlight-day",
                accept: ".sidepane-problem-set, .assign",
                greedy: true,
                drop: function(ev,ui) {
                    ev.stopPropagation();
                    if($(ui.draggable).hasClass("sidepane-problem-set")){
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
            var problemSet = this.problemSets.findWhere({set_id: _setName.toString()});
            if(type==="all") {
                problemSet.setDefaultDates(_date).save({success: this.update()});
            } else {
                problemSet.setDate(type,moment(_date,"YYYY-MM-DD").unix());
            }

        }

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

    var DateTypeModel = Backbone.Model.extend({
        defaults: {
                answer_date: true,
                due_date: true,
                reduced_scoring_date: true,
                open_date: true,
                first_day: ""
            }
    });

	return AssignmentCalendar;
});
