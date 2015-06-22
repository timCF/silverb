defmodule Silverb.Mixfile do
  use Mix.Project

  def project do
    [app: :silverb,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: 	 [	
    				 	:logger,
    				 	:tools,
    				 	:exrm,
    				 	:exutils
    				 ],
     mod: {Silverb, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [	
    	{:exrm, github: "bitwalker/exrm", tag: "bebc97c7707b6019a2790132b16653418f25afdc", override: true},
    	{:exutils, github: "timCF/exutils"}
    ]
  end
end
