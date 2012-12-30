define(['Backbone'],function(Backbone) {

var EditableCell = Backbone.View.extend({
        tagName: "td",
        initialize: function () {
            _.bindAll(this, 'render','editString','editDate','editTime');  // include all functions that need the this object
            _.extend(this,this.options);
        },
        render: function () {
            var optsRe = /opt\((.*)\)/;
            if(this.model.types[this.property]==="datetime"){
                var re = /(\d?\d\/\d?\d\/\d{4})\sat\s(\d?\d:\d\d[aApP][mM])\s\w{3}/;
                var dt = re.exec(this.model.get(this.property));
                this.$el.html("<span class='edit-date'>" + dt[1] + "</span> at <span class='edit-time'>" + dt[2] +"</span>"); 
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
                "click .edit-time": "editString",
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
                var _wwdate = inputBox.val() + " at " + self.$(".edit-time").text() + " EDT";
                console.log(_wwdate);
                var valid = self.model.preValidate(self.property,_wwdate);

                if (self.model.isValid(self.property)) {
                    inputBox.datepicker("hide");
                    tableCell.html(inputBox.val());
                    self.model.set(self.property,_wwdate);
                } else
                {
                    console.log(valid);
                }

            });
            inputBox.datepicker("show");
            //inputBox.datepicker({autoclose: true});
            //inputBox.click(function (event) {event.stopPropagation();});
            this.$(".srv-edit-box").focusout(function() {
                
                inputBox.datepicker("hide");

                }); 
           
        },
        editTime: function() {

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
        }
        
        
        });

return EditableCell;
});