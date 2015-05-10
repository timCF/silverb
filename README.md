Silverb
=======

Now if one of module in your app contains some of this .. app will not even start
- Calls of undefined or deprecated public functions from other modules
- Outdated attributes

To use it in your module, write on top

```
use Silverb, [
				{"@foo", 456},
				{"@bar", :application.get_env(:app, :bar, nil)}
			 ]
```

In addition, there are some mix tasks to make your releases easier

- mix silverb.init : init "Makefile" and "start.sh"
- make release : will build, check and make release of your project
- make clean : totally cleanup build
- mix silverb.check : execute checks (it also executes in start of app)
- mix silverb.off : swith off silverb
- mix silverb.on : swith on silverb

Let's check it works. Do simple module with deps

```
config :example, bar: 111
config :myswt, app: :example, server_port: 8081, callback_module: Myswt.Example
```
```
defmodule Example do
  use Silverb, [{"@foo", Enum.map(1..100, &(&1+1))}, {"@bar", :application.get_env(:example, :bar, nil)}]
  use Application
  def get_attrs, do: {@foo, @bar}

  ...

```
```
$ mix clean
$ mix compile
Compiled lib/example.ex
Generated example.app
$ iex -S mix
Erlang/OTP 17 [erts-6.3.1] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

2015-05-10 15:29:26.185 [debug] Elixir.Myswt : iced compilation ok.
2015-05-10 15:29:26.621 [debug] HTTP MYSWT server started at port 8081
==> Elixir.Silverb : checking modules ...
==> Elixir.Silverb : module Elixir.Example is OK.
==> Elixir.Silverb : module Elixir.Example attrs are OK.
==> Elixir.Silverb : module Elixir.Myswt.Example is OK.
==> Elixir.Silverb : module Elixir.Myswt.Example attrs are OK.
==> Elixir.Silverb : module Elixir.Myswt is OK.
==> Elixir.Silverb : module Elixir.Myswt attrs are OK.
==> Elixir.Silverb : module Elixir.Myswt.WebServer is OK.
==> Elixir.Silverb : module Elixir.Myswt.WebServer attrs are OK.
==> Elixir.Silverb : module Elixir.Myswt.Bullet is OK.
==> Elixir.Silverb : module Elixir.Myswt.Bullet attrs are OK.
==> Elixir.Silverb : module Elixir.Silverb.OnCompile is OK.
==> Elixir.Silverb : module Elixir.Silverb.OnCompile attrs are OK.
Interactive Elixir (1.0.3) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Example.get_attrs
{[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
  23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41,
  42, 43, 44, 45, 46, 47, 48, 49, 50, ...], 111}
iex(2)>
```

Now add this to module Example, and app fail on startup

```
def count(some), do: Enummm.count(some)
```
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3.1] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

==> Elixir.Silverb : checking modules ...
==> Elixir.Silverb : found errors [deprecated: [], undefined: [{{Example, :count, 1}, {Enummm, :count, 1}}], unused: []]
```

Change some config for dependence Myswt, and it also fail on startup! Server port changed and module Myswt.WebServer is need to be recompiled now!
```
config :myswt, app: :example, server_port: 9999, callback_module: Myswt.Example
```
```
$ iex -S mix
Erlang/OTP 17 [erts-6.3.1] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Compiled lib/example.ex
Generated example.app
==> Elixir.Silverb : checking modules ...
==> Elixir.Silverb : module Elixir.Example is OK.
==> Elixir.Silverb : module Elixir.Example attrs are OK.
==> Elixir.Silverb : module Elixir.Silverb.OnCompile is OK.
==> Elixir.Silverb : module Elixir.Silverb.OnCompile attrs are OK.
==> Elixir.Silverb : module Elixir.Myswt.Example is OK.
==> Elixir.Silverb : module Elixir.Myswt.Example attrs are OK.
==> Elixir.Silverb : module Elixir.Myswt is OK.
==> Elixir.Silverb : module Elixir.Myswt attrs are OK.
==> Elixir.Silverb : module Elixir.Myswt.WebServer is OK.
==> Elixir.Silverb : attrs are out of date, recompile module Elixir.Myswt.WebServer!
```

WARNING! If you are using Silverb in your module, attr @silverb and function &silverb/0 are reserved, not redefine them!