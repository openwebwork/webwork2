$(function(){
    
    $('#submit_button_id').click(function() {
	if ($('.tabberactive a:contains("View")').length > 0 && $('#newWindow:checked').length==0) {
	    $('#render-modal').modal({show :true, keyboard: true});
	}});
			       
})