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

    $('.psd_list_row').wrapInner('<div class="span11 well"/>')
        .append('<div class="span1"/>')
	.wrapInner('<div class="pdr_container row-fluid" />');

    $('.pdr_block_1').addClass('span2');
    $('.pdr_block_2').addClass('span3');
    $('.pdr_block_3').addClass('span7');

    $('.pdr_collapse').prepend('<i class="icon-minus"\>');

    $('.pdr_collapse').on('click', function() {
	$(this).closest('li').toggleClass('mjs-nestedSortable-collapsed').toggleClass('mjs-nestedSortable-expanded');
	$(this).children('i').toggleClass('icon-plus').toggleClass('icon-minus');
    })

    var recurse_on_heirarchy = function (heirarchy,array) {
	for (var i=0; i < heirarchy.length; i++) {
	    var id = heirarchy[i].id;

	    $('#prob_num_'+id).val(i+1);
	    $('#pdr_handle_'+id).html(i+1);
	    $('#prob_parent_id_'+id).val(array[i].parent_id);

	    if (typeof heirarchy[i].children != 'undefined') {
		recurse_on_heirarchy(heirarchy[i].children,array);
	    }
	}
    };

    var set_prob_num_fields = function () {
	var array = $('#psd_list').nestedSortable("toArray",{key:'prob_num'});
	var heirarchy = $('#psd_list').nestedSortable("toHierarchy",{key:'prob_num'});
	
	recurse_on_heirarchy(heirarchy,array);
    };

    $('#psd_list').on('sortupdate', set_prob_num_fields);

    $('#psd_renumber').addClass('btn').click(function (event) {
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


// Messaging

function nomsg() {
  $(".Message").html("");
}

function goodmsg(msg) {
  $(".Message").html('<div class="ResultsWithoutError">'+msg+"</div>");
}

function badmsg(msg) {
  $(".Message").html('<div class="ResultsWithError">'+msg+"</div>");
}


function settoggle(id, text1, text2) {
  $('#'+id).toggle(function() {$('#'+id).html(text2)}, 
    function() {$('#'+id).html(text1)});
  return true;
}

function toggle_content(id, text1, text2) {
  var e = $('#'+id);
  nomsg();
  if(e.text() == text1)
    e.text(text2);
  else
    e.text(text1);
  return true;
}

function togglepaths() {
  var toggle_from = $('#toggle_path_current')[0].value;
  var new_text = $('#showtext');
  nomsg();
  if(toggle_from == 'show') {
    new_text = $('#hidetext')[0].value;
    $('#toggle_path_current').val('hide');
	$("[id*=filepath]").each(function() {
		// If showing, trigger
		if(this.textContent.match('^Show')) {
		  this.click();
	    }
	});
  } else {
    new_text = $('#showtext')[0].value;
    $('#toggle_path_current').val('show');
	$("[id*=filepath]").each(function() {
		// If hidden, trigger
		if(! this.textContent.match('^Show')) {
		  this.click();
		}
	});
  }
  $('#toggle_paths').prop('value',new_text);
  return false;
}

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

function addme(path, who) {
  nomsg();
  var target = $('[name="local_sets"] option:selected').val();
  if(target == 'Select a Set from this Course') {
    alert('You need to pick a target set above so we know what set to which we should add this problem.');
    return true;
  }
  var mydefaultRequestObject = init_webservice('addProblem');
  if(mydefaultRequestObject == null) {
    // We failed
	badmsg("Could not connect back to server");
    return false;
  }
  mydefaultRequestObject.set_id = target;
  var pathlist = new Array();
  if(who=='one') {
    pathlist.push(path);
  } else { // who == 'all'
    var allprobs = $('[name^="filetrial"]');
    for(var i=0,len =allprobs.length; i< len; ++i) {
      pathlist.push(allprobs[i].value);
    }
  }
  mydefaultRequestObject.total = pathlist.length;
  mydefaultRequestObject.set = target;
  addemcallback(basicWebserviceURL, mydefaultRequestObject, pathlist, 0)(true);
}

function addemcallback(wsURL, ro, probarray, count) {
  if(probarray.length==0) {
    return function(data) {
      var phrase = count+" problem";
      if(count!=1) { phrase += "s";}
     // alert("Added "+phrase+" to "+ro.set);
      markinset();

	  var prbs = "problems";
	  if(ro.total == 1) { 
		prbs = "problem";
	  }
	  goodmsg("Added "+ro.total+" "+prbs+" to set "+ro.set_id);

      return true;
    };
  }
  // Need to clone the object so the recursion works
  var ro2 = jQuery.extend(true, {}, ro);
  ro2.problemPath=probarray.shift();
  return function (data) {
    return $.post(wsURL, ro2, addemcallback(wsURL, ro2, probarray, count+1));
  };
}
