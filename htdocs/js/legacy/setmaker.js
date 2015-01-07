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

// For watermark of sample text for adding set text box
$(function() {
 $('input[example]').each(function(a,b) { $(b).watermark($(b).attr('example')+'   '  ) } )
 $('textarea[example]').each(function(a,b) { $(b).watermark($(b).attr('example')+'   ', {useNative:false}  ) } )
});

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

function lib_update(who, what) {
  var child = { subjects : 'chapters', chapters : 'sections', sections : 'count'};

  nomsg();
  var all = 'All ' + capFirstLetter(who);

  var mydefaultRequestObject = init_webservice('searchLib');
  if(mydefaultRequestObject == null) {
    // We failed
    // console.log("Could not get webservice request object");
    return false;
  }
  var subj = $('[name="library_subjects"] option:selected').val();
  var chap = $('[name="library_chapters"] option:selected').val();
  var sect = $('[name="library_sections"] option:selected').val();
  if(subj == 'All Subjects') { subj = '';};
  if(chap == 'All Chapters') { chap = '';};
  if(sect == 'All Sections') { sect = '';};
  var lib_text = $('[name="library_textbook"] option:selected').val();
  var lib_textchap = $('[name="library_textchapter"] option:selected').val();
  var lib_textsect = $('[name="library_textsection"] option:selected').val();
  if(lib_text == 'All Textbooks') { lib_text = '';};
  if(lib_textchap == 'All Chapters') { lib_textchap = '';};
  if(lib_textsect == 'All Sections') { lib_textsect = '';};
  mydefaultRequestObject.library_subjects = subj;
  mydefaultRequestObject.library_chapters = chap;
  mydefaultRequestObject.library_sections = sect;
  mydefaultRequestObject.library_textbooks = lib_text;
  mydefaultRequestObject.library_textchapter = lib_textchap;
  mydefaultRequestObject.library_textsection = lib_textsect;
  if(who == 'count') {
    mydefaultRequestObject.command = 'countDBListings';
    // console.log(mydefaultRequestObject);
    return $.post(basicWebserviceURL, mydefaultRequestObject, function (data) {
      var response = $.parseJSON(data);
      // console.log(response);
      var arr = response.result_data;
      arr = arr[0];
      var line = "There are "+ arr +" matching WeBWorK problems"
      if(arr == "1") {
        line = "There is 1 matching WeBWorK problem"
      }
      $('#library_count_line').html(line);
      return true;
    });
  }
  var subcommand = "getAllDBchapters";
  if(what == 'clear') {
    setselect('library_'+who, [all]);
    return lib_update(child[who], 'clear');
  }
  if(who=='chapters' && subj=='') { return lib_update(who, 'clear'); }
  if(who=='sections' && chap=='') { return lib_update(who, 'clear'); }
  if(who=='sections') { subcommand = "getSectionListings";}
  mydefaultRequestObject.command = subcommand;
  // console.log(mydefaultRequestObject);
  return $.post(basicWebserviceURL, mydefaultRequestObject, function (data) {
      var response = $.parseJSON(data);
      // console.log(response);
      var arr = response.result_data;
      arr.splice(0,0,all);
      setselect('library_'+who, arr);
      lib_update(child[who], 'clear');
    });
  return true;
}

function setselect(selname, newarray) {
  var sel = $('[name="'+selname+'"]');
  sel.empty();
  $.each(newarray, function(i,val) {
    sel.append($("<option></option>").val(val).html(val));
  });
}

function capFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
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

// Reset all the messages about who is in the current set
function markinset() {
  var ro = init_webservice('listSetProblems');
  var target = $('[name="local_sets"] option:selected').val();
  if(target == 'Select a Set from this Course') {
    target = null;
  }
  var shownprobs = $('[name^="filetrial"]'); // shownprobs.value
  ro.set_id = target;
  ro.command = 'true';
  return $.post(basicWebserviceURL, ro, function (data) {
    var response = $.parseJSON(data);
    // console.log(response);
    var arr = response.result_data;
    var pathhash = {};
    for(var i=0; i<arr.length; i++) {
      arr[i] = arr[i].replace(/^\//,'');
      pathhash[arr[i]] = 1;
    }
    for(var i=0; i< shownprobs.length; i++) {
      var num= shownprobs[i].name;
      num = num.replace("filetrial","");
      if(pathhash[shownprobs[i].value] ==1) {
        $('#inset'+num).html('<i><b>(in target set)</b></i>');
      } else {
        $('#inset'+num).html('<i><b></b></i>');
      }
    }
  });
}

function delrow(num) { 
  nomsg();
  var path = $('[name="filetrial'+ num +'"]').val();
  var APLindex = findAPLindex(path);
  var mymlt = $('[name="all_past_mlt'+ APLindex +'"]').val();
  var cnt = 1;
  var loop = 1;
  var mymltM = $('#mlt'+num);
  var mymltMtext = 'L'; // so extra stuff is not deleted
 if(mymltM) {
    mymltMtext = mymltM.text();
  }
  $('#pgrow'+num).remove(); 
  delFromPGList(num, path);
    if((mymlt > 0) && mymltMtext=='M') { // delete hidden problems
    var table_num = num;
    while((newmlt = $('[name="all_past_mlt'+ APLindex +'"]')) && newmlt.val() == mymlt) {
      cnt += 1;
      num++;
      path = $('[name="filetrial'+ num +'"]').val();
      $('#pgrow'+num).remove(); 
      delFromPGList(num, path);
    }
    $('#mlt-table'+table_num).remove();
    } else if ((mymlt > 0) && $('.MLT'+mymlt).length == 0) {
	  $('#mlt-table'+num).remove();
   } else if ((mymlt > 0) && mymltMtext=='L') {
      var new_num = $('#mlt-table'+num+' .MLT'+mymlt+':first')
	   .attr('id').match(/pgrow([0-9]+)/)[1];
      $('#mlt-table'+num).attr('id','mlt-table'+new_num);
      var onclickfunction = mymltM.attr('onclick').replace(num,new_num);
      mymltM.attr('id','mlt'+new_num).attr('onclick', onclickfunction);
      mymltM.insertAfter('#inset'+new_num);
      var classstr = $('#pgrow'+new_num).attr('class')
	  .replace('MLT'+mymlt,'NS'+new_num);
      $('#pgrow'+new_num).attr('class',classstr);
   }
  // Update various variables in the page
  var n1 = $('#lastshown').text();
  var n2 = $('#totalshown').text();
  $('#lastshown').text(n1-1);
  $('#totalshown').text(n2-1);
  var lastind = $('[name="last_index"]');
  lastind.val(lastind.val()-cnt);
  var ls = $('[name="last_shown"]').val();
  ls--;
  $('[name="last_shown"]').val(ls);
  if(ls < $('[name="first_shown"]').val()) {
    $('#what_shown').text('None');
  }
//  showpglist();
  return(true);
}

function findAPLindex(path) {
  var j=0;
  while ($('[name="all_past_list'+ j +'"]').val() != path && (j<100)) {
    j++;
  }
  if(j==100) { alert("Cannot find "+path);}
  return j;
}

function delFromPGList(num, path) {
  var j = findAPLindex(path);
  j++;
  while ($('[name="all_past_list'+ j +'"]').length>0) {
    var jm = j-1;
    $('[name="all_past_list'+ jm +'"]').val($('[name="all_past_list'+ j +'"]').val());
    $('[name="all_past_mlt'+ jm +'"]').val($('[name="all_past_mlt'+ j +'"]').val());
    j++;
  }
  j--;
  // var v = $('[name="all_past_list'+ j +'"]').val();
  $('[name="all_past_list'+ j +'"]').remove();
  $('[name="all_past_mlt'+ j +'"]').remove();
  return true;
}

function randomize(filepath, el) {
  nomsg();
  var seed = Math.floor((Math.random()*10000));
  var ro = init_webservice('renderProblem');
  var templatedir = $('#hidden_templatedir').val();
  ro.problemSeed = seed;
  ro.problemSource = templatedir + '/' + filepath;
  ro.set = ro.problemSource;
  var showhint = 0;
  if($("input[name='showHints']").is(':checked')) { showhint = 1;}
  var showsoln = 0;
  if($("input[name='showSolutions']").is(':checked')) { showsoln = 1;}
  ro.showHints = showhint;
  ro.showSolutions = showsoln;
  var displayMode = $('[name="original_displayMode"]').val();
  if(displayMode != 'None') {
    ro.displayMode = displayMode;
  }
  ro.noprepostambles = 1;
  $.post(basicWebserviceURL, ro, function (data) {
    var response = data;
    $('#'+el).html(data);
    // run typesetter depending on the displaymode
    if(displayMode=='MathJax')
      MathJax.Hub.Queue(["Typeset",MathJax.Hub,el]);
    if(displayMode=='jsMath')
      jsMath.ProcessBeforeShowing(el);
    //console.log(data);
  });
  return false;
}

function togglemlt(cnt,noshowclass) {
  nomsg();
  var count = $('.'+noshowclass).length;
  var n1 = $('#lastshown').text();
  var n2 = $('#totalshown').text();

  if($('#mlt'+cnt).text()=='M') {
    $('.'+noshowclass).show();
    $('#mlt'+cnt).text("L");
    $('#mlt'+cnt).attr("title","Show less like this");
    count = -1*count;
  } else {
    $('.'+noshowclass).hide();
    $('#mlt'+cnt).text("M");
    $('#mlt'+cnt).attr("title","Show "+$('.'+noshowclass).length+" more like this");
  }
  $('#lastshown').text(n1-count);
  $('#totalshown').text(n2-count);
  $('[name="last_shown"]').val($('[name="last_shown"]').val()-count);
  return false;
}

function showpglist() {
  var j=0;
  var s='';
  while ($('[name="all_past_list'+ j +'"]').length>0) {
    s = s+ $('[name="all_past_list'+ j +'"]').val()+", "+ $('[name="all_past_mlt'+ j +'"]').val()+"\n";
    j++;
  }
  alert(s);
  return true;
}
