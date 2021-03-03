$(function(){
	// Comment preview popovers.
	$(".preview").popover({html: "true", trigger: "focus", placement: "bottom", delay: { show: 0, hide: 2 }});

	$(".preview").click(function(evt) {
		$(evt.target).attr("data-content",
			$(evt.target).siblings("textarea").val().replace(/</g, '< ').replace(/>/g, ' >'));
		$(evt.target).popover('show');
		if (window.MathJax) {
			MathJax.startup.promise = MathJax.startup.promise.then(function() {
				return MathJax.typesetPromise(['.popover-content']);
			});
		}
	});

	// Compute the problem score from any answer sub scores, and update the problem score input.
	function updateProblemScore() {
		var elt = $(this);
		var problemId = elt.data('problem-id');
		var answerLabels = elt.data('answer-labels');

		var score = 0;
		answerLabels.forEach(function(label, index) {
			var partElt = $("#score_problem" + problemId + "_" + label);
			score += partElt.val() * partElt.data('weight');
		});
		$("#score_problem" + problemId).val(Math.round(score));
		$('#grader_messages_problem' + problemId).html("");
	}
	$(".answer-part-score").on('input', updateProblemScore);

	// Clear messages when the score or comment are changed.
	function removeMessage() { $('#grader_messages_problem' + $(this).data('problemId')).html(""); }
	$(".problem-score").on('input', removeMessage);
	$(".grader-problem-comment").on('input', removeMessage);

	// Save the score and comment.
	$(".save-grade").click(function() {
		var elt = $(this);
		var saveData = elt.data();

		var user = $('#hidden_user').val();
		var sessionKey = $('#hidden_key').val();

		var messageArea = $('#grader_messages_problem' + saveData.problemId);

		var scoreInput = $("#score_problem" + saveData.problemId);
		if (!scoreInput[0].checkValidity()) {
			messageArea.addClass('ResultsWithError');
			messageArea.text(scoreInput[0].validationMessage);
			messageArea.removeClass('ResultsWithError', 3000);
			scoreInput.focus();
			return;
		}

		// FIXME: /webwork2/ should not be hard coded here.
		// Save the score.
		var basicWebserviceURL = "/webwork2/instructorXMLHandler";
		$.ajax(basicWebserviceURL, {
			type: 'post',
			data: {
				user: user,
				session_key: sessionKey,
				xml_command: saveData.versionId ? 'putProblemVersion' : 'putUserProblem',
				courseID: saveData.courseId,
				user_id: saveData.studentId,
				set_id: saveData.setId,
				version_id: saveData.versionId,
				problem_id: saveData.problemId,
				status: scoreInput.val() / 100
			},
			timeout: 10000,
			success: function (data) {
				if (saveData.pastAnswerId) {
					// Save the comment.
					var comment = $("#comment_problem" + saveData.problemId).val();
					$.ajax(basicWebserviceURL, {
						type: 'post',
						data: {
							user: user,
							session_key: sessionKey,
							xml_command: 'putPastAnswer',
							courseID: saveData.courseId,
							answer_id: saveData.pastAnswerId,
							comment_string: comment
						},
						timeout: 10000,
						success: function (data) {
							messageArea.addClass('ResultsWithoutError');
							messageArea.text("Score and comment saved.");
							messageArea.removeClass('ResultsWithoutError', 3000);
						},
						error: function (data) {
							messageArea.addClass('ResultsWithError');
							messageArea.html('<div>The score was saved, but there was an error saving the comment.</div>' +
								'<div>' + basicWebserviceURL + ' response: ' + data.statusText + '</div>');
							messageArea.removeClass('ResultsWithError', 3000);
						},
					});
				} else {
					messageArea.addClass('ResultsWithoutError');
					messageArea.text("Score saved.");
					messageArea.removeClass('ResultsWithoutError', 3000);
				}
			},
			error: function (data) {
				messageArea.addClass('ResultsWithError');
				messageArea.html('<div>Error saving score.</div>' +
						'<div>' + basicWebserviceURL + ' response: ' + data.statusText + '</div>');
				messageArea.removeClass('ResultsWithError', 3000);
			},
		});
	});
});
