/* GradeBook.js

   Handles some minor dynamic functionality on the GradeBook page (i.e. Delete Modals). 
*/

$(document).ready(function(){

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

});