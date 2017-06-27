$(document).keydown(function(e){
    if (e.keyCode === 27)
	$('#render-modal').modal('hide');
});

$(function(){
   
    $('#render-modal').modal({keyboard:true,show:false});
    
    $('#pg_editor_frame_id').on('load', function () {
	$('#pg_editor_frame_id').contents().find('#site-navigation')
	    .addClass('hidden-desktop hidden-tablet');
	$('#pg_editor_frame_id').contents().find('#content')
	    .removeClass('span10').addClass('span12');
	$("#pg_editor_frame_id").contents().find('#toggle-sidebar')
	    .addClass('hidden');
    });

    var codeMirrorDefined = true;

    try { CodeMirror; }

    catch (e) {

	if (e.name == "ReferenceError") {
	    codeMirrorDefined = false;
	}
    }
    
    if (codeMirrorDefined) {
	cm = CodeMirror.fromTextArea(
	    $("#problemContents")[0],
	    {mode: "PG",
	     indentUnit: 4,
	     tabMode: "spaces",
             lineNumbers: true,
	     lineWrapping: true,
             extraKeys:
             {Tab: function(cm) {cm.execCommand('insertSoftTab')}},
	     highlightSelectionMatches: true,
	     matchBrackets: true,
	     
	    });
	cm.setSize(700,400);
    }
    
});

addOnLoadEvent( function () {
    $('#submit_button_id').on('click',function() {
	/* NOTE:  This makes a lot of the updateTarget()/setTarget() JS
	   in the main pgeditor3 code superfluous.  Since we are doing a 
	   just in time check to see what the target should be, it doesn't
	   matter if we keep the target up to date before submit is pressed.
	*/

	// action0 = view
	// action1 = update
	// action2 = new version
	// action3 = append
	// action 4 = revert
	
	var inWindow = $("#newWindow").attr('checked');
	var target = "pg_editor_frame";
	if (inWindow) {
	    if ($('#action2').attr('checked') ||
		$('#action3').attr('checked') ||
		$('#action4').attr('checked')) {
		target = "WW_New_Edit";
	    } else {
		target = "WW_View";
	    }
	} 
	else if ($('#action2').attr('checked')
		 || $('#action3').attr('checked') 
		 || $('#action4').attr('checked'))
	{
	    target = "";
	}
	$("#editor").attr('target',target);
	
	if ($('#editor').attr('target') == "pg_editor_frame") {
	    $('#render-modal').modal('show');
	}

    });
        
})
