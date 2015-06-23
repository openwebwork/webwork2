var WWLocalStorage = function(givenContainer) {

    var container;

    if (givenContainer) {
	container = givenContainer;
    } else {
	container = $('#problemMainForm');
    }

    var identifier = $("input[name='sourceFilePath']").val()+
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
		if (!/previous_/.test($(input).attr('name'))) {
		
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
	    $(container).find('[name="'+key+'"]').val(storedData['inputs'][key]);
	    });	    
	}
    }

}

    