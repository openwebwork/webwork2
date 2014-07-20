define(['backbone','views/Sidebar', 'config'],function(Backbone,Sidebar,config){
	var HelpSidebar = Sidebar.extend({
	    render: function(){
	        this.$el.html(this.mainView.getHelpTemplate());
	        return this;
	    }
	});
	return HelpSidebar;
});