defmodule Silverb do
  use Application
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
	check_modules
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
  	IO.puts "#{__MODULE__} : checking modules ... "
	Enum.each(:application.get_env(:silverb, :modules, nil), 
		fn(mod) ->
			case :xref.m(mod) do
				[deprecated: [], undefined: [], unused: []] -> IO.puts "#{__MODULE__} : module #{mod} is OK."
				some -> raise "#{__MODULE__} : fonded errors #{inspect some}"
			end
		end)
  end

  #
  #	amazing getting modules names on compile time
  #

  defmacro __using__(_) do
	quote location: :keep do
		@silverb Silverb.send_data(__MODULE__)
	end
  end

  def send_data(mod) do
  	dir =  :code.priv_dir(:silverb) |> to_string
  	try do
		:erlang.register(:silverb_worker, spawn fn() -> worker_func(dir<>"/silverb") end)
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

  defp worker_func(dir) do
  	receive do
  		{:silverb, mod, pid} -> 
			if not(File.exists?(dir)) do
				:ok = File.mkdir_p!(dir)
			end
			file = dir<>"/silverb.txt"
			if not(File.exists?(file)) do
				:ok = File.touch!(file)
			end
			case File.read!(file) do
				"" -> write_to_file([mod], file)
				bin -> write_to_file(Enum.uniq([mod|:erlang.binary_to_term(bin)]) , file)
			end
			send(pid, {:silverb, :ok})
  			worker_func(dir)
  	end
  end

  defp write_to_file(lst, file) do
  	data = :erlang.term_to_binary(lst)
  	{:ok, io} = :file.open(file, [:write])
  	:ok = :file.write(io, data)
  	:ok = :file.sync(io)
  	:ok = :file.close(io)
  end

end
