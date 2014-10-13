defmodule MailToJson.SmtpHandler do
  @behaviour :gen_smtp_server_session

  require Logger
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


  @doc """
  Accept receipt of mail to an email address or reject it

    * Return `{:ok, state}` to accept
    * Return `{:error, error_message, state}` to reject
  """
  @spec handle_RCPT(binary(), State.t) :: {:ok, State.t} | {:error, String.t, State.t}
  def handle_RCPT(to, state) do

    {:ok, state}
  end


  @spec handle_DATA(binary, [binary,...], binary, State.t) :: {:ok, String.t, State.t} | {:error, String.t, State.t}
  def handle_DATA(_from, _to, "", state) do
    {:error, "552 Message too small", state}
  end

  def handle_DATA(from, to, data, state) do
    unique_id = MailToJson.create_unique_id()
    relay = state.options[:relay] || false

    cond do
      relay == true -> relay_mail(from, to, data)
      relay == false ->
        Logger.debug("Message from #{from} to #{to} with body length #{byte_size(data)} queued as #{unique_id}")
        mail = parse_mail(data, state, unique_id)
    end

    {:ok, unique_id, state}
  end


  @doc "Reset internal state"
  @spec handle_RSET(State.t) :: State.t
  def handle_RSET(state) do
    state
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


  @spec terminate(any, State.t) :: {:ok, any, State.t}
  def terminate(reason, state) do
    {:ok, reason, state}
  end



  defp parse_mail(data, state, unique_id) do
    try do
      {content_type_name, content_subtype_name, mail_meta, _, body} = :mimemail.decode(data)
      %{
        content_type: "#{content_type_name}/#{content_subtype_name}",
        to:      :proplists.get_value("To", mail_meta),
        from:    :proplists.get_value("From", mail_meta),
        subject: :proplists.get_value("Subject", mail_meta),
        body: body
      }
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
