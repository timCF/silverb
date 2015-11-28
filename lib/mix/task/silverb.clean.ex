defmodule Mix.Tasks.Silverb.Clean do
	use Mix.Task
	def run(_) do
		case File.exists?(file) do
			true ->
				:ok = File.rm!(file)
				Silverb.Console.notice("Silverb cleaned, file #{file} deleted")
			false ->
				Silverb.Console.warn("Silverb clean is not need , file #{file} is not exist")
		end
	end
	defp file, do: "#{:code.priv_dir(:silverb)}/silverb/silverb"
end
