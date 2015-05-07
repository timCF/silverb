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
end
