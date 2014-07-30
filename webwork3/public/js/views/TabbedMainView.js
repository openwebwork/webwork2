/**
 *  This is a tabbed version of a main view.  The views are passed as the object views in the initialize. 
 * 
 **/


define(['backbone','underscore','views/MainView'], 
    function(Backbone, _,MainView){
	var TabbedMainView = MainView.extend({
		initialize: function (options){
			_(this).bindAll("changeTab");
			_(this).extend(_(options).pick("views","tabs","tabContent","template"));
			this.tabNames = _(options.views).keys();
			MainView.prototype.initialize.call(this,options);
		},
		render: function(){
			var self = this;
			if(this.template){
				this.$el.html(this.template);
			} else {
				this.$el.empty();
			}
			// Build up the bootstrap tab system. 
			var tabs = $("<ul>").addClass("nav nav-tabs").attr("role","tablist");
			var tabContent = $("<div>").addClass("tab-content");
			_(this.tabNames).each(function(name,i){
				tabs.append($("<li>").append($("<a>").attr("href","#tab"+i).attr("role","tab").attr("data-toggle","tab")
					.attr("data-tabname",name).text(self.views[name].tabName)));
				tabContent.append($("<div>").addClass("tab-pane").attr("id","tab"+i));
			})
			if(this.tabs){
				this.$(this.tabs).html(tabs);
			} else {
				this.$el.append(tabs);
			}
			if(this.tabContent){
				this.$(this.tabContent).html(tabContent)
			} else {
				this.$el.append(tabContent);
			}
			if(this.state.get("tab_name")===""){
				this.state.set("tab_name",_(this.views).keys()[0]);
			}

            var tabNum = _(this.views).keys().indexOf(this.state.get("tab_name"));
            this.$((this.tabs || "" ) + " a:eq("+ tabNum+")").tab("show");

			MainView.prototype.render.call(this);
			this.delegateEvents();
		},
		additionalEvents: {
	          	"show.bs.tab a[data-toggle='tab']": "changeTab",
		},
      	changeTab: function(options){
            var _tabName = _.isString(options)? options: $(options.target).data("tabname");
			this.views[_tabName].setElement(this.$("#tab"+this.tabNames.indexOf(_tabName))).render();
			if(_.isString(options)){ // was triggered other than a tab change.
				this.$(".set-details-tab a:first").tab("show");
			}

			// how do we know there is a "help" sidebar? 
			if(this.sidebar && this.sidebar.info.id==="help"){
				this.eventDispatcher.trigger("show-help");
			}
			this.state.set("tab_name",_tabName);
		},
		getState: function () {
			this.state.get("tab_states")[this.state.get("tab_name")]=this.views[this.state.get("tab_name")].tabState.attributes;
			return MainView.prototype.getState.apply(this);
		},
		setState: function(_state){
			var self = this;
			MainView.prototype.setState.apply(this,[_state]);
			if(_state){
				_(_state.tab_states).chain().keys().each(function(st){
					self.views[st].tabState.set(_state.tab_states[st],{silent: true});
				});
			}
			return this;
		},
	    getDefaultState: function () {
	    	var _tabStates={}
	    		, self = this;
	    	_(this.tabNames).each(function(name){
	    		_tabStates[name] = self.views[name].getDefaultState();
	    	})
	    	return {tab_name: this.tabNames[0], tab_states:  _tabStates};
	    }


	});
	return TabbedMainView;
});