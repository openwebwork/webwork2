define(['Backbone','Closeable'], function(Backbone,Closeable){
	var WebPage = Backbone.View.extend({
    tagName: "div",
    className: "webwork-container",
    initialize: function () {
    	_.bindAll(this,"render");
    	_.extend(this,this.options);
    },
    render: function () {
    	var self = this; 


        // Create an announcement pane for successful messages.
        this.announce = new Closeable({classes: ["alert-success"], id: "announce-pane"});
        this.$el.prepend(this.announce.el);
        
        // Create an announcement pane for error messages.
        this.errorPane = new Closeable({classes: ["alert-error"], id: "error-pane"});
        this.$el.prepend(this.errorPane.el);
        
        // This is the help Pane
        this.helpPane = new Closeable({closeableType : "Help", text: $("#help-text").html(), id: "help-pane"});
        this.$el.prepend(this.helpPane.el);

        $("button#help-link").click(function () {
                self.helpPane.open();});


         this.setUpNavMenu();  

    },

    // setUpNavMenu will dynamically changed the navigation menu to make it look better in the bootstrap view.
    // In the future, we need to have the template for the menu better suited for a navigation menu.  

    setUpNavMenu: function ()
    {
        $("#webwork_navigation h2").remove() //  Remove the "Main Menu" in the menu. 

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

        $("#webwork_navigation").attr("style","");

        var toolName = $(".navbar .breadcrumb li:last").text();

        var toolSpan = $(".navbar .breadcrumb").parent();
        toolSpan.html(toolName);
        toolSpan.addClass("brand");

    }


    });
    return WebPage;
});