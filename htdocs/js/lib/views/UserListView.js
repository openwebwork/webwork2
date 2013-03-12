
define(['Backbone', 
	'underscore',
	//'Closeable',
	//'../../lib/models/User',
	'config'
	], function(Backbone, _,config){
    
	var UserListView = Backbone.View.extend({
		template: _.template($("#user-template").html()),
		initialize: function() {
			_.bindAll(this,"render","highlightUsers","disableCheckboxForUsers");
			_.extend(this,this.options);
			return this;
		},
		render: function () {
			var self = this;

			this.$el.html("<td><ul class='no-bullets' id='classlist-col1'></ul></td>" +
				"<td><ul class='no-bullets' id='classlist-col2'></ul></td>" +
				"<td><ul class='no-bullets' id='classlist-col3'></ul></td>")


			_(this.users).each(function(user,i) { 
                var cl = null;
                if (i<self.users.length/3) { cl = self.$("#classlist-col1")} 
                else if (i<2*self.users.length/3) {cl = self.$("#classlist-col2")}
                else {cl = self.$("#classlist-col3")}
				cl.append(self.template({user: user.get("user_id"), cid: user.cid, firstname: user.get("first_name"), 
                                            lastname: user.get("last_name")}));
            });

            if(!(_.isUndefined(this.checked))) {this.$(".classlist-li").attr("checked",this.checked);}  
            return this;
		},
		highlightUsers: function(users){
			var self = this;
			_(users).each(function(_user){
                var checkbox = self.$(".classlist-li[data-username='"+ _user + "']");
                checkbox.parent().addClass("hw-assigned");
	        });
		},
		disableCheckboxForUsers: function(users){
			var self = this;
			// colors all previously assigned users and disables the checkbox.
            _(users).each(function(_user){
                var checkbox = self.$(".classlist-li[data-username='"+ _user + "']");
                checkbox.prop("disabled",true);
                checkbox.prop("checked",true);
            });
		},
		checkAll: function (checked) {
			this.$(".classlist-li").attr("checked",(checked)?"checked":false);
		},
		getSelectedUsers: function (){
			return _(this.$("input:checkbox.classlist-li[checked='checked']")).map(function(v){ return $(v).data("username")});
		}
	});

	return UserListView;

});