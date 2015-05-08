defmodule Silverb do
  use Application
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    case File.exists?("#{:code.priv_dir(:silverb)}/silverb/off") do
		true -> ReleaseManager.Utils.warn "#{__MODULE__} : swithed off, pass checks ..."
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
  	ReleaseManager.Utils.info "#{__MODULE__} : checking modules ... "
	Enum.each("#{:code.priv_dir(:silverb)}/silverb/silverb" |> File.read! |> :erlang.binary_to_term, 
		fn(mod) ->
			case :xref.m(mod) do
				[deprecated: [], undefined: [], unused: _] -> ReleaseManager.Utils.debug "#{__MODULE__} : module #{mod} is OK."
				some -> raise "#{__MODULE__} : found errors #{inspect some}"
			end
			case mod.silverb do
				true -> ReleaseManager.Utils.debug "#{__MODULE__} : module #{mod} attrs are OK."
				false -> raise "#{__MODULE__} : attrs are out of date, recompile module!"
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
	  {this_attr = <<"@",_::binary>>, this_expr}, %{attrs: nil, checks: nil} ->
	  	this_value = Code.eval_quoted(this_expr) |> elem(0)
        %{
          attrs:  quote location: :keep do
                    unquote(Code.string_to_quoted!("#{this_attr} #{inspect this_value}"))
                  end,
          checks: quote location: :keep do
          			(unquote(Macro.escape(this_value)) == unquote(this_expr))
                  end
        }
      {this_attr = <<"@",_::binary>>, this_expr}, %{attrs: attrs, checks: checks} ->
        this_value = Code.eval_quoted(this_expr) |> elem(0)
        %{
          attrs:  quote location: :keep do
          			unquote(attrs)
                    unquote(Code.string_to_quoted!("#{this_attr} #{inspect this_value}"))
                  end,
          checks: quote location: :keep do
          			unquote(checks) and (unquote(Macro.escape(this_value)) == unquote(this_expr))
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
		1000 -> raise "#{mod} not received ans from silverb_worker"
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
end