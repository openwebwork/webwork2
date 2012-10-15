/*
 * The core model for a ProblemSet in config. 
 *
 * */
define(['Backbone', 'underscore','config'], function(Backbone, _, config){

    var ProblemSet = Backbone.Model.extend({
        defaults:{
            set_id: "",
            set_header: "",
            hardcopy_header: "",
            open_date: 0,
            due_date: 0,
            answer_date: 0,
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
            visible_to_students: "Yes"
        },
        initialize: function(){
            this.on('change',this.update);
        },

        update: function(){
            
            console.log("in config.ProblemSet update");
            var self = this;
            var requestObject = {
                "xml_command": 'updateSetProperties'
            };
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);

            $.post(config.webserviceURL, requestObject, function(data){
                console.log(data);
                var response = $.parseJSON(data);
                
    	    self.trigger("success","problem_set_changed",self)
            });
        },
        fetch: function()
        {
            var self=this;
            var requestObject = { xml_command: "getSet"};
            _.extend(requestObject, this.attributes);
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject,
                function (data) {

                    var response = $.parseJSON(data);
                    console.log(response);
                    _.extend(self.attributes,response.result_data);
                });       
        }

    });
    return ProblemSet;
});
    
    