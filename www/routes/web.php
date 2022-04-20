<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;
use App\Mail\FeedbackReceived;
use Illuminate\Support\Facades\Mail;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/', function () {
    return view('home');
});

Route::get('about', function () {
    return view('about');
});

Route::match(['get', 'post'], 'contact', function (Request $request) {

    if ('POST' === $request->method()) {

        $request->validate([
            'name' => 'required|string',
            'email' => 'required|email',
            'comment' => 'required|string',
        ]);

        Mail::to($request->input('email'))->send(new FeedbackReceived($request->input('name'), $request->input('comment')));

        return redirect('/contact')->with([
            'success_message' => 'Your message has been sent!',
        ]);
    }

    return view('contact');
});
