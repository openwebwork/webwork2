## WeBWorK-es  Spanish language lexicon

package WeBWorK::Localize::es;

use base qw(WeBWorK::Localize);
use strict;
use vars qw(%Lexicon);

%Lexicon = (

## File locations
"navPrevGrey" =>			"images_es/navPrevGrey",
"navPrev" =>				"images_es/navPrev",
"navProbListGrey" =>	    "images_es/navProbListGrey",
"navProbList" =>			"images_es/navProbList",
"navNextGrey" =>			"images_es/navNextGrey",
"navNext" =>				"images_es/navNext",
"navUp" =>				    "images_es/navUp",

"The selected problem([_1]) is not a valid problem for set [_2]." =>
	"El problema seleccionado ([_1]) no es válido para el conjunto de problemas ([_2]). ", 

"Download Hardcopy for Selected [plural,_1,Set,Sets]" => "Baja la copia escrita de: [plural,_1,Set,Sets] ", 



"[_1]: Problem [_2]." =>		"[_1]: Problema [_2].",

"Next Problem" =>			    "Problema siguiente",

"Previous Problem" =>			"Problema anterior",

"Problem List" =>			    "Lista de problemas",

"now open, due " =>			    "Abierta, se entrega",

"Set" =>				        "Tarea",

"Score" =>				        "Calificación",

"Problems" =>				    "Problemas",

"You can earn partial credit on this problem." => "En este problema puedes obtener crédito parcial.",

"You have [negquant,_1,unlimited attempts,attempt,attempts] remaining." => "Te quedan [negquant,_1,unlimited attempts,attempt,attempts].",

"over time: closed." =>			"Tiempo terminado: cerrada.",

"open: complete by [_1]" =>		"Abierta: completa por [_1]",

"will open on [_1]" =>			"Abrirá el [_1]",

"closed, answers on [_1]" =>    "Cerrada, respuestas el [_1]",

"closed, answers recently available" =>	"Cerrada, respuestas recientemente disponibles",

"closed, answers available" =>		"Cerrada, respuestas disponibles",

"Viewing temporary file: " =>		"Viendo archivo temporal",

"Course Info" =>			"Información del curso",

"~[edit~]" =>				"~[editar~]",

"Course Administration" =>		"Administración del curso",

"Feedback" =>				"Retroalimentación",

"Grades" =>				"Notas",

"Instructor Tools" =>			"Herramientas del instructor",

"Classlist Editor" =>			"Editor de la lista de clases",

"Hmwk Sets Editor" =>			"Editor de tareas",

"Add Users" =>				"Agregar usuarios",

"Course Configuration" =>		"Configuración del curso",

"Library Browser" =>			"Explorador de bibliotecas",

"File Manager" =>			"Administrador de archivos",

"Problem Editor" =>			"Editor de problemas",

"Scoring Tools" =>			"Herramientas para evaluar",

"Scoring Download" =>			"Bajar Calificaciones",

"Email" =>				"E-mail",

"Email instructor" =>			"E-mail del profesor",

"Logout" => 				"Salir",

"Password/Email" =>			"Contraseña/Email",

"Statistics" =>				"Estadísticas",

"Courses" =>		"Cursos",

"Homework Sets" => 	"Tareas",

"Problem [_1]" => 	"Problema [_1]",

"Library Browser" => 	"Explorador de bibliotecas",

"Report bugs" => 	"Reportar problemas (bugs)",

"Logged in as [_1]. " => "Autentificado como: [_1]",

"Log Out" => 		"Salir",

"Not logged in." => 	"No ha iniciado sesión",

"Acting as [_1]. " =>  	"Actuando como [_1]",

"Stop Acting" => 	"Volver al usuario original",

"Welcome to WeBWorK!" => "Bienvenido a WeBWork!",

"Messages" => 		"Mensajes",

"Entered" => 		"Enviado",

"Result" => 		"Resultado",

"Answer Preview" => 	"Previsualizar respuesta",

"Correct" => 		"Correcto",

"correct" => 		"correcto",

"[_1]% correct" => 	"[_1]% correcto",

"incorrect" => 		"incorrecto",

"Published" => 		"Publicado",

"Unpublished "	=>	"No publicado",

"Show Hints "	=>	"Mostrar ayuda",

"Show Solutions "	=>	"Mostrar soluciones",

"Preview Answers "	=>	"Previsualizar respuestas",

"Check Answers "	=>	"Checar respuestas",

"Submit Answers "	=>	"Enviar respuestas",

"Submit Answers for [_1] "	=>	"Enviar respuestas por [_1]",

"times "	=>	"tiempos",

"time "	=>	"tiempo",

"unlimited "	=>	"ilimitado",

"attempts "	=>	"intentos",

"attempt "	=>	"intento",

"Name "	=>	" ## edited - ozcanNombre",

"Attempts "	=>	"Intentos",

"Remaining "	=>	"Quedan",

"Worth "	=>	"Valor",

"Status "	=>	"Estatus",

"Change Password "	=>	"Cambio de contraseña",

"[_1]'s Current Password "	=>	"Contraseña actual",

"[_1]'s New Password "	=>	"Nueva Contraseña",

"Change Email Address "	=>	"Cambio de e-mail",

"[_1]'s Current Address "	=>	" [_1]'s E-mail actual",

"[_1]'s New Address "	=>	"[_1]'s nuevo correo",

"Change User Options "	=>	"Cambio de opciones de usuario",

"Your score was recorded. "	=>	"Tu evaluación ha sido registrada.",

"Show correct answers "	=>	"Mostrar las respuestas correctas",

"This homework set is closed. "	=>	"Esta tarea está cerrada",

"Show Past Answers "	=>	"Mostrar la respuesta anterior",

"Log In Again "	=>	"Volver a iniciar sesión",

"The answer above is correct. "	=>	"La respuesta arriba es correcta",

"The answer above is NOT [_1]correct. "	=>	"La respuesta arriba no es [_1] correcta",

"All of the answers above are correct. "	=>	"Todas las respuestas son correctas",

"At least one of the answers above is NOT [_1]correct. "	=>	"Al menos una de las respuestas no es [_1] correcta",

"[quant,_1,of the questions remains,of the questions remain] unanswered. "	=>	"[quant,_1,de las preguntas permanecen,  pregunta permanece ] sin contestar.",

"This set is [_1] students. "	=>	"Este conjunto es de [_1] estudiantes",

"visible to "	=>	"visible para",

"hidden from "	=>	"oculta para",

"This problem will not count towards your grade. "	=>	"Este problema no cuenta para la evaluación.",

"The selected problem ([_1]) is not a valid problem for set [_2]. "	=>	"El problema seleccionado ([_1]) no es un problema válido para el conjunto [_2].",

"You do not have permission to view the details of this error. "	=>	"Usted no tiene permiso para ver los detalles de este error.",

"Your score was not recorded because there was a failure in storing the problem record to the database. "	=>	"Tu evaluación no fue registrada porque hubo una falla al almacenar la información en la base de datos.",

"Your score was not recorded because this homework set is closed. "	=>	"Tu evaluación no fue registrada porque esta tarea está cerrada.",

"Your score was not recorded because this problem has not been assigned to you. "	=>	"Tu calificación no fue registrada porque este problema no te fue asignado.",

"Viewing temporary file:  "	=>	"Viendo el archivo temporal",

"ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED "	=>	"RESPUESTAS SOLO VERIFICADAS--RESPUESTAS NO GUARDADAS",

"PREVIEW ONLY -- ANSWERS NOT RECORDED "	=>	"SOLAMENTE PREVISUALIZACIÓN -- RESPUESTAS NO GUARDADAS",

"submit button clicked "	=>	"Botón enviar pulsado.",

"This homework set is not yet open. "	=>	"Esta tarea aun no está abierta.",

"(This problem will not count towards your grade.) "	=>	"(Este problema no cuenta para tu evaluación).",

"You have attempted this problem [quant,_1,time,times]. "	=>	"Tu has intentado este problema [quant,_1,vez,veces].",

"You received a score of [_1] for this attempt. "	=>	"Tu has recibido una evaluación de [_1] por este intento.",

"Your overall recorded score is [_1].  [_2] "	=>	"Tu calificación total es de [_1].  [_2].",

"You have [_1] [_2] remaining. "	=>	" Te quedan [_1] [_2] intentos",

"Download a hardcopy of this homework set. "	=>	"Obtén una copia escrita de esta tarea.",

"This homework set contains no problems. "	=>	"Esta tarea no contiene problemas.",

"Can't get password record for user '[_1]': [_2] "	=>	"No se puede obtener la contraseña para el usuario '[_1]': [_2]",

"Can't get password record for effective user '[_1]': [_2] "	=>	"No se puede obtener la contraseña para el usuario efectivo '[_1]': [_2]",

"Couldn't change [_1]'s password: [_2] "	=>	"No se puede cambiar la contraseña [_2] de [_1].",

"[_1]'s password has been changed. "	=>	"La contraseña de [_1] ha sido cambiada.",

"The passwords you entered in the [_1] and [_2] fields don't match. Please retype your new password and try again. "	=>	"La contraseña introducida en [_1] y el campo [_2] no coinciden. Por favor introduzca nuevamente su contraseña. ",

"Confirm [_1]'s New Password "	=>	"Confirme su nueva contraseña.",

"[_1]'s new password cannot be blank. "	=>	"[_1] nueva contraseña no puede dejarse en blanco.",


"The password you entered in the [_1] field does not match your current password. 
Please retype your current password and try again." => 
	"La contraseña introducida en el campo [_1] no corresponde a su contraseña actual. 
	Por favor reescriba su contraseña actual e intente de nuevo.",

"You do not have permission to change your password." => 
	"Usted no tiene permiso para cambar su contraseña.",

"Couldn't change your email address: [_1]" => 
	"No se pudo cambiar su dirección de correo.",

"Your email address has been changed." => 
	"Su dirección de correo ha sido cambiada.",

"You do not have permission to change email addresses." => 
	"Usted no tiene permiso para cambiar su dirección de correo.",

"You have been logged out of WeBWorK." => "Has salido de WeBWork",

"Invalid user ID or password." => "Usuario o contraseña inválidos.",

"You must specify a user ID." => "Debe especificar un ID de usuario.",
"Your session has timed out due to inactivity. Please log in again." => 
	"Tu sesión ha terminado debido a inactividad. Por favor reinicia sesión.",

"_REQUEST_ERROR" => q{
  WebWork ha detectado un error de software al intentar procesar este problema. Es probable que hay un error en el problema mismo. Si usted es un estudiante, el informe de este mensaje de error al profesor para que sea subsanado. Si usted es un profesor, por favor consulte la salida de error para obtener más información.
},

"_LOGIN_MESSAGE" => q{
Eğer [_1] seçeneğini işaretlerseniz, giriş bilgileriniz kullandığınız tarayıcı tarafından hatırlanacak ve sonraki girişlerinizde kullanıcı adı ve şifre girmeden WebWork sayfalarını kullanabileceksiniz. Bu özellik, ortak kullanıma açık bilgisayarlar, güvenli olmayan bilgisayarlar, ve doğrudan kontrole sahip olmadığınız bilgisayarlarda kullanmak için güvenli değildir.
},

# Login.pm

"WeBWorK" => "WeBWorK",
"webwork" => "webwork",

"Continue" => "tr: Continue",

"_GUEST_LOGIN_MESSAGE" => q{tr: This course supports guest logins. Click [_1] to log into this course as a guest.},

"_EXTERNAL_AUTH_MESSAGE" => q{[_1] uses an external authentication system.  You've authenticated through that system, but aren't allowed to log in to this course.},

"Guest Login" => "tr: Guest Login",

"Page generated at [_1]" => "tr: Page generated at [_1]",

"The WeBWorK Project" => "tr: The WeBWorK Project",

"Test Score" => "tr: Test Score",

"Test Date" => "tr: Test Date",

"[_1] (test [_2])" => "tr: [_1] (test [_2])",

"Take [_1] test" => "tr: Take [_1] test",

"[_1] test" => "tr: [_1] test",

"Closed" => "tr: Closed",

"Reduced Credit Starts: [_1]" => "tr: Reduced Credit Starts: [_1]",

# ProblemSets.pm

"Resources" => "tr: Resources",

"Clear" => "tr: Clear",

"Download PDF or TeX Hardcopy for Selected Sets" => "tr: Download PDF or TeX Hardcopy for Selected Sets",

#ProblemSet.pm

"Download PDF or TeX Hardcopy for Current Set" => "tr: Download PDF or TeX Hardcopy for Current Set",

"The selected problem set ([_1]) is not a valid set for [_2]" => "tr: The selected problem set ([_1]) is not a valid set for [_2]",

"Set Info" => "tr: Set Info",

"visible to students" => "tr: visible to students",

"hidden from students" => "tr: hidden from students",

"This set is [_1]" => "tr: This set is [_1]",

"Sets" => "tr: Sets",

"Apply Options" => "tr: Apply Options",

"Display Options" => "tr: Display Options",

"_REDUCED_CREDIT_MESSAGE_1" => "tr: This assignment has a Reduced Credit Period that begins [_1] and ends on the due date, [_2].  During this period all additional work done counts [_3]\% of the original.",

"_REDUCED_CREDIT_MESSAGE_2" => "tr: This assignment had a Reduced Credit Period that began [_1] and ended on the due date, [_2].  During that period all additional work done counted [_3]\% of the original.",

"Viewing temporary file" => "tr: Viewing temporary file",

# UserList.pm

"Result of last action performed: [_1]" => "tr: Result of last action performed: [_1]",

"You are not authorized to access the instructor tools." => "tr: You are not authorized to access the instructor tools.",

"You are not authorized to modify student data." => "tr: You are not authorized to modify student data.",

"You are not authorized to perform this action." => "tr: You are not authorized to perform this action.",

"Show/Hide Site Description" => "tr: Show/Hide Site Description",

"_CLASSLIST_EDITOR_DESCRIPTION" => "tr: This is the classlist editor page, where you can view and edit the records of all the students currently enrolled in this course.  The top of the page contains forms which allow you to filter which students to view, sort your students in a chosen order, edit student records, give new passwords to students, import/export student records from/to external files, or add/delete students.  To use, please select the action you would like to perform, enter in the relevant information in the fields below, and hit the \"Take Action!\" button at the bottom of the form.  The bottom of the page contains a table containing the student usernames and their information.",

"Select an action to perform" => "tr: Select an action to perform",

"Login Name" => "tr: Login Name", 
"First Name" => "tr: First Name", 
"Last Name" => "tr: Last Name", 
"Email Address" => "tr: Email Address", 
"Student ID" => "tr: Student ID", 
"Enrollment Status" => "tr: Enrollment Status",
"Section" => "tr: Section", 
"Recitation" => "tr: Recitation", 
"Comment" => "tr: Comment", 
"Permission Level" => "tr: Permission Level",

"Filter" => "tr: Filter",
"Sort" => "tr: Sort",
"Edit" => "tr: Edit",
"Import" => "tr: Import",
"Export" => "tr: Export",
"Add" => "tr: Add",
"Delete" => "tr: Delete",
"Cancel Edit" => "tr: Cancel Edit",
"Save Edit" => "tr: Save Edit",
"Cancel Password" => "tr: Cancel Password",
"Save Password" => "tr: Save Password",

"Select all users" => "tr: Select all users",

"Unselect all users" => "tr: Unselect all users",

"Take Action!" => "tr: Take Action!",

"Showing [_1] out of [_2] users" => "tr: Showing [_1] out of [_2] users",

"If a password field is left blank, the student's current password will be maintained." => "tr: If a password field is left blank, the student's current password will be maintained.",

"Click on the login name to edit individual problem set data, ~(e.g. due dates~) for these students." => "tr: Click on the login name to edit individual problem set data, (e.g. due dates) for these students.",

"Show Which Users?" => "tr: Show Which Users?",
"all users" => "tr: all users",
"no users" => "tr: no users",
"selected users" => "tr: selected users",
"users who match on selected field" => "tr: users who match on selected field",
"What field should filtered users match on?" => "tr: What field should filtered users match on?",
"Filter by what text?" => "tr: Filter by what text?",
"showing all users" => "tr: showing all users",
"showing no users" => "tr: showing no users",
"showing selected users" => "tr: showing selected users",
"showing matching users" => "tr: showing matching users",

"Sort by" => "tr: Sort by",
"Then by" => "tr: Then by",
"Users sorted by [_1], then by [_2], then by [_3]" => "tr: Users sorted by [_1], then by [_2], then by [_3]",

"Edit Which Users?" => "tr: Edit Which Users?",
"visible users" => "tr: visible users",
"editing all users" => "tr: editing all users",
"editing visible users" => "tr: editing visible users",
"editing selected users" => "tr: editing selected users",

"Give new password to which users?" => "tr: Give new password to which users?",
"giving new passwords to all users" => "tr: giving new passwords to all users",
"giving new passwords to visible users" => "tr: giving new passwords to visible users",
"giving new passwords to selected users" => "tr: giving new passwords to selected users",

"Warning: Deletion destroys all user-related data and is not undoable!" => "tr: Warning: Deletion destroys all user-related data and is not undoable!",
"Delete how many?" => "tr: Delete how many?",
"You cannot delete yourself!" => "tr: You cannot delete yourself!",
"deleted [_1] users" => "tr: deleted [_1] users",

"Add how many students?" => "tr: Add how many students?",

"Import users from what file?" => "tr: Import users from what file?",
"Replace which users?" => "tr: Replace which users?",
"Add which new users?" => "tr: Add which new users?",
"any users" => "tr: any users",
"[_1] users replaced, [_2] users added, [_3] users skipped. Skipped Users: ([_4])" => "tr: [_1] users replaced, [_2] users added, [_3] users skipped.  Skipped users: ([_4])",

"Export which users?" => "tr: Export which users?",
"Export to what kind of file?" => "tr: Export to what kind of file?",
"Filename" => "tr: Filename",
"Enter filename below" => "tr: Enter filename below",
"[_1] users exported to file [_2]/[_3]" => "tr: [_1] users exported to file [_2]/[_3]",

"Abandon changes" => "tr: Abandon changes",
"changes abandoned" => "tr: changes abandoned",

"Save changes" => "tr: Save changes",
"changes saved" => "tr: changes saved",

"Active" => "tr: Active",
"Inactive" => "tr: Inactive",
"You may not change your own password here!" => "tr: You may not change your own password here!",
"New Password" => "tr: New Password",
"New passwords saved" => "tr: New passwords saved",

"Users List" => "tr: Users List",
"No students shown.  Choose one of the options above to list the students in the course." => "tr: No students shown.  Choose one of the options above to list the students in the course.",

"Enrolled" => "tr: Enrolled",
"Audit" => "tr: Enrolled",
"Proctor" => "tr: Proctor",
"Drop" => "tr: Drop",

"New Password" => "tr: New Password",

"No students shown.  Choose one of the options above to list the students in the course." => "tr: No students shown.  Choose one of the options above to list the students in the course.",

# ProblemSetList.pm

"No sets selected for scoring" => "tr: No sets selected for scoring",

"You are not authorized to modify homework sets." => "tr: You are not authorized to modify homework sets.",

"You are not authorized to modify set definition files." => "tr: You are not authorized to modify set definition files.",

"Results of last action performed" => "tr: Results of last action performed",

"Please select action to be performed." => "tr: Please select action to be performed.",

"_HMWKSETS_EDITOR_DESCRIPTION" => "tr: This is the homework sets editor page where you can view and edit the homework sets that exist in this course and the problems that they contain. The top of the page contains forms which allow you to filter which sets to display in the table, sort the sets in a chosen order, edit homework sets, publish homework sets, import/export sets from/to an external file, score sets, or create/delete sets.  To use, please select the action you would like to perform, enter in the relevant information in the fields below, and hit the \"Take Action!\" button at the bottom of the form.  The bottom of the page contains a table displaying the sets and several pieces of relevant information.",

"Any changes made below will be reflected in the set for ALL students." => "tr: Any changes made below will be reflected in the set for ALL students.",

"Publish" => "tr: Publish",
"Create" => "tr: Create",

"Select all sets" => "tr: Select all sets",
"Unselect all sets" => "tr: Unselect all sets",

"Showing [_1] out of [_2] sets." => "tr: Showing [_1] out of [_2] sets.",

"Show which sets?" => "tr: Show which sets?",
"Match on what? (separate multiple IDs with commas)" => "tr: Match on what? (separate multiple IDs with commas)",
"Sort by [_1] and then by [_2]" => "tr: Sort by [_1] and then by [_2]",

"all sets" => "tr: all sets",
"no sets" => "tr: no sets",
"selected sets" => "tr: selected sets",
"visible sets" => "tr: visible sets",
"hidden sets" => "tr: hidden sets",
"enter matching set IDs below" => "tr: enter matching set IDs below",
"showing all sets" => "tr: showing all sets",
"showing no sets" => "tr: showing no sets",
"showing selected sets" => "tr: showing selected sets",

"Set Name" => "tr: Set Name",
"Set Header" => "tr: Set Header",
"Hardcopy Header" => "tr: Hardcopy Header",
"Open Date" => "tr: Open Date",
"Due Date" => "tr: Due Date",
"Answer Date" => "tr: Answer Date",
"Visibility" => "tr: Visibility",

"Edit which sets?" => "tr: Edit which sets?",
"editing all sets" => "tr: editing all sets",
"editing visible sets" => "tr: editing visible sets",
"editing selected sets" => "tr: editing selected sets",

"Choose which sets to be affected" => "tr: Choose which sets to be affected",
"Choose visibility of the sets to be affected" => "tr: Choose visibility of the sets to be affected",
"Hidden" => "tr: Hidden",
"Visible" => "tr: Visible",
"Hidden" => "tr: Hidden",
"Visible" => "tr: Visible",
"No change made to any set" => "tr: No change made to any set",
"All sets [_1] all students" => "tr: All sets [_1] all students",
"All visible sets [_1] all students" => "tr: All visible sets [_1] all students",
"All selected sets [_1] all students" => "tr: All selected sets [_1] all students",

"deleted [_1] sets" => "tr: deleted [_1] sets",

"Enable/Disable reduced scoring for selected sets" => "tr: Enable/Disable reduced scoring for selected sets",
"Disable" => "tr: Disable",
"Enable" => "tr: Enable",
"Reduced Credit [_1] for all sets" => "tr: Reduced Credit [_1] for all sets",
"Reduced Credit [_1] for visable sets" => "tr: Reduced Credit [_1] for visable sets",
"Reduced Credit [_1] for selected sets" => "tr: Reduced Credit [_1] for selected sets",

"Score which sets?" => "tr: Score which sets?",

"Name the new set" => "tr: Name the new set",
"Create as what type of set?" => "tr: Create as what type of set?",
"a new empty set" => "tr: a new empty set",
"a duplicate of the first selected set" => "tr: a duplicate of the first selected set",

"Import how many sets?" => "tr: Import how many sets?",
"a single set" => "tr: a single set",
"multiple sets" => "tr: multiple sets",
"Import from where?" => "tr: Import from where?",
"Enter filenames below" => "tr: Enter filenames below",
"Import sets with names" => "tr: Import sets with names",
"Assign this set to which users?" => "tr: Assign this set to which users?",

"Failed to create new set: no set name specified!" => "tr: Failed to create new set: no set name specified!",
"Set [_1] exists.  No set created" => "tr: Set [_1] exists.  No set created",
"Failed to duplicate set: no set selected for duplication!" => "tr: Failed to duplicate set: no set selected for duplication!",

"Export which sets?" => "tr: Export which sets?",
"exporting all sets" => "tr: exporting all sets",
"exporting visible sets" => "tr: exporting visible sets",
"exporting selected sets" => "tr: exporting selected sets",

"Abandon export" => "tr: Abandon export",
"export abandoned" => "tr: export abandoned",

"Export selected sets" => "tr: Export selected sets",
"[_1] sets exported, [_2] sets skipped. Skipped sets: ([_3])" => "tr: [_1] sets exported, [_2] sets skipped. Skipped sets: ([_3])",

"Duplicate this set and name it" => "tr: Duplicate this set and name it",
"Duplicate" => "tr: Duplicate",
"Failed to duplicate set: no set selected for duplication!" => "tr: Failed to duplicate set: no set selected for duplication!",
"Failed to duplicate set: no set name specified!" => "tr: Failed to duplicate set: no set name specified!",
"Failed to duplicate set: set [_1] already exists!" => "tr: Failed to duplicate set: set [_1] already exists!",
"Failed to duplicate set: [_1]" => "tr: Failed to duplicate set: [_1]",
"Success" => "tr: Success",

"Cancel Export" => "tr: Cancel Export",
"Save Export" => "tr: Save Export",

"Set List" => "tr: Set List",

"No sets shown.  Choose one of the options above to list the sets in the course." => "tr: No sets shown.  Choose one of the options above to list the sets in the course.",

"Edit Set Data" => "tr: Edit Set Data",
"Edit Problems" => "tr: Edit Problems",
"Edit Assigned Users" => "tr: Edit Assigned Users",
"Reduced Credit Enabled" => "tr: Reduced Credit Enabled",
"Reduced Credit Disabled" => "tr: Reduced Credit Disabled",
"Open Date" => "tr: Open Date",
"Due Date" => "tr: Due Date",
"Answer Date" => "tr: Answer Date",
"Edit All Set Data" => "tr: Edit All Set Data",
"Enable Reduced Credit" => "tr: Enable Reduced Credit",
"Use System Default" => "tr: Use System Default",

"Yes" => "tr: Yes",
"No" => "tr: No",

# Problem.pm

"completely" => "tr: completely",

"This set is [_1]" => "tr: This set is [_1]",

"Note" => "tr: Note",

"Edit this problem" => "tr: Edit this problem",

"Checking additional error messages" => "tr: Checking additional error messages",

# PGProblemEditor.pm

"Changes in this file have not yet been permanently saved." => "tr: Changes in this file have not yet been permanently saved.",

"The file '[_1]' cannot be found." => "tr: The file '[_1]' cannot be found.",

"The file '[_1]' is protected!" => "tr: The file '[_1]' is protected!",

"To edit this text you must first make a copy of this file using the 'Save as' action below." => "tr: To edit this text you must first make a copy of this file using the 'Save as' action below.",

"The file '[_1]' is a blank problem!" => "tr: The file '[_1]' is a blank problem!",

"To edit this text you must use the 'Save AS' action below to save it to another file." => "tr: To edit this text you must use the 'Save AS' action below to save it to another file.",

"Set Header for set [_1]" => "tr: Set Header for set [_1]",
"Hardcopy Header for set [_1]" => "tr: Hardcopy Header for set [_1]",
"Course Information for course [_1]" => "tr: Course Information for course [_1]",
"Options Information" => "tr: Options Information",

"You are not authorized to modify problems." => "tr: You are not authorized to modify problems.",

"Problem Techniques" => "tr: Problem Techniques",
"Snippets of PG code illustrating specific techniques" => "tr: Snippets of PG code illustrating specific techniques",

"Math Objects" => "tr: Math Objects",
"Wiki summary page for MathObjects" => "tr: Wiki summary page for MathObjects",

"Documentation from source code for PG modules and macro files. Often the most up-to-date information." => "tr: Documentation from source code for PG modules and macro files. Often the most up-to-date information.",

"Test snippets of PG code in interactive lab.  Good way to learn PG language." => "tr: Test snippets of PG code in interactive lab.  Good way to learn PG language.",

"PG mark down syntax used to format WeBWorK questions. This interactive lab can help you to learn the techniques." => "tr: PG mark down syntax used to format WeBWorK questions. This interactive lab can help you to learn the techniques.",

"Author Info" => "tr: Author Info",
"Top level of author information on the wiki." => "tr: Top level of author information on the wiki.",

"report bugs in this problem" => "tr: report bugs in this problem",
"Report bugs in a WeBWorK question/problem using this link. The very first time you do this you will need to register with an email address so that information on the bug fix can be reported back to you." => "tr: Report bugs in a WeBWorK question/problem using this link. The very first time you do this you will need to register with an email address so that information on the bug fix can be reported back to you.",

"set [_1]/problem [_2]" => "tr: set [_1]/problem [_2]",
"blank problem" => "tr: blank problem",
"header file" => "tr: header file",
"hardcopy header file" => "tr: hardcopy header file",
"course information" => "tr: course information",
"options information" => "tr: options information",
"Unknown file type" => "tr: Unknown file type",
"unassigned problem file" => "tr: unassigned problem file",

"Editing [_1] in file '[_2]'" => "tr: Editing [_1] in file '[_2]'",
"Problem Source Code" => "tr: Problem Source Code",
"Select action below" => "tr: Select action below",

"View" => "tr: View",
"Save" => "tr: Save",
"Add problem" => "tr: Add problem",
"Save as" => "tr: Save as",
"Revert" => "tr: Revert",

"Show in another window" => "tr: Show in another window",

"Problem Viewer" => "tr: Problem Viewer",

"Note: this problem viewer is for viewing purposes only. As of right now, testing functionality is not possible." => "tr: Note: this problem viewer is for viewing purposes only. As of right now, testing functionality is not possible.",

"The path to the original file should be absolute" => "tr: The path to the original file should be absolute",

"Error: This path is already in the temporary edit directory -- no new temporary file is created. path = [_1]" => "tr: Error: This path is already in the temporary edit directory -- no new temporary file is created. path = [_1]",

"Can't determine user of temporary edit file [_1]." => "tr: Can't determine user of temporary edit file [_1].",

"This path |[_1]| is not the path to a temporary edit file." => "tr: This path |[_1]| is not the path to a temporary edit file.",

"This is a blank problem template file and can not be edited directly. Use the 'Save as' action below to create a local copy of the file and add it to the current problem set." => "tr: This is a blank problem template file and can not be edited directly. Use the 'Save as' action below to create a local copy of the file and add it to the current problem set.",

"the original path to the file is [_1]" => "tr: the original path to the file is [_1]",

"The file '[_1]' is a directory!" => "tr: The file '[_1]' is a directory!",

"no action" => "tr: no action",

"You must specify an file name in order to save a new file." => "tr: You must specify an file name in order to save a new file.",

"Write permissions have not been enabled in the templates directory.  No changes can be made." => "tr: Write permissions have not been enabled in the templates directory.  No changes can be made.",

"Write permissions have not been enabled in '[_1]'.  Changes must be saved to a different directory for viewing." => "tr: Write permissions have not been enabled in '[_1]'.  Changes must be saved to a different directory for viewing.",

"Write permissions have not been enabled for '[_1]'.  Changes must be saved to another file for viewing." => "tr: Write permissions have not been enabled for '[_1]'.  Changes must be saved to another file for viewing.",

"Unable to write to '[_1]': [_2]" => "tr: Unable to write to '[_1]': [_2]",

"Error copying [_1] to [_2]" => "tr: Error copying [_1] to [_2]",

"Copied auxiliary files from [_1] to  new location at [_2]" => "tr: Copied auxiliary files from [_1] to  new location at [_2]",

"Deleting temp file at [_1]" => "tr: Deleting temp file at [_1]",

"Saved to file '[_1]'" => "tr: Saved to file '[_1]'",

"View Using Seed Number" => "tr: View Using Seed Number",

"Display Mode" => "tr: Display Mode",

"Problem" => "tr: Problem",

"Add to which set?" => "tr: Add to which set?",
"Add as what filetype?" => "tr: Add as what filetype?",

"Added [_1] to [_2] as problem [_3]" => "tr: Added [_1] to [_2] as problem [_3]",
"Added '[_1]' to [_2] as new set header" => "tr: Added '[_1]' to [_2] as new set header",
"Unable to make '[_1]' the set header for [_2]" => "tr: Unable to make '[_1]' the set header for [_2]",

"Save [_1] and View" => "tr: Save [_1] and View",
"Replace [_1]" => "tr: Replace [_1]",
"Append to end of set [_1]" => "tr: Append to end of set [_1]",
"Save as new independent problem" => "tr: Save as new independent problem",
"Save As" => "tr: Save As [TMPL]/",

"Please specify a file to save to." => "tr: Please specify a file to save to.",
"File '[_1]' exists. File not saved. No changes have been made. You can change the file path for this problem manually from the 'Hmwk Sets Editor' page" => "
tr: File '[_1]' exists. File not saved. No changes have been made. You can change the file path for this problem manually from the 'Hmwk Sets Editor' page",

"The text box now contains the source of the original problem. You can recover lost edits by using the Back button on your browser." => "tr: The text box now contains the source of the original problem. You can recover lost edits by using the Back button on your browser.",

"The set header for set [_1] has been renamed to '[_2]'." => "tr: The set header for set [_1] has been renamed to '[_2]'.",
"Unable to change the set header for set [_1]. Unknown error." => "tr: Unable to change the set header for set [_1]. Unknown error.",

"The hardcopy header for set [_1] has been renamed to '[_2]'." => "tr: The hardcopy header for set [_1] has been renamed to '[_2]'.",
"Unable to change the hardcopy header for set [_1]. Unknown error." => "tr: Unable to change the hardcopy header for set [_1]. Unknown error.",

"The source file for 'set [_1] / problem [_2]' has been changed from [_3] to '[_4]'." => "tr: The source file for 'set [_1] / problem [_2]' has been changed from [_3] to '[_4]'.",
"Unable to change the source file path for set [_1], problem [_2]. Unknown error." => "tr: Unable to change the source file path for set [_1], problem [_2]. Unknown error.",

"Added [_1] to [_2] as problem [_3]" => "tr: Added [_1] to [_2] as problem [_3]",

"A new file has been created at '[_1]' with the contents below. No changes have been made to set [_2]." => "tr: A new file has been created at '[_1]' with the contents below. No changes have been made to set [_2].",

"Unrecognized saveMode: |[_1]|. Unknown error." => "tr: Unrecognized saveMode: |[_1]|. Unknown error.",

"Please use radio buttons to choose the method for saving this file. Can't recognize saveMode: |[_1]|." => "tr: Please use radio buttons to choose the method for saving this file. Can't recognize saveMode: |[_1]|.",

"Error: The original file [_1] cannot be read." => "tr: Error: The original file [_1] cannot be read.",
"Revert to [_1]" => "tr: Revert to [_1]",

"Deleting temp file at [_1]" => "tr: Deleting temp file at [_1]",
"Reverting to original file '[_1]'" => "tr: Reverting to original file '[_1]'",



);
1;

