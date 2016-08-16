/* GradeBook.js

   Handles some minor UI on the GradeBook page (i.e. Delete Modals, export to csv). 

*/


$(document).ready(function(){

//Gradebook Config (includes grading formula)
	var gc = JSON.parse($('#gradebook-config').text()),
        categoryAverages={};

	$( '.delete-student' ).on('click', function(e){
			e.preventDefault();
			var deleteUrl = e.currentTarget.href,
				studentName = $(e.currentTarget).parent().parent().parent().find('div').html()
			$('#confirm-delete-modal .modal-header').html('<h3>Delete Student</h3>');
			$('#confirm-delete-modal .modal-body').html('You are about to delete '+studentName+'.  Please confirm to permanently remove this student from the course.');			
			$('#confirm-delete-button').attr("href",deleteUrl);
			$('#confirm-delete-modal').modal();
	});

	$( '.delete-assignment' ).on('click', function(e){
			e.preventDefault();			
			var deleteUrl = e.currentTarget.href,
				setName = $(e.currentTarget).parent().parent().parent().find('div').html()
			$('#confirm-delete-modal .modal-header').html('<h3>Delete Assignment</h3>');
			$('#confirm-delete-modal .modal-body').html('You are about to delete '+setName+'.  Please confirm to permanently remove this assignment from the course.');
			$('#confirm-delete-button').attr("href",deleteUrl);
			$('#confirm-delete-modal').modal();
	});
//Grading Utility
	function calculateCourseGrades($myTable){
		var $headers = $myTable.find('tr:has(th)'),
			$rows = $myTable.find('tr:has(td)');
		$headers.append('<th><div>Course Grades</div></th>');		
		$.each( $rows ,function(index, value){
			var courseGrade = 0,
				controlGrade = 0,
				studentRecord = $(value);
			$.each(gc, function(key, val){
				var filteredScores = $.map($(studentRecord).find("."+key+":not(.hidden-from-students)"), function(value, index){
					return parseInt($(value).text());
				});
				
				if(filteredScores.length > 0 ){
					if(filteredScores.length > val.numberToDrop){
						filteredScores = filteredScores.sort(function(a, b){return a-b}).slice(val.numberToDrop,filteredScores.length);									
					} 
					filteredScores.sum = filteredScores.reduce(function(prevVal,curVal){
						return prevVal + curVal;
					});
					filteredScores.average = filteredScores.sum / filteredScores.length;
					controlGrade = controlGrade + 100 * val.categoryWeight;
				} else {
					filteredScores.sum = 0;
					filteredScores.average = 0;
				}

				courseGrade = courseGrade +	filteredScores.average * val.categoryWeight;		
                categoryAverages[key] = filteredScores.average * val.categoryWeight;                
			});

			$(studentRecord).append('<td><span class="course-grade">'+ (controlGrade > 0 ? ( courseGrade/controlGrade *100 ).toFixed(2) : 0 )+'%</span></td>');
		});
	}	

//CSV	

    function exportTableToCSV($myTable, filename) {
    	var $table = $myTable.clone(),
        	$headers = $table.find('tr:has(th)'),
            $rows = $table.find('tr:has(td)'),

            // Temporary delimiter characters unlikely to be typed by keyboard
            // This is to avoid accidentally splitting the actual contents
            tmpColDelim = String.fromCharCode(11), // vertical tab character
            tmpRowDelim = String.fromCharCode(0), // null character

            // actual delimiter characters for CSV format
            colDelim = '","',
            rowDelim = '"\r\n"';

            //Remove dropdown menus
			$.each($headers.find('th'),function(index, value){
			    var $value = $(value);
			    if(index == 0){
			       $value.html($value.text());
			    } else {
			       $value.html($value.find('.column-name').text());
			    }
			});
			$.each($rows, function(index, value){
			    var $value = $(value),
			        $rowName = $value.find('.row-name'),
			        $firstTd = $value.children().first();
			   console.log($firstTd);
			  $firstTd.html($rowName);
			});
            // Grab text from table into CSV formatted string
            var csv = '"';
            csv += formatRows($headers.map(grabRow));
            csv += rowDelim;
            csv += formatRows($rows.map(grabRow)) + '"';

            // Data URI
            var csvData = 'data:application/csv;charset=utf-8,' + encodeURIComponent(csv);

        // For IE (tested 10+)
        if (window.navigator.msSaveOrOpenBlob) {
            var blob = new Blob([decodeURIComponent(encodeURI(csv))], {
                type: "text/csv;charset=utf-8;"
            });
            navigator.msSaveBlob(blob, filename);
        } else {
            $(this)
                .attr({
                    'download': filename
                    ,'href': csvData
                    //,'target' : '_blank' //if you want it to open in a new window
            });
        }

        //------------------------------------------------------------
        // Helper Functions 
        //------------------------------------------------------------
        // Format the output so it has the appropriate delimiters
        function formatRows(rows){
            return rows.get().join(tmpRowDelim)
                .split(tmpRowDelim).join(rowDelim)
                .split(tmpColDelim).join(colDelim);
        }
        // Grab and format a row from the table
        function grabRow(i,row){
             
            var $row = $(row);
            //for some reason $cols = $row.find('td') || $row.find('th') won't work...
            var $cols = $row.find('td'); 
            if(!$cols.length) $cols = $row.find('th');  

            return $cols.map(grabCol)
                        .get().join(tmpColDelim);
        }
        // Grab and format a column from the table 
        function grabCol(j,col){
            var $col = $(col),
                $text = $col.text();

            return $text.replace('"', '""'); // escape double quotes

        }
    }

    function filterAssignents($myTable) {

    }


    // This must be a hyperlink
    $("#export").click(function (event) {
        // var outputFile = 'export'
        var outputFile = window.prompt("What do you want to name your output file (Note: This won't have any effect on Safari)") || 'export';
        outputFile = outputFile.replace('.csv','') + '.csv'
         
        // CSV
        exportTableToCSV.apply(this, [$('#gradebook'), outputFile]);
        
        // IF CSV, don't do event.preventDefault() or return false
        // We actually need this to be a typical hyperlink
    });

    // $("#filterAssignments").click(function( event ){
    //     filerAssignments($('#gradebook'));
    // });

    function appendFilterMenu($myMenu) {
        $myMenu.find('ul').append('<li class="dropdown-submenu"><a tabindex="-1" href="#">Filter</a><ul id="filter-assignments-submenu" class="dropdown-menu"></ul></li>');
        var $subMenu = $myMenu.find('#filter-assignments-submenu');
        $subMenu.append('<li class="showAll"><a href="#">Show all</a></li>');
        $.each(gc, function( key, value){
            $subMenu.append('<li class="'+key+'"><a href="#">'+key+'</a></li>');
        });
    }

    function filterAssignments( className ){ 
        if( className == "showAll"){       
            $('#gradebook td a.cell').parent().show();
            $('#gradebook th div').parent().show()
        } else {
            $('#gradebook td a:not(.'+className+')').parent().hide();            
            $('#gradebook th div.dropdown:not(.'+className+')').parent().hide()
            $('#gradebook td a.'+className).parent().show();            
            $('#gradebook th .'+ className).parent().show();     
        }
    }

    function appendCategoryAverages($myTable) {
        $.each(categoryAverages, function( key, value){
            $myTable.append('<tr><td>'+key+'</td><td>'+ value +'</td></tr>');
        });        
    }

    function styleCells($myTable) {
        $.each(gc, function(key, value){
            $('#gradebook td .' + key).parent().css('background', value.categoryColor);
        });
    }
    
    calculateCourseGrades($('#gradebook'));

    styleCells($('#gradebook'));

    appendFilterMenu($('#gradebook-menu'));    

    appendCategoryAverages($('#category_averages'));

    $('#gradebook-menu #filter-assignments-submenu li').on('click', function( event ){
        event.preventDefault();
        filterAssignments(event.currentTarget.className);
    });

});