$(function() {

    //Problem set detail 2 
    $('#problemset_detail_list').addClass('container-fluid');

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
 
    });

    $('.problem_detail_row').addClass('well span11')
	.wrap('<div class="row-fluid" />')
	.after('<div class="span1" />');

    $('.pdr_block_1').addClass('span2');
    $('.pdr_block_2').addClass('span3');
    $('.pdr_block_3').addClass('span7');

    $('.psd_view').addClass('btn btn-mini')
	.html('<i class="icon-eye-open" />')
	.tooltip();
    $('.psd_edit').addClass('btn btn-mini')
	.html('<i class="icon-pencil" />')
	.tooltip();
    $('.pdr_render').addClass('btn btn-mini')
	.html('<i class="icon-picture" />')
	.tooltip();

    $('.pdr_handle').append('<i class="icon-resize-vertical" />');

    $('.pdr_collapse').prepend('<i class="icon-minus-sign"\>');
    $('.mjs-nestedSortable-collapsed .pdr_collapse').find('i:first')
	.removeClass('icon-minus-sign')
	.addClass('icon-plus-sign');

    $('.pdr_collapse').on('click', function() {
	$(this).closest('li').toggleClass('mjs-nestedSortable-collapsed').toggleClass('mjs-nestedSortable-expanded');
	$(this).children('i').toggleClass('icon-plus-sign').toggleClass('icon-minus-sign');
    })

    $('.pdr_render').click(function() {
	event.preventDefault();
	var id = this.id.match(/^pdr_render_(\d+)/)[1];
	render(id);
	
    });

    var recurse_on_heirarchy = function (heirarchy,array) {
	for (var i=0; i < heirarchy.length; i++) {
	    var id = heirarchy[i].id;

	    $('#prob_num_'+id).val(i+1);
	    $('#pdr_handle_'+id).html(i+1)
		.append('<i class="icon-resize-vertical" />');;

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
	
	recurse_on_heirarchy(heirarchy,array);
    };

    $('#psd_list').on('sortupdate', set_prob_num_fields);

    $('#psd_renumber').addClass('btn').tooltip().click(function (event) {
	event.preventDefault();
	set_prob_num_fields();
    });

});

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
  var myCourseID = $('#hidden_courseID').val();
  var mySessionKey = $('#hidden_key').val();
  var mydefaultRequestObject = {
        };
  _.defaults(mydefaultRequestObject, basicRequestObject);
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
    if ($('#problem.'+id+'.problem_seed_id').length > 0) {
	ro.problemSeed = $('#problem.'+id+'.problem_seed_id').val();
    } else {
	ro.problemSeed = 0;
    }
    ro.problemSource = templatedir + '/' + $('#prob_filepath_'+id);
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
