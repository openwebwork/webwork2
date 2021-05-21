(function() {
	$(".datepicker-group").each(function() {
		if (this.dataset.enableDatepicker != "1") return;

		var name = this.name.replace(".open_date", "");

		var open_rule = $(this);
		var due_rule = $('input[id="' + name + '.due_date_id"]');
		var answer_rule = $('input[id="' + name + '.answer_date_id"]');
		var reduced_rule = $('input[id="' + name + '.reduced_scoring_date_id"]');
		var reduced = reduced_rule.length;

		var toggleChanged = function(e) {
			var elt = $(this);
			if (elt.val() != e.data.orig_value) elt.addClass('changed');
			else elt.removeClass('changed');
		}

		open_rule.change({ orig_value: open_rule.val() }, toggleChanged)
			.blur(function() {update();});
		due_rule.change({ orig_value: due_rule.val() }, toggleChanged)
			.blur(function() {update();});
		answer_rule.change({ orig_value: answer_rule.val() }, toggleChanged)
			.blur(function() {update();});

		if (reduced) {
			var reduced_rule = $('input[id="' + name + '.reduced_scoring_date_id"]');
			reduced_rule.change({ orig_value: reduced_rule.val() }, toggleChanged)
				.blur(function() {update();});
		}

		open_rule.datetimepicker({
			showOn: "button",
			buttonText: "<i class='fas fa-calendar-alt'></i>",
			ampm: true,
			timeFormat: 'hh:mmtt',
			separator: ' at ',
			constrainInput: false,
			onClose: update,
		});
		open_rule.parent().addClass('input-append').find('.ui-datepicker-trigger').addClass('btn');

		due_rule.datetimepicker({
			showOn: "button",
			buttonText: "<i class='fas fa-calendar-alt'></i>",
			ampm: true,
			timeFormat: 'hh:mmtt',
			separator: ' at ',
			constrainInput: false,
			onClose: update,
		});
		due_rule.parent().addClass('input-append').find('.ui-datepicker-trigger').addClass('btn');

		answer_rule.datetimepicker({
			showOn: "button",
			buttonText: "<i class='fas fa-calendar-alt'></i>",
			ampm: true,
			timeFormat: 'hh:mmtt',
			separator: ' at ',
			constrainInput: false,
			onClose: update,
		});
		answer_rule.parent().addClass('input-append').find('.ui-datepicker-trigger').addClass('btn');

		if (reduced) {
			reduced_rule.datetimepicker({
				showOn: "button",
				buttonText: "<i class='fas fa-calendar-alt'></i>",
				ampm: true,
				timeFormat: 'hh:mmtt',
				separator: ' at ',
				constrainInput: false,
				onClose: update,
			});
			reduced_rule.parent().addClass('input-append').find('.ui-datepicker-trigger').addClass('btn');
		}

		var getDate = function(element) {

			if (element.val() == '') {
				return null;
			} else {
				return element.datetimepicker('getDate');
			}

		}

		var update = function() {
			var openDate = getDate(open_rule);
			var dueDate = getDate(due_rule);
			var answerDate = getDate(answer_rule);
			var reducedDate;

			if (reduced) {
				reducedDate = getDate(reduced_rule);
			}

			if (reduced && openDate && reducedDate && openDate > reducedDate ) {
				var reducedDate = new Date(openDate);
				reduced_rule.datetimepicker('setDate',reducedDate);
			} else if (openDate && dueDate && openDate > dueDate) {
				dueDate = new Date(openDate);
				due_rule.datetimepicker('setDate',dueDate);
			}

			if (reduced && reducedDate && dueDate && reducedDate > dueDate)  {
				dueDate = new Date(reducedDate);
				due_rule.datetimepicker('setDate',dueDate);
			}

			if (dueDate && answerDate && dueDate > answerDate) {
				answerDate = new Date(dueDate);
				answer_rule.datetimepicker('setDate',answerDate);
			}

		}
	});

	// This will make the popup menu alternate between a single selection and a multiple selection menu.
	// Note: search by name is required since document.problemsetlist.action.import.number is not seen as
	// a valid reference to the object named 'action.import.number'
	var importAmtSelect = document.getElementById("import_amt_select");
	if (importAmtSelect) {
		importAmtSelect.addEventListener("change", function() {
			var number = document.getElementsByName('action.import.number')[0].value;
			document.getElementsByName('action.import.source')[0].size = number;
			document.getElementsByName('action.import.source')[0].multiple = (number > 1 ? true : false);
			document.getElementsByName('action.import.name')[0].value = (number > 1 ? '(taken from filenames)' : '');
		});
	}

	var importDateShift = $('#import_date_shift');
	if (importDateShift.length && importDateShift.data('enable-datepicker') == "1") {
		importDateShift.datetimepicker({
			showOn: "button",
			buttonText: "<i class='fas fa-calendar-alt'></i>",
			ampm: true,
			timeFormat: 'hh:mmtt',
			separator: ' at ',
			constrainInput: false, 
		});
		importDateShift.parent().addClass('input-append').find('.ui-datepicker-trigger').addClass('btn');
	}
})();
