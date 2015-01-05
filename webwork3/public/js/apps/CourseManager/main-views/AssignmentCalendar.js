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
            this.state.on("change:reduced_scoring_date change:answer_date change:due_date change:open_date",
                    this.showHideAssigns);
        this.state.on("change",this.render);
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
        showHideAssigns: function(model){
            // define the mapping between fields in the model and assignment classes. 
            var obj = {
                reduced_scoring_date: "assign-reduced-scoring",
                due_date: "assign-due",
                open_date: "assign-open",
                answer_date: "assign-answer"
            }

            var keys = _(obj).keys();
            if(! this.settings.getSettingValue("pg{ansEvalDefaults}{enableReducedScoring}")){
                keys = _(keys).without("reduced_scoring_date");
            }
            _(keys).each(function(key){
                config.changeClass({state: model.get(key), remove_class: "hidden", els: this.$(".assign." + obj[key]) });
            });

            if(!model.get("reduced_scoring_date")){
                return;
            }
            // hide the reduced credit sets that shouldn't be visible. 
            this.problemSets.chain().each(function(_set) { 
                config.changeClass({state: _set.get("enable_reduced_scoring"), remove_class: "hidden", 
                    els: self.$(".assign-reduced-scoring[data-setname='"+_set.get("set_id")+"']")});
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
            this.$el.attr("data-setname",this.model.get("set_id"));
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
