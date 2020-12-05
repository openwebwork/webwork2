$(function(){
	// This is the code which allows you do the preview popovers.
	$(".preview").popover({html: "true", trigger: "manual", placement: "left", delay: { show: 0, hide: 2 }});

	$(".preview").click(function(evt) {
		$(evt.target).attr("data-content",
			$(evt.target).siblings("textarea").val().replace(/</g, '< ').replace(/>/g, ' >'));
		$(evt.target).popover('toggle');
		if (window.MathJax) {
			MathJax.Hub.Queue(["Typeset",MathJax.Hub])
		}
	});

	// Compute the problem score from the answer sub scores.
	function updateProblemScore() {
		var elt = $(this);
		var probId = elt.data('prob-id');
		var answerLabels = elt.data('answer-labels');

		var score = 0;
		answerLabels.forEach(function(label, index) {
			var partElt = $('input[name="' + probId + "." + label + '.score"]');
			score += partElt.val() * partElt.data('weight');
		});
		$('input[name="' + probId + '.score"]').val(Math.round(score));
	}

	$(".answer-part-score").change(updateProblemScore).keyup(updateProblemScore);
});
