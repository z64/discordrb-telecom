require "ffi"
require "./src/discordrb_bot"

# @!visibility private
module LibTelecom
  extend FFI::Library
  ffi_lib(["telecom.so", "telecom.a", "vendor/telecom/telecom.so", "vendor/telecom/telecom.a"])
  attach_function(:setup_logging, :telecom_setup_logging, [:bool, :bool], :void)
  attach_function(:create_client, :telecom_create_client, [:string, :string, :string], :pointer)
  attach_function(:destroy_client, :telecom_client_destroy, [:pointer], :void)
  attach_function(:update_server_info, :telecom_client_update_server_info, [:pointer, :string, :string], :void)
  attach_function(:play, :telecom_client_play, [:pointer, :pointer], :void)
  attach_function(:create_avconv_playable, :telecom_create_avconv_playable, [:string], :pointer)
  attach_function(:destroy_avconv_playable, :telecom_playable_destroy, [:pointer], :void)
end

# Logging is silenced by default to match discordrb's current logging policies.
# If your bot is in debug logging mode, this will automatically be changed.
LibTelecom.setup_logging(false, false)

module Telecom
  # @param enabled [true, false]
  # @param debug [true, false]
  def self.logging(enabled, debug)
    LibTelecom.setup_logging(enabled, debug)
  end

  class Client
    # @!visibility private
    def initialize(bot)
      if LOGGER.instance_variable_get(:@enabled_modes).include?(:debug)
        Telecom.setup_logging(true, true)
      end

      @bot = bot
      @alive = true
    end

    # @param user_id [Integer, String]
    # @param guild_id [Integer, String]
    # @param session_id [String]
    # @note Exposed for custom implementations or testing.
    def update_state_info(user_id, guild_id, session_id)
      @user_id = user_id
      @guild_id = guild_id
      @session_id = session_id
      @client_handle = LibTelecom.create_client(user_id.to_s, guild_id.to_s, session_id)
    end

    # @param endpoint [String]
    # @param token [String]
    # @note Exposed for custom implementations or testing.
    def update_server_info(endpoint, token)
      ready!
      @endpoint = endpoint
      @token = token
      LibTelecom.update_server_info(@client_handle, endpoint, token)
    end

    # @param path [String] path to local file, or other resource that can be handled by ffmpeg
    # @note This method does not block. Calling play mid-stream will replace the current stream.
    def play(path)
      ready!
      playable = LibTelecom.create_avconv_playable(path)
      LibTelecom.play(@client_handle, playable)
      LibTelecom.destroy_avconv_playable(playable)
    end

    # Disconnects this client from the voice websocket and voice UDP service.
    # Additionally, this propagates a voice state update from your bot to disconnect
    # it from the voice channel.
    # Any current playback will be halted.
    def destroy
      @bot.voice_destroy(@guild_id)
      LibTelecom.destroy_client(@client_handle)
      @client_handle = nil
      @alive = false
    end

    # @!visibility private
    def connected?
      @user_id && @guild_id && @session_id && @endpoint && @token
    end

    # @!visibility private
    def ready!
      raise "Attempt to use destroyed client" unless @alive && @client_handle
    end
  end
end
