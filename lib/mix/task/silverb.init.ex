defmodule Mix.Tasks.Silverb.Init do
	use Mix.Task
	@startfile "./start.sh"
	@makefile "./Makefile"
	def run(some) do
		dir = :os.cmd('pwd') |> to_string |> String.strip
		app = String.split(dir, "/") |> List.last
		case some do
			["rel"] -> 
				"""
				#!/bin/bash
				while true; do
					#{dir}/rel/#{app}/bin/#{app} console
					sleep 0.2
				done
				""" 
				|> make_file(@startfile)
				[] = :os.cmd('chmod a+x ./start.sh')
				"""
				clean:
					rm -rf #{:code.priv_dir(:silverb)}/silverb
					mix clean
					mix deps.clean --all
					rm -rf ./_build
				release:
					mix clean
					mix deps.get
					mix compile.protocols
					mix silverb.on
					mix silverb.check
					mix silverb.off
					mix release.clean --implode
					mix release
				"""
				|> make_file(@makefile)
			["iex"] ->
				"""
				#!/bin/bash
				mix clean
				mix deps.get
				mix compile.protocols
				while true; do
					iex --erl "+K true +A 32" -pa _build/dev/consolidated/ -S mix
					sleep 0.2
				done
				""" 
				|> make_file(@startfile)
				[] = :os.cmd('chmod a+x ./start.sh')
				"""
				clean:
					rm -rf #{:code.priv_dir(:silverb)}/silverb
					mix clean
					mix deps.clean --all
					rm -rf ./_build
				release:
					mix clean
					mix deps.get
					mix compile.protocols
					mix silverb.on
					mix silverb.check
				"""
				|> make_file(@makefile)
			_ -> 
				Silverb.Console.warn("usage : \"mix silverb.init rel\" | \"mix silverb.init iex\"")
		end
	end
	defp make_file(bin, fname) do
		case File.exists?(fname) do
			true ->  Silverb.Console.error("FAIL, #{inspect fname} file already exist")
			false -> File.touch!(fname)
					 Silverb.write_to_file(bin, fname)
					 Silverb.Console.notice("SUCCESS, #{inspect fname} file created")
		end
	end
end