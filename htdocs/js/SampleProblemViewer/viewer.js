const offcanvas = bootstrap.Offcanvas.getOrCreateInstance(document.getElementById('sidebar'));
for (const link of document.querySelectorAll('#sidebar-list .list-group-item-action')) {
	link.addEventListener('click', () => offcanvas.hide());
}
