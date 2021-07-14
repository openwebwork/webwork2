(function() {
	var basicRequestObject = {
		"xml_command": "listLib",
		"library_name": "Library",
		"command": "buildtree"
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

	function init_webservice(command) {
		var myUser = $('#hidden_user').val();
		var myCourseID = $('#hidden_courseID').val();
		var mySessionKey = $('#hidden_key').val();
		var mydefaultRequestObject = {};
		$.extend(mydefaultRequestObject, basicRequestObject);
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
			return $.ajax({type:'post',
				url: basicWebserviceURL,
				data: mydefaultRequestObject,
				timeout: 10000, //milliseconds
				success: function (data) {
					if (data.match(/WeBWorK error/)) {
						reportWWerror(data);		   
					}

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
				},
				error: function (data) {
					alert('150 setmaker.js: '+basicWebserviceURL+': '+data.statusText);
				},
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
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: mydefaultRequestObject,
			timeout: 10000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				var response = $.parseJSON(data);
				// console.log(response);
				var arr = response.result_data;
				arr.splice(0,0,all);
				setselect('library_'+who, arr);
				lib_update(child[who], 'clear');
				return true;
			},
			error: function (data) {
				alert('183 setmaker.js: ' + basicWebserviceURL+': '+data.statusText);
			},
		});
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
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

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
			return $.ajax({type:'post',
				url: wsURL,
				data: ro2,
				timeout: 10000, //milliseconds
				success: addemcallback(wsURL, ro2, probarray, count+1),
				error: function (data) {
					alert('259 setmaker.js: '+wsURL+': '+data.statusText);
				},
			});

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
		return $.ajax({type:'post',
			url: basicWebserviceURL,
			data: ro,
			timeout: 10000, //milliseconds
			success: function (data) {
				if (data.match(/WeBWorK error/)) {
					reportWWerror(data);
				}

				var response = $.parseJSON(data);
				// console.log(response);
				var arr = response.result_data;
				var pathhash = {};
				for(var i=0; i<arr.length; i++) {
					arr[i] = arr[i].path;
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
			},
			error: function (data) {
				alert('305 setmaker.js: '+ basicWebserviceURL+': '+data.statusText);
			},
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
			var insetel = $('#inset'+new_num);
			insetel.next().after(mymltM).after(" ");
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
		while ($('[name="all_past_list'+ j +'"]').val() != path && (j<1000)) {
			j++;
		}
		if(j==1000) { alert('370 setmaker.js: ' + "Cannot find " +path);}
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

	var basicRendererURL = "/webwork2/html2xml";

	async function render(id) {
		return new Promise(function(resolve, reject) {
			var renderArea = $('#psr_render_area_' + id);

			var iframe = renderArea.find('#psr_render_iframe_' + id);
			if (iframe[0] && iframe[0].iFrameResizer) {
				iframe[0].contentDocument.location.replace('about:blank');
			}

			var ro = {
				userID: $('#hidden_user').val(),
				courseID: $('#hidden_courseID').val(),
				session_key: $('#hidden_key').val()
			};

			if (!(ro.userID && ro.courseID && ro.session_key)) {
				renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
					.text("Missing hidden credentials: user, session_key, courseID"));
				resolve();
				return;
			}

			ro.sourceFilePath = renderArea.data('pg-file');
			ro.outputformat = 'simple';
			ro.showAnswerNumbers = 0;
			ro.problemSeed = Math.floor((Math.random()*10000));
			ro.showHints = $('input[name=showHints]').is(':checked') ? 1 : 0;
			ro.showSolutions = $('input[name=showSolutions]').is(':checked') ? 1 : 0;
			ro.noprepostambles = 1;
			ro.processAnswers = 0;
			ro.showFooter = 0;
			ro.displayMode = $('select[name=mydisplayMode]').val();
			ro.send_pg_flags = 1;
			ro.extra_header_text = "<style>html{overflow-y:hidden;}body{padding:0;background:#f5f5f5;.container-fluid{padding:0px;}</style>";
			if (window.location.port) ro.forcePortNumber = window.location.port;

			$.ajax({type:'post',
				url: basicRendererURL,
				data: ro,
				dataType: "json",
				timeout: 10000, //milliseconds
			}).done(function (data) {
				// Give nicer session timeout error
				if (!data.html || /Can\'t authenticate -- session may have timed out/i.test(data.html) ||
					/Webservice.pm: Error when trying to authenticate./i.test(data.html)) {
					renderArea.html($('<div/>',{ style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text("Can't authenticate -- session may have timed out."));
					resolve();
					return;
				}
				// Give nicer file not found error
				if (/this problem file was empty/i.test(data.html)) {
					renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text('No Such File or Directory!'));
					resolve();
					return;
				}
				// Give nicer problem rendering error
				if ((data.pg_flags && data.pg_flags.error_flag) ||
					/error caught by translator while processing problem/i.test(data.html) ||
					/error message for command: renderproblem/i.test(data.html)) {
					renderArea.html($('<div/>',{ style: 'font-weight:bold', 'class': 'ResultsWithError' })
						.text('There was an error rendering this problem!'));
					resolve();
					return;
				}

				if (!(iframe[0] && iframe[0].iFrameResizer)) {
					iframe = $("<iframe/>", { id: "psr_render_iframe_" + id });
					iframe[0].style.border = 'none';
					renderArea.html(iframe);
					if (data.pg_flags && data.pg_flags.comment) iframe.after($(data.pg_flags.comment));
					iFrameResize({ checkOrigin: false, warningTimeout: 20000, scrolling: 'omit' }, iframe[0]);
					iframe[0].addEventListener('load', function() { resolve(); });
				}
				iframe[0].srcdoc = data.html;
			}).fail(function (data) {
				renderArea.html($('<div/>', { style: 'font-weight:bold', 'class': 'ResultsWithError' })
					.text(basicRendererURL + ': ' + data.statusText));
				resolve();
			});
		});
	}

	async function togglemlt(cnt, noshowclass) {
		nomsg();
		let unshownAreas = $('.' + noshowclass);
		var count = unshownAreas.length;
		var n1 = $('#lastshown').text();
		var n2 = $('#totalshown').text();

		if($('#mlt' + cnt).text() == 'M') {
			unshownAreas.show();
			// Render any problems that were hidden that have not yet been rendered.
			for (let area of unshownAreas) {
				let iframe = $(area).find('iframe[id^=psr_render_iframe_]');
				if (iframe[0] && iframe[0].iFrameResizer) iframe[0].iFrameResizer.resize();
				else await render(area.id.match(/^pgrow(\d+)/)[1]);
			}
			$('#mlt' + cnt).text("L");
			$('#mlt' + cnt).attr("title", "Show less like this");
			count = -count;
		} else {
			unshownAreas.hide();
			$('#mlt' + cnt).text("M");
			$('#mlt' + cnt).attr("title", "Show " + unshownAreas.length + " more like this");
		}
		$('#lastshown').text(n1 - count);
		$('#totalshown').text(n2 - count);
		$('[name="last_shown"]').val($('[name="last_shown"]').val() - count);
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

	function reportWWerror(data) {
		console.log(data);
		$('<div/>',{class : 'WWerror', title : 'WeBWorK Error'})
			.html(data)
			.dialog({width:'70%'});
	}

	// Set up the problem rerandomization buttons.
	$(".rerandomize_problem_button").click(function() {
		var targetProblem = $(this).data('target-problem');
		render(targetProblem);
	});

	// Find all render areas
	var renderAreas = $('.psr_render_area');

	// Add the loading message to all render areas.
	for (var renderArea of renderAreas) {
		$(renderArea).html('Loading Please Wait...');
	}

	// Render all visible problems on the page
	(async function() {
		for (let renderArea of renderAreas) {
			if (!$(renderArea).is(':visible')) continue;
			await render(renderArea.id.match(/^psr_render_area_(\d+)/)[1]);
		}
	})();

	$("select[name=library_chapters]").on("change", function() { lib_update('sections', 'get'); });
	$("select[name=library_subjects]").on("change", function() { lib_update('chapters', 'get'); });
	$("select[name=library_sections]").on("change", function() { lib_update('count', 'clear'); });
	$("input[name=level]").on("change", function() { lib_update('count', 'clear'); });
	$("input[name=select_all]").click(function() { addme('', 'all'); });
	$("input[name=add_me]").click(function() { addme($(this).data('source-file'), 'one'); });
	$("select[name=local_sets]").on("change", markinset);
	$("span[name=dont_show]").click(function() { delrow($(this).data('row-cnt')); });
	$(".lb-mlt-parent").click(function() { togglemlt($(this).data('mlt-cnt'), $(this).data('mlt-noshow-class')); });
})();
