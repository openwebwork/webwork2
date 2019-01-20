$(document).ready(function() {
	function mqReady() {
		if (typeof 'MathQuill' != 'undefined') {
			// initialize MathQuill
			var MQ = MathQuill.getInterface(2);
			var i = 1;				
			while ((document.getElementById("AnSwEr000" + i)) != null) {
				var input = document.getElementById("AnSwEr000" + i);
				var newSpan = document.createElement('span');
				newSpan.id = "AnSwEr000" + i + "-mq";
				if (input.value){
					var node = math.parse(input.value); // parse previous student answer
					newSpan.innerHTML = node.toTex(); // initialize with TeX'd version
				}
				var cfgOptions = {
				  spaceBehavesLikeTab: true,
				  leftRightIntoCmdGoes: 'up',
				  restrictMismatchedBrackets: true,
				  sumStartsWithNEquals: true,
				  supSubsRequireOperand: true,
				  charsThatBreakOutOfSupSub: '+-=<>',
				  autoSubscriptNumerals: true,
				  autoCommands: 'pi sqrt',
				  autoOperatorNames: 'sin cos tan',
				  maxDepth: 10,
				  handlers: {
				    edit: function(mqField) {
				      var inputField = document.getElementById(mqField.data.parentID);
				      inputField.value = mqField.text(); // update the WW answer field on edit
				    },
				  }
				}
				input.style.display = "none"; // hide the <input>
				input.parentNode.insertBefore(newSpan, input); // use the mathSpan instead
				answerField = MQ.MathField(newSpan,cfgOptions); // convert the span
				answerField.data.parentID = "AnSwEr000" + i; // store the ID for the "real" answer blank
				i++;	
			}

		} else {
			setTimeout(mqReady, 300);
		}

	}
	mqReady();

});
