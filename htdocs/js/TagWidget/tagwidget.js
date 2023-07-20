'use strict';

(async () => {
	const tagWidgetScript = document.getElementById('tag-widget-script');
	if (!tagWidgetScript || !tagWidgetScript.dataset.taxonomy) return;

	// Add a container for message toasts.
	const toastContainer = document.createElement('div');
	toastContainer.classList.add('toast-container', 'position-fixed', 'bottom-0', 'end-0', 'p-3');
	toastContainer.style.zIndex = 1060;
	document.body.append(toastContainer);

	// Convenience method for showing messages in a Bootstrap toast.
	const showMessage = (message, success = false) => {
		if (!message) return;

		const toast = document.createElement('div');
		toast.classList.add('toast', 'align-items-center', 'border-0');
		toast.setAttribute('role', 'alert');
		toast.setAttribute('aria-live', success ? 'polite' : 'assertive');
		toast.setAttribute('aria-atomic', 'true');

		const alert = document.createElement('div');
		alert.classList.add('d-flex', 'alert', success ? 'alert-success' : 'alert-danger', 'p-0');
		toast.append(alert);

		const toastBody = document.createElement('div');
		toastBody.classList.add('toast-body');
		toastBody.textContent = message;

		const closeButton = document.createElement('button');
		closeButton.classList.add('btn-close', 'me-2', 'm-auto');
		closeButton.type = 'button';
		closeButton.dataset.bsDismiss = 'toast';
		closeButton.setAttribute('aria-label', 'Close');

		alert.append(toastBody, closeButton);

		toastContainer.append(toast);

		const bsToast = new bootstrap.Toast(toast, { delay: toastContainer.childElementCount * 5000 });
		toast.addEventListener('hidden.bs.toast', () => {
			bsToast.dispose();
			toast.remove();
		});
		bsToast.show();
	};

	// Load the library taxonomy from the JSON file.
	const response = await fetch(tagWidgetScript.dataset.taxonomy).catch(
		(err) => `Could not load the OPL taxonomy from the server: ${err.messsage ?? err}`
	);
	if (typeof response === 'string') return showMessage(response);
	if (!response.ok) return showMessage('Could not load the OPL taxonomy from the server.');

	const taxonomy = await response.json();

	const webServiceURL = `${webworkConfig?.webwork_url ?? '/webwork2'}/instructor_rpc`;

	const readFromTaxonomy = (category, values) => {
		const subjectTaxonomy = taxonomy;
		if (category === 'subject') return subjectTaxonomy.map((subject) => subject.name);

		const chapterTaxonomy = subjectTaxonomy.find((value) => value.name === values[0])?.subfields;
		if (!chapterTaxonomy) return [];
		if (category === 'chapter') return chapterTaxonomy.map((chapter) => chapter.name);

		const sectionTaxonomy = chapterTaxonomy.find((value) => value.name === values[1])?.subfields;
		if (!sectionTaxonomy) return [];
		if (category === 'section') return sectionTaxonomy.map((section) => section['name']);

		return []; // Should not get here
	};

	const createWebServiceObject = (command, values = {}) => {
		return {
			rpc_command: command,
			library_name: 'Library',
			command: 'searchLib',
			user: document.getElementById('hidden_user')?.value,
			courseID: document.getElementsByName('hidden_course_id')[0]?.value,
			key: document.getElementById('hidden_key')?.value,
			...values
		};
	};

	class TagWidget {
		constructor(filePath) {
			this.filePath = filePath;
		}

		async show() {
			await this.getTags();

			if (!this.tags) return;

			if (this.tags.DBsubject && /ZZZ/.test(this.tags.DBsubject)) {
				showMessage('Problem file is a pointer to another file', true);
				return;
			}

			const modal = document.createElement('div');
			modal.classList.add('modal');
			modal.ariaLabelledby = 'tag-editor';
			modal.setAttribute('aria-hidden', 'true');
			modal.tabIndex = -1;

			const dialog = document.createElement('div');
			dialog.classList.add('modal-dialog', 'modal-dialog-centered', 'modal-lg');
			modal.append(dialog);

			const content = document.createElement('div');
			content.classList.add('modal-content');
			dialog.append(content);

			const header = document.createElement('div');
			header.classList.add('modal-header');

			const headerTitle = document.createElement('h1');
			headerTitle.classList.add('modal-title', 'fs-4');
			headerTitle.id = 'tag-editor';
			headerTitle.textContent = 'Tag Editor';

			const headerCloseButton = document.createElement('button');
			headerCloseButton.type = 'button';
			headerCloseButton.classList.add('btn-close');
			headerCloseButton.dataset.bsDismiss = 'modal';
			headerCloseButton.setAttribute('aria-label', 'Close');

			header.append(headerTitle, headerCloseButton);

			const body = document.createElement('div');
			body.classList.add('modal-body');

			for (const [select, label] of [
				['subjectSelect', 'Subject'],
				['chapterSelect', 'Chapter'],
				['sectionSelect', 'Section'],
				['levelSelect', 'Level']
			]) {
				const row = document.createElement('div');
				row.classList.add('row', 'mb-2');

				const labelEl = document.createElement('label');
				labelEl.classList.add('col-sm-2', 'col-form-label');
				labelEl.textContent = `${label}:`;
				labelEl.setAttribute('for', select);

				const selectColumn = document.createElement('div');
				selectColumn.classList.add('col-sm-10');
				row.append(labelEl, selectColumn);

				this[select] = document.createElement('select');
				this[select].id = select;
				this[select].classList.add('form-select');
				this[select].add(new Option(`Select ${label}`, '', true));
				selectColumn.append(this[select]);

				body.append(row);
			}

			this.subjectSelect.addEventListener('change', () =>
				this.update('chapter', { DBsubject: '', DBchapter: '', DBsection: '' })
			);

			this.chapterSelect.addEventListener('change', () =>
				this.update('section', { DBsubject: '', DBchapter: '', DBsection: '' })
			);

			for (const j of Array(6).keys()) {
				this.levelSelect.add(new Option(j + 1));
			}

			// Show the status menu if this is a problem in "Pending".
			if (/^Pending\//.test(this.filePath.replace(/^.*templates\//, ''))) {
				const statusRow = document.createElement('div');
				statusRow.classList.add('row', 'mt-2');

				const statusLabel = document.createElement('label');
				statusLabel.classList.add('col-sm-2', 'col-form-label');
				statusLabel.textContent = 'Status:';
				statusLabel.setAttribute('for', 'statusSelect');

				const statusColumn = document.createElement('div');
				statusColumn.classList.add('col-sm-10');
				statusRow.append(statusLabel, statusColumn);

				this.statusSelect = document.createElement('select');
				this.statusSelect.id = 'statusSelect';
				this.statusSelect.classList.add('form-select');
				for (const value of [
					['Accept', 'A'],
					['Review', '0', true, true],
					['Reject', 'R'],
					['Further', 'F'],
					['Needs Resource', 'N']
				]) {
					this.statusSelect.add(new Option(...value));
				}
				statusColumn.append(this.statusSelect);

				body.append(statusRow);
			}

			const footer = document.createElement('div');
			footer.classList.add('modal-footer');

			this.saveButton = document.createElement('button');
			this.saveButton.type = 'button';
			this.saveButton.classList.add('btn', 'btn-primary');
			this.saveButton.textContent = 'Save';
			this.saveButton.addEventListener('click', () => this.savetags());

			const closeButton = document.createElement('button');
			closeButton.type = 'button';
			closeButton.classList.add('btn', 'btn-secondary');
			closeButton.dataset.bsDismiss = 'modal';
			closeButton.textContent = 'Close';

			footer.append(this.saveButton, closeButton);

			content.append(header, body, footer);

			modal.addEventListener('shown.bs.modal', () => this.update('subject', this.tags));
			modal.addEventListener('hidden.bs.modal', () => {
				this.bsModal.dispose();
				modal.remove();
			});

			this.bsModal = new bootstrap.Modal(modal);
			this.bsModal.show();
		}

		async getTags() {
			const response = await fetch(webServiceURL, {
				method: 'post',
				mode: 'same-origin',
				body: new URLSearchParams(createWebServiceObject('getProblemTags', { command: this.filePath }))
			}).catch((err) => `Error requesting problem tags: ${err.message ?? err}`);
			if (typeof response === 'string') return showMessage(response);
			if (!response.ok) return showMessage('Unable to obtain problem tags.');
			const data = await response.json();
			if (data.error) return showMessage(data.error);
			this.tags = data.result_data;
		}

		update(category, values, clear = false) {
			if (category === 'level') {
				if (values.Level) this.levelSelect.value = values.Level;
				return this.update('status', values);
			}
			if (category === 'status') {
				if (this.statusSelect && values.Status) this.statusSelect.value = values.Status;
				return;
			}

			const child = {
				subject: 'chapter',
				chapter: 'section',
				section: 'level'
			};

			const defaultOption = `Select ${category.charAt(0).toUpperCase() + category.slice(1)}`;

			if (clear) {
				this.setSelect(category, defaultOption);
				return this.update(child[category], values);
			}

			const subject = values.DBsubject || this.subjectSelect.value;
			const chapter = values.DBchapter || this.chapterSelect.value;
			const section = values.DBsection || this.sectionSelect.value;

			if (category === 'chapter' && subject === '') return this.update(category, values, true);
			if (category === 'section' && chapter === '') return this.update(category, values, true);

			this.setSelect(category, defaultOption, readFromTaxonomy(category, [subject, chapter, section]), values);

			this.update(child[category], values);
		}

		setSelect(category, defaultOption, options = [], values = {}) {
			const select = this[`${category}Select`];
			while (select.lastChild) select.firstChild.remove();

			const currentValue = values[`DB${category}`];

			select.add(new Option(defaultOption, '', true, !!currentValue));

			for (const option of options) {
				select.add(new Option(option, option, false, option === currentValue));
			}

			if (currentValue && !select.value) {
				showMessage(`Provided ${category} "${currentValue}" is not in the taxonomy.`);
				select.remove(0);
				select.add(new Option(currentValue, currentValue, false, true), 0);
			}
		}

		async savetags() {
			const response = await fetch(webServiceURL, {
				method: 'post',
				mode: 'same-origin',
				body: new URLSearchParams(
					createWebServiceObject('setProblemTags', {
						library_subjects: this.subjectSelect.value,
						library_chapters: this.chapterSelect.value,
						library_sections: this.sectionSelect.value,
						library_levels: this.levelSelect.value,
						library_status: this.statusSelect?.value ?? '0',
						command: this.filePath
					})
				)
			}).catch((err) => `Error saving problem tags: ${err.message ?? err}`);
			if (typeof response === 'string') return showMessage(response);
			if (!response.ok) return showMessage('Unable to save problem tags.');
			const data = await response.json();
			if (data.error) return showMessage(data.error);
			showMessage(data.server_response);
		}
	}

	for (const tagEditButton of document.querySelectorAll('.tag-edit-btn')) {
		if (!tagEditButton.dataset.sourceFile) return;
		tagEditButton.addEventListener('click', () => new TagWidget(tagEditButton.dataset.sourceFile).show());
	}
})();
