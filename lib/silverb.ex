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
    File.write!("#{:code.priv_dir(:silverb)}/silverb/init_log.txt", Exutils.make_verbose_datetime<>"\n", [:append])
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
  	Silverb.Console.notice("checking modules ... ")
    modules_paths = File.read!("#{:code.priv_dir(:silverb)}/silverb/modules_paths") |> :erlang.binary_to_term
    "#{:code.priv_dir(:silverb)}/silverb/silverb" 
    |> File.read! 
    |> :erlang.binary_to_term
    |> Enum.each(fn(mod) -> 
      if not(Map.has_key?(modules_paths, mod)) do
        Silverb.Console.error("can't find path for module #{inspect mod}")
      end
    end)
	Enum.each(modules_paths, 
		fn({mod, path}) ->
			case :xref.m(path) do
				[deprecated: [], undefined: [], unused: _] -> Silverb.Console.notice("module #{mod} is OK.")
				some -> Silverb.Console.error("found errors #{inspect some}")
			end
      if not(mod in @own_modules) do
  			case mod.silverb do
  				true -> Silverb.Console.notice("module #{mod} attrs are OK.")
  				false -> Silverb.Console.error("attrs are out of date, recompile module #{mod}!")
  			end
      end
		end)
  end

  #
  #	in client side (modules)
  #

  defmacro __using__(lst) do
    %{attrs: attrs, checks: checks} = get_checks(lst)
    body = 	case checks do
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
  		3000 -> Silverb.Console.error("#{mod} not received ans from silverb_worker")
  	end 
  end

  #
  #	in app
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
  	data = 	case input do
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
	end
	file = dir<>"/silverb"
	if not(File.exists?(file)) do
		:ok = File.touch!(file)
		write_to_file([], file)
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
  defp wait_for_module(module) do
    case :code.which(module) do
      :non_existing -> 
        :timer.sleep(1000)
        wait_for_module(module)
      some ->
        some
    end
  end
  def compile_modules(last_lst) do
    :timer.sleep(3500)
    case File.read(to_string(:code.priv_dir(:silverb))<>"/silverb/silverb") do
      {:ok, file} ->
        case :erlang.binary_to_term(file) do
          ^last_lst -> 
            data = Enum.reduce(last_lst, %{}, &(Map.put(&2, &1, wait_for_module(&1)))) |> IO.inspect |> :erlang.term_to_binary
            File.write!(to_string(:code.priv_dir(:silverb))<>"/silverb/modules_paths", data)
          new_lst ->
            compile_modules(new_lst)
        end
      _ ->
        compile_modules(last_lst)
    end
  end
end

defmodule Silverb.OnCompile.Receiver do
  @compile Silverb.OnCompile.compile_modules([])
end