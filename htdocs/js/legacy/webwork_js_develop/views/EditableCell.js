define(['Backbone','config'],function(Backbone,config) {

var EditableCell = Backbone.View.extend({
        tagName: "td",
        initialize: function () {
            _.bindAll(this, 'render','editString','editDate','editTime');  // include all functions that need the this object
            _.extend(this,this.options);
        },
        render: function () {
            var optsRe = /opt\((.*)\)/;
            if(this.model.types[this.property]==="datetime"){
                var dt = config.regexp.wwDate.exec(this.model.get(this.property));
                this.$el.html("<span class='edit-date'>" + dt[1] + "</span> at <span class='edit-time'>" + dt[5] +"</span>"); 
            } else if (optsRe.test(this.model.types[this.property])) 
            {
                var opts = optsRe.exec(this.model.types[this.property])[1].split(",");
                this.$el.html("<select class='edit-opt'>" + _(opts).map(function(v){return "<option>" + v + "</option>";}) + "</select>");
                this.$(".edit-opt").val(this.model.get(this.property));
            } else {
                this.$el.html("<span class='srv-value'> " + this.model.get(this.property) + "</span>");
            }
            return this;
            
        },
        events: {"click .srv-value": "editString",
                 "click .edit-date": "editDate",
                 "click .edit-time": "editTime",
                 "change .edit-opt": "editOption"
        },
        editOption: function (event) {
            this.model.set(this.property,$(event.target).val());
        },
        editDate: function(event) {
            var self = this;
            var tableCell = $(event.target);
            var currentValue = tableCell.html();
            tableCell.html("<input class='srv-edit-box' size='10' type='text'></input>");
            var inputBox = this.$(".srv-edit-box");
            inputBox.val(currentValue);
            inputBox.focus();
            inputBox.datepicker().on("changeDate",function (event){
                var valid = self.saveDateTime(inputBox, inputBox.val(),self.$(".edit-time").text());
                if (valid) {
                    inputBox.datepicker("hide");
                    tableCell.html(inputBox.val());    
                } 
            });
            inputBox.datepicker("show");
            this.$(".srv-edit-box").focusout(function() {
                var valid = self.saveDateTime(inputBox, inputBox.val(),self.$(".edit-time").text()); 
                if (valid) {
                    inputBox.datepicker("hide");
                    tableCell.html(inputBox.val());
                }
            }); 
           
        },
        editTime: function() {
            var self = this;
            var tableCell = $(event.target);
            var currentValue = tableCell.html();
            tableCell.html("<input class='srv-edit-box' size='20' type='text'></input>");
            var inputBox = this.$(".srv-edit-box");
            inputBox.focus();
            inputBox.val(currentValue);
            inputBox.click(function (event) {event.stopPropagation();});
            this.$(".srv-edit-box").focusout(function() {
                var valid = self.saveDateTime(inputBox,self.$(".edit-date").text(),inputBox.val());
                if (valid) {tableCell.html(inputBox.val());}
            }); 
        },
        saveDateTime: function(box,date,time){

            var _wwdate = date + " at " + time + " " + config.timezone;
            console.log(_wwdate);
            var error = this.model.preValidate(this.property,_wwdate);

            if (error) {
                box.attr("data-content",error);
                box.attr("data-placement","top");
                box.popover("show");
                console.log(error);
                return false; 
                
            } else if (this.silent) {
                return true;
                // don't save the property yet. 
            } else 
            {
                this.model.set(this.property,_wwdate);
                return true;
            } 
        },
        editString: function (event) {
            var self = this;
            var tableCell = $(event.target);
            var currentValue = tableCell.html();
            tableCell.html("<input class='srv-edit-box' size='20' type='text'></input>");
            var inputBox = this.$(".srv-edit-box");
            inputBox.focus();
            inputBox.val(currentValue);
            inputBox.click(function (event) {event.stopPropagation();});
            this.$(".srv-edit-box").focusout(function() {
                tableCell.html(inputBox.val());
                self.model.set("value",inputBox.val());  // should validate here as well.  
                
                // need to also set the property on the server or 
                }); 
        },
        getValue: function ()
        {
            return this.$el.text();
        }
        
        
        });

return EditableCell;
});