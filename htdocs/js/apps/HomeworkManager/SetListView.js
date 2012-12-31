    /**
*  This view has a listing of all the HW sets (similar to the old Homework Editor)
*
*/

define(['Backbone', 'underscore',], function(Backbone, _){
    
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
            this.$el.append((_(["set_id","open_date","due_date","answer_date"]).map(function(v) {
                return "<td>" + self.model.get(v) + "</td>"; })).join(""));
        }
        });
    
    var SetListView = Backbone.View.extend({
        className: "set-list-view",
        initialize: function () {
            _.bindAll(this, 'render','updateSetInfo');  // include all functions that need the this object
            this.parent = this.options.parent; 
            this.render();
            return this;
        },
        render: function () {
            var self = this;
            this.$el.html("<table id='set-list-table' class='table table-bordered'><thead><tr><th>Name</th><th>Open Date</th><th>Due Date</th><th>Answer Date</th></tr></thead><tbody></tbody></table>");
            var tab = $("#set-list-table");
            this.collection.each(function(m){
                tab.append((new SetListRowView({model: m})).el);
            });
            
        },
        updateSetInfo: function () {
            this.render();
        },
        addSet: function (_set) {
            this.$("#set-list-table").append((new SetListRowView({model: _set})).el);
        }


    });


    return SetListView;

});