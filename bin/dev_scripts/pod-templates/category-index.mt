<!DOCTYPE html>
<html lang="en" dir="ltr">
%
<head>
	<meta charset='UTF-8'>
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title><%= $title %></title>
	<link rel="shortcut icon" href="/favicon.ico">
	<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css" rel="stylesheet">
	<link href="<%= $base_url %>/assets/podviewer.css" rel="stylesheet">
	<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/js/bootstrap.bundle.min.js" defer></script>
	<script src="<%= $base_url %>/assets/podviewer.js" defer></script>
</head>
%
<body>
	<div class="pod-header navbar navbar-dark bg-primary px-3 position-fixed border-bottom border-dark">
		<div class="container-fluid d-flex flex-column d-md-block">
			<h1 class="navbar-brand fw-bold fs-5 me-auto me-md-0 mb-2 mb-md-0"><%= $title %></h1>
			<button class="navbar-toggler d-md-none me-auto" type="button" data-bs-toggle="offcanvas"
				data-bs-target="#sidebar" aria-controls="sidebar" aria-label="Toggle Sidebar">
				<span class="navbar-toggler-icon"></span>
			</button>
		</div>
	</div>
	%
	% my ($index, $macro_index, $content, $macro_content) = ('', '', '', '');
	% for my $macro (@$macros_order) {
		% next unless defined $pod_index->{$macro};
		% my $new_index = begin
			<a href="#macro-<%= $macro %>" class="nav-link"><%= $macros->{$macro} %></a>
		% end
		% $macro_index .= $new_index->();
		% my $new_content = begin
			<h3><a href="#_podtop_" id="macro-<%= $macro %>"><%= $macros->{$macro} %></a></h3>
			<div class="list-group mb-2">
				% for my $file (sort { $a->[1] cmp $b->[1] } @{ $pod_index->{$macro} }) {
					<a href="<%= $file->[0] %>" class="list-group-item list-group-item-action"><%= $file->[1] %></a>
				% }
			</div>
		% end
		% $macro_content .= $new_content->();
	% }
	% for my $section (@$section_order) {
		% next unless defined $pod_index->{$section};
		% my $new_index = begin
			<a href="#<%= $section %>" class="nav-link"><%= $sections->{$section} %></a>
			% if ($section eq 'macros') {
				<div class="nav flex-column ms-3">
					<%= $macro_index %>
				</div>
			% }
		% end
		% $index .= $new_index->();
		% my $new_content = begin
			<h2><a href="#_podtop_" id="<%= $section %>"><%= $sections->{$section} %></a></h2>
			<div class="list-group mb-2">
				% if ($section eq 'macros') {
					<%= $macro_content =%>
				% } else {
					% for my $file (sort { $a->[1] cmp $b->[1] } @{ $pod_index->{$section} }) {
						<a href="<%= $file->[0] %>" class="list-group-item list-group-item-action">
							<%= $file->[1] %>
						</a>
					% }
				% }
			</div>
		% end
		% $content .= $new_content->();
	% }
	%
	<aside class="offcanvas-md offcanvas-start border-end border-dark position-fixed" tabindex="-1"
		id="sidebar" aria-labelledby="sidebar-label">
		<div class="offcanvas-header">
			<h2 class="offcanvas-title" id="sidebar-label">Index</h2>
			<button type="button" class="btn-close" data-bs-dismiss="offcanvas" data-bs-target="#sidebar"
			   	aria-label="Close">
			</button>
		</div>
		<div class="offcanvas-body p-md-3 w-100">
			<nav class="nav flex-column w-100">
				<a href="<%= $base_url %>" class="nav-link">WeBWorK POD Home</a>
				<a href="http://webwork.maa.org/wiki/WeBWorK_Main_Page" class="nav-link">WeBWorK Wiki</a>
				<hr>
				<%= $index =%>
			</nav>
		</div>
	</aside>
	<div class="pod-page-container d-flex">
		<div class="container-fluid p-3 h-100" id="_podtop_">
			<%= $content =%>
			<p class="mt-3">Generated <%= $date %></p>
		</div>
	</div>
</body>
%
</html>
