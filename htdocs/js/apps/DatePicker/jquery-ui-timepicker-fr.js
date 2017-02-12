/* French translation for the jQuery Timepicker Addon */
/* Written by Thomas Lété */
(function($) {
	$.datepicker.regional['fr'] = {
	closeText: 'Terminé',
	prevText: 'Précédent',
	nextText: 'Suivant',
	currentText: 'Aujourd\'hui',
	monthNames: ['Janvier','Février','Mars','Avril','Mai','Juin',
			'Juillet','Août','Septembre','Octobre','Novembre','Décembre'],
	monthNamesShort: ['JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUN', 'JUL', 'AOÛ', 'SEP', 'OCT', 'NOV', 'DÉC'],
	dayNames: ['Dimanche', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'],
	dayNamesShort: ['DIM','LUN','MAR','MER','JEU','VEN','SAM'],
	dayNamesMin: ['S','L','M','M','J','V','S'],
	weekHeader: 'Sem.',
	dateFormat: 'mm/dd/yy',
	firstDay: 1,
	isRTL: false,
	showMonthAfterYear: false,
	yearSuffix: ''
};
$.datepicker.setDefaults($.datepicker.regional['fr']);

	$.timepicker.regional['fr'] = {
		timeOnlyTitle: 'Choisir une heure',
		timeText: 'Heure',
		hourText: 'Heures',
		minuteText: 'Minutes',
		secondText: 'Secondes',
		millisecText: 'Millisecondes',
		microsecText: 'Microsecondes',
		timezoneText: 'Fuseau horaire',
		currentText: 'Maintenant',
		closeText: 'Terminé',
		timeFormat: 'HH:mm',
		timeSuffix: '',
		amNames: ['AM', 'A'],
		pmNames: ['PM', 'P'],
		isRTL: false
	};

	$.timepicker.setDefaults($.timepicker.regional['fr']);
})(jQuery);
