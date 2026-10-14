(() => {
	const form = document.getElementById('manage-locations-form');
	if (!form) return;

	const action_radios = Array.from(form.querySelectorAll('input[name="manage_location_action"]'));
	const delete_action = document.getElementById('delete_location_action');
	const delete_select = document.getElementById('delete_location_select');
	const dialog = document.getElementById('delete_location_confirm_dialog');
	const modal = dialog ? new bootstrap.Modal(dialog) : null;
	let confirmed = false;
	let submitter = null;

	const add_action = document.getElementById('add_location_action');
	const create_fields = ['new_location_name', 'new_location_description', 'new_location_addresses']
		.map((id) => document.getElementById(id))
		.filter((field) => field);
	const create_err_msg = document.getElementById('create_location_err_msg');
	const hide_create_errors = () => {
		create_err_msg?.classList.add('d-none');
		for (const field of create_fields) field.classList.remove('is-invalid');
	};
	for (const field of create_fields) {
		field.addEventListener('input', () => {
			if (!field.value.trim()) return;
			field.classList.remove('is-invalid');
			if (!create_fields.some((f) => f.classList.contains('is-invalid'))) hide_create_errors();
		});
	}

	const action_err_msg = document.getElementById('select_action_err_msg');
	const location_err_msg = document.getElementById('select_location_err_msg');
	form.addEventListener('change', (e) => {
		if (e.target.name === 'manage_location_action') hide_create_errors();
		action_err_msg?.classList.add('d-none');
		for (const radio of action_radios) radio.classList.remove('is-invalid');
		location_err_msg?.classList.add('d-none');
		delete_select?.classList.remove('is-invalid');
	});

	document.getElementById('delete_location_confirm_proceed')?.addEventListener('click', () => {
		confirmed = true;
		modal.hide();
		const confirmInput = document.getElementsByName('delete_location_confirm')[0];
		if (confirmInput) confirmInput.value = 1;
		form.requestSubmit(submitter);
	});

	form.addEventListener('submit', (e) => {
		if (!action_radios.some((radio) => radio.checked)) {
			e.preventDefault();
			action_err_msg?.classList.remove('d-none');
			for (const radio of action_radios) radio.classList.add('is-invalid');
			return;
		}

		if (add_action?.checked) {
			const empty_fields = create_fields.filter((field) => !field.value.trim());
			if (empty_fields.length) {
				e.preventDefault();
				create_err_msg?.classList.remove('d-none');
				for (const field of empty_fields) field.classList.add('is-invalid');
			}
			return;
		}

		if (!delete_action?.checked || !delete_select || !modal) return;
		if (confirmed) {
			confirmed = false;
			return;
		}

		const locations =
			delete_select.value === 'selected_locations'
				? Array.from(form.querySelectorAll('input[name="delete_selected"]:checked')).map((check) => check.value)
				: [delete_select.value];

		e.preventDefault();

		if (!locations.length) {
			location_err_msg?.classList.remove('d-none');
			delete_select.classList.add('is-invalid');
			return;
		}

		submitter = e.submitter;
		document.getElementById('delete_location_confirm_list')?.replaceChildren(
			...locations.map((location) => {
				const item = document.createElement('li');
				item.textContent = location;
				return item;
			})
		);
		modal.show();
	});
})();
