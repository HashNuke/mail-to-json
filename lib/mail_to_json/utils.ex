defmodule MailToJson.Utils do

  def send_mail(sender, recipients, subject, body) do
    host = :net_adm.localhost
    sender     = participant_email(sender)
    recipients = participant_emails(recipients)

    formatted_sender     = format_participant(sender)
    formatted_recipients = format_participants(recipients)
    formatted_mail_body  = mail_body(formatted_sender, formatted_recipients, subject, body)

    mail = {sender, recipients, formatted_mail_body}

    client_options = [relay: host, username: sender, password: "anything", port: 2525]
    :gen_smtp_client.send(mail, client_options)
  end


  defp mail_body(sender, recipients, subject, body) do
    'Subject: #{subject}\r\nFrom: #{sender}\r\nTo: #{recipients}\r\n\r\n#{body}'
  end


  def participant_emails([]),            do: []
  def participant_emails([], collected), do: collected

  def participant_emails([participant | participants], collected \\ []) do
    new_collected = [participant_email(participant) | collected]
    participant_emails(participants, new_collected)
  end


  def participant_email({_name, email}),              do: email
  def participant_email(email) when is_binary(email), do: email


  def format_participant({name, email}), do: "#{name} <#{email}>"
  def format_participant(email) when is_binary(email), do: email


  def format_participants([]),            do: []
  def format_participants([], formatted), do: formatted

  def format_participants([participant | participants], formatted \\ []) do
    new_formatted = [format_participant(participant) | formatted]
    format_participants participants, new_formatted
  end


  def parse_participants(participants) when is_binary(participants) do
    String.split(participants)
    parse_participants(participants, [])
  end


  def parse_participants([], parsed) do
    parsed
  end

  def parse_participants([participant | participants], parsed) do
    participant = String.strip(participant)
    new_parsed = [ parse_participant(participant) | parsed ]
    parse_participants(participants, new_parsed)
  end


  def parse_participant(participant) do
    parts = String.split(participant, "<")
    case length(parts) do
      1 -> %{email: participant}
      2 ->
        email = List.last(parts)
        |> String.split(">")
        |> hd
        |> String.strip()
        name = hd(parts) |> String.strip
        %{name: name, email: email}
    end
  end


  def create_unique_id do
    ref_list = :erlang.now()
    |> :erlang.term_to_binary()
    |> :erlang.md5()
    |> :erlang.bitstring_to_list()

    :lists.flatten Enum.map(ref_list, fn(n)-> :io_lib.format("~2.16.0b", [n]) end)
  end
end
