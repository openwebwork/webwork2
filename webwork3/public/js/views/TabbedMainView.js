/**
 *  This is a tabbed version of a main view.  The views are passed as the object views in the initialize. 
 * 
 **/


define(['backbone','underscore','views/MainView'], 
    function(Backbone, _,MainView){
	var TabbedMainView = MainView.extend({
		initialize: function (options){
			_(this).bindAll("changeView");
			_(this).extend(_(options).pick("views","tabs","tabContent"));
			this.viewNames = _(options.views).keys();
			MainView.prototype.initialize.call(this,options);
		},
		render: function(){
			var self = this;
			var tabs = $("<ul>").addClass("nav nav-tabs").attr("role","tablist");
			var tabContent = $("<div>").addClass("tab-content");
			_(this.viewNames).each(function(view,i){
				tabs.append($("<li>").append($("<a>").attr("href","#tab"+i).attr("role","tab").attr("data-toggle","tab")
					.attr("data-view",view).text(self.views[view].viewName)));
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
			if(typeof(this.currentViewName)==="undefined"){
				this.currentViewName = _(this.views).keys()[0];
			}

            var tabNum = _(this.views).keys().indexOf(this.currentViewName);
            this.$((this.tabs || "" ) + " a:eq("+ tabNum+")").tab("show");
            this.views[this.currentViewName].render();


			MainView.prototype.render.call(this);
		},
		additionalEvents: {
	          	"show.bs.tab a[data-toggle='tab']": "changeView",
		},
      	changeView: function(options){
            this.currentViewName = _.isString(options)? options: $(options.target).data("view");
			this.views[this.currentViewName].setElement(this.$("#tab"+this.viewNames.indexOf(this.currentViewName)))
				.render();
			if(_.isString(options)){ // was triggered other than a tab change.
				this.$(".set-details-tab a:first").tab("show");
			}
			if(this.optionPane && this.optionPane.id==="help"){
				this.eventDispatcher.trigger("show-help");
			}
            this.eventDispatcher.trigger("save-state");
		},
        setState: function(state){
        	console.log("in TabbedMainView.setState");
            if(state){
                this.currentViewName =  state.subview || this.viewNames[0];
            }
            if(state && this.views[this.currentViewName] && _.isFunction(this.views[this.currentViewName].setState)){
                this.views[this.currentViewName].setState(state);
            }

            return this;
        },
        getState: function(){
        	var state = {subview: this.currentViewName};
            if(this.views[this.currentViewName] && _.isFunction(this.views[this.currentViewName].getState)){
                _.extend(state,this.views[this.currentViewName].getState());
            }

            return state;
        },


	});
	return TabbedMainView;
});