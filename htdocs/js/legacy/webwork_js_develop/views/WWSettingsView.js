/* This View provides the super class for any Settings in WebWork.  The list of Settings should be included by 
    setting the "settings" field and providing it an array of WeBWorKProperty models. 
    */

define(['Backbone', 
    'underscore',
    '../../../lib/views/EditableCell','../../../apps/config'], 
function(Backbone, _,EditableCell,config){
    var WWSettingsView = Backbone.View.extend({

        initialize: function () {
            _.bindAll(this,'render');
        },
        render: function ()
        {
            var self = this;
            _(this.settings).each(function(setting){
                var settingView =new WWSettingRowView({property: setting}); 
                self.$el.append(settingView.el);
            });

            //this.$(".help-button").popover();
        }


    });

    var WWSettingRowView = Backbone.View.extend({
        className: "set-detail-row",
        tagName: "tr",
        template: _.template($("#setting-row-template").html()),
        initialize: function () {
            _.bindAll(this,'render','update');
            this.property = this.options.property;
            //this.dateRE =/(\d\d\/\d\d\/\d\d\d\d)\sat\s((\d\d:\d\d)([apAP][mM])\s([a-zA-Z]{3}))/;
            this.render();
            return this;
        },
        render: function() {
            var self = this; 
            this.$el.html(this.template(this.property.attributes));
            
            switch(this.property.get("type")){
                case "text":
                case "number":
                    this.$el.append("<td><input type='text' value='" + this.property.get("value") + "'></input></td>");
                    break;
                case "checkboxlist":
                    var opts = _(self.property.get("values")).map(function(v) {return "<li><input type='checkbox' value='"+v+"'>" + v + "</li>";});
                    this.$el.append("<td id='prop-" + self.property.cid + "'><ul style='list-style: none'>" + opts.join("") + "</ul></td>");
                    _(self.property.get("value")).each(function(v){
                        self.$("#prop-" + self.property.cid + " input:checkbox[value='" + v + "']").attr("checked","checked");
                    })
                    break;
                case "popuplist":
                    var opts = _(self.property.get("values")).map(function(v) {return "<option value='" + v + "'>" + v + "</option>";});
                    this.$el.append("<td id='prop-" + self.property.cid + "'><select class='popuplist'>" + opts + "</select>");
                    self.$("#prop-" + self.property.cid + " select.popuplist option[value='" + self.property.get("value") + "']").attr("selected","selected");
                    break;
                case "boolean":
                    this.$el.append("<td id='prop-" + self.property.cid + "'>" + 
                                    "<select class='bool'><option value='1'>true</option><option value='0'>false</option></select");
                    //this.$("#prop-" + self.property.cid + " select.bool option[value='0']").attr("selected","selected")
                    this.$("#prop-" + self.property.cid + " select.bool option[value='" + self.property.get("value") +  "']").attr("selected","selected");
     
                   break;
                default: 
                    this.$el.append("<td id='value-col'> " + this.property.get("value") + "</td>");

            }

        
        },
        events: {
            "change input": "update",
            "change select": "update",
            "click .help-button": "openHelp",
            "click .close": "closeHelp",
        },
        openHelp: function (evt){
            $(evt.target).siblings(".help-hidden").css("display","block");
        },
        closeHelp: function (evt){
            $(evt.target).parent().css("display","none");
        },
        update: function(evt){
            var self = this;
            var prop = self.property.get("var");
            var newValue = $(evt.target).val();
            console.log("updating " + prop);
            console.log("new value: " + newValue);
            switch(this.property.get("type")){
                case "text":
                    self.property.set("value",$(evt.target).val());
                    break;
                case "number":
                    if (config.regexp.number.test(newValue)){
                        self.property.set("value",$(evt.target).val());                        
                    } else {
                        console.log("Error!!! " + newValue + " is not a number");
                    }


                    break;
                case "checkboxlist":

                    break;
                case "boolean":
     
                   break;
            }
        }
    });

    return WWSettingsView;
});