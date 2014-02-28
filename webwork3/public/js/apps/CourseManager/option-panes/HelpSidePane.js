define(['backbone','views/SidePane', 'config'],function(Backbone,SidePane,config){
	var HelpSidePane = SidePane.extend({
	    render: function(){
	        this.$el.html($("#help-sidepane-template").html());
	        return this;
	    }
	});
	return HelpSidePane;
});