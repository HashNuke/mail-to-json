defmodule MailToJson do
  use Application

  alias MailToJson.Utils

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(MailToJson.SmtpServer, [], restart: :transient)
    ]

    opts = [strategy: :one_for_one, name: MailToJson.Supervisor]
    Supervisor.start_link(children, opts)
  end


  def test_mail() do
    host = :net_adm.localhost
    recepients = [{"Jane", "jane@#{host}"}]
    sender = {"John Doe", "john@#{host}"}

    Utils.send_mail(sender, recepients, "Hello World", "This is a test mail")
  end


  def config(name) do
    Application.get_env :mail_to_json, name
  end

end
