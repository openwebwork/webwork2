$(function() {

    //Problem set detail 2 
    $('#problemset_detail_list').addClass('container-fluid');

    //This uses the nextedSortable jquery-ui module to drive the 
    // problem list
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
	maxLevels: 7,
 
    });

    // This adds soem bootstrap elements to the page to format it
    $('.problem_detail_row').addClass('well span11')
	.wrap('<div class="row-fluid" />')
	.after('<div class="span1" />');

    $('.pdr_block_1').addClass('span2');
    $('.pdr_block_2').addClass('span3');
    $('.pdr_block_3').addClass('span7');

    $('#psd_toolbar').addClass('btn-group');

    $('.psd_view').addClass('btn btn-mini')
	.html('<i class="icon-eye-open" />')
	.tooltip();
    $('.psd_edit').addClass('btn btn-mini')
	.html('<i class="icon-pencil" />')
	.tooltip();
    $('.pdr_render').addClass('btn btn-mini')
	.html('<i class="icon-picture" />')
	.tooltip();

    $('.pdr_grader').addClass('btn btn-mini')
	.html('<i class="icon-edit">')
	.tooltip();

    $('.pdr_handle').append('<i class="icon-resize-vertical" />');

    // This code controls the expand/collapse on the elements
    $('.pdr_collapse').prepend('<i class="icon-minus-sign"\>');
    $('.mjs-nestedSortable-collapsed .pdr_collapse').find('i:first')
	.removeClass('icon-minus-sign')
	.addClass('icon-plus-sign');

    $('.pdr_collapse').on('click', function() {
	$(this).closest('li').toggleClass('mjs-nestedSortable-collapsed').toggleClass('mjs-nestedSortable-expanded');
	$(this).children('i').toggleClass('icon-plus-sign').toggleClass('icon-minus-sign');
    })

    // This is for the render buttons
    $('.pdr_render').click(function(event) {
	event.preventDefault();
	var id = this.id.match(/^pdr_render_(\d+)/)[1];
	if ($('#psr_render_area_'+id).html()) {
	    $('#psr_render_area_'+id).html('');
	} else {
	    render(id);	
	}
    });

    $('#psd_render_all').addClass('btn').click(function (event) {
	event.preventDefault();
	$('.pdr_render').each(function () {
	    var id = this.id.match(/^pdr_render_(\d+)/)[1];
	    render(id);
	});
    });

    // This is for collapsing and expanding the tree
    $('#psd_hide_all').addClass('btn').click(function (event) {
	event.preventDefault();
	$('.psr_render_area').html('');
    });

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

    var set_prob_num_fields = function () {
	var array = $('#psd_list').nestedSortable("toArray");
	var heirarchy = $('#psd_list').nestedSortable("toHierarchy");
	
	$('.pdr_handle').html('');
	recurse_on_heirarchy(heirarchy,array);
	
	$('.pdr_handle').each(function () {
	    $(this).html($(this).html().slice(0,-1));
	    $(this).append('<i class="icon-resize-vertical" />');
	});

    };

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
  var mydefaultRequestObject = {
        };

  if (myUser && mySessionKey && myCourseID) {
    mydefaultRequestObject.user = myUser;
    mydefaultRequestObject.session_key = mySessionKey;
    mydefaultRequestObject.courseID = myCourseID;
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
    if ($('[name="problem.'+id+'.problem_seed"]').length > 0) {
	ro.problemSeed = $('[name="problem.'+id+'.problem_seed"]').val();
    } else {
	ro.problemSeed = 0;
    }
    var source_file

    if ($('[name="problem.'+id+'.source_file"]').val()) {
	source_file = $('[name="problem.'+id+'.source_file"]').val();
    } else {
	source_file = $('#problem_'+id+'_default_source_file').val();
    }

    ro.problemSource = templatedir + '/' + source_file;

    ro.set = ro.problemSource;
    ro.showHints = 1;
    ro.showSolutions = 1;
    var displayMode = $('[name="problem.displayMode"]').val();
    ro.noprepostambles = 1;
    $.post(basicWebserviceURL, ro, function (data) {
	var response = data;
	$('#psr_render_area_'+id).html(data);
	// run typesetter depending on the displaymode
	if(displayMode=='MathJax')
	    MathJax.Hub.Queue(["Typeset",MathJax.Hub,el]);
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
