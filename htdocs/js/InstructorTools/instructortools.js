(() => {
	const form = document.forms['instructor-tools-form'];

	form?.addEventListener('submit', (e) => {
		const selectedUsers = Array.from(document.querySelector('select[name=selected_users]')?.options ?? []).filter(
			(option) => option.selected
		);
		const selectedSets = Array.from(document.querySelector('select[name=selected_sets]')?.options ?? []).filter(
			(option) => option.selected
		);

		// Check for the neccessary data for the requested module.
		// Show a message and prevent submission if it is missing.
		const messages = [];

		if (
			(e.submitter.dataset.usersNeeded === 'at least one' && !selectedUsers.length) ||
			(e.submitter.dataset.usersNeeded === 'exactly one' && selectedUsers.length !== 1)
		)
			messages.push(e.submitter.dataset.errorUsers);
		if (
			(e.submitter.dataset.setsNeeded === 'at least one' && !selectedSets.length) ||
			(e.submitter.dataset.setsNeeded === 'exactly one' && selectedSets.length !== 1) ||
			(e.submitter.dataset.setsNeeded === 'at most one' && selectedSets.length > 1)
		)
			messages.push(e.submitter.dataset.errorSets);
		if (e.submitter.dataset.setNameNeeded) {
			const newSetName = form.querySelector('input[name="new_set_name"]')?.value ?? '';
			if (!newSetName) messages.push(e.submitter.dataset.errorSetName);
			if (newSetName && !/^[\w.-]*$/.test(newSetName)) messages.push(e.submitter.dataset.errorInvalidSetName);
		}

		if (messages.length) {
			const msgBoxes = document.querySelectorAll('.message');
			msgBoxes.forEach((msgBox) => {
				while (msgBox.firstChild) msgBox.firstChild.remove();
				const container = document.createElement('div');
				container.classList.add('alert', 'alert-danger', 'p-1', 'my-2');
				const contents = document.createElement('div');
				contents.classList.add('d-flex', 'flex-column', 'gap-1');
				for (const msg of messages) {
					const newMsgDiv = document.createElement('div');
					newMsgDiv.textContent = msg;
					contents.append(newMsgDiv);
				}
				container.append(contents);
				msgBox?.append(container);
			});

			// Make sure that the lower message box is visible.
			const rect = msgBoxes[msgBoxes.length - 1].getBoundingClientRect();
			if (rect.bottom > window.innerHeight) msgBoxes[msgBoxes.length - 1].scrollIntoView({ block: 'end' });

			// Prevent the form from submitting.
			e.preventDefault();

			return;
		}

		// Any additional form parameters added below should be placed in this div.  Each time the form is submitted it
		// is emptied so that form parameters don't build up in the DOM. This can happen if the form is submitted, and
		// then the user uses the browser back button.
		const additionalParams = document.querySelector('.additional-params') || document.createElement('div');
		if (additionalParams.classList.contains('additional-params')) {
			while (additionalParams.firstChild) additionalParams.firstChild.remove();
		} else {
			additionalParams.classList.add('d-none', 'additional-params');
			form.append(additionalParams);
		}

		// The UserList.pm and Scoring.pm modules have different form parameters than the form in the instructor tools
		// Index.pm module.  This sets the correct parameters for those modules from the parameters in the form in
		// Index.pm.
		switch (e.submitter.name) {
			case 'edit_users':
				{
					const visibleUsers = document.createElement('select');
					visibleUsers.name = 'visible_users';
					visibleUsers.type = 'select';
					visibleUsers.multiple = true;
					visibleUsers.style.display = 'none';
					visibleUsers.append(
						...selectedUsers.map((option) => {
							const selectedUser = document.createElement('option');
							selectedUser.value = option.value;
							selectedUser.selected = true;
							return selectedUser;
						})
					);

					const editMode = document.createElement('input');
					editMode.type = 'hidden';
					editMode.name = 'editMode';
					editMode.value = 1;

					additionalParams.append(visibleUsers, editMode);
				}
				break;
			case 'score_sets':
				{
					const selectedSet = document.createElement('select');
					selectedSet.name = 'selectedSet';
					selectedSet.type = 'select';
					selectedSet.multiple = true;
					selectedSet.style.display = 'none';
					selectedSet.append(
						...selectedSets.map((option) => {
							const selectedSetOption = document.createElement('option');
							selectedSetOption.value = option.value;
							selectedSetOption.selected = true;
							return selectedSetOption;
						})
					);

					const scoreSelected = document.createElement('input');
					scoreSelected.type = 'hidden';
					scoreSelected.name = 'scoreSelected';
					scoreSelected.value = 1;

					additionalParams.append(selectedSet, scoreSelected);
				}
				break;
			case 'edit_set_for_users':
				{
					if (
						!new RegExp(`\\/instructor\\/sets\\/?${selectedSets[0].value}(\\?.*)?$`).test(
							e.submitter.formAction
						)
					) {
						e.submitter.formAction = e.submitter.formAction.replace(
							/\/instructor\/sets\/?.*?(\?.*)?$/,
							`/instructor/sets/${selectedSets[0].value}$1`
						);
					}

					for (const user of selectedUsers) {
						const editForUser = document.createElement('input');
						editForUser.name = 'editForUser';
						editForUser.type = 'hidden';
						editForUser.style.display = 'none';
						editForUser.value = user.value;
						additionalParams.append(editForUser);
					}
				}
				break;
			case 'show_answers':
				{
					if (!selectedSets.length) return;

					const selectedProblems = document.createElement('select');
					selectedProblems.name = 'selected_problems';
					selectedProblems.type = 'select';
					selectedProblems.multiple = true;
					selectedProblems.style.display = 'none';

					const allProblemIds = {};

					for (const set of selectedSets) {
						for (const id of JSON.parse(
							document.getElementsByName(`${set.value}_problem_ids`)[0]?.value || '[]'
						)) {
							allProblemIds[id] = 1;
						}
					}

					for (const id of Object.keys(allProblemIds)) {
						const selectedProblemsOption = document.createElement('option');
						selectedProblemsOption.value = id;
						selectedProblemsOption.selected = true;
						selectedProblems.append(selectedProblemsOption);
					}

					additionalParams.append(selectedProblems);
				}
				break;
		}
	});
})();
