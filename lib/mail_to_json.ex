defmodule MailToJson do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(MailToJson.SmtpHandler, [], restart: :transient)
    ]

    opts = [strategy: :one_for_one, name: MailToJson.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
