   

    // This the view class of the Add Students Manually for a row of the table. 


define(['Backbone', 
	'underscore',
	//'Closeable',
	//'../../lib/models/User',
	'config'
	], function(Backbone, _,config){
    
	var UserRowView = Backbone.View.extend({
		tagName: "tr",
		className: "userRow",
		initialize: function(){
		    _.bindAll(this, 'render','unrender','updateProp','removeUser'); // every function that uses 'this' as the current object should be in here
		    this.model.bind('remove', this.unrender);
		    this.model.on('validated:invalid', function (model,error) {
		    	console.log(error);	
		    });
		    
		    this.render();
		    
	    	},
		events: {
		    'change input': 'updateProp',
		    'click button.removeUser': 'removeUser'
		},
		render: function(){
		    var self = this;
		    self.$el.append("<td><button class='removeUser'>Delete</button></td>");
		    _.each(config.userProps, function (prop){self.$el.append("<td><input type='text' size='10' class='input-for-" + prop.shortName + "'></input></td>"); });
		    return this; // for chainable calls, like .render().el
		},
	       updateProp: function(evt){
		    var changedAttr = evt.target.className.split("for-")[1];
		    this.model.set(changedAttr,evt.target.value,{silent: true});
		    var errorMessage = this.model.preValidate(changedAttr, evt.target.value);
		    if(errorMessage)
		    {
				$(evt.target).css("background-color","rgba(255,0,0,0.5)");
				this.model.trigger("error",this.model, {type: changedAttr, message: errorMessage});
		    }  else
		    {
				$(evt.target).css("background","none");
		    }
		    
		},
		unrender: function(){
		    this.$el.remove();
		},
		removeUser: function() {this.model.destroy();}
	});

   return UserRowView;
	
});
