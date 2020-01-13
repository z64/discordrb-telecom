require "discordrb"

class Discordrb::Bot
  def voice(thing)
    id = thing.resolve_id
    return @voices[id] if @voices[id]

    channel = channel(id)
    return nil unless channel

    server_id = channel.server.id
    return @voices[server_id] if @voices[server_id]

    nil
  end

  def voice_connect(chan)
    chan = channel(chan.resolve_id)
    raise(ArgumentError, "Voice channel not found") unless chan
    raise(ArgumentError, "Channel is not a voice channel") unless chan.voice?
    guild_id = chan.server.id

    @telecom_sessions ||= {}
    if @telecom_sessions[guild_id]
      debug("(Telecom) Voice bot exists already! Recreating it")
      client = @telecom_sessions.delete(guild_id)
      client.destroy
    end
    client = @telecom_sessions[guild_id] = Telecom::Client.new(self)

    @gateway.send_voice_state_update(guild_id, chan.id, false, false)
    sleep(0.05) until client.connected?
    debug("(Telecom) Voice connected succeded!")
    client
  end

  def voice_destroy(server)
    guild_id = server.resolve_id

    @telecom_sessions ||= {}
    telecom_session = @telecom_sessions.delete(guild_id)
    if telecom_session
      @gateway.send_voice_state_update(guild_id, nil, false, false)
      telecom_session.destroy
    end
  end

  def update_voice_state(data)
    guild_id = data["guild_id"].to_i
    server = server(guild_id)
    return unless server

    user_id = data["user_id"].to_i
    previous_voice_state = server.voice_states[user_id]
    previous_channel_id = previous_voice_state.voice_channel.id if previous_voice_state
    server.update_voice_state(data)

    @telecom_sessions ||= {}
    telecom_session = @telecom_sessions[guild_id]
    if user_id == @profile.id && telecom_session
      if data["channel_id"]
        telecom_session.update_state_info(user_id, guild_id, data["session_id"])
      else
        voice_destroy(guild_id)
      end
    end

    previous_channel_id
  end

  def update_voice_server(data)
    guild_id = data["guild_id"].to_i
    @telecom_sessions ||= {}
    telecom_session = @telecom_sessions[guild_id]
    return unless telecom_session

    token = data["token"]
    endpoint = data["endpoint"]
    telecom_session.update_server_info(endpoint, token)
  end
end
