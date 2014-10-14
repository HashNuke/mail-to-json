defmodule MailToJson.SmtpServer do

  def start_link do
    session_options = [ callbackoptions: [parse: true] ]
    :gen_smtp_server.start(MailToJson.SmtpHandler, [[port: MailToJson.smtp_port, sessionoptions: session_options]])
  end

end
