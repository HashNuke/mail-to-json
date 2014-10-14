use Mix.Config

# This is where you want the JSON of the mail to be posted to
config :mail_to_json, :webhook_url, System.get_env("M2J_WEBHOOK_URL")

# The SMTP port to which we want our application to listen to
config :mail_to_json, :smtp_port,   (System.get_env("M2J_SMTP_PORT") || 2525)
