defmodule Mix.Tasks.Silverb.Check do
	use Mix.Task
	def run(_) do
		Silverb.check_modules
	end
end