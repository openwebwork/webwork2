define(['backbone','views/SidePane', 'config'],function(Backbone,SidePane,config){
	var HelpSidePane = SidePane.extend({
	    render: function(){
	        this.$el.html(this.mainView.getHelpTemplate());
	        return this;
	    }
	});
	return HelpSidePane;
});