defmodule Silverb do
  use Application
  @modules :application.get_env(:silverb, :modules, nil)
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(Silverb.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Silverb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defmacro __using__(_) do
	quote location: :keep do
		defmodule unquote(List.first(@modules)).Silverb do
			@check_process Silverb.check_modules
		end
	end
  end

  def check_modules do
	Enum.each(@modules, 
		fn(mod) ->
			case :xref.m(mod) do
				[deprecated: [], undefined: [], unused: []] -> IO.puts "#{__MODULE__} : module #{mod} is OK."
				some -> raise "#{__MODULE__} : fonded errors #{inspect some}"
			end
		end)
  end
end
