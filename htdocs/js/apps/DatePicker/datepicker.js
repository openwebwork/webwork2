
function WWDatePicker(name,reduced) {
    
    var open_rule = $('#' + name + '\\.open_date_id');
    var due_rule = $('#' + name + '\\.due_date_id');
    var answer_rule = $('#' + name + '\\.answer_date_id');

    open_rule.change(function() {open_rule.addClass('changed')})
	.blur(function() {update();});
    due_rule.change(function() {due_rule.addClass('changed')})
	.blur(function() {update();});
    answer_rule.change(function() {answer_rule.addClass('changed')})
	.blur(function() {update();});
    
    if (reduced) {
	var reduced_rule = $('#' + name + '\\.reduced_scoring_date_id');
	reduced_rule.change(function() {reduced_rule.addClass('changed')})
	    .blur(function() {update();});
    }
        
    open_rule.datetimepicker({
        showOn: "button",
	buttonText: "<i class='icon-calendar'></i>",
	ampm: true,
	timeFormat: 'hh:mmtt',
	separator: ' at ',
	constrainInput: false, 
	onClose: function(dateText, inst) {
	    open_rule.addClass('changed');
            update();
	},
	
    });

    due_rule.datetimepicker({
        showOn: "button",
	buttonText: "<i class='icon-calendar'></i>",
	ampm: true,
	timeFormat: 'hh:mmtt',
	separator: ' at ',
	constrainInput: false, 
	onClose: function(dateText, inst) {
	    due_rule.addClass('changed');
    	    update();
	},
    });
    
    answer_rule.datetimepicker({
        showOn: "button",
	buttonText: "<i class='icon-calendar'></i>",
	ampm: true,
	timeFormat: 'hh:mmtt',
	separator: ' at ',
	constrainInput: false, 
	onClose: function(dateText, inst) {
	    answer_rule.addClass('changed');
    	    update();
	},
    });

    if (reduced) {
	reduced_rule.datetimepicker({
            showOn: "button",
	    buttonText: "<i class='icon-calendar'></i>",
	    ampm: true,
	    timeFormat: 'hh:mmtt',
	    separator: ' at ',
	    constrainInput: false, 
	    onClose: function(dateText, inst) {
		update();
		reduced_rule.addClass('changed');
	},
	});
    }

    var getDate = function(element) {

	if ($(element).val() == 'None Specified') {
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
	    reduced_rule.addClass('changed');
	} else if (openDate && dueDate && openDate > dueDate) {
	    dueDate = new Date(openDate);
	    due_rule.datetimepicker('setDate',dueDate);
	    due_rule.addClass('changed');
	}
	
	if (reduced && reducedDate && dueDate && reducedDate > dueDate)  {
	    dueDate = new Date(reducedDate);
	    due_rule.datetimepicker('setDate',dueDate);
	    due_rule.addClass('changed');
	}
	
	if (dueDate && answerDate && dueDate > answerDate) {
	    answerDate = new Date(dueDate);
	    answer_rule.datetimepicker('setDate',answerDate);
	    answer_rule.addClass('changed');
	}
	
    }
}
