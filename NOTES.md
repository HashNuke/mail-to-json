A quick and dirty Mailgun clone in Elixir

> If you want to go straight to the source code, [here it is](https://github.com/HashNuke/mail-to-json) ~!

## Email as an API

Email is one of the oldest social networks. It has a very large user base and it still works. Want to share news about your new born? Share sales report with your team? Invite people to a party?

Email works. What more? If you accept incoming mail from your users, it comes with free authentication.

## SMTP - the protocol that powers Email

[SMTP](http://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) is eight years older than me (the first RFC was in 1982). The API is simple:

* The program that handles the SMTP messages listens to a port.
* When the client is making a request to an SMTP server, the server maintains a session. Just like what a web browser does for a user today.
* The API request (what we could call it today) is made by sending a message with an SMTP verb following by data. Each request ends with a line break.
* The SMTP server _usually_ responds with a message that starts with an SMTP code followed by the message.

A typical request-response might look like the following:

    DUDE whats up
    200 I am fine

I made up that request-response. `DUDE` is not an SMTP verb. But there are many others like `HELO`, `RCPT`, `DATA`, etc.

> I apologize if I've convinced you that SMTP is very simple. There's much more to it. And our fellow humans have done great work to extend it by building stuff for it or on top of it. You can read more [here](http://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol#Related_Requests_For_Comments).

Sadly, setting up an SMTP server to handle incoming email still needs a great [bullet-proof guide](http://iafonov.github.io/blog/hardcore-email-infrastructure-setup.html). There are services like [MailGun](http://mailgun.com), [Postmark](http://postmarkapp.com), etc, that make it easier for developers to handle incoming mail for apps. They receive incoming mail on your behalf and POST them as JSON to your app.

## Building an SMTP server in Elixir

Since I started working on Erlang (and later on Elixir), I've been curious to try handling incoming mail with it. I've always believed that the nature of the language and the primitives that OTP provides makes it easy to build applications that can accept and process incoming mail. My luck turned gold when I hit upon an SMTP server example, within the source code of an Erlang library called [`gen_smtp`](https://github.com/Vagabond/gen_smtp/blob/master/src/smtp_server_example.erl).

I'll try and walk you through some code to (sufficiently) understand and hack it up to get a quick and dirty `mail-to-json` API up and running.

## Generating a new Elixir mix project

At this point, I'll assume you have Elixir v1.0.1 installed, to be able to generate a new project using mix:

```shell
$ mix new mail_to_json --sup
```

Once we are done with this walkthrough, this is what the structure of the project would look like:

```
mail_to_json
├── README.md
├── config
│   └── config.exs
├── lib
│   ├── mail_to_json
│   │   ├── mail_parser.ex
│   │   ├── smtp_handler
│   │   │   └── state.ex
│   │   ├── smtp_handler.ex
│   │   ├── smtp_server.ex
│   │   └── utils.ex
│   └── mail_to_json.ex
├── mix.exs
└── mix.lock
```

## Adding dependencies

In your project's `mix.exs` file add the following libraries as dependencies:

* `eiconv` - Erlang library that interfaces with [iconv](http://en.wikipedia.org/wiki/Iconv) using NIFs
* `gen_smtp` - Erlang SMTP library
* `poison` - pure Elixir JSON parser
* `httpoison` - HTTP client for Elixir

Your `deps/0` function in `mix.exs` should look like the following:

```elixir
defp deps do
  [
    {:eiconv,    github: "zotonic/eiconv"},
    {:gen_smtp,  github: "Vagabond/gen_smtp"},
    {:poison,    "~> 1.2.0"},
    {:httpoison, "~> 0.5.0"}
  ]
end
```

The setup for `httpoison`, requires that it be added to the application start list in `mix.exs`. This is to ensure that it is started and ready for our application to use.

```elixir
def application do
  [applications: [:logger, :httpoison],
   mod: {MailToJson, []}]
end
```

## Fetch dependencies

When within the project directory, run the following command to fetch the dependencies.

```shell
$ mix deps.get
```

## Configuration options

* When the app receives an email, we want it to post a JSON webhook to a particular URL.
* We want to tell the app which port to listen for emails on.

For these two, we'll setup configuration options in the `config/config.exs` file. This file is read when Mix starts the project.

```elixir
use Mix.Config

# This is where you want the JSON of the mail to be posted to
config :mail_to_json, :webhook_url,
  System.get_env("M2J_WEBHOOK_URL")

# The SMTP port to which we want our application to listen to
config :mail_to_json, :smtp_port,
  System.get_env("M2J_SMTP_PORT") || 2525
```

These configuration options are read from system environment variables. Now when we want to set the webhook URL to which JSON data is to be posted, we just have to set the `M2J_WEBHOOK_URL` system environment variable.

### Forwarding mail to port 2525

Most servers receive mail at port 25. In order to avoid having to run the app with `sudo`, our app listens to 2525. So we'll have to forward traffic from port 25 to port 2525.

On Ubuntu, this can be done by the following command:

```shell
$ sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 25 -j REDIRECT --to-ports 2525
```

To be able to receive mail on a remote server, you'll also need to setup DNS records. Refer to the [readme](https://github.com/HashNuke/mail-to-json/blob/b12de94cb966a99039d081e8fc3c794b770974eb/README.md#setup-receiving-mail) for detailed instructions.

## The app

We are now ready to add the nuts and bolts to get our stuff running.

### `MailToJson` - the module where everything begins

*File*: `lib/mail_to_json.ex`

`MailToJson.start/2` is called by OTP to start our app. Most of this module is pretty standard and generated by `mix` when you create the project. To the list of `children`, we add our `MailToJson.SmtpServer` module to be started as a worker.

The following line in the `start/2` function...

```elixir
children = []
```

becomes...

```elixir
children = [
  worker(MailToJson.SmtpServer, [], restart: :transient)
]
```

We'll also add a function to allow reading configuration options:

```elixir
def config(name) do
  Application.get_env(:mail_to_json, name)
end
```

### A module to wrap `:gen_smtp_server`

*File*: `lib/mail_to_json/smtp_server.ex`

`MailToJson.SmtpServer` being added as a worker in the above file means the `start_link/0` function will be called. It will also expect that the return value of the function is a pid.

The `start_link/0` function wraps `:gen_smtp_server.start/2`, so that it can be supervised. We pick the SMTP port to listen to from the application configuration.

For now we assume that `MailToJson.SmtpHandler` is the module that handles the SMTP callbacks that `:gen_smtp_server` requires. The following is what `lib/mail_to_json/smtp_server.ex` would look like:

```elixir
defmodule MailToJson.SmtpServer do

  def start_link do
    session_options = [callbackoptions: [parse: true]]
    smtp_port = MailToJson.config(:smtp_port)
    smtp_server_options = [[port: smtp_port,
                            sessionoptions: session_options]]
    :gen_smtp_server.start(MailToJson.SmtpHandler,
                           smtp_server_options)
  end

end
```

### A struct to hold the SMTP session state

*File*: `lib/mail_to_json/smtp_handler/state.ex`

We'll need a struct to hold state through functions. For now we'll define only an options field. The following is what it would look like:

```elixir
defmodule MailToJson.SmtpHandler.State do
  defstruct options: []
end
```

### A handler that defines callbacks for `:gen_smtp_server`

*File*: `lib/mail_to_json/smtp_handler.ex`

`MailToJson.SmtpHandler` module is pretty large but it is simple. In the beginning we have certain module attributes defined in order to make SMTP error codes readable.

#### init/4

This function is called by `gen_smtp` when a new mail arrives. It initializes a new session to serve the client. It is passed the following arguments:

* `hostname` - the SMTP server's hostname
* `session_count` - number of mails currently being handled. We can then choose to reject the current mail session based on this.
* `client_ip_address` - IP address of the client
* `options` - the `callbackoptions` passed to `:gen_smtp_server.start/2`

The return value should be the banner that is shown to the client. This is sort of the welcome banner. You can display anything you want.

```elixir
def init(hostname, _session_count, _client_ip_address, options) do
  banner = [hostname, " mail-to-json server"]
  state  = %State{options: options}
  {:ok, banner, state}
end
```

#### handle_HELO/2

As soon as the client successfully connects. It sends a `HELO` message. This function handles the `HELO` message. We just reply with our response.

```elixir
def handle_HELO(hostname, state) do
  # This is how we respond to the client
  :io.format("#{@smtp_requested_action_okay} HELO from #{hostname}~n")

  # We return the max size of the mail the that we will allow the
  # client to send
  {:ok, 10 * 1024, state}
end
```

#### handle_EHLO/2

This allows servers to respond with the ESMTP extensions that the SMTP server supports. We support nothing extra.

```elixir
def handle_EHLO(_hostname, extensions, state) do
  {:ok, extensions, state}
end
```

#### handle_MAIL/2

Accept or reject mail from addresses here. We'll allow all senders to send us mail.

```elixir
def handle_MAIL(_sender, state) do
  {:ok, state}
end
```

#### handle_VRFY/2

Accept mail only for the accounts that exist in the system. We'll just say that all accounts are valid. And return the email address of any account passed.

```elixir
def handle_VRFY(user, state) do
  fqdn = :smtp_util.guess_FQDN()
  {:ok, "#{user}@#{fqdn}", state}
end
```

> Some internet reading suggests that the `VRFY` SMTP verb may be used as a security hole to guess which user accounts exist in the system.

#### handle_RCPT/2

Responds to the client with a receipt that the mail to the recipient was received and handled. We'll say yes :)

```elixir
def handle_RCPT(_to, state) do
  {:ok, state}
end
```

#### handle_DATA/4

Handle data from the mail. We'll parse the mail here and send a `POST` request to the webhook url with the JSON data.

```elixir
def handle_DATA(from, to, data, state) do
  # Each mail thread needs a unique ID. We'll generate one here
  unique_id = Utils.create_unique_id()

  # parse_mail uses gen_smtp's mimemail module to parse the mail
  # Then uses the MailToJson.MailParser module to generate nice JSON
  mail = parse_mail(data, state, unique_id)
  mail_json = Poison.encode!(mail)

  webhook_url = MailToJson.config(:webhook_url)
  HTTPoison.post(webhook_url, mail_json, %{
    "Accept" => "application/json"
  })

  {:ok, unique_id, state}
end
```


On the whole, the `MailToJson.SmtpHandler` looks like [this](https://github.com/HashNuke/mail-to-json/blob/5641df4d4eff817bd3601764f3db36afccdb0080/lib//mail_to_json/smtp_handler.ex).


### JSON data in the webhook

The JSON data that is POSTed to the webhook url will look like this:

```javascript
{
  "From": {
    "name": "John Doe",
    "email": "john@example.com"
  },
  "To": [
    {
      "name": "Jane Doe",
      "email": "jane@example.com"
    }
  ],
  "Subject": "Hello subject",
  "plain_body": "Hello body\r\n",
  "html_body": "<div dir=\"ltr\">Hello body</div>\r\n",
  "Date": "Thu, 16 Oct 2014 19:33:12 +0530",
  "Message-ID": "<CAEy2aia+pK5k3UqdcEPqB2JiLCRMQvyBWXtOAbV3Wmuo2QBtog@mail.gmail.com>"
}
```


### Other miscellaneous modules and functions

* [MailToJson.MailParser](https://github.com/HashNuke/mail-to-json/blob/5641df4d4eff817bd3601764f3db36afccdb0080/lib/mail_to_json/mail_parser.ex) module - To handle parsing mail data that is handed to us by `gen_smtp`, we have a . This is responsible for handing us an Elixir map of data, that we can encode to JSON

* [MailToJson.Utils](https://github.com/HashNuke/mail-to-json/blob/5641df4d4eff817bd3601764f3db36afccdb0080/lib/mail_to_json/utils.ex) module The above required some utility functions in `lib/mail_to_json/utils.ex`.

* `MailToJson.send_mail/4` - added this in order to send email in a sane way.

* `MailToJson.test_mail/0` - added this as a short-hand to send test mails from and to localhost itself. This helps in testing and development.

## Closing notes

There's no security. There's no myriad of configuration options. We don't yet handle attachments. My console screams a few warnings about unimplemented functions for the `:gen_smtp_server_session` behaviour. But...

**We built it!**

We can handle HTML and plain text emails.

This is bare-bones and under 300 lines of code. Along with primitives that come with OTP itself, Erlang and Elixir libraries have made it very easy for us to build a stripped down version of a relatively complex service.

## Reference

* [SMTP commands](http://the-welters.com/professional/smtp.html)
* [SMTP error codes](http://www.greenend.org.uk/rjk/tech/smtpreplies.html)
