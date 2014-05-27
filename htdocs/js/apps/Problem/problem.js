$(function() {    
    $(window).load(function() { $('#achievementModal').modal('show');
				setTimeout(function(){$('#achievementModal').modal('hide');},5000);
			      });
    
    $('.problem-list .disabled-problem').parent().addClass('disabled')
	.click(function (e) {
	    e.preventDefault();
	});
    
})

function submitAction() {
    
}