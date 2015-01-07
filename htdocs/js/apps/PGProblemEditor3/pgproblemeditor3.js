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
    });
});

addOnLoadEvent( function () {
    $('#submit_button_id').on('click',function() {
	/* NOTE:  This makes a lot of the updateTarget()/setTarget() JS
	   in the main pgeditor3 code superfluous.  Since we are doing a 
	   just in time check to see what the target should be, it doesn't
	   matter if we keep the target up to date before submit is pressed.
	*/

	var inWindow = $("#newWindow").attr('checked');
	var target = "pg_editor_frame";
	if (inWindow) {
	    if ($('#save_as_form_id').attr('checked')) {
		target = "WW_New_Edit";
	    } else {
		target = "WW_View";
	    }
	} 
	else if ($('#save_as_form_id').attr('checked')
		 || ($('#revert_form_id').length > 0 &&
		     $('#revert_form_id').attr('checked')) 
		 || ($('#add_problem_form_id').length > 0 &&
		     $('#add_problem_form_id').attr('checked')))
	{
	    target = "";
	}
	$("#editor").attr('target',target);
	
	if ($('#editor').attr('target') == "pg_editor_frame") {
	    $('#render-modal').modal('show');
	}

    });
        
})