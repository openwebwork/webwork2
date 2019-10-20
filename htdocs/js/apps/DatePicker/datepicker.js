function WWDatePicker(name,reduced) {

	var open_rule = $('#' + name + '\\.open_date_id');
	var due_rule = $('#' + name + '\\.due_date_id');
	var answer_rule = $('#' + name + '\\.answer_date_id');

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
		var reduced_rule = $('#' + name + '\\.reduced_scoring_date_id');
		reduced_rule.change({ orig_value: reduced_rule.val() }, toggleChanged)
			.blur(function() {update();});
	}

	open_rule.datetimepicker({
		showOn: "button",
		buttonText: "<i class='icon-calendar'></i>",
		ampm: true,
		timeFormat: 'hh:mmtt',
		separator: ' at ',
		constrainInput: false,
		onClose: update,
	});

	due_rule.datetimepicker({
		showOn: "button",
		buttonText: "<i class='icon-calendar'></i>",
		ampm: true,
		timeFormat: 'hh:mmtt',
		separator: ' at ',
		constrainInput: false,
		onClose: update,
	});

	answer_rule.datetimepicker({
		showOn: "button",
		buttonText: "<i class='icon-calendar'></i>",
		ampm: true,
		timeFormat: 'hh:mmtt',
		separator: ' at ',
		constrainInput: false,
		onClose: update,
	});

	if (reduced) {
		reduced_rule.datetimepicker({
			showOn: "button",
			buttonText: "<i class='icon-calendar'></i>",
			ampm: true,
			timeFormat: 'hh:mmtt',
			separator: ' at ',
			constrainInput: false,
			onClose: update,
		});
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
}
