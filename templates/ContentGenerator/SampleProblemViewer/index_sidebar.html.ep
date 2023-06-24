<div class="offcanvas-header">
	<h2 class="offcanvas-title fs-3" id="sidebar-label"><%= $label =%></h2>
	<button type="button" class="btn-close" data-bs-dismiss="offcanvas"
		data-bs-target="#sidebar" aria-label="Close">
	</button>
</div>

<h2 class="fs-3 d-none d-md-block px-3 pt-3"><%= $label =%></h2>
<div class="offcanvas-body px-md-3 pb-md-3 w-100">
	<div class="list-group w-100" role="tablist" id="sidebar-list">
	  % if ($label eq 'Problem Techniques') {
			% for (['A' .. 'C'], ['D' .. 'F'], ['G' .. 'N'], ['O' .. 'Z']) {
			<a class="list-group-item list-group-item-action" id="<%= $_->[0] %>-tab" href="#<%= $_->[0] %>"
				data-bs-toggle="list" role="tab" aria-controls="<%= $_->[0] %>">
				<%= $_->[0] %> .. <%= $_->[-1] %>
			</a>
			% }
		% } else {
			% for (sort(keys %$list)) {
				% my $id = $_ =~ s/\s/_/gr;
				<a class="list-group-item list-group-item-action" id="<%= $id %>-tab" href="#<%= $id %>"
					data-bs-toggle="list" role="tab" aria-controls="<%= $id %>">
					<%= $_ %>
				</a>
			% }
		% }
	</div>
</div>
