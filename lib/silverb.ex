defmodule Silverb do
  use Application
  defmodule Console do
    def error(bin) do
      message(bin, IO.ANSI.red)
      raise("#{__MODULE__} : #{bin}")
    end
    def warn(bin), do: message(bin, IO.ANSI.yellow)
    def notice(bin), do: message(bin, IO.ANSI.cyan)
    defp message(bin, color), do: IO.puts("#{IO.ANSI.bright}==> #{__MODULE__}#{IO.ANSI.reset} : #{color}#{bin}#{IO.ANSI.reset}")
  end
  @own_modules [Silverb, Silverb.Console, Silverb.OnCompile, Mix.Tasks.Silverb.Check, Mix.Tasks.Silverb.Init, Mix.Tasks.Silverb.Off, Mix.Tasks.Silverb.On]
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    case File.exists?("#{:code.priv_dir(:silverb)}/silverb/off") do
    true -> Silverb.Console.warn("silverb swithed off, pass checks ...")
    false -> check_modules
    end
    children = [
      # Define workers and child supervisors to be supervised
      # worker(Silverb.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Silverb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def check_modules do
    maybe_create_priv
    load_modules
    Silverb.Console.notice("checking modules ... ")
  Enum.each(@own_modules++("#{:code.priv_dir(:silverb)}/silverb/silverb" |> File.read! |> :erlang.binary_to_term),
    fn(mod) ->
      case :xref.m(mod) do
        [deprecated: [], undefined: [], unused: _] -> :ok
        some -> Silverb.Console.error("found errors #{inspect some}")
      end
      if not(mod in @own_modules) do
        case mod.silverb do
          true -> :ok
          false -> Silverb.Console.error("attrs are out of date, recompile module #{mod}!")
        end
      end
    end)
  Silverb.Console.notice("modules and attrs are OK!")
  end

  defp load_modules do
    Silverb.Console.notice("loading modules ... ")
    dir = (:os.cmd('pwd') |> to_string |> String.strip) <> "/_build/#{Mix.env}/lib/"
    File.ls!(dir) |> Enum.each(fn(app) ->
      dir_ebin = dir<>app<>"/ebin/"
      File.ls!(dir_ebin)
      |> Enum.filter(&(Regex.match?(~r/\.beam$/, &1)))
      |> Enum.map(&(Regex.replace(~r/(\.beam)$/, &1, fn(_,_) -> "" end)))
      |> Enum.each(fn(mod) ->
		case String.to_atom(mod) |> Code.ensure_loaded? do
			true -> :ok
			false ->
				case String.to_char_list(dir_ebin<>mod) |> :code.load_abs do
					{:module, _} -> :ok
					error -> Silverb.Console.error("module #{inspect mod} loading error #{inspect error}.")
				end
		end
      end)
    end)
  end

  #
  # in client side (modules)
  #

  defmacro __using__(lst) do
    %{attrs: attrs, checks: checks} = get_checks(lst)
    body =  case checks do
        nil -> quote location: :keep do true end
        _ -> checks
      end
    quote location: :keep do
      unquote(attrs)
      @silverb Silverb.send_data(__MODULE__)
      def silverb, do: unquote(body)
    end
  end

  defp get_checks(lst) do
  Enum.reduce(lst, %{attrs: nil, checks: nil},
      fn
    {<<"@",this_attr::binary>>, this_expr}, %{attrs: nil, checks: nil} ->
      this_value = Code.eval_quoted(this_expr) |> elem(0) |> Macro.escape
        %{
          attrs:  quote location: :keep do
                    unquote({:@, [], [{String.to_atom(this_attr), [], [this_value] }]})
                  end,
          checks: quote location: :keep do
                (unquote(this_value) == unquote(this_expr))
                  end
        }
      {<<"@",this_attr::binary>>, this_expr}, %{attrs: attrs, checks: checks} ->
        this_value = Code.eval_quoted(this_expr) |> elem(0) |> Macro.escape
        %{
          attrs:  quote location: :keep do
                unquote(attrs)
                    unquote({:@, [], [{String.to_atom(this_attr), [], [this_value] }]})
                  end,
          checks: quote location: :keep do
                unquote(checks) and (unquote(this_value) == unquote(this_expr))
                  end
        }
      end)
  end


  def send_data(mod) do
    try do
      :erlang.register(:silverb_worker, spawn fn() -> worker_func end)
    catch
      _ -> :ok
    rescue
      _ -> :ok
    end
    send(:silverb_worker, {:silverb, mod, self})
    receive do
      {:silverb, :ok} -> :ok
    after
      3000 -> Silverb.Console.error("#{mod} not received ans from silverb_worker maybe 'mix silverb.clean' will help")
    end
  end

  #
  # in app
  #

  defp worker_func do
    receive do
      {:silverb, mod, pid} ->
      file = to_string(:code.priv_dir(:silverb))<>"/silverb/silverb"
      Enum.uniq([mod|(File.read!(file) |> :erlang.binary_to_term)])
      |> write_to_file(file)
      send(pid, {:silverb, :ok})
        worker_func
    end
  end

  def write_to_file(input, file) do
    data =  case input do
          bin when is_binary(bin) -> bin
          term -> :erlang.term_to_binary(term)
      end
    {:ok, io} = :file.open(file, [:write])
    :ok = :file.write(io, data)
    :ok = :file.sync(io)
    :ok = :file.close(io)
  end

  def maybe_create_priv do
  dir = to_string(:code.priv_dir(:silverb))<>"/silverb"
  if not(File.exists?(dir)) do
    :ok = File.mkdir_p!(dir)
    Silverb.Console.notice("dir #{dir} created")
  end
  file = dir<>"/silverb"
  if not(File.exists?(file)) do
    :ok = File.touch!(file)
    write_to_file([], file)
    Silverb.Console.notice("file #{file} created")
  end
  end

end

defmodule Silverb.OnCompile do
  @oncompile Silverb.maybe_create_priv
  use Silverb, [
          {"@canged", :application.get_env(:silverb, :some)},
          {"@good", %{a: 1}}
         ]
    def test, do: {@canged, @good}
end
