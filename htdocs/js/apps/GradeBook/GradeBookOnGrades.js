/* GradeBookOnGrades.js

   Handles some minor UI on the Grades page.  Surface course grade information on student Grades page.

*/


$(document).ready(function(){

//Gradebook Config (includes grading formula)
	var gc = JSON.parse($('#gradebook-config').text());

	function calculateCourseAverage($assignmentCells){
		var courseGrade = 0,
			controlGrade = 0;			
		$.each(gc, function(key, val){
			var filteredScores = $.map($assignmentCells.filter("."+key), function(value, index){
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
		});

		return 100 * courseGrade/controlGrade;
	}

//Grading Utility
	function appendCourseAverage($myTable){
		var $assignmentCells = $myTable.find('.grade-cell'),			
			courseAverage = calculateCourseAverage($assignmentCells);

			$myTable.append('<tr><td>Course Average</td><td id="course-average">'+courseAverage+'%</td></tr>');				
	}

	appendCourseAverage($('#grades_table'));

});