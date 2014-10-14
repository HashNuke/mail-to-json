defmodule MailToJson do
  use Application

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

    send_mail(sender, recepients, "Hello World", "This is a test mail")
  end


  def send_mail(sender, recipients, subject, body) do
    host = :net_adm.localhost
    sender     = participant_email(sender)
    recipients = participant_emails(recipients)

    formatted_sender     = format_participant(sender)
    formatted_recipients = format_participants(recipients)
    formatted_mail_body  = mail_body(formatted_sender, formatted_recipients, subject, body)

    mail = {sender, recipients, formatted_mail_body}

    client_options = [relay: host, username: sender, password: "mypassword", port: 2525]
    :gen_smtp_client.send(mail, client_options)
  end


  defp mail_body(sender, recipients, subject, body) do
    'Subject: #{subject}\r\nFrom: #{sender}\r\nTo: #{recipients}\r\n\r\n#{body}'
  end


  defp participant_emails([]) do
    []
  end


  defp participant_emails([], collected_emails) do
    collected_emails
  end


  defp participant_emails([participant | participants], collected_emails \\ []) do
    new_collected_emails = [participant_email(participant) | collected_emails]
    participant_emails(participants, new_collected_emails)
  end


  defp participant_email({_name, email}) do
    email
  end


  defp participant_email(email) when is_binary(email) do
    email
  end


  defp format_participant({name, email}) do
    "#{name} <#{email}>"
  end


  defp format_participant(email) when is_binary(email) do
    email
  end


  defp format_participants([]) do
    []
  end


  defp format_participants([], formatted) do
    formatted
  end


  defp format_participants([participant | participants], formatted \\ []) do
    new_formatted = [format_participant(participant) | formatted]
    format_participants participants, new_formatted
  end


  def create_unique_id do
    ref_list = :erlang.now()
    |> :erlang.term_to_binary()
    |> :erlang.md5()
    |> :erlang.bitstring_to_list()

    :lists.flatten Enum.map(ref_list, fn(n)-> :io_lib.format("~2.16.0b", [n]) end)
  end


  def smtp_port do
    Application.get_env :mail_to_json, :smtp_port
  end


  def webhook_url do
    Application.get_env :mail_to_json, :webhook_url
  end
end
