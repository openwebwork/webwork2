$(function() {

    //Problem set detail 2 
    $('#problemset_detail_list').addClass('container-fluid');

    //This uses the nextedSortable jquery-ui module to drive the 
    // problem list, if its enabled

    $('#psd_list').nestedSortable({
	handle: 'span.pdr_handle',
	placeholder: 'pdr_placeholder',
	tolerance: 'intersect',
	toleranceElement: '> div',
	items: 'li',
	opacity: '.1',
	forcePlaceholderSize: true,
 	scrollSpeed: 40,
	scrollSensitivity: 30,
	tabSize: 30,
	isTree: true,
	startCollapsed: true,
	maxLevels: 6,
	
    });
    
    if ($('#psd_list').hasClass('disable_renumber')) {
	$('#psd_list').nestedSortable({ disabled:true});
    }

    // The actual expand collapse icon is controlled by css
    $('.pdr_collapse').on('click', function() {
	$(this).closest('li').toggleClass('mjs-nestedSortable-collapsed').toggleClass('mjs-nestedSortable-expanded');
    })

    // This is for the render buttons
    $('.pdr_render').click(function(event) {
	event.preventDefault();
	var id = this.id.match(/^pdr_render_(\d+)/)[1];
	if ($('#psr_render_area_'+id).html()) {
	    $('#psr_render_area_'+id).html('');
	} else {
	    $('#psr_render_area_'+id).html('Loading Please Wait...');
	    render(id);	
	}
    });

    $('#psd_render_all').addClass('btn').click(function (event) {
	event.preventDefault();
	$('.pdr_render').each(function () {
	    var id = this.id.match(/^pdr_render_(\d+)/)[1];
	    $('#psr_render_area_'+id).html('Loading Please Wait...');
	    render(id);
	});
    });

    
    if ($('#auto_render').is(':checked')) {
	$('#psd_render_all').click();
    }

    $('#psd_hide_all').addClass('btn').click(function (event) {
	event.preventDefault();
	$('.psr_render_area').html('');
    });

    // This is for collapsing and expanding the tree
    $('#psd_expand_all').addClass('btn').click(function (event) {
	event.preventDefault();
	$('li.psd_list_row').removeClass('mjs-nestedSortable-collapsed').addClass('mjs-nestedSortable-expanded');
	$('i.icon-plus-sign').removeClass('icon-plus-sign').addClass('icon-minus-sign');
    });

    $('#psd_collapse_all').addClass('btn').click(function (event) {
	event.preventDefault();
	$('li.psd_list_row').addClass('mjs-nestedSortable-collapsed').removeClass('mjs-nestedSortable-expanded');
	$('i.icon-minus-sign').addClass('icon-plus-sign').removeClass('icon-minus-sign');
    });


    // This uses recursion to set the #prob_num_id fields to the 
    // new position in the tree whenever the tree is updated or 
    // the renumber button is clicked
    var recurse_on_heirarchy = function (heirarchy,array) {
	for (var i=0; i < heirarchy.length; i++) {
	    var id = heirarchy[i].id;

	    $('#prob_num_'+id).val(i+1);
	
	    $('#psd_list_'+id).find('.pdr_handle').each(function () {
		$(this).html($(this).html()+(i+1)+'.');
	    });

	    for (var j=0; j < array.length; j++) {
		if (array[j].item_id == id) {
		    $('#prob_parent_id_'+id).val(array[j].parent_id);
		}
	    }
		
	    if (typeof heirarchy[i].children != 'undefined') {
		recurse_on_heirarchy(heirarchy[i].children,array);
	    }
	}
    };

    // this sets the prob_num fields so that the correct number is passed
    // to WeBWorK as a parameter
    var set_prob_num_fields = function () {
	var array = $('#psd_list').nestedSortable("toArray");
	var heirarchy = $('#psd_list').nestedSortable("toHierarchy");
	
	$('.pdr_handle').html('');
	recurse_on_heirarchy(heirarchy,array);
	
	$('.pdr_handle').each(function () {
	    $(this).html($(this).html().slice(0,-1));
	    $(this).append('<i class="icon-resize-vertical" />');
	});
	disable_fields();

    };

    // This enables and disables problem fields that don't make sense
    // based on the position of the problem
    var disable_fields = function () {

	var array = $('#psd_list').nestedSortable("toArray");

	$('.psd_list_row').each(function () {
	    var id = this.id.match(/^psd_list_(\d+)/)[1];
	    
	    // If it has children then attempts to open is enabled
	    var has_children = false;
	    for (var i = 0; i < array.length; i++) {
		if (!has_children && array[i].parent_id == id) {
		    $('#problem\\.'+id+'\\.att_to_open_children_id').parents('tr:first').removeClass('hidden');
		    has_children = true;
		} else if (array[i].item_id == id) {
		    // If its a top level problem counts_for_parent is disabled
		    if (!array[i].parent_id) {
			$('#problem\\.'+id+'\\.counts_parent_grade_id').parents('tr:first').addClass('hidden');
		    } else {
			$('#problem\\.'+id+'\\.counts_parent_grade_id').parents('tr:first').removeClass('hidden');
		    }
		    
		}
	    }
	    if (!has_children) {
		$('#problem\\.'+id+'\\.att_to_open_children_id').parents('tr:first').addClass('hidden');	
	    }
	});
    }

    //Actually run disabled fields on page load. 
    disable_fields();

    $('#psd_list').on('sortupdate', set_prob_num_fields);

    $('#psd_renumber').addClass('btn').tooltip().click(function (event) {
	event.preventDefault();
	set_prob_num_fields();
    });

});

// This is the WeBWorK XML interface code for rendering problems
var basicRequestObject = {
    "xml_command":"listLib",
    "pw":"",
    "password":'change-me',
    "session_key":'change-me',
    "user":"user-needs-to-be-defined",
    "library_name":"Library",
    "courseID":'change-me',
    "set":"set0",
    "new_set_name":"new set",
    "command":"buildtree"
};

var basicWebserviceURL = "/webwork2/instructorXMLHandler";


function init_webservice(command) {
  var myUser = $('#hidden_user').val();
  var myCourseID = $('#hidden_course_id').val();
  var mySessionKey = $('#hidden_key').val();
  var mySetID = $('#hidden_set_id').val();
  var mydefaultRequestObject = {
        };

  if (myUser && mySessionKey && myCourseID) {
    mydefaultRequestObject.user = myUser;
    mydefaultRequestObject.session_key = mySessionKey;
    mydefaultRequestObject.courseID = myCourseID;
    mydefaultRequestObject.set_id = mySetID;
  } else {
    alert("missing hidden credentials: user "
      + myUser + " session_key " + mySessionKey+ " courseID "
      + myCourseID, "alert-error");
    return null;
  }
  mydefaultRequestObject.xml_command = command;
  return mydefaultRequestObject;
}

function render(id) {
    var ro = init_webservice('renderProblem');
    var templatedir = $('#template_dir').val();
    if ($('#problem\\.'+id+'\\.problem_seed').length > 0) {
	ro.problemSeed = $('#problem\\.'+id+'\\.problem_seed').val();
    } else {
	ro.problemSeed = 0;
    }
    var source_file

    if ($('#problem\\.'+id+'\\.source_file_id').val()) {
	source_file = $('#problem\\.'+id+'\\.source_file_id').val();
    } else {
	source_file = $('#problem_'+id+'_default_source_file').val();
    }

    if (/^group/.test(source_file)) {
	$('#psr_render_area_'+id).html( $('<div/>',{style:'font-weight:bold','class':'ResultsWithError'}).text("Problem source is drawn from a grouping set."));
	return false;
    }

    ro.problemPath = templatedir + '/' + source_file;

    ro.set = ro.problemPath;
    ro.showHints = 1;
    ro.showSolutions = 1;
    ro.noprepostambles = 1;
    ro.processAnswers = 0;
    var displayMode = $('#problem_displaymode').val();
    ro.displayMode = displayMode;
    $.post(basicWebserviceURL, ro, function (data) {
	var response = data;
	// Give nicer file not found error
	if (/No such file or directory at/i.test(response)) {
	    response = $('<div/>',{style:'font-weight:bold','class':'ResultsWithError'}).text('No Such File or Directory!');
	}
	if (/"server_response":"","result_data":""/i.test(response)) {
	    response = $('<div/>',{style:'font-weight:bold','class':'ResultsWithError'}).text('There was an error rendering this problem!');
	}

	$('#psr_render_area_'+id).html(response);
	// run typesetter depending on the displaymode
	if(displayMode=='MathJax')
	    MathJax.Hub.Queue(["Typeset",MathJax.Hub]);
	if(displayMode=='jsMath')
	    jsMath.ProcessBeforeShowing(el);
	
	if(displayMode=='asciimath') {
	    //processNode(el);
	    translate();
	}
	if(displayMode=='LaTeXMathML') {
	    AMprocessNode(document.getElementsByTagName("body")[0], false);
	}
	//console.log(data);
    });
    return false;
}
