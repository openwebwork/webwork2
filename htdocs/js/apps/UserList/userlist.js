
// this variable was defined inside the following, but I think it needs global scope.

var userList;


$(function(){

    // get usernames and keys from hidden variables and set up webwork object:
    var myUser = document.getElementById("hidden_user").value;
    var mySessionKey = document.getElementById("hidden_key").value;
    var myCourseID = document.getElementById("hidden_courseID").value;
    // check to make sure that our credentials are available.
    if (myUser && mySessionKey && myCourseID) {
        webwork.requestObject.user = myUser;
        webwork.requestObject.session_key = mySessionKey;
        webwork.requestObject.courseID = myCourseID;
    } else {
        alert("missing hidden credentials: user "
            + myUser + " session_key " + mySessionKey
            + " courseID" + myCourseID, "alert-error");
    }



    var UserListView = Backbone.View.extend({
        initialize: function(){

            this.setElement(new EditableGrid("UserListTable", {
                enableSort: true
            }));
            // we build and load the metadata in Javascript
            this.el.load({ metadata: [
                { name: "Select", datatype: "boolean", editable: true},
                { label: "Login Name", name: "user_id", datatype: "string", editable: false },
                { name: "Login Status", datatype: "string", editable: false },
                { name: "Assigned Sets", datatype: "integer", editable: false },
                { label: "First Name", name: "first_name", datatype: "string", editable: true },
                { label: "Last Name", name:"last_name", datatype: "string", editable: true },
                { label: "Email Address", name: "email_address", datatype: "string", editable: true },
                { label: "Student ID", name: "student_id", datatype: "string", editable: true },
                { label: "Status", name: "status", datatype: "string", editable: true,
                    values : {
                        "en":"Enrolled",
                        "noten":"Not Enrolled"
                    }
                },
                { label: "Section", name: "section", datatype: "integer", editable: true },
                { label: "Recitation", name: "recitation", datatype: "integer", editable: true },
                { label: "Comment", name: "comment", datatype: "string", editable: true },
                { label: "Permission Level", name: "permission", datatype: "integer", editable: true,
                    values : {
                        "-5":"guest","0":"Student","2":"login proctor",
                        "3":"grade proctor","5":"T.A.", "10": "Professor",
                        "20":"Admininistrator"
                    }
                },
                { name: "Take Action", datatype: "string", editable: true,
                    values: {"action0":"Take Action","action1":"Change Password",
                        "action2":"Delete User","action3":"Act as User",
                        "action4":"Student Progess","action5":"Email Student"}
                }
            ], data: [{id:0, values:{}}]});
            this.el.renderGrid('users_table', 'testgrid');
            var self = this;
            this.el.modelChanged = function(rowIndex, columnIndex, oldValue, newValue) {
                var cid = self.el.getRowId(rowIndex);
                var property = self.el.getColumnName(columnIndex);
                var editedModel = self.model.getByCid(cid);
                if(property == 'permission'){
                    newValue = {name: "", value: newValue};
                }
                editedModel.set(property, newValue);
                editedModel.update();
                console.log(rowIndex);
                console.log(columnIndex);
                console.log(oldValue);
                console.log(newValue);
            }

            this.model.on('reset', function(){
                while(self.el.getRowCount() > 1){
                    self.el.remove(1);
                }
                self.addAll();
            }, this);
            this.model.on('all', this.render, this);
            this.model.fetch();


            document.getElementById("filter").addEventListener("keyup", function(){self.el.filter(document.getElementById("filter").value)}, false);
        },

        render: function(){
            this.el.refreshGrid();

        },

        addOne: function(user){
            var userInfo = user.toJSON();
            userInfo.permission = ""+userInfo.permission.value;
            this.el.append(user.cid, userInfo);
        },

        addAll: function(){
            var self = this;
            this.model.each(function(user){self.addOne(user)});
        }


    });

    userList = new webwork.UserList;

    var App = new UserListView({model: userList});

    // then we attach to the HTML table and render it
    //editableGrid.attachToHTMLTable('cltable');


    //userList.fetch();
    /*var users = new Array();
    for(var i = 0; i < editableGrid.getRowCount(); i++){
        var atts = editableGrid.getRowValues(i);
        delete atts['Take Action'];
        console.log(atts);
        users.push(atts);
    }
    userList.reset(users, {silent: true});*/
});


/*
window.onload = function()
{

    
// update paginator whenever the table is rendered (after a sort, filter, page change, etc.)
	//	tableRendered = function() { this.updatePaginator(); };
	
	// set active (stored) filter if any
	//	_$('filter').value = currentFilter ? currentFilter : '';
		
		// filter when something is typed into filter
	//	_$('filter').onkeyup = function() { editableGrid.filter(_$('filter').value); };
	


} */


// The following is for test purposes only

function addStud()
{
    var u = new webwork.User({"first_name":"Homer","last_name":"Simpson","user_id":"hsimp"});
    userList.add(u);
}
