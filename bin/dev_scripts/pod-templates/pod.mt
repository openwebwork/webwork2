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
	<aside class="offcanvas-md offcanvas-start border-end border-dark position-fixed" tabindex="-1"
		id="sidebar" aria-labelledby="sidebar-label">
		<div class="offcanvas-header">
			<h2 class="offcanvas-title" id="sidebar-label">Index</h2>
			<button type="button" class="btn-close" data-bs-dismiss="offcanvas" data-bs-target="#sidebar"
			   	aria-label="Close">
			</button>
		</div>
		<div class="offcanvas-body p-md-3 w-100">
			<nav>
				<ul class="nav flex-column w-100">
					<li class="nav-item">
						<a href="<%= $base_url %>" class="nav-link p-0">WeBWorK POD Home</a>
					</li>
					<li class="nav-item">
						<a href="http://webwork.maa.org/wiki/WeBWorK_Main_Page" class="nav-link p-0">WeBWorK Wiki</a>
					</li>
					<li><hr></li>
					<%= $index->join('') =%>
				</ul>
			</nav>
		</div>
	</aside>
	<div class="pod-page-container d-flex">
		<div class="container-fluid p-3 h-100" id="_podtop_">
			<%= $content =%>
		</div>
	</div>
</body>
%
</html>
