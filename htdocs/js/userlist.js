window.onload = function() 
{
    editableGrid = new EditableGrid("UserListTable"); 

    // we build and load the metadata in Javascript
    editableGrid.load({ metadata: [
	{ name: "Select", datatype: "boolean", editable: true},
	{ name: "Login Name", datatype: "string", editable: false },
	{ name: "Login Status", datatype: "string", editable: false },
	{ name: "Assigned Sets", datatype: "integer", editable: false },
	{ name: "First Name", datatype: "string", editable: true },
	{ name: "Last Name", datatype: "string", editable: true },
	{ name: "Email Address", datatype: "string", editable: true },
	{ name: "Student ID", datatype: "string", editable: true },
	{ name: "Status", datatype: "string", editable: true, 
	  values : {"en":"Enrolled", "noten":"Not Enrolled"}},
	{ name: "Section", datatype: "integer", editable: true },
	{ name: "Recitation", datatype: "integer", editable: true },
	{ name: "Comment", datatype: "string", editable: true },
	{ name: "Permission Level", datatype: "string", editable: true, 
	  values : {"role-5":"guest","role0":"Student","role2":"login proctor",
		    "role3":"grade proctor","role5":"T.A.", "role10": "Professor",
		    "role20":"Admininistrator" }},
	{ name: "Take Action", datatype: "string", editable: true,
	  values: {"action0":"Take Action","action1":"Change Password",
		   "action2":"Delete User","action3":"Act as User",
		   "action4":"Student Progess","action5":"Email Student"}}


		
    ]});
    
// update paginator whenever the table is rendered (after a sort, filter, page change, etc.)
	//	tableRendered = function() { this.updatePaginator(); };
	
	// set active (stored) filter if any
	//	_$('filter').value = currentFilter ? currentFilter : '';
		
		// filter when something is typed into filter
	//	_$('filter').onkeyup = function() { editableGrid.filter(_$('filter').value); };
	

    // then we attach to the HTML table and render it
    editableGrid.attachToHTMLTable('cltable');
    editableGrid.renderGrid();
} 