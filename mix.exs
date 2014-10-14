defmodule MailToJson.Mixfile do
  use Mix.Project

  def project do
    [app: :mail_to_json,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end


  def application do
    [applications: [:logger, :httpoison],
     mod: {MailToJson, []}]
  end


  defp deps do
    [
      {:eiconv,    github: "zotonic/eiconv"},
      {:gen_smtp,  github: "Vagabond/gen_smtp"},
      {:poison,    "~> 1.2.0"},
      {:httpoison, "~> 0.5.0"}
    ]
  end
end
