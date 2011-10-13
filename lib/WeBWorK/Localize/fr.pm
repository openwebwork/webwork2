## WeBWorK-tr  French language lexicon

## AUTHORS:
##
##   - Michael Gage (initial version)
##   - Stéphanie Lanthier, September 2011, Université du Québec à Montréal (UQAM)
##   - Sébastien Labbé, September 2011, Université du Québec à Montréal (UQAM)
##
## WARNING:
## 
##     For now, this is incomplete. It is a work in progress...
##
## AVERTISSEMENT:
## 
##     Ce fichier est incomplet. Le travail est en cours...
##

package WeBWorK::Localize::fr;

use base qw(WeBWorK::Localize);
use strict;
use vars qw(%Lexicon);

%Lexicon = (

# ## File locations
# "navPrevGrey" =>			"images_fr/navPrevGrey",
# "navPrev" =>				"images_fr/navPrev",
# "navProbListGrey" =>	    "images_fr/navProbListGrey",
# "navProbList" =>			"images_fr/navProbList",
# "navNextGrey" =>			"images_fr/navNextGrey",
# "navNext" =>				"images_fr/navNext",
# "navUp" =>				    "images_fr/navUp",

## File locations
"navPrevGrey" =>			"Précédent",
"navPrev" =>				"Précédent",
"navProbListGrey" =>	    "Liste de problèmes",
"navProbList" =>			"Liste de problèmes",
"navNextGrey" =>			"Suivant",
"navNext" =>				"Suivant",
"navUp" =>				    "Haut",


"The selected problem([_1]) is not a valid problem for set [_2]." =>
	"Le problème choisi([_1]) n'est pas valide pour le devoir [_2].", 

"Download Hardcopy for Selected [plural,_1,Set,Sets]" => 
	"Télécharger une copie de : [plural,_1,Set,Sets]",  

## Hardcopy Generator
"Hardcopy Generator" => 
	"Imprimer dans un fichier",  
"You may choose to show any of the following data. Correct answers and solutions are only available after the answer date of the homework set." =>
	"Options. Les bonnes réponses et les solutions ne sont disponibles qu'après la date de remise.", ## ozcan
"Show:" => "Afficher : ",
"Student answers" => "Réponses de l'étudiant",
"Correct answers" => "Bonnes réponses",
"Hints" => "Indices",
"Solutions" => "Solutions",
"Hardcopy Format:" => "Format :",
"Generate Hardcopy" => "Générer le fichier",

## Scoring Tools
"Include Index"                    => "Inclure l'index",
"Record Scores for Single Sets"    => "Ajouter les résultats de chaque devoir",
"Pad Fields"                       => "Remplir les champs",
"Score selected set(s) and save to:" => 
           "Sauvegarder les résultats sélectionnés sous",


"[_1]: Problem [_2]." =>		"[_1]: Problème [_2].", ## gage
"Next Problem" =>			    "Problème suivant",  ## gage
"Previous Problem" =>			"Problème précédent", ## gage
"Problem List" =>			    "Liste des problèmes", ## gage
"now open, due " =>			    "Disponible, date de remise : ", ## gage
"Set" =>				        "Devoirs", ## gage
"Score" =>				        "Résultat", ## gage
"Problems" =>				    "Problèmes", ## gage
"You can earn partial credit on this problem." =>
	"Vous pouvez obtenir une partie des points pour ce problème.", ## ozcan
"You have [negquant,_1,unlimited attempts,attempt,attempts] remaining." =>
	"Il reste [negquant,_1,un nombre illimité d'essais,essai,essais].", ## ozcan

## TRANSLATED BY SALIH
## Traduction : Stéphanie Lanthier

"over time: closed." =>			"Le temps est écoulé. Fin.",
"open: complete by [_1]" =>		"Disponible : date de remise : [_1]",
"will open on [_1]" =>			"sera disponible le [_1]",
"closed, answers on [_1]" =>		"échu, réponses disponibles le [_1]",
"closed, answers recently available" =>	"échu, réponses disponibles depuis peu",
"closed, answers available" =>		"échu, réponses disponbles",
"Viewing temporary file: " =>		"Visionnement du fichier temporaire : ",
"Course Info" =>			"Informations sur le cours",
"~[edit~]" =>				"~[modifier~]",    ## edited - ozcan
"Course Administration" =>		"Administration du cours",
"Feedback" =>				"Commentaires",
"Grades" =>				"Résultats",
"Instructor Tools" =>			"Outils pour l'enseignant",
"Classlist Editor" =>			"Liste d'étudiants",
"Hmwk Sets Editor" =>			"Éditeur de devoirs",
"Add Users" =>				"Ajouter des usagers",
"Course Configuration" =>		"Configuration du cours",
"Library Browser" =>			"Choisir des problèmes",
"Library Browser 2" =>			"Choisir des problèmes 2",
"File Manager" =>			"Gestionnaire de fichiers",
"Problem Editor" =>			"Éditeur de problèmes",
"Scoring Tools" =>			"Exporter les résultats",
"Scoring Download" =>			"Télécharger les résultats",
"Email" =>				"Courriel",
"Clear" =>				"Désélectionner",
"Email instructor" =>			"Envoyer un courriel à l'enseignant",
"Logout" => 				"Déconnexion",
"Password/Email" =>			"Mot de passe/courriel",
"Statistics" =>				"Statistiques",
"Student Progress" =>		        "Progrès des étudiants",
"Help" =>		                "Aide",

## Sets
"Sets" => "Devoirs",

## Display Options
"Display Options" => "Options d'affichage",
"View equations as" => "Afficher les équations à l'aide de",
"Apply Options" => "Appliquer",

## Set Info
"Set Info" => "Informations",
"WeBWorK Assignment [_1] is due : [_2]." => 
       "Date de remise du devoir [_1] : [_2]",

## E-mail Instructor
"E-mail Instructor" =>	"Envoyer un courriel à l'enseignant",
"From:" =>  "De :",
"Use this form to report to your professor a problem with the WeBWorK system or an error in a problem you are attempting. Along with your message, additional information about the state of the system will be included." => "Utiliser ce formulaire pour signaler à l'enseignant un problème avec le système WeBWorK ou une erreur dans un problème d'un devoir. Des informations additionnelles sur l'état du système utilisé accompagneront votre message.",
"E-mail:" =>  "Corps du message :",
"Send E-mail:" =>  "Envoyer",
"Cancel Email" =>  "Annuler",


## TRANSLATED by OZCAN
## Traduction : Stéphanie Lanthier

"Courses" =>		"Cours",
"Homework Sets" => 	"Devoirs",
"Problem [_1]" => 	"Problème [_1]",
"Library Browser" =>    "Choisir des problèmes",
"Report bugs" => 	"Signaler un bogue",

"Logged in as [_1]. " => "Connecté sous le nom [_1]",
"Log Out" => 		"Se déconnecter",
"Not logged in." => 	"Non connecté.",
"Acting as [_1]. " =>  	"Prendre le rôle de [_1].",
"Stop Acting" => 	"Cesser de jouer le rôle",

"Welcome to WeBWorK!" => "Bienvenue sur WeBWorK!",
"Messages" => 		"Messages",
"Entered" => 		"Saisi",
"Result" => 		"Résultat",
"Answer Preview" => 	"Aperçu des réponses",

"Correct" => 		"Correct",
"correct" => 		"correct",
"[_1]% correct" => 	"[_1]% correct",
"incorrect" => 		"erroné",
"Published" => 		"Publié",

"Unpublished" => 	"Non publié",
"Show Hints" => 	"Recourir à des indices",
"Show Solutions" => 	"Afficher les solutions",
"Preview Answers" => 	"Visualiser les réponses",
"Check Answers" => 	"Vérifier les réponses",

"Submit Answers" => 	"Soumettre ses réponses",
"Submit Answers for [_1]" => 
	"[_1] Soumettre ses réponses",
"times" => 		"reprises",
"time" => 		"reprise",
"unlimited" =>  	"illimité",

"attempts" =>  		"essais",
"attempt" => 		"essai",
"Name" => 		"Nom", ## edited - ozcan
"Attempts" => 		"Essais",
"Remaining" => 		"Nombre d'essais restants",

"Worth" => 		"Pondération",
"Status" => 		"Statut",
"Change Password" => 		"Changer le mot de passe",
"[_1]'s Current Password" => 	"Mot de passe actuel [_1]",
"[_1]'s New Password" => 	"Nouveau mot de passe [_1]",

"Change Email Address" => 	"Changer l'adresse courriel",
"[_1]'s Current Address" => 	"Courriel actuel [_1]",
"[_1]'s New Address" => 	"Nouveau courriel [_1]",
"Change User Options" => 	"Changer les options d'usager",
"Your score was recorded." => 	"Votre résultat a été enregistré",

"Show correct answers" => 	"Montrer les bonnes réponses",
"This homework set is closed." => "Ce devoir est échu.",
"Show Past Answers" => 		"Afficher les réponses précédentes",
"Log In Again" => 		"Se connecter à nouveau",


"The answer above is correct." => 
	"La réponse ci-dessus est correcte.",

"The answer above is NOT [_1]correct." => 
	"La réponse ci-dessus N'EST PAS [_1]correcte.",

"All of the answers above are correct." => 
	"Les réponses ci-dessus sont toutes correctes.",

"At least one of the answers above is NOT [_1]correct." => 
	"Au moins une des réponses ci-dessus N'EST PAS [_1]correcte.",

"[quant,_1,of the questions remains,of the questions remain] unanswered." => 
	"Certaines questions [_1] restent sans réponse.",

"This set is [_1] students." =>	
	"Ce devoir est [_1] pour les étudiants.",

"visible to" => 
	"visible",

"hidden from" => 
	"invisible",

"This problem will not count towards your grade." => 
	"Ce problème n'est pas noté.",

"The selected problem ([_1]) is not a valid problem for set [_2]." =>
	"Le problème choisi ([_1]), n'est pas valide pour l'ensemble [_2].",

"You do not have permission to view the details of this error." => 
	"Les droits qui vous sont assignés ne permettent pas de voir les détails de cette erreur.",

"Your score was not recorded because there was a failure in storing the problem record to the database." =>
	"Votre résultat n'a pas été enregistré à cause d'une défaillance dans le processus d'enregistrement dans la base de données.",

"Your score was not recorded because this homework set is closed." =>
	"Votre résultat n'a pas été enregistré car la date de remise est passée.",

"Your score was not recorded because this problem has not been assigned to you." =>
	"Votre résultat n'a pas été enregistré car ce problème ne vous a pas été assigné.",

"Viewing temporary file: " => 	
	"Visionnement du fichier temporaire : ",

"ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED" => 
	"Les réponses ont été vérifiées -- MAIS LES RÉPONSES N'ONT PAS ÉTÉ ENREGISTRÉES",

"PREVIEW ONLY -- ANSWERS NOT RECORDED" => 
	"Afficher seulement  --  NE PAS ENREGISTRER LES RÉPONSES",

"submit button clicked" =>
 	"On a appuyé sur le bouton Soumission",

"This homework set is not yet open." => 
	"Ce devoir n'est pas encore disponible.",

"This set is visible to students." => 
	"Les étudiants voient ce devoir.",

"(This problem will not count towards your grade.)" => 
	"(Ce problème ne sera pas noté.)",

"You have attempted this problem [quant,_1,time,times]." => 
	"Vous avez essayé ce problème à [quant,_1,reprise,reprises].",

"You received a score of [_1] for this attempt." => 
	"Résultat pour cette tentative : [_1].",

"Your overall recorded score is [_1].  [_2]" => 
	"Le résultat final est : [_1].  [_2]",

"You have [_1] [_2] remaining." => 
	"Il reste [_1] [_2].",

"Download a hardcopy of this homework set." => 
	"Télécharger une copie de ce devoir." ,

"Download PDF or TeX Hardcopy for Current Set" => 
	"Télécharger une copie PDF ou TeX de ce devoir.",

"Download PDF or TeX Hardcopy for Selected Sets" => 
	"Télécharger une copie PDF ou TeX des devoirs sélectionnés.",

"This homework set contains no problems." => 
	"Ce devoir ne contient aucun problème.",

"Can't get password record for user '[_1]': [_2]" => 
	"Can't get password record for user '[_1]': [_2]",

"Can't get password record for effective user '[_1]': [_2]" => 
	"Can't get password record for effective user '[_1]': [_2]",

"Couldn't change [_1]'s password: [_2]" => 
	"Il n'a pas été possible de modifier le mot de passei : [_2] de l'usager : [_1]",

"[_1]'s password has been changed." => 
	"Le mot de passe de l'usager [_1] a été modifié.",

"The passwords you entered in the [_1] and [_2] fields don't match. Please retype your new password and try again." =>
   "Les mots de passe saisis dans les champs [_1] et [_2] sont différents. Veuiller essayer à nouveau",

"Confirm [_1]'s New Password" => 
	"Confirmer le nouveau mot de passe [_1]",

"[_1]'s new password cannot be blank." => 
	"Le nouveau mot de passe ne peut rester vide. [_1]",

"The password you entered in the [_1] field does not match your current password. 
Please retype your current password and try again." => 
	"Le mot de passe que vous avez entré dans la case [_1] est erroné. Veuillez le corriger et essayer de nouveau.",

"You do not have permission to change your password." => 
	"Vos droits ne vous permettent pas de modifier votre mot de passe.",

"Couldn't change your email address: [_1]" => 
	"Il n'a pas été possible de modifier votre courriel : [_1]", 

"Your email address has been changed." => 
	"Votre courriel a été modifié.",

"You do not have permission to change email addresses." => 
	"Vos droits ne vous permettent pas de modifier votre courriel.",

"You have been logged out of WeBWorK." => 
	"Vous êtes déconnecté de WeBWorK.", 

"Invalid user ID or password." =>
	"Code d'usager ou mot de passe invalides",

"You must specify a user ID." =>
	"Spécifier le code d'usager.",

"Your session has timed out due to inactivity. Please log in again." => 
	"Cette session est échue. Veuillez vous reconnecter",

"_REQUEST_ERROR" => q{
 WebWork bu problemi işlerken bir yazılım hatası ile karşılaştı. Problemin kendisinde bir hata olması muhtemeldir. Eğer bir öğrenci iseniz bu hatayı ilgili kişilere bildiriniz. Eğer yetkili bir kişiyseniz daha fazla bilgi için alttaki hata raporunu inceleyiniz.
},
);
1;

