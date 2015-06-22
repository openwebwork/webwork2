define(['backbone','views/MainView','views/AssignmentCalendar','moment'],
    function(Backbone,MainView,AssignmentCalendar,moment){
var CourseCalendar = MainView.extend({
    initialize: function (options) {
        var self = this; 
        _(this).bindAll("render");
        MainView.prototype.initialize.call(this,options);
        this.calendar = new AssignmentCalendar(_.extend({},options,this.state.attributes));
        this.state.on("change:reduced_scoring_date change:answer_date change:due_date change:open_date",
                                this.calendar.showHideAssigns);
        this.state.on("change",this.render);
        this.calendar.state.on("change",function (){
            self.state.set(self.calendar.state.changed);
        });
    },
    render: function(){
        this.$el.html(this.calendar.render().el);
    },
    getDefaultState: function () {
        var firstOfMonth = moment(this.date||moment()).date(1)
            , firstDay = moment(firstOfMonth).subtract(firstOfMonth.date(1).day(),"days");
        return {
            answer_date: true,
            due_date: true,
            reduced_scoring_date: true,
            open_date: true,
            first_day: firstDay.format("YYYY-MM-DD"),
            calendar_type: "month"
        };
    },
    set: function(options) {
        this.calendar.set(options);
        return this;
    }

    

    
});
    
return CourseCalendar;
});