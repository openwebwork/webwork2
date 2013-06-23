$(function(){
    
    $('#render-modal').modal({keyboard:true,show:false});

    $('#submit_button_id').click(function() {
	if ($('#newWindow:checked').length==0) {
	    $('#render-modal').modal('show');
	}});
			       
})