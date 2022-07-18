// Setup for ajax
(async () => {
	// Load the library taxonomy from the JSON file.
	const tagWidgetScript = document.getElementById('tag-widget-script');
	if (!tagWidgetScript || !tagWidgetScript.dataset.taxo) return;

	const response = await fetch(tagWidgetScript.dataset.taxo);
	if (!response.ok) {
		alert('Could not load the OPL taxonomy from the server.')
		return;
	}

	const taxo = await response.json();

	const basicWebserviceURL = '/webwork2/instructorXMLHandler';

	function readfromtaxo(who, valarray) {
		var mytaxo = taxo;
		if (who == 'subjects') {
			return mytaxo.map(function(z) {return z['name'];} );
		}
		var failed = true;
		for(var i=0; i<mytaxo.length; i++) {
			if(mytaxo[i]['name'] == valarray[0]) {
				mytaxo = mytaxo[i]['subfields'];
				failed=false;
				break;
			}
		}
		if(failed) {
			alert('Provided value "' + valarray[0] + '" is not in my subject taxonomy. ' );
			return([]);
		}
		if(who == 'chapters') {
			return(mytaxo.map(function(z) {return(z['name']);} ));
		}
		failed = true;
		for(var i=0; i<mytaxo.length; i++) {
			if(mytaxo[i]['name'] == valarray[1]) {
				mytaxo = mytaxo[i]['subfields'];
				failed=false;
				break;
			}
		}
		if(failed) {
			alert('Provided value "'+ valarray[1] + '" is not in my chapter taxonomy. ' );
			return([]);
		}
		if(who == 'sections') {
			return mytaxo.map(function(z) {return(z['name']);} );
		}
		return([]); // Should not get here
	}

	function init_webservice(command) {
		const myUser = $('#hidden_user').val();
		const myCourseID = $('#hidden_courseID').val();
		const mySessionKey = $('#hidden_key').val();
		const requestObject = {
			'xml_command': 'listLib',
			'library_name': 'Library',
			'command': 'searchLib'
		};
		if (myUser && mySessionKey && myCourseID) {
			requestObject.user = myUser;
			requestObject.session_key = mySessionKey;
			requestObject.courseID = myCourseID;
		} else {
			alert("missing hidden credentials: user "
				+ myUser + " session_key " + mySessionKey+ " courseID "
				+ myCourseID, "alert-danger");
			return null;
		}
		requestObject.xml_command = command;
		return requestObject;
	}


	// New object
	function tag_widget(el, path) {
		const id = el.id;

		var nodata = {'DBsubject': '', 'DBchapter': '', 'DBsection': ''};

		var $el = $(el);
		$el.html('<b>Edit tags:</b> ');
		$el.append('<select id="'+id+'subjects"></select>');
		var subj = $('#'+id+'subjects');
		subj.append('<option value="All Subjects">All Subjects</option>');
		$el.append('<select id="'+id+'chapters"></select>');
		var chap = $('#'+id+'chapters');
		chap.append('<option value="All Chapters">All Chapters</option>');
		$el.append('<select id="'+id+'sections"></select>');
		var sect = $('#'+id+'sections');
		sect.append('<option value="All Sections">All Sections</option>');
		$el.append('<select id="'+id+'level"></select>');
		var levels = $('#'+id+'level');
		levels.append('<option value="">Level</option>');
		for (var j=1; j<7; j++) {
			levels.append('<option value="'+j+'">'+j+'</option>');
		}
		// Only show the status menu if we are looking at something in Pending
		var shortpath = path.replace(/^.*templates\//,'');
		if(/^Pending\//.test(shortpath)) {

			$el.append('<select id="'+id+'stat"></select>');
			var stat = $('#'+id+'stat');
			stat.append('<option value="A">Accept</option>');
			stat.append('<option value="0">Review</option>');
			stat.append('<option value="R">Reject</option>');
			stat.append('<option value="F">Further review</option>');
			stat.append('<option value="N">Needs resource</option>');
		}
		subj.on('change', function() {tag_widget_clear_message(id);tag_widget_update('chapters', 'get', id, nodata);});
		chap.on('change', function() {tag_widget_clear_message(id);tag_widget_update('sections', 'get', id, nodata);});
		sect.on('change', function() {tag_widget_clear_message(id);});
		this.tw_gettags(path, id);
		$el.append('<button id="'+id+'Save">Save</button>');
		$('#'+id+'Save').on('click', function() {tag_widget_savetags(id, path);return false;});
		$el.append('<span id="'+id+'result"></span>');
		return false;
	}

	tag_widget.prototype.tw_gettags = function(path, id) {
		var requestObject = init_webservice('getProblemTags');
		// console.log("In tw_gettags");
		if(requestObject == null) {
			// We failed
			return false;
		}
		requestObject.command = path;
		// console.log(requestObject);
		return $.post(basicWebserviceURL, requestObject, function (data) {
			var response = JSON.parse(data);
			var dat = response.result_data;
			// console.log(dat);
			tag_widget_update('subjects', 'get', id, dat);
		});
	}

	tag_widget_savetags = function(id, path) {
		var requestObject = init_webservice('setProblemTags');
		if(requestObject == null) {
			// We failed
			return false;
		}
		var subj = $('#'+id+'subjects').find(':selected').text();
		var chap = $('#'+id+'chapters').find(':selected').text();
		var sect = $('#'+id+'sections').find(':selected').text();
		var level = $('#'+id+'level').find(':selected').text();
		var stat = $('#'+id+'stat').find(':selected').val();
		if(subj == 'All Subjects') { subj = '';};
		if(chap == 'All Chapters') { chap = '';};
		if(sect == 'All Sections') { sect = '';};
		if(level == 'Level') { level = '';};
		requestObject.library_subjects = subj;
		requestObject.library_chapters = chap;
		requestObject.library_sections = sect;
		requestObject.library_levels = level;
		requestObject.library_status = stat;
		requestObject.command = path;
		// console.log(requestObject);
		return $.post(basicWebserviceURL, requestObject, function (data) {
			var response = JSON.parse(data);
			var mesg = response.server_response;
			// console.log(response);
			$('#'+id+'result').text(mesg);
		});
	}

	tag_widget_clear_message = function(id) {
		$('#'+id+'result').text('');
	}

	tag_widget_update = function(who, what, where, values) {
		// where is the start of the id's for the parts
		const child = {
			subjects: 'chapters',
			chapters: 'sections',
			sections: 'level',
			level: 'stat',
			stat: 'count'
		};

		// console.log({"who": who, "what": what, "where":where, "values": values});
		var all = 'All ' + capFirstLetter(who);
		if(who=='level') {
			all = 'Level';
		}

		if(who=='count') {
			return false;
		}
		if(!values.DBsubject && values.DBsubject.match(/ZZZ/)) {
			$('#'+where+'subjects').remove();
			$('#'+where+'chapters').remove();
			$('#'+where+'sections').remove();
			$('#'+where+'level').remove();
			$('#'+where+'stat').remove();
			$('#'+where+'Save').remove();
			$('#'+where+'result').text(' Problem file is a pointer to another file');
			return false;
		}
		var requestObject = init_webservice('searchLib');
		if(requestObject == null) {
			// We failed
			return false;
		}
		var subj = $('#'+where+'subjects').find(':selected').text();
		var chap = $('#'+where+'chapters').find(':selected').text();
		var sect = $('#'+where+'sections').find(':selected').text();
		var level = $('#'+where+'level').find(':selected').text();
		var stat = $('#'+where+'stat').find(':selected').val();
		if(subj == 'All Subjects') { subj = '';};
		if(chap == 'All Chapters') { chap = '';};
		if(sect == 'All Sections') { sect = '';};
		if(level == 'Level') { level = '';};
		// Now override in case we were fed values
		if(values.DBsubject) { subj = values.DBsubject;}
		if(values.DBchapter) { chap = values.DBchapter;}
		if(values.DBsection) { sect = values.DBsection;}
		if(values.Level) { level = values.Level;}
		if(values.Status) { stat = values.Status;} else { stat = "0" }
		requestObject.library_subjects = subj;
		requestObject.library_chapters = chap;
		requestObject.library_sections = sect;
		var subcommand = "getAllDBsubjects";
		if(who == 'level') {
			$('#'+where+who).val(level);
			return tag_widget_update('stat','get',where,values);
		}
		if(who == 'stat') {
			$('#'+where+who).val(stat);
			return true;
		}
		if(what == 'clear') {
			setselectbyid(where+who, [all]);
			return tag_widget_update(child[who], 'clear',where, values);
		}
		if(who=='chapters' && subj=='') { return tag_widget_update(who, 'clear', where, values); }
		if(who=='sections' && chap=='') { return tag_widget_update(who, 'clear', where, values); }
		if(who=='chapters') { subcommand = "getAllDBchapters";}
		if(who=='sections') { subcommand = "getSectionListings";}
		requestObject.command = subcommand;
		// console.log("Setting menu "+where+who);
		// console.log(requestObject);
		var arr = readfromtaxo(who, [subj, chap, sect]);
		arr.splice(0,0,all);
		setselectbyid(where+who, arr);
		if(values.DBsubject && who=='subjects') {
			$('#'+where+who).val(values.DBsubject);
		}
		if(values.DBchapter && who=='chapters') {
			$('#'+where+who).val(values.DBchapter);
		}
		if(values.DBsection && who=='sections') {
			$('#'+where+who).val(values.DBsection);
		}
		tag_widget_update(child[who], 'get',where, values);
		return true;
	}

	// Two utility functions
	function setselectbyid(id, newarray) {
		var sel = $('#'+id);
		// console.log("Setting "+id);
		sel.empty();
		$.each(newarray, function(_i,val) {
			sel.append($("<option></option>").val(val).html(val));
		});
	}

	function capFirstLetter(string) {
		return string.charAt(0).toUpperCase() + string.slice(1);
	}

	document.querySelectorAll('.tag-widget').forEach(
		(tagger) => {
			if (!tagger.dataset.sourceFilePath) return;
			new tag_widget(tagger, tagger.dataset.sourceFilePath);
		});
})();
