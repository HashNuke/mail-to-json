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

    send_mail(sender, recipients, subject, body)
  end


  def send_mail(sender, recipients, subject, body) do
    sender    = participant_email(sender)
    recipients = participant_emails(recipients)

    formatted_sender     = format_participant(sender)
    formatted_recipients = format_participants(recipients) |> Enum.join(", ")
    formatted_mail_body  = mail_body(formatted_sender, formatted_recipients, subject, body)

    client_options = [relay: host, username: sender, password: "mypassword", port: 2525]
    :gen_smtp_client.send(mail, client_options)
  end


  defp mail_body(subject, sender, recipients, body) do
    "Subject: #{subject}\r\nFrom: #{sender}\r\nTo: #{recipients}\r\n\r\n#{body}"
  end


  defp participant_emails([], collected_emails) do
    collected_emails
  end


  defp participant_emails([recipient | recipients], collected_emails) do
    new_collected_emails = [participant_email(recipient) | collected_emails]
    participant_emails(recipient, new_collected_emails)
  end


  defp participant_email({name, email}) do
    email
  end


  defp participant_email(email) when is_binary(email) do
    email
  end


  defp format_participant({name, email}) do
    "#{name} <#{email}>"
  end


  defp format_participant(email) when is_binary(participant_email) do
    participant_email
  end


  defp format_recipients([], formatted_recipients) do
    formatted_recipients
  end


  defp format_recipients([recipient | recipients], formatted_recipients) do
    new_formatted_recipients = [format_recipient(recipient) | format_recipients]
    format_recipients recipients, new_formatted_recipients
  end
end
