$(document).ready(function() {
		function quizzesReady() {
			if (typeof 'com.wiris.quizzes' != 'undefined') {
				// Get WIRIS quizzes builders.
				var builder = com.wiris.quizzes.api.QuizzesBuilder.getInstance();
				var uibuilder = builder.getQuizzesUIBuilder();
				questionObject = builder.newQuestion();
				questionObject.setAnswerFieldType("popupEditor");
				instanceObject = builder.newQuestionInstance(questionObject);
				var i = 0;				
				while ((document.getElementById("AnSwEr000" + (i + 1))) != null) {
					var input = document.getElementById("AnSwEr000" + (i + 1));
					answerField = uibuilder.newAnswerField(questionObject, instanceObject, i);
					var elem = answerField.getElement();
					input.style.display = "none";
					input.parentNode.insertBefore(elem, input);
					addAnswerFieldEvents(answerField, input, instanceObject);
					i++;	
				}

			} else {
				setTimeout(quizzesReady, 300);
			}

		}
		quizzesReady();

		function addAnswerFieldEvents(answerField, inputField, instanceObject) {
			answerField.addQuizzesFieldListener({
				contentChanged: function(source) {
					var text = instanceObject.expandVariablesText(source.getValue());
					inputField.value = text;
				},
				contentChangeStarted: function(source) {

				}
			});
		}
});