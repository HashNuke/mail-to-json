# MailToJson

Receives email and forwards it to your app as a JSON webhook (aka stripped down [MailGun](http://mailgun.com) clone).


## Install application

Assuming you have Erlang and Elixir installed.

* Install dependencies:
  ```shell
  $ mix deps.get
  ```
* Set the webhook url by setting system env var `M2J_WEBHOOK_URL`
  ```shell
  export M2J_WEBHOOK_URL="http://example.com/foo/bar"
  ```
* Follow the next section to be able to receive mail on your server
* Start server with Elixir console: `iex -S mix`


## Setup to receive mail

#### Local setup

Forward port 25 to 2525 on your server

* For linux
  ```shell
  # You'll have to run the above command everytime you start the computer
  # or add it permanently to your iptables.
  $ sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 25 -j REDIRECT --to-ports 2525
  ```
* For Mac (I think this works. Please send a PR if it's wrong)
  ```shell
  sudo ipfw add fwd 127.0.0.1,25 tcp from me to 127.0.0.1 dst-port 2525
  ```

#### Remote setup (vps and such)

Follow the local setup instructions and along with the following:

* Let's assume that you want to receive mail on the domain `foo.example.com`
* Note the IP address of your server
* Add the following DNS records for `example.com`
  * Add an `A record` with the IP address of your server, that points to `foo.example.com`
  * Add an `MX record` with the value `foo.example.com`


## Playing with it

You can send a test mail from your local computer from the Elixir shell itself by running `MailToJson.test_mail`. You should receive a log message on the shell and also a POST request at the webhook url you configured.

The JSON data in the webhook POST request will look like this:

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

## Caveats

* No security
* No myriad of configuration
* Doesn't handle attachments

## License

Copyright &copy; 2014, Akash Manohar J, under the MIT License

Basically, do whatever you want with it
