$(function(){
    
    $('#submit_button_id').click(function() {
	if ($('#newWindow:checked').length==0) {
	    $('#render-modal').modal({show :true, keyboard: true});
	}});
			       
})