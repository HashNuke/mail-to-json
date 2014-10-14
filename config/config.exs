use Mix.Config

config :mail_to_json, :webhook_url, (System.get_env("M2J_WEBHOOK_URL") || "")
config :mail_to_json, :smtp_port,   (System.get_env("M2J_SMTP_PORT")   || 2525)
