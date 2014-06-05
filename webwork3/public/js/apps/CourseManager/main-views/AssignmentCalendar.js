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
    		_.bindAll(this,"render","renderDay","update");

            this.problemSets.on({sync: this.render});
            return this;
    	},
    	render: function (){
    		CalendarView.prototype.render.apply(this);
            this.update();

    		this.$(".assign").popover({html: true});
            // set up the calendar to scroll correctly
            this.$(".calendar-container").height($(window).height()-160);
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
            this.$(".assign-calendar-name").truncate({width: 85});
            return this;
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
            return {};
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
                    } 

                }
            });

            // The following allows an assignment date (due, open) to be dropped on the calendar

            this.$(".assign-due,.assign-open,.assign-answer").draggable({
                revert: true,
                start: function () {
                    $(this).children(".show-set-popup-info").popover("destroy")
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
