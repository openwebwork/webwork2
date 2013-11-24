define(['Backbone','views/MessageListView', 'jquery-truncate'], function(Backbone,MessageListView){
	var WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    initialize: function () {
    	_.bindAll(this,"render","toggleMessageWindow");
    	_.extend(this,this.options);
    },
    render: function () {
    	var self = this; 

        this.$el.prepend((this.messagePane = new MessageListView()).render().el);
        
        $("button#help-link").click(function () {
                self.helpPane.open();});

        $("button#msg-toggle").on("click",this.toggleMessageWindow);

         this.setUpNavMenu();  

    },
    toggleMessageWindow: function() {
        this.messagePane.toggle();
    },
    // setUpNavMenu will dynamically changed the navigation menu to make it look better in the bootstrap view.
    // In the future, we need to have the template for the menu better suited for a navigation menu.  

    setUpNavMenu: function ()
    {
        var allCourses = $("#webwork_navigation ul:eq(0)").addClass("dropdown-menu");
        var InstructorTools = $("#webwork_navigation ul:eq(0) ul:eq(0) ul:eq(0)");
        var StudentTools = $("#webwork_navigation ul:eq(0) ul:eq(0)");



        InstructorTools.children("ul").remove();  // remove any links under the instructor tools
        StudentTools.children("ul").remove(); // remove 
        allCourses.children("ul").remove();

        allCourses.append("<li class='divider'>").append(StudentTools.children("li"))
            .append("<li class='divider'>").append(InstructorTools.children("li"));

        var activeLink = $("#webwork_navigation strong").children();
        var strongElem = $("#webwork_navigation strong").parent();
        strongElem.children().remove();
        strongElem.addClass("active").append(activeLink);

        $("#webwork_navigation").removeAttr("style")

    }


    });
    return WebPage;
});