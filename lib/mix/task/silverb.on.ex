defmodule Mix.Tasks.Silverb.On do
	use Mix.Task
	def run(_) do
		case File.exists?(file) do
			true ->  File.rm!(file)
					 Silverb.Console.notice("Silverb is ON, file #{file} deleted")
			false -> Silverb.Console.notice("Silverb is ON, file #{file} is not exist")
		end
	end
	defp file, do: "#{:code.priv_dir(:silverb)}/silverb/off"
end