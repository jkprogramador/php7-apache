<!DOCTYPE html>
<html lang="en" dir="ltr">

<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, shrink-to-fit=no">
    <title>@yield('title', 'Elementary Laravel')</title>
</head>

<body>
    @include('layouts.partials.nav') {{-- Include subview --}}

    @yield('content')
</body>

</html>