defmodule MailToJson.SmtpHandler do
  @behaviour :gen_smtp_server_session

  alias MailToJson.SmtpHandler.State

  @relay true
  @type error_message :: {:error, String.t, State.t}


# %% @doc Initialize the callback module's state for a new session.
# %% The arguments to the function are the SMTP server's hostname (for use in the SMTP anner),
# %% The number of current sessions (eg. so you can do session limiting), the IP address of the
# %% connecting client, and a freeform list of options for the module. The Options are extracted
# %% from the `callbackoptions' parameter passed into the `gen_smtp_server_session' when it was
# %% started.
# %%
# %% If you want to continue the session, return `{ok, Banner, State}' where Banner is the SMTP
# %% banner to send to the client and State is the callback module's state. The State will be passed
# %% to ALL subsequent calls to the callback module, so it can be used to keep track of the SMTP
# %% session. You can also return `{stop, Reason, Message}' where the session will exit with Reason
# %% and send Message to the client.
  @spec init(binary, non_neg_integer, tuple, list) :: {:ok, String.t, State.t} | {:stop, any, String.t}
  def init(hostname, session_count, address, options) do
    :io.format("peer: ~p~n", [address])
    case session_count > 20 do
      false ->
        banner = [hostname, " ESMTP smtp_server_example"]
        state = %State{options: options}
        IO.inspect state
        {:ok, banner, state}
      true ->
        :io.format("Connection limit exceeded~n")
        {:stop, :normal, ["421 ", hostname, " is too busy to accept mail right now"]}
    end
  end


  @doc """
  Handshake with the client

    * Return `{:ok, max_message_size, state}` if we handle the hostname
      ```
      # max_message_size should be an integer
      # For 10kb max size, the return value would look like this
      {:ok, 1024 * 10, state}
      ```
    * Return `{:error, error_message, state}` if we don't handle mail for the hostname
      ```
      # error_message must be prefixed with standard SMTP error code
      # looks like this
      554 invalid hostname
      554 Dear human from Sector-8614 we don't handle mail for this domain name
      ```
  """
  @spec handle_HELO(binary, State.t) :: {:ok, pos_integer, State.t} | {:ok, State.t} | error_message
  def handle_HELO(hostname, state) do
    :io.format("250 HELO from #{hostname}~n")
    {:ok, 655360, state} # we'll say 640kb of max size
  end


  @spec handle_EHLO(binary, list, State.t) :: {:ok, list, State.t} | error_message
  def handle_EHLO(_hostname, extensions, state) do
    my_extensions = case (state.options[:auth] || false) do
      true ->
        extensions ++ [{"AUTH", "PLAIN LOGIN CRAM-MD5"}, {"STARTTLS", true}]
      false ->
        extensions
    end
    {:ok, my_extensions, state}
  end


  # %% Return values are either `{ok, State}' or `{error, Message, State}' as before.
  @spec handle_MAIL(binary, State.t) :: {:ok, State.t} | error_message
  def handle_MAIL(sender, state) do
    IO.inspect "Got mail"
    IO.inspect sender
    :io.format("Mail from ~s~n", [sender])
    # you can accept or reject the FROM address here
    {:ok, state}
  end


  # @doc Handle an extension to the MAIL verb. Return either `{ok, State}' or `error' to reject
  # the option.
  @spec handle_MAIL_extension(binary, State.t) :: {:ok, State.t} | :error
  def handle_MAIL_extension("X-SomeExtension" = extension, state) do
    :io.format("Mail from extension ~s~n", [extension])
    # any MAIL extensions can be handled here
    {:ok, state}
  end

  def handle_MAIL_extension(extension, _state) do
    :io.format("Unknown MAIL FROM extension ~s~n", [extension])
    :error
  end


  @spec handle_RCPT(binary(), State.t) :: {:ok, State.t} | {:error, String.t, State.t}
  def handle_RCPT("nobody@example.com", state) do
    {:error, "550 No such recipient", state}
  end

  def handle_RCPT(to, state) do
    :io.format("Mail to ~s~n", [to])
    # you can accept or reject RCPT TO addesses here, one per call
    {:ok, state}
  end


  @spec handle_RCPT_extension(binary, State.t) :: {:ok, State.t} | :error
  def handle_RCPT_extension("X-SomeExtension" = extension, state) do
    # any RCPT TO extensions can be handled here
    :io.format("Mail to extension ~s~n", [extension])
    {:ok, state}
  end

  def handle_RCPT_extension(extension, _state) do
    :io.format("Unknown RCPT TO extension ~s~n", [extension])
    :error
  end


  @spec handle_DATA(binary, [binary,...], binary, State.t) :: {:ok, String.t, State.t} | {:error, String.t, State.t}
  def handle_DATA(_from, _to, "", state) do
    {:error, "552 Message too small", state}
  end

  def handle_DATA(from, to, data, state) do
    unique_id = MailToJson.create_unique_id()
    relay = :proplists.get_value(:relay, state.options, false)

    cond do
      relay == true -> relay_mail(from, to, data)
      relay == false ->
        :io.format("message from ~s to ~p queued as ~s, body length ~p~n", [from, to, unique_id, byte_size(data)])
        if :proplists.get_value(:parse, state.options, false) do
          parse_mail(data, state, unique_id)
        end
    end

    # At this point, if we return ok, we've accepted responsibility for the email
    {:ok, unique_id, state}
  end


  @spec handle_RSET(State.t) :: State.t
  def handle_RSET(state) do
    state # reset any relevant internal state
  end

  @spec handle_VRFY(binary, State.t) :: {:ok, String.t, State.t} | {:error, String.t, State.t}
  def handle_VRFY("someuser", state) do
    {:ok, "someuser@#{:smtp_util.guess_FQDN()}", state}
  end

  def handle_VRFY(_address, state) do
    {:error, "252 VRFY disabled by policy, just send some mail", state}
  end

  @spec handle_other(binary, binary, State.t) :: {String.t, State.t}
  def handle_other(verb, _args, state) do
    {["500 Error: command not recognized : '", verb, "'"], state}
  end

  # this callback is OPTIONAL
  # it only gets called if you add AUTH to your ESMTP extensions
  # @spec handle_AUTH('login' | 'plain' | 'cram-md5', binary, binary | {binary, binary}, State.t) :: {:ok, State.t} | :error
  # def handle_AUTH(type, "username", "PaSSw0rd", state) when type =:= login; type =:= plain do
  #   {ok, state}
  # end

  def handle_AUTH('cram-md5', "username", {_digest, seed}, state) do
    IO.inspect "AUTH CRAM ERROR"
    case :smtp_util.compute_cram_digest("PaSSw0rd", seed) do
      _digest ->
        {:ok, state}
      # _ ->  # never comes to this, because previous case matches all
      #   :error
    end
  end

  def handle_AUTH(_type, _username, _password, _state) do
    IO.inspect "AUTH ERROR"
    :error
  end

  # this callback is OPTIONAL
  # it only gets called if you add STARTTLS to your ESMTP extensions
  @spec handle_STARTTLS(State.t) :: State.t
  def handle_STARTTLS(state) do
    :io.format("TLS Started~n")
    state
  end

  @spec terminate(any, State.t) :: {:ok, any, State.t}
  def terminate(reason, state) do
    {:ok, reason, state}
  end


  # Internal Functions

  defp parse_mail(data, state, unique_id) do
    try do
      IO.inspect :mimemail.decode(data)
    rescue
      reason ->
        :io.format("Message decode FAILED with ~p:~n", [reason])
    end
  end


  defp relay_mail(_, [], _) do
    :ok
  end

  defp relay_mail(from, [to|rest], data) do
    [_user, host] = String.split(to, "@")
    :gen_smtp_client.send({from, [to], :erlang.binary_to_list(data)}, [relay: host])
    relay_mail(from, rest, data)
  end

end
