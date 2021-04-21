$('.action-link').click(function() {
	var actionLink = $(this);
	actionLink.blur();
	document.getElementById("current_action").value = actionLink.data('action');
});
