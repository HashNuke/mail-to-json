# MailToJson

Receives email and forwards it to your app as a JSON webhook (aka simple half-assed [Mailgun](http://mailgun.com) clone).


## Setup

Assuming you have Erlang and Elixir installed.

* Install dependencies: `mix deps.get`
* Follow instructions in the `Notes` section to receive and send emails


## Notes

### To receive email

* Forward port `25` to port `2525` using IP tables.
  ```
  sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 25 -j REDIRECT --to-ports 2525
  ```
  You'll have to run the above command everytime or add it permanently to your iptables.


* To use a port other than `2525`, change the `smtp_port` option in `config/config.exs`. Default has been set to `2525`. Also reflect that in the above command.


### TODO To send email via this server

* TODO set valid emails in the config file and a password
* TODO set valid
