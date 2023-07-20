<!DOCTYPE html>
<html lang="en" dir="ltr">
%
<head>
	<meta charset='UTF-8'>
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<link rel="shortcut icon" href="/favicon.ico">
	<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.3/dist/css/bootstrap.min.css" rel="stylesheet">
	<link href="<%= $base_url %>/assets/podviewer.css" rel="stylesheet">
	<title>WeBWorK/PG POD</title>
</head>
%
<body>
	<div class="main-index-header navbar navbar-dark bg-primary px-3 position-fixed border-bottom border-dark">
		<div class="container-fluid">
			<h1 class="navbar-brand fw-bold fs-5 m-0">WeBWorK/PG POD</h1>
		</div>
	</div>
	<div class="main-index-container mx-3">
		<div class="pt-3">
			<h2 class="fw-bold fs-6">(Plain Old Documentation)</h2>
			<nav class="nav flex-column list-group">
				% if ($pg_root) {
					<a class="nav-link list-group-item list-group-item-action d-inline-block w-100" href="pg">
						PG
					</a>
				% }
				% if ($webwork_root) {
					<a class="nav-link list-group-item list-group-item-action d-inline-block w-100" href="webwork2">
						Webwork2
					</a>
				% }
			</nav>
		</div>
	</div>
</body>
%
</html>
