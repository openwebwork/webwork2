
function WWDatePicker(name,open_tz,due_tz,answer_tz,reduced,reduced_tz) {
    
    var open_rule = $('#' + name + '\\.open_date_id');
    var due_rule = $('#' + name + '\\.due_date_id');
    var answer_rule = $('#' + name + '\\.answer_date_id');
    var dueDateOffset = 7; // 7 days after open date
    var answerDateOffset = 5; //5 hours after due date

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
	timeSuffix: ' '+open_tz,
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
	timeSuffix: ' '+due_tz,
	separator: ' at ',
	constrainInput: false, 
	onClose: function(dateText, inst) {
            var open_changed=0;
    	    if (open_rule.val() == "") {
    		var openDate = new Date(dateText);
    		openDate.setDate(openDate.getDate() -dueDateOffset );
    		open_rule.datetimepicker('setDate',openDate);
    	    }
	    due_rule.addClass('changed');
    	    update();
	},
    });
    
    answer_rule.datetimepicker({
        showOn: "button",
	buttonText: "<i class='icon-calendar'></i>",
	ampm: true,
	timeFormat: 'hh:mmtt',
	timeSuffix: ' '+answer_tz,
	separator: ' at ',
	constrainInput: false, 
	onClose: function(dateText, inst) {
            var open_changed=0;    
            if (open_rule.val() == "") {
    		var openDate = new Date(dateText);
    		openDate.setDate(openDate.getDate() - dueDateOffset );
    		openDate.setHours(openDate.getHours() - answerDateOffset);
    		open_rule.datetimepicker('setDate',openDate);
    	    }
	    answer_rule.addClass('changed');
    	    update();
	},
	onSelect: function (selectedDateTime){
	}
    });

    if (reduced) {
	reduced_rule.datetimepicker({
            showOn: "button",
	    buttonText: "<i class='icon-calendar'></i>",
	    ampm: true,
	    timeFormat: 'hh:mmtt',
	    timeSuffix: ' '+reduced_tz,
	    separator: ' at ',
	    constrainInput: false, 
	    onClose: function(dateText, inst) {
		update();
		reduced_rule.addClass('changed');
	},
	});
    }
    
    var update = function() {
	var openDate = open_rule.datetimepicker('getDate');
	var dueDate = due_rule.datetimepicker('getDate');
	var answerDate = answer_rule.datetimepicker('getDate');
	if ( due_rule.val() =='') {
	    dueDate = new Date(openDate);
	    dueDate.setDate(dueDate.getDate()+dueDateOffset);
	    due_rule.datetimepicker('setDate',dueDate);
	    due_rule.addClass('changed');
	} else if (openDate > due_rule.datetimepicker('getDate')) {
	    dueDate = new Date(openDate);
	    due_rule.datetimepicker('setDate',dueDate);
	    due_rule.addClass('changed');
	}

	if (reduced) {
	    var reducedDate = reduced_rule.datetimepicker('getDate');
	    if (openDate > reducedDate) {
		reducedDate = new Date(openDate);
		reduced_rule.datetimepicker('setDate',reducedDate);
		reduced_rule.addClass('changed');
	    }
	    
	    if (dueDate < reducedDate) {
		reducedDate = new Date(dueDate);
		reduced_rule.datetimepicker('setDate',reducedDate);
		reduced_rule.addClass('changed');
	    }
	}
	
	if ( answer_rule.val() =='') {
	    answerDate = new Date(dueDate);
	    answerDate.setHours(answerDate.getHours()+answerDateOffset);
	    answer_rule.datetimepicker('setDate',answerDate);
	    answer_rule.addClass("changed");
	} else if (dueDate > answer_rule.datetimepicker('getDate')) {
	    answerDate = new Date(dueDate);
	    answer_rule.datetimepicker('setDate',answerDate);
	    answer_rule.addClass('changed');
	}
	
    }
}
