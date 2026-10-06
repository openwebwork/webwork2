(() => {
	// Show/hide the filter elements depending on if the field matching option is selected.
	const filter_select = document.getElementById('filter_select');
	const filter_elements = document.getElementById('filter_elements');
	if (filter_select && filter_elements) {
		const toggle_filter_elements = () => {
			if (filter_select.value === 'match_regex') filter_elements.style.display = 'block';
			else filter_elements.style.display = 'none';
		};
		filter_select.addEventListener('change', toggle_filter_elements);
		toggle_filter_elements();
	}

	const job_list_form = document.getElementById('job-list-form');
	const select_job_err_msg = document.getElementById('select_job_err_msg');
	const hide_select_job_err_msg = () => select_job_err_msg?.classList.add('d-none');
	job_list_form?.addEventListener('change', hide_select_job_err_msg);
	for (const tab of document.querySelectorAll('a[data-bs-toggle="tab"]')) {
		tab.addEventListener('shown.bs.tab', hide_select_job_err_msg);
	}

	let delete_confirmed = false;
	const delete_confirm_dialog = document.getElementById('delete_confirm_dialog');
	const delete_confirm_modal = delete_confirm_dialog ? new bootstrap.Modal(delete_confirm_dialog) : null;
	document.getElementById('delete_confirm_proceed')?.addEventListener('click', () => {
		delete_confirmed = true;
		delete_confirm_modal?.hide();
		const confirmInput = document.getElementsByName('action.delete.confirm')[0];
		if (confirmInput) confirmInput.value = 1;
		document.getElementById('take_action')?.click();
	});

	job_list_form?.addEventListener('submit', (e) => {
		if (document.getElementById('current_action')?.value !== 'delete' || !delete_confirm_modal) return;
		if (delete_confirmed) {
			delete_confirmed = false;
			return;
		}
		e.preventDefault();
		e.stopPropagation();

		const selected_jobs = Array.from(document.querySelectorAll('input[name="selected_jobs"]:checked'));
		if (!selected_jobs.length) {
			select_job_err_msg?.classList.remove('d-none');
			return;
		}

		document.getElementById('delete_confirm_job_list')?.replaceChildren(
			...selected_jobs.map((job) => {
				const item = document.createElement('li');
				item.textContent = job.dataset.task ? `${job.value} (${job.dataset.task})` : job.value;
				return item;
			})
		);
		delete_confirm_modal.show();
	});
})();
