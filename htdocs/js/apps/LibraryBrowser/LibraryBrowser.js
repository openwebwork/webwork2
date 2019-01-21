define(['Backbone', 'underscore', './LibraryListView', './SetListView', 'LibraryList', 'SetList'], function(Backbone, _, LibraryListView, SetListView, LibraryList, SetList){
	//Since many of the views we'll define will all want to post alerts and messages to the same place
    //we define a global template and alert function for them.
    var alert_template = _.template('<div class="alert <%= classes %> fade in"><a class="close" data-dismiss="alert" href="#">×</a><%= message %></div>');

    //set up alerts to close
    //$().alert();

    var alert = function(message, classes){
        console.log("alert: "+message);
        $('#messages').html(alert_template({message: message, classes: classes}));
        //setTimeout(function(){$(".alert").alert('close')}, 5000);
    };
	//The APP!! yay!!
    var LibraryBrowser = Backbone.View.extend({
        //el:$('#app_box'),
        tagName:'div',
        events:{
            "click #undo_button":"undo",
            "click #redo_button":"redo",
            "hover .problem": "highlightSets",
            "click #create_set": "createHomeworkSet"
        },

        initialize:function () {

            var self = this;

            //Some default ajax stuff we can keep it or not
            $(document).ajaxError(function(e, jqxhr, settings, exception) {
                alert(exception, "alert-error");
            });

            // get usernames and keys from hidden variables and set up webwork object:
            //var myUser = document.getElementById("hidden_user").value;
            //var mySessionKey = document.getElementById("hidden_key").value;
            //var myCourseID = document.getElementById("hidden_courseID").value;
            // check to make sure that our credentials are available.
            /*if (myUser && mySessionKey && myCourseID) {
                webwork.requestObject.user = myUser;
                webwork.requestObject.session_key = mySessionKey;
                webwork.requestObject.courseID = myCourseID;
            } else {
                alert("missing hidden credentials: user "
                    + myUser + " session_key " + mySessionKey
                    + " courseID" + myCourseID, "alert-error");
            }*/


            //Set up the tabbed set lists and libraries:
            $("#problems_container").tabs(
                {
                    closable:true,
                    add:function (event, ui) {
                        //document.getElementById("library_link").removeChild(document.getElementById("library_link").lastChild);
                        console.log("adding a tab");
                        $('#problems_container').tabs('select', '#' + ui.panel.id);
                        $(".ww_selected").removeClass("ww_selected");// probably reduntant but I want to make sure nothing stays selected
                    },
                    create:function (event, ui) {
                        //document.getElementById("library_link").removeChild(document.getElementById("library_link").lastChild);
                        $(".ww_selected").removeClass("ww_selected");
                    },
                    select:function (event, ui) {
                        $(".ww_selected").removeClass("ww_selected");
                    },
                    remove:function (event, ui) {
                        //document.getElementById("library_link").removeChild(document.getElementById("library_link").lastChild);
                        $(".ww_selected").removeClass("ww_selected");
                    }
            });


            //set up our models
            this.homeworkSets = new SetList;
            this.cardCatalog = new LibraryList;
            this.cardCatalog.defaultRequestObject.xml_command = "listLibraries";
            //this.browser = new Browse;

            this.render();
        },

        createHomeworkSet: function(){
            if(this.$("#dialog_text").val()){
                this.homeworkSets.create({name: this.$("#dialog_text").val()});
            }
            this.$("#dialog_text").val('');
        },

        highlightSets: function(event) {
            switch(event.type){
                case "mouseenter":
                    var problemPath = event.currentTarget.getAttribute("data-path");
                    this.homeworkSets.each(function(set){
                        if(set.get('problems').find(function(problem){return problem.get('path') == problemPath})){
                            set.trigger('highlight');
                        }
                    });
                    break;
                default:
                    $(".contains_problem").removeClass("contains_problem");
                    break;
            }

        },

        render: function(){
            console.log(this.el);
            var homeworkSetsView = new SetListView({model: this.homeworkSets});
            this.$("#homework_sets_container").append(homeworkSetsView.render().el);

            var cardCatalogView = new LibraryListView({model: this.cardCatalog, name: "root"});
            this.$("#CardCatalog").append(cardCatalogView.render().el);
            
            //var browserView = new BrowseListView({model: this.browser});
            //this.$("#Browser").append(browserView.render().el);
        },

        undo:function () {
            // pop the stack and call the function, that's it
            var undoFunc = undo_stack.pop();
            undoing = true;
            undoFunc();
        },

        redo:function () {
            var redoFunc = redo_stack.pop();
            redoFunc();
        }
    });
	return LibraryBrowser;
});