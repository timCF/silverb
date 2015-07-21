defmodule Mix.Tasks.Silverb.Off do
	use Mix.Task
	def run(_) do
		case File.exists?(file) do
			true ->  Silverb.Console.warn("Silverb is OFF, file #{file} is already exist")
			false -> File.touch!(file)
					 Silverb.Console.warn("Silverb is OFF, file #{file} created")
		end
	end
	defp file, do: "#{:code.priv_dir(:silverb)}/silverb/off"
end