# A quick and dirty MailGun clone in Elixir


## SMTP

[SMTP](http://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) is 8yrs older than me (the first RFC was in 1982). The API is simple:

* The program that handles the SMTP messages listens to a port.
* When the client is making a request to an SMTP server, the server maintains a session. Just like what a web browser does for a user today.
* The API request (what we could call it today) is made by sending a message with an SMTP verb following by data. Each request ends with a line break.
* The SMTP server _usually_ responds with a message that starts with an SMTP code followed by the message.

A typical request-response might look like the following:

```
DUDE whats up
200 I am fine
```

I made up that request-response. `DUDE` is not an SMTP verb. But there are many others like `HELO`, `RCPT`, `DATA`, etc.

> I apologize if I've convinced you that SMTP is very simple. There's much more to it. And our fellow humans have done great work to extend it by building stuff for it or on top of it. You can read more [here](http://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol#Related_Requests_For_Comments).


### Email as an API

SMTP is one of the oldest APIs. It has a very large user base and it still works. Want to share news about your new born? Shares sales report with your team? Invite people to a party?

Email works. What more? If you accept incoming mail from your users, it comes with free authentication :)

Sadly, setting up an SMTP server to handle incoming email still needs a great [bullet-proof guide](http://iafonov.github.io/blog/hardcore-email-infrastructure-setup.html). There are services like [MailGun](http://mailgun.com), [Postmark](http://postmarkapp.com), etc, that make it easier for developers to handle incoming mail for apps. They receive incoming mail on your behalf and POST them as JSON to your app.


## Building an SMTP server in Elixir

Since I started working on Erlang (and later on Elixir), I've been curious to try handling incoming mail with it. I've always believed that the nature of the language and the primitives that OTP provides makes it easy to build applications that can accept and process incoming mail. My luck turned gold when I hit upon an SMTP server example, within the source code of an Erlang library called [gen_smtp](https://github.com/Vagabond/gen_smtp/blob/master/src/smtp_server_example.erl).

I'll try and walk you through some code to understand (sufficiently) and hack it up to get a quick and dirty mail-to-json API up and running.


### Setting up a new Elixir project

At this point, I'll assume you have Elixir v1.0.1 installed, to be able to generate a new project using mix

```
mix new mail_to_json --sup
```

In your project's `mix.exs` file add the following libraries as dependencies:

* `gen_smtp` - (Erlang SMTP library
* `poison` - pure Elixir JSON parser
* `httpoison` - HTTP client for Elixir

It should look like the following:

```
defp deps do
  [
    {:gen_smtp,  github: "Vagabond/gen_smtp"},
    {:poison,    github: "devinus/poison"},
    {:httpoison, github: "edgurgel/httpoison"}
  ]
end
```

Also add `httpoison` to the application start list to ensure that it's started before your app

```
def application do
  [applications: [:logger, :httpoison],
   mod: {MailToJson, []}]
end
```

Fetch the dependencies by running the following command in your console

```
mix deps.get
```

Let's setup some options that can be configured in the app

```
use Mix.Config

config :mail_to_json, :webhook_url, "http://example.com/you/want"
config :mail_to_json, :smtp_port, 2525
```

We are now ready to add nut and bolts to get our stuff running



### Architecting the app

#### lib/mail_to_json.ex

```
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

end

```

#### lib/mail_to_json/smtp_server.ex

The `MailToJson.SmtpServer` module wraps `:gen_smtp_server.start/2`, so that it can be supervised

```
defmodule MailToJson.SmtpServer do

  def start_link do
    session_options = [ callbackoptions: [parse: true] ]
    :gen_smtp_server.start(MailToJson.SmtpHandler, [[port: smtp_port, sessionoptions: session_options]])
  end


  defp smtp_port do
    Application.get_env :mail_to_json, :smtp_port
  end
end
```
