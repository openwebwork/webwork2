$(function() {    
    // Cause achievement popups to appear and then go away 
    $(window).load(function() { $('#achievementModal').modal('show');
				setTimeout(function(){$('#achievementModal').modal('hide');},5000);
			      });
    
    // Prevent problems which are disabled from acting as links
    $('.problem-list .disabled-problem').parent().addClass('disabled')
	.click(function (e) {
	    e.preventDefault();
	});
    
})

function submitAction() {
    
}

