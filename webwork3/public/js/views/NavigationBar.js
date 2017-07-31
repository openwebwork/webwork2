define(['backbone','underscore','views/MessageListView'],
  function(Backbone,_,MessageListView){

	var NavigationBar = Backbone.View.extend({
    template: $("#menu-bar-template").html(),
    initialize: function(opts){
      var self = this;
      _(this).extend(_(opts).pick("eventDispatcher"));
      this.messagePane = new MessageListView();
      this.eventDispatcher.on("add-message",function(msg){
        if(self.eventDispatcher){
          self.messagePane.addMessage(msg);
        }
      });
    },
		render: function (){
			this.$el.html(this.template);
      this.messagePane.render();
			return this;
		},
		events: {
			"click .manager-menu a.link": function(evt){
                // if the icon is clicked on, then need to select the parent.
                var id= $(evt.target).data("id");
                if(typeof(id)==="undefined"){
                    id = $(evt.target).parent().data("id");
                }
                this.trigger("change-view",id)
            },
			"click .main-help-button": function(evt){
        this.eventDispatcher.trigger("show-help")},
			"click .logout-link": function(evt){
        this.eventDispatcher.trigger("logout")},
			"click .stop-acting-link": function(evt){
        this.eventDispatcher.trigger("stop-acting")},
			"click .forward-button": function(){
        this.eventDispatcher.trigger("forward-page")},
			"click .back-button": function(){
        this.eventDispatcher.trigger("back-page")},
		},
		setPaneName: function(name){
			this.$(".main-view-name").text(name);
		},
		setLoginName: function(name){
			this.$(".logged-in-as").text(name);
		},
		setActAsName: function(name){
			if(name===""){
				this.$(".act-as-user").text("");
				this.$(".stop-acting-li").addClass("disabled");
			} else {
				this.$(".act-as-user").text("("+name+")");
				this.$(".stop-acting-li").removeClass("disabled");
			}
		}
	});

	return NavigationBar;

});
