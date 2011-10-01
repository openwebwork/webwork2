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
);
1;

