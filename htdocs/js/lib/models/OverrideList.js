define(['Backbone', 'underscore','./Override','config','moment'], function(Backbone, _, PropertySetOverride,config,moment){
    var ProblemSetOverrideList = Backbone.Collection.extend({
        model: PropertySetOverride,
        initialize: function (_set) {
            this.problemSet = _set;
        },

        fetch: function() {
            var self = this;
            var requestObject = {"xml_command": "getUserSets", set_id: this.problemSet.get("set_id")};
            _.defaults(requestObject, config.requestObject);

            $.get(config.webserviceURL, requestObject, function(data){
                var response = $.parseJSON(data);

                var overrides = [];
                _(response.result_data).each(function(_userSet){
                    var obj = { user_id: _userSet.user_id,
                                open_date: _userSet.open_date ? _userSet.open_date: self.problemSet.get("open_date"),
                                due_date: _userSet.due_date ? _userSet.due_date: self.problemSet.get("due_date"),
                                answer_date: _userSet.answer_date ? _userSet.answer_date: self.problemSet.get("answer_date")
                            }
                    overrides.push(obj)
                });
                self.set(overrides);
                self.trigger("fetchSuccess");
			});

            
            return this;
        },
        update: function(){  // saves the entire Collection to the server.  
            var self = this;
            var requestObject = { xml_command: "saveUserSets", set_id: this.problemSet.get("set_id")};
            _.defaults(requestObject,config.requestObject);

            var overrides = [];
            this.collection.each(function(override){
                overrides.push(override.attributes);
            });

            requestObject.overrides = JSON.stringify(overrides);

            $.post(config.webserviceURL,requestObject,function(data){
                console.log(data);
            })

        }


    });

    return ProblemSetOverrideList;
});