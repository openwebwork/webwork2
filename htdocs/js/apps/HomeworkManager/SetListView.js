    /**
*  This view has a listing of all the HW sets (similar to the old Homework Editor)
*
*/

define(['Backbone', 'underscore','../../lib/views/EditableCell','jquery-tablesorter'], function(Backbone, _,EditableCell){
    
    var SetListRowView = Backbone.View.extend({
        className: "set-list-row",
        tagName: "tr",
        initialize: function () {
            _.bindAll(this,'render');
            var self = this;
            this.render();
            return this;
        },
        render: function () {
            var self = this;
            this.$el.append("<td>" + this.model.get("set_id") + "</td>");
            this.$el.append( (new EditableCell({model : this.model, type: "datetime", property: "open_date"})).render().el);
            this.$el.append( (new EditableCell({model : this.model, type: "datetime", property: "due_date"})).render().el);
            this.$el.append( (new EditableCell({model : this.model, type: "datetime", property: "answer_date"})).render().el);
        }
        });
    
    var SetListView = Backbone.View.extend({
        className: "set-list-view",
        initialize: function () {
            _.bindAll(this, 'render');  // include all functions that need the this object
            this.parent = this.options.parent; 
            return this;
        },
        render: function () {
            var self = this;
            this.$el.html("<table id='set-list-table' class='table table-bordered'><thead><tr><th>Name</th><th>Open Date</th><th>Due Date</th><th>Answer Date</th></tr></thead><tbody></tbody></table>");
            var tab = $("#set-list-table");
            this.collection.each(function(m){
                tab.append((new SetListRowView({model: m})).el);
            });
            
            tab.tablesorter();


        },
        addSet: function (_set) {
            this.$("#set-list-table").append((new SetListRowView({model: _set})).el);
        }


    });


    return SetListView;

});