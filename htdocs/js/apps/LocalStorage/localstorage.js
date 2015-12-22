var WWLocalStorage = function(givenContainer) {

    var container;

    if (givenContainer) {
	container = givenContainer;
    } else {
	container = $('#problemMainForm');
    }

    var identifier = $("input[name='problemIdentifierPrefix']").val()+
	$("input[name='sourceFilePath']").val()+
	$("input[name='problemSource']").val()+
	$("input[name='problemSeed']").val();

    var storedData = $.jStorage.get(identifier);

    if (!storedData) {
	storedData = {};
    }

    var storeData = function () {
	//event.preventDefault();

	if (!storedData['inputs']) {
	    storedData['inputs'] = {};
	}
	
	var inputs = $(container).find(":input")
	    .each(function(index,input) {
		if ($(input).attr('type').toUpperCase() == 'RADIO') {
		    var name = $(input).attr('name');
		    storedData['inputs'][name] = $('input[name="'+name'"]:checked').val();
		} else if (!/previous_/.test($(input).attr('name'))) {
		
		    storedData['inputs'][$(input).attr('name')] = $(input).val();
		}
	    });

	$.jStorage.set(identifier,storedData);
    }

    $(container).find(":submit").click(storeData);

    if (storedData) {
	if (storedData['inputs']) {
	    var keys = Object.keys(storedData['inputs']);
	    
	    keys.forEach(function(key) {
		my input = $(container).find('[name="'+key'"]');
		
		if (input.length > 0 &&
		    $(input).attr('type').toUpperCase() == 'RADIO') {
		 
		    $(input).each(function () {
			if ($(this).val() == storedData['inputs'][key]) {
			    $(this).attr('checked',true);
			}
   
		} else if (input.length > 0) {
		    $(input).val(storedData['inputs'][key]);
		}
	    });	    
	}
	
	if ($('#problem-result-score').length > 0) {
	    if (!storedData['score'] ||
		storedData['score'] < $('#problem-result-score').val()) {
		storedData['score'] = $('#problem-result-score').val();
		$.jStorage.set(identifier,storedData);
	    }
	}	    

	if (storedData['score']) {
	    $('#problem-overall-score').html(Math.round(storedData['score']*100)+'%');
	} else {
	    $('#problem-overall-score').html("0%");
	}

    }

}

    
