


define(['Backbone', './WeBWorKProperty','underscore','config'], function(Backbone, WeBWorKProperty,_,config){
    /**
     *
     * @class webwork
     * @type Object
     * @static
     */

var Settings = Backbone.Collection.extend({ 
    model: WeBWorKProperty,
    initialize: function (){
        _.bindAll(this,"fetch","getSettingValue");
        this.on("update",this.update);
    },
    fetch: function () {
        var self=this;
        var requestObject = { xml_command: "getCourseSettings"};
        _.defaults(requestObject, config.requestObject);

        this.reset();


        $.get(config.webserviceURL, requestObject,
            function (data) {
                var response = $.parseJSON(data);
                console.log("The course settings have loaded");
                var settingsData = response.result_data;

                if (settingsData.length === 5) {
                    var tzData = settingsData.pop();
                    self.add(new WeBWorKProperty({category: "timezone", "var": "timezone", value: tzData[1]},{silent: true}));
                }

                _(settingsData).each(function(set){
                    var _category = "";
                    _(set).each(function(prop,i){
                        if (i===0) {_category = prop} else {
                            self.add(new WeBWorKProperty(_.extend(prop,{category: _category})),{silent: true});
                        }

                    });
                });
                self.trigger("fetchSuccess");
            });

            

        },
        getSettingValue: function(_setting){
            return (this.find(function(v) { return v.get("var")===_setting;})).get("value");
        }
    });
    

    
    return Settings;
});


/*
        defaults: {
            time_assign_due: "11:59PM",
            assign_open_prior_to_due: "1 week",
            answers_open_after_due: "2 days",
            reduced_credit: true,
            reduced_credit_time: "3 days",
            timezone: "EDT"
        },
        descriptions : {
            time_assign_due: "Time that the Assignment is Due",
            assign_open_prior_to_due: "Prior time that the Assignment is Open",
            answers_open_after_due: "Time after Due Date that Answers are Open",
            reduced_credit: "Assignment has Reduced Credit",
            reduced_credit_time: "Length of Time for Reduced Credit",
            timezone: "Timezone"
        },
        types: {
            time_assign_due: "time_of_day",
            assign_open_prior_to_due: "time(0+)",
            answers_open_after_due: "time(0+)",
            reduced_credit: "opt('yes','no')",
            reduced_credit_time: "time(0+)",
            timezone: "string(3)"
        },

        */

