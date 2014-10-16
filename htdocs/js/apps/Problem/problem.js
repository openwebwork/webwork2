$(function() {    
$(window).load(function() { $('#achievementModal').modal('show');
			    setTimeout(function(){$('#achievementModal').modal('hide');},5000);
			  });
})

window.onbeforeunload = function(e) {
	window.unsubmittedAnswers = false;
	$('input:text').each(function() {
		if ($(this).val() != "") {
			window.unsubmittedAnswers = true;
		}
	});

	if (window.unsubmittedAnswers == true){
		return "Stop";
	} else {
		return;
	}
}

function submitAction() {

}