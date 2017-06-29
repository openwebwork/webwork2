$(document).ready(function() {
		function answerId(j) {
			var id = "AnSwEr";
			if (j < 1000) id += "0";
			if (j < 100) id += "0";
			if (j < 10) id += "0";
			id += (j);
			return id;
		}
		function quizzesReady() {
			if (typeof 'com.wiris.quizzes' != 'undefined') {
				// Get WIRIS quizzes builders.
				var builder = com.wiris.quizzes.api.QuizzesBuilder.getInstance();
				var uibuilder = builder.getQuizzesUIBuilder();
				questionObject = builder.newQuestion();
				questionObject.setAnswerFieldType("popupEditor");
				instanceObject = builder.newQuestionInstance(questionObject);
				var i = 0;				
				while ((document.getElementById(answerId(i + 1))) != null) {
					var input = document.getElementById(answerId(i + 1));
					if (input.getAttribute("type") == "text") {
						answerField = uibuilder.newAnswerField(questionObject, instanceObject, i);
						//Configure underlying editor. We put the parameters in order to get a toolbar compatible with the options of WebWork.
						//See http://www.wiris.com/en/editor/docs/reference/parameters for the full list of available parameters.
						answerField.setEditorInitialParams({
							'toolbar':	'<toolbar><tab rows="1" name="Basic">'+
								'<section extraRows="1"><item ref="+"/><item ref="&#xB7;"/><item ref="-"/><item ref="fraction"/><item ref="verticalBar"/><item ref="superscript"/><item ref="angleBrackets"/></section>'+
								'<section extraRows="1"><item ref="numberPi"/><item ref="&#8734;"/><item ref="numberE" extra="true"/><item ref="imaginaryI" extra="true"/></section>'+
								'<section><item ref="undo"/><item ref="redo"/></section></tab>'+
								'<tab rows="1" name="Functions">'+
								'<section><item ref="squareRoot"/><item ref="nRoot"/><item ref="exponential"/></section>'+
								'<section extraRows="1"><item ref="log"/><item ref="nlog"/><item ref="naturalLog" extra="true"/></section>'+
								'<section extraRows="2"><item ref="sinus"/><item ref="cosinus"/><item ref="tangent"/><item ref="arcsinus" extra="true"/><item ref="cosecant" extra="true"/><item ref="arccosinus" extra="true"/><item ref="secant" extra="true"/><item ref="arctangent" extra="true"/><item ref="cotangent" extra="true"/></section></tab>'+
								'<tab rows="1" name="Intervals">'+
								'<section extraRows="1"><item ref="openInterval"/><item ref="closedInterval"/><item ref="openClosedInterval"/><item ref="closedOpenInterval"/><item ref="curlyBracket"/></section>'+
								'<section><item ref="reals"/><item ref="&#8746;"/></section>'+
								'</tab></toolbar>',
						});
						var elem = answerField.getElement();
						input.style.display = "none";
						input.parentNode.insertBefore(elem, input);
						addAnswerFieldEvents(answerField, input, instanceObject);
					}
					i++;
				}

			} else {
				setTimeout(quizzesReady, 300);
			}

		}
		quizzesReady();
		var m2w = new com.wiris.webwork.MathML2Webwork();

		function addAnswerFieldEvents(answerField, inputField, instanceObject) {
			answerField.addQuizzesFieldListener({
				contentChanged: function(source) {
					var input = source.getValue();
					var output = "";
					if (input.startsWith("<math") && input.endsWith("</math>")) {
						output = m2w.mathML2Webwork(input);
					} else {
						output = input;
					}
					inputField.value = output;
				},
				contentChangeStarted: function(source) {

				}
			});
		}
});
