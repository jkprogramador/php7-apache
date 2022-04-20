@extends('layouts.default')

@section('title', 'Contact page')

@section('content')

{{-- Contact page here --}}

@if (session('success_message'))
<p>{{ session('success_message') }}</p>
@endif

<h1>Contact Page</h1>
<a href="{{ url('/') }}">Go back to homepage</a>

@if (count($errors) > 0)
<ul>
    @foreach ($errors->all() as $error)
    <li>{{ $error }}</li>
    @endforeach
</ul>
@endif

<form action="{{ url('/contact') }}" method="post">
    {{ csrf_field() }}
    <label for="name">Name</label>
    <input type="text" name="name" id="name" value="{{ old('name') }}" placeholder="Your name">

    <label for="email">Email</label>
    <input type="email" name="email" id="email" value="{{ old('email') }}" placeholder="Your email">

    <label for="comment">Comment</label>
    <textarea name="comment" id="comment" cols="30" rows="10" placeholder="Your comment">{{ old('comment') }}</textarea>

    <input type="submit" value="Send">
</form>


@stop