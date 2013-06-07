/**
 *  This view has a listing of all the HW sets (similar to the old Homework Editor)
 *
 */

define(['Backbone', 'underscore','jquery-tablesorter','stickit'], 
    function(Backbone, _){

    
    var SetListView = Backbone.View.extend({
        className: "set-list-view",
        initialize: function () {
            _.bindAll(this, 'render');  // include all functions that need the this object
            this.rowTemplate = $("#problem-set-row-template").html();
            this.collection.on("change",function (model) {
                console.log(model)
            });
        },
        render: function () {
            var self = this;
            this.$el.html($("#problem-set-list-template").html());
            var tab = $("#set-list-table tbody");
            this.collection.each(function(m){
                tab.append((new SetListRowView({model: m, rowTemplate: self.rowTemplate})).render().el);
            });
            
            tab.tablesorter();
        },  // why is this needed?  
        addSet: function (_set) {
            this.$("#set-list-table").append((new SetListRowView({model: _set})).render().el);
        }


    });


        var SetListRowView = Backbone.View.extend({
        className: "set-list-row",
        tagName: "tr",
        initialize: function () {
            _.bindAll(this,'render');
            this.rowTemplate = this.options.rowTemplate;
        },
        render: function () {
            this.$el.html(this.rowTemplate);
            this.stickit();
            return this; 
        },
        bindings: {".set-name": "set_id", 
                    ".open-date": "open_date",
                    ".due-date": "due_date",
                    ".answer-date": "answer_date"}
    });


    return SetListView;

});