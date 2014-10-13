defmodule MailToJson.SmtpServer do

  def start_link do
    MailToJson.set_smtp_password
    session_options = [callbackoptions: [parse: true] ]
    :gen_smtp_server.start(MailToJson.SmtpHandler, [[port: smtp_port, sessionoptions: session_options]])
  end


  defp smtp_port do
    Application.get_env :mail_to_json, :smtp_port
  end
end
